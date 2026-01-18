@echo off
REM ============================================================
REM LifeBoard - Run Script
REM 
REM This script starts the LifeBoard server.
REM The application will be available at http://localhost:8080
REM ============================================================

echo ============================================
echo   Starting LifeBoard Server...
echo ============================================
echo.

REM Change to the script's directory
cd /d "%~dp0"

REM Check if compiled
if not exist "out\lifeboard\Main.class" (
    echo ERROR: Application not compiled.
    echo Please run compile.bat first.
    pause
    exit /b 1
)

REM Check for SQLite driver
if not exist "lib\sqlite-jdbc.jar" (
    echo ERROR: SQLite JDBC driver not found.
    echo Please run compile.bat first to download dependencies.
    pause
    exit /b 1
)

echo Using classpath: out;lib\sqlite-jdbc.jar
echo.

REM Run the application with full paths
java -cp "%~dp0out;%~dp0lib\sqlite-jdbc.jar" lifeboard.Main

pause
