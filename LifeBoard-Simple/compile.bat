@echo off
REM ============================================================
REM LifeBoard - Compile Script
REM 
REM This script compiles all Java source files.
REM Requires: Java JDK 11 or higher
REM ============================================================

echo ============================================
echo   LifeBoard Compiler
echo ============================================
echo.

REM Change to script directory
cd /d "%~dp0"

REM Check if Java is available
where javac >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Java JDK is not installed or not in PATH.
    echo Please install Java JDK 11 or higher.
    pause
    exit /b 1
)

REM Create lib directory if it doesn't exist
if not exist "lib" mkdir lib

REM Download SQLite JDBC driver if not present (using older version without SLF4J dependency)
if not exist "lib\sqlite-jdbc.jar" (
    echo Downloading SQLite JDBC driver...
    powershell -Command "Invoke-WebRequest -Uri 'https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.36.0.3/sqlite-jdbc-3.36.0.3.jar' -OutFile 'lib\sqlite-jdbc.jar'" 2>nul
    if %ERRORLEVEL% neq 0 (
        echo WARNING: Could not download SQLite driver automatically.
        echo Please download sqlite-jdbc-3.36.0.3.jar from:
        echo https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.36.0.3/
        echo and save it as 'lib\sqlite-jdbc.jar'
        pause
        exit /b 1
    ) else (
        echo SQLite driver downloaded successfully.
    )
)

REM Create output directory
if not exist "out" mkdir out

echo.
echo Compiling Java source files...
echo.

REM Compile all Java files
javac -d out -cp "lib\sqlite-jdbc.jar" -sourcepath src src\Main.java src\db\Database.java src\util\*.java src\handlers\*.java

if %ERRORLEVEL% equ 0 (
    echo.
    echo ============================================
    echo   Compilation successful!
    echo   Run 'run.bat' to start the server.
    echo ============================================
) else (
    echo.
    echo ============================================
    echo   Compilation failed. Check errors above.
    echo ============================================
    pause
    exit /b 1
)

pause
