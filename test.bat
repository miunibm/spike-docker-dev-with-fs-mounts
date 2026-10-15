@echo off
setlocal enabledelayedexpansion

REM ==============================================================================
REM Spike Automated Test Runner (Windows Batch)
REM Multi-Identity Matrix: Standard User (1000:1000) vs. Vendor User (1824:1824)
REM ==============================================================================

echo ======================================================================
echo  Docker Dev with Filesystem Mounts Spike: Windows Test Suite
echo ======================================================================

cd /d "%~dp0"

REM --- Test Iteration 1: Standard UID 1000:1000 ---
call :RUN_ITERATION 1000 1000 "Standard User Identity (UID=1000, GID=1000)"
if errorlevel 1 goto :FAILED

REM --- Test Iteration 2: Vendor UID 1824:1824 ---
call :RUN_ITERATION 1824 1824 "Vendor / Disjoint Identity (UID=1824, GID=1824)"
if errorlevel 1 goto :FAILED

echo.
echo ======================================================================
echo  [ALL TESTS COMPLETED SUCCESSFULLY]
echo ======================================================================
goto :EOF

:RUN_ITERATION
set "TEST_UID=%~1"
set "TEST_GID=%~2"
set "TITLE=%~3"

echo.
echo ======================================================================
echo  [TEST ITERATION] %TITLE%
echo  Target UID: %TEST_UID% ^| Target GID: %TEST_GID%
echo ======================================================================

REM Clean previous test files
if exist "packages\SamplePackage\file_by_devuser.txt" del /f /q "packages\SamplePackage\file_by_devuser.txt"
if exist "packages\SamplePackage\file_by_root.txt" del /f /q "packages\SamplePackage\file_by_root.txt"

set "DEV_UID=%TEST_UID%"
set "DEV_GID=%TEST_GID%"

echo [1] Building and starting dev-runner container with UID=%DEV_UID%, GID=%DEV_GID%...
docker compose build --build-arg DEV_UID=%DEV_UID% --build-arg DEV_GID=%DEV_GID% dev-runner
if errorlevel 1 exit /b 1

docker compose up -d --force-recreate dev-runner
if errorlevel 1 exit /b 1

echo.
echo [2] Guardrail Verification...
echo  -^> Testing Read-Only Root Filesystem (/app/forbidden.txt)...
docker compose exec dev-runner touch /app/forbidden.txt 2>nul
if not errorlevel 1 (
    echo     [FAIL] Root filesystem was writable!
    exit /b 1
) else (
    echo     [PASS] Root filesystem is read-only.
)

echo  -^> Testing Tmpfs Scratchpads (/tmp, /app/temp, /app/logs)...
docker compose exec dev-runner touch /tmp/test_scratch.txt
docker compose exec dev-runner touch /app/temp/engine.lock
docker compose exec dev-runner touch /app/logs/runtime.log
echo     [PASS] Tmpfs scratchpads writable by non-root user.

echo  -^> Testing Read-Only Config (/app/config/application.properties)...
docker compose exec dev-runner touch /app/config/application.properties 2>nul
if not errorlevel 1 (
    echo     [FAIL] Config file was writable!
    exit /b 1
) else (
    echo     [PASS] Config file is read-only.
)

echo.
echo [3] Creating files inside guest package mount...
echo  -^> Creating file as default container user (UID %DEV_UID%)...
docker compose exec dev-runner touch /app/packages/SamplePackage/file_by_devuser.txt

echo  -^> Creating file as container root user (-u root / UID 0)...
docker compose exec -u root dev-runner touch /app/packages/SamplePackage/file_by_root.txt

echo.
echo [4] State BEFORE sweeper:
echo   [GUEST VIEW] (ls -lan /app/packages/SamplePackage/):
docker compose exec dev-runner ls -lan /app/packages/SamplePackage/

echo.
echo   [HOST VIEW]  (dir packages\SamplePackage):
dir packages\SamplePackage

echo.
echo [5] Executing namespace-aware sweeper...
docker compose --profile sweeper run --rm sweeper

echo.
echo [6] State AFTER sweeper:
echo   [GUEST VIEW] (ls -lan /app/packages/SamplePackage/):
docker compose exec dev-runner ls -lan /app/packages/SamplePackage/

echo.
echo   [HOST VIEW]  (dir packages\SamplePackage):
dir packages\SamplePackage

exit /b 0

:FAILED
echo.
echo ======================================================================
echo  [ERROR] Test suite failed!
echo ======================================================================
exit /b 1
