include Makefile.common

RESOURCE_DIR = src/main/resources
NDK=android-ndk-r27d
ANDROID_NDK_HOME=`pwd`/$(NDK)
TOOLCHAIN=$(ANDROID_NDK_HOME)/toolchains/llvm/prebuilt/linux-x86_64

.phony: all package native native-all deploy

all: jni-header package
	echo "Now run ./compile"

deploy: 
	mvn package deploy -DperformRelease=true

DOCKER_RUN_OPTS=--rm
MVN:=mvn
CODESIGN:=docker run $(DOCKER_RUN_OPTS) -v $$PWD:/workdir gotson/rcodesign sign
SRC:=src/main/java
JAVA_CLASSPATH:=$(TARGET)/classpath/slf4j-api.jar
SQLITE_OUT:=$(TARGET)/$(sqlite)-$(OS_NAME)-$(OS_ARCH)
SQLITE_OBJ?=$(SQLITE_OUT)/sqlite3.o
SQLITE_ARCHIVE:=$(TARGET)/$(sqlite)-amal.zip
SQLITE_UNPACKED:=$(TARGET)/sqlite-unpack.log
SQLITE_SOURCE?=$(TARGET)/$(SQLITE_AMAL_PREFIX)
SQLCIPHER_SOURCE?=sqlcipher
SQLITE_HEADER?=$(SQLITE_SOURCE)/sqlite3.h
ifneq ($(SQLITE_SOURCE),$(TARGET)/$(SQLITE_AMAL_PREFIX))
	created := $(shell touch $(SQLITE_UNPACKED))
endif

SQLITE_INCLUDE := $(shell dirname "$(SQLITE_HEADER)")

CCFLAGS:= -I$(SQLITE_OUT) -I$(SQLITE_INCLUDE) $(CCFLAGS) $(OTHERFLAGS)

$(SQLITE_ARCHIVE):
	@mkdir -p $(@D)
	curl -L --max-redirs 0 -f -o$@ https://www.sqlite.org/2024/$(SQLITE_AMAL_PREFIX).zip || \
	curl -L --max-redirs 0 -f -o$@ https://www.sqlite.org/2023/$(SQLITE_AMAL_PREFIX).zip || \
	curl -L --max-redirs 0 -f -o$@ https://www.sqlite.org/2022/$(SQLITE_AMAL_PREFIX).zip || \
	curl -L --max-redirs 0 -f -o$@ https://www.sqlite.org/2021/$(SQLITE_AMAL_PREFIX).zip || \
	curl -L --max-redirs 0 -f -o$@ https://www.sqlite.org/2020/$(SQLITE_AMAL_PREFIX).zip || \
	curl -L --max-redirs 0 -f -o$@ https://www.sqlite.org/$(SQLITE_AMAL_PREFIX).zip || \
	curl -L --max-redirs 0 -f -o$@ https://www.sqlite.org/$(SQLITE_OLD_AMAL_PREFIX).zip

$(SQLITE_UNPACKED): $(SQLITE_ARCHIVE)
	unzip -qo $< -d $(TARGET)/tmp.$(version)
	(mv $(TARGET)/tmp.$(version)/$(SQLITE_AMAL_PREFIX) $(TARGET) && rmdir $(TARGET)/tmp.$(version)) || mv $(TARGET)/tmp.$(version)/ $(TARGET)/$(SQLITE_AMAL_PREFIX)
	touch $@

$(JAVA_CLASSPATH):
	@mkdir -p $(@D)
	curl -L -f -o$@ https://search.maven.org/remotecontent?filepath=org/slf4j/slf4j-api/1.7.36/slf4j-api-1.7.36.jar

$(TARGET)/common-lib/org/sqlite/%.class: src/main/java/org/sqlite/%.java
	@mkdir -p $(@D)
	$(JAVAC) -source 1.6 -target 1.6 -sourcepath $(SRC) -d $(TARGET)/common-lib $<

jni-header: $(TARGET)/common-lib/NativeDB.h

