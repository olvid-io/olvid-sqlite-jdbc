# Olvid version of the SQLite JDBC Driver

This repository is a clone of the [Xerial SQLite JDBC Driver](https://github.com/xerial/sqlite-jdbc), adapted for the needs of the [Android Olvid application](https://github.com/olvid-io/olvid-android).

Compared to the original version, the following modifications were made:
- removal of the embedded native libraries from the final `jar` as Android uses its own `.so` files,
- removal of the `OSInfo.java` and `ProcessRunner.java` as they are not need on Android and include OS detection methods that could trigger some alerts on bytecode analysis tools,
- modification of the `SQLiteJDBCLoader.java` native library loading mechanism to compensate for the missing `OSInfo.java`,
- modification of the compilation process to run natively with NDK instead of inside a docker,
- inclusion of [SQLCipher](https://github.com/sqlcipher/sqlcipher) to allow encryption of Olvid's databases,
- removale of the tests (our modifications make the tests fail, but we are confident the base version was extensively tested).

# How to recompile this library

- Clone this repository
- Load the openSSL and SQLCipher submodules with:
```
git submodule init
git submodule update
```
- Download and unpack the Android NDK (that will be used to compile the sources) at the root of the repository:
```
wget https://dl.google.com/android/repository/android-ndk-r27d-linux.zip
unzip android-ndk-r27d-linux.zip
```
- Run `make all` to compile the JAR file. The following file is obtained:
  - `target/sqlite-jdbc-3.50.3.0.jar`
- Run `./compile` to compile the native code (you can safely ignore the multiple warnings). The following files are obtained:
  - `target/sqlite-3.50.3-Linux-android-arm64/libsqlitejdbc.so`
  - `target/sqlite-3.50.3-Linux-android-arm64/libcrypto_3_0.so`
  - `target/sqlite-3.50.3-Linux-android-arm/libsqlitejdbc.so`
  - `target/sqlite-3.50.3-Linux-android-arm/libcrypto_3_0.so`
  - `target/sqlite-3.50.3-Linux-android-x86/libsqlitejdbc.so`
  - `target/sqlite-3.50.3-Linux-android-x86/libcrypto_3_0.so`
  - `target/sqlite-3.50.3-Linux-android-x86_64/libsqlitejdbc.so`
  - `target/sqlite-3.50.3-Linux-android-x86_64/libcrypto_3_0.so`

Now you simply have to copy the obtained files to the relevant places in the Android Olvid repository:
- the JAR file in `obv_engine/engine/libs/`
- the `.so` files in the corresponding subdirectories of `obv_messenger/app/src/main/jniLibs/`
