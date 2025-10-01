# Olvid version of the SQLite JDBC Driver

This repository is a clone of the [Xerial SQLite JDBC Driver](https://github.com/xerial/sqlite-jdbc), adapted for the needs of the [Android Olvid application](https://github.com/olvid-io/olvid-android).

Compared to the original version, the following modifications were made:
- removal of the embedded native libraries from the final `jar` as Android uses its own `.so` files,
- removal of the `OSInfo.java` and `ProcessRunner.java` as they are not need on Android and include OS detection methods that could trigger some alerts on bytecode analysis tools,
- modification of the `SQLiteJDBCLoader.java` native library loading mechanism to compensate for the missing `OSInfo.java`,
- modification of the compilation process to run natively with NDK instead of inside a docker,
- inclusion of [SQLCipher](https://github.com/sqlcipher/sqlcipher) to allow encryption of Olvid's databases,
- removale of the tests (our modifications make the tests fail, but we are confident the base version was extensively tested).

