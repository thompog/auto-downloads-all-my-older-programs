@echo off
setlocal enabledelayedexpansion

:: Configuration - change these
set "MANIFEST_URL=https://raw.githubusercontent.com/thompog/auto-downloads-all-my-older-programs/refs/heads/main/manifest.txt"
set "INSTALL_DIR=%USERPROFILE%\MyPrograms"
set "LOG=%INSTALL_DIR%\multi_updater.log"
set "TEMP_MANIFEST=%temp%\manifest.txt"

:: Ensure install dir exists
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo [%date% %time%] Starting updater... >> "%LOG%"

:: Download manifest
echo [INFO] Downloading manifest...
curl -fsS -o "%TEMP_MANIFEST%" "%MANIFEST_URL%" || (
    echo [ERROR] Failed to download manifest: %MANIFEST_URL% >> "%LOG%"
    echo Manifest download failed. See log: %LOG%
    pause
    exit /b 1
)

:: Parse and process manifest
for /f "usebackq delims=" %%L in ("%TEMP_MANIFEST%") do (
    set "line=%%L"
    rem skip comments and blank lines
    if not "!line:~0,1!"=="#" if not "!line!"=="" (
        for /f "tokens=1-3 delims=|" %%A in ("!line!") do (
            set "url=%%~A"
            set "fname=%%~B"
            set "fhash=%%~C"
            for /f "tokens=* delims= " %%x in ("!fname!") do set "fname=%%x"
            for /f "tokens=* delims= " %%x in ("!fhash!") do set "fhash=%%x"
            if "!fname!"=="" (
                for %%U in ("!url!") do set "fname=%%~nxU"
            )
            set "target=%INSTALL_DIR%\!fname!"

            echo -------------------------------------------------- >> "%LOG%"
            echo [%date% %time%] Processing: !url! -> !target! >> "%LOG%"
            echo [INFO] Downloading !url! ...
            curl -L -f -o "!target!" "!url!" 2>> "%LOG%"
            if errorlevel 1 (
                echo [ERROR] Download failed for !url! >> "%LOG%"
                goto continue_loop
            )

            if not "!fhash!"=="" (
                for /f "usebackq delims=" %%H in (`powershell -NoProfile -Command "Get-FileHash -Algorithm SHA256 -Path '%target%' | Select -ExpandProperty Hash"`) do set "computed=%%H"
                if /i "!computed!" NEQ "!fhash!" (
                    echo [ERROR] Hash mismatch for !fname! >> "%LOG%"
                    echo Expected: !fhash! >> "%LOG%"
                    echo Actual:   !computed! >> "%LOG%"
                    del /f /q "!target!" 2>nul
                    goto continue_loop
                ) else (
                    echo [OK] Hash verified for !fname! >> "%LOG%"
                )
            ) else (
                echo [WARN] No hash specified for !fname! >> "%LOG%"
            )

            echo [%date% %time%] Installed !fname! >> "%LOG%"
            echo Installed: !target!
            :continue_loop
        )
    )
)

echo [%date% %time%] Updater finished. >> "%LOG%"
echo Done. See log: %LOG%
pause

endlocal