$(TARGET)/common-lib/NativeDB.h: src/main/java/org/sqlite/core/NativeDB.java $(JAVA_CLASSPATH)
	@mkdir -p $(TARGET)/common-lib
	$(JAVAC) -cp $(JAVA_CLASSPATH) -d $(TARGET)/common-lib -sourcepath $(SRC) -h $(TARGET)/common-lib src/main/java/org/sqlite/core/NativeDB.java
	mv target/common-lib/org_sqlite_core_NativeDB.h target/common-lib/NativeDB.h

test:
	mvn test

clean: clean-native clean-java clean-tests

$(SQLITE_OUT)/sqlite3.o : $(SQLITE_UNPACKED)
	@mkdir -p $(@D)
	export ANDROID_NDK_HOME=$(ANDROID_NDK_HOME); ./build-openssl-libraries.sh 21 21 ./openssl $(SQLITE_OUT) $(OS_ARCH)
	cp openssl/libcrypto_1_1.so $(SQLITE_OUT)/libcrypto_1_1.so
	cd sqlcipher; CPPFLAGS="$(SQLITE_FLAGS)" ./configure --with-crypto-lib=none; make
	cp $(SQLCIPHER_SOURCE)/sqlite3.c $(SQLITE_OUT)/sqlite3.c
	cp $(SQLCIPHER_SOURCE)/sqlite3.h $(SQLITE_OUT)/sqlite3.h
	perl -p -e "s/sqlite3_api;/sqlite3_api = 0;/g" \
	    $(SQLCIPHER_SOURCE)/sqlite3ext.h > $(SQLITE_OUT)/sqlite3ext.h
	$(CC) -o $@ -c $(CCFLAGS) -Iopenssl/include \
	    -DSQLITE_ENABLE_LOAD_EXTENSION=1 \
	    -DSQLITE_HAVE_ISNAN \
	    -DHAVE_USLEEP=1 \
	    -DSQLITE_ENABLE_COLUMN_METADATA \
	    -DSQLITE_CORE \
	    -DSQLITE_ENABLE_FTS3 \
	    -DSQLITE_ENABLE_FTS3_PARENTHESIS \
	    -DSQLITE_ENABLE_FTS5 \
	    -DSQLITE_ENABLE_RTREE \
	    -DSQLITE_ENABLE_STAT4 \
	    -DSQLITE_ENABLE_DBSTAT_VTAB \
	    -DSQLITE_ENABLE_MATH_FUNCTIONS \
	    -DSQLITE_THREADSAFE=1 \
	    -DSQLITE_DEFAULT_MEMSTATUS=0 \
	    -DSQLITE_DEFAULT_FILE_PERMISSIONS=0666 \
	    -DSQLITE_MAX_VARIABLE_NUMBER=250000 \
	    -DSQLITE_MAX_MMAP_SIZE=1099511627776 \
	    -DSQLITE_MAX_LENGTH=2147483647 \
	    -DSQLITE_MAX_COLUMN=32767 \
	    -DSQLITE_MAX_SQL_LENGTH=1073741824 \
	    -DSQLITE_MAX_FUNCTION_ARG=127 \
	    -DSQLITE_MAX_ATTACHED=125 \
	    -DSQLITE_MAX_PAGE_COUNT=4294967294 \
	    -DSQLITE_DISABLE_PAGECACHE_OVERFLOW_STATS \
	    -DSQLITE_HAS_CODEC \
	    -DSQLITE_TEMP_STORE=2 \
	    -DSQLCIPHER_CRYPTO_OPENSSL \
	    $(SQLITE_FLAGS) \
	    $(SQLITE_OUT)/sqlite3.c

$(SQLCIPHER_SOURCE)/sqlite3.h: $(SQLITE_UNPACKED)

$(SQLITE_OUT)/$(LIBNAME): $(SQLITE_HEADER) $(SQLITE_OBJ) $(SRC)/org/sqlite/core/NativeDB.c $(TARGET)/common-lib/NativeDB.h
	@mkdir -p $(@D)
	$(CC) $(CCFLAGS) -I $(TARGET)/common-lib -c -o $(SQLITE_OUT)/NativeDB.o $(SRC)/org/sqlite/core/NativeDB.c
	$(CC) $(CCFLAGS) -o $@ $(SQLITE_OUT)/NativeDB.o $(SQLITE_OBJ) $(LINKFLAGS) -L$(SQLITE_OUT) -l:libcrypto_1_1.so
# Workaround for strip Protocol error when using VirtualBox on Mac
	cp $@ /tmp/$(@F)
	$(STRIP) /tmp/$(@F)
	cp /tmp/$(@F) $@

NATIVE_DIR=src/main/resources/org/sqlite/native/$(OS_NAME)/$(OS_ARCH)
NATIVE_TARGET_DIR:=$(TARGET)/classes/org/sqlite/native/$(OS_NAME)/$(OS_ARCH)
NATIVE_DLL:=$(NATIVE_DIR)/$(LIBNAME)

# For cross-compilation, install docker. See also https://github.com/dockcross/dockcross
# Disabled linux-armv6 build because of this issue; https://github.com/dockcross/dockcross/issues/190
#native-all: native win32 win64 mac64 linux32 linux64 linux-arm linux-armv7 linux-arm64 linux-android-arm linux-ppc64 alpine-linux64
native-all: android-arm android-arm64 android-x86 android-x86_64

native: $(NATIVE_DLL)

$(NATIVE_DLL): $(SQLITE_OUT)/$(LIBNAME)
	@mkdir -p $(@D)
	cp $< $@
	@mkdir -p $(NATIVE_TARGET_DIR)
	cp $< $(NATIVE_TARGET_DIR)/$(LIBNAME)

package:
	rm -rf target/dependency-maven-plugin-markers
	$(MVN) package

clean-native:
	rm -rf $(SQLITE_OUT)

clean-java:
	rm -rf $(TARGET)/*classes
	rm -rf $(TARGET)/common-lib/*
	rm -rf $(TARGET)/sqlite-jdbc-*jar

clean-tests:
	rm -rf $(TARGET)/{surefire*,testdb.jar*}

android-x86_64: CC=$(TOOLCHAIN)/bin/x86_64-linux-android21-clang
android-x86_64: STRIP=$(TOOLCHAIN)/bin/llvm-strip
android-x86_64: OTHERFLAGS=-fPIE -pie -lm -lc -landroid -ldl -llog
android-x86_64: LINKFLAGS=-shared -static-libgcc -pthread -lm -Wl -z max-page-size=16384
android-x86_64: OS_NAME=Linux
android-x86_64: OS_ARCH=android-x86_64
android-x86_64: $(SQLITE_UNPACKED) jni-header clean-native native

android-x86: CC=$(TOOLCHAIN)/bin/i686-linux-android21-clang
android-x86: STRIP=$(TOOLCHAIN)/bin/llvm-strip
android-x86: OTHERFLAGS=-fPIE -pie -lm -lc -landroid -ldl -llog
android-x86: LINKFLAGS=-shared -static-libgcc -pthread -lm -Wl -z max-page-size=16384
android-x86: OS_NAME=Linux
android-x86: OS_ARCH=android-x86
android-x86: $(SQLITE_UNPACKED) jni-header clean-native native

android-arm: CC=$(TOOLCHAIN)/bin/armv7a-linux-androideabi21-clang
android-arm: STRIP=$(TOOLCHAIN)/bin/llvm-strip
android-arm: OTHERFLAGS=-fPIE -pie -lm -lc -landroid -ldl -llog
android-arm: LINKFLAGS=-shared -static-libgcc -pthread -lm -Wl -z max-page-size=16384
android-arm: OS_NAME=Linux
android-arm: OS_ARCH=android-arm
android-arm: $(SQLITE_UNPACKED) jni-header clean-native native

android-arm64: CC=$(TOOLCHAIN)/bin/aarch64-linux-android21-clang
android-arm64: STRIP=$(TOOLCHAIN)/bin/llvm-strip
android-arm64: OTHERFLAGS=-fPIE -pie -lm -lc -landroid -ldl -llog
android-arm64: LINKFLAGS=-shared -static-libgcc -pthread -lm -Wl -z max-page-size=16384
android-arm64: OS_NAME=Linux
android-arm64: OS_ARCH=android-arm64
android-arm64: $(SQLITE_UNPACKED) jni-header clean-native native



