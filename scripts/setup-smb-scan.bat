@echo off
chcp 65001 >nul
title SMB 掃描資料夾自動設定 v2

:: ============================================
::  SMB 掃描資料夾自動設定 v2
::  用法：右鍵 → 以系統管理員身分執行
::  需要改的只有下面三個變數
:: ============================================
set "SCAN_USER=scan"
set "FOLDER=C:\Scan"
set "SHARE=Scan"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [錯誤] 請右鍵選「以系統管理員身分執行」
    pause
    exit /b
)

echo.
echo ============================================
echo   帳號: %SCAN_USER%   資料夾: %FOLDER%   共用名: %SHARE%
echo ============================================
echo 密碼請避開 ^& ^% ^^ ^! ^| 等符號，建議 14 碼以內
set /p "PW=請輸入 %SCAN_USER% 帳號密碼: "
if "%PW%"=="" (
    echo [錯誤] 密碼不能空白
    pause
    exit /b
)

:: ---- 1. 帳號 ----
echo.
echo [1/7] 建立帳號...
net user %SCAN_USER% >nul 2>&1
if %errorlevel%==0 (
    net user %SCAN_USER% "%PW%" >nul
) else (
    net user %SCAN_USER% "%PW%" /add >nul
)
if %errorlevel% neq 0 (
    echo [錯誤] 帳號建立失敗，請檢查密碼原則
    pause
    exit /b
)
echo       OK

:: ---- 2. 密碼永不過期 ----
echo [2/7] 密碼永不過期...
powershell -NoProfile -Command "Set-LocalUser -Name '%SCAN_USER%' -PasswordNeverExpires $true"
echo       OK

:: ---- 3. NTFS 權限 ----
echo [3/7] 資料夾 + NTFS 修改權限...
if not exist "%FOLDER%" mkdir "%FOLDER%"
icacls "%FOLDER%" /grant "%SCAN_USER%:(OI)(CI)M" >nul
echo       OK

:: ---- 4. 共用權限 ----
echo [4/7] 網路共用 + 變更權限...
net share %SHARE% /delete /y >nul 2>&1
net share %SHARE%="%FOLDER%" /grant:%SCAN_USER%,CHANGE >nul
echo       OK

:: ---- 5. 網路類型改私人 ----
echo [5/7] 檢查網路類型...
set "PUBCOUNT=0"
for /f %%a in ('powershell -NoProfile -Command "@(Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' }).Count"') do set "PUBCOUNT=%%a"
if %PUBCOUNT% GTR 0 (
    echo       目前是公用網路，共用會被擋
    choice /c YN /m "      要改成私人網路嗎"
    if errorlevel 2 (
        echo       略過，掃描可能會失敗
    ) else (
        powershell -NoProfile -Command "Get-NetConnectionProfile | Where-Object { $_.NetworkCategory -eq 'Public' } | Set-NetConnectionProfile -NetworkCategory Private"
        echo       已改為私人網路
    )
) else (
    echo       OK
)

:: ---- 6. 防火牆：只開私人/網域 ----
echo [6/7] 防火牆放行檔案及印表機共用 - 僅私人/網域...
powershell -NoProfile -Command "Get-NetFirewallRule -Group '@FirewallAPI.dll,-28502' | Where-Object { $_.Profile -match 'Private|Domain' } | Enable-NetFirewallRule" >nul 2>&1
echo       OK

:: ---- 7. 環境檢查 ----
echo [7/7] 環境檢查
echo.
echo   --- IP 與 DHCP 狀態 - DHCP=Enabled 代表 IP 可能會變 ---
powershell -NoProfile -Command "Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object { '  {0}  [{1}]  DHCP={2}' -f $_.IPAddress,$_.InterfaceAlias,(Get-NetIPInterface -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4).Dhcp }"
echo.
echo   --- SMB 版本 ---
powershell -NoProfile -Command "Get-SmbServerConfiguration | ForEach-Object { '  SMB1: {0}   SMB2/3: {1}' -f $_.EnableSMB1Protocol,$_.EnableSMB2Protocol }"

:: ---- 輸出資訊檔 ----
set "INFO=%FOLDER%\_印表機設定資訊.txt"
(
    echo 印表機 SMB 設定資訊
    echo ==========================
    echo 電腦名稱  : %COMPUTERNAME%
    echo 共用名稱  : %SHARE%
    echo 使用者名稱: %COMPUTERNAME%\%SCAN_USER%
    echo.
    echo [Canon] 主機名稱填 IP，資料夾路徑填 \%SHARE%
    echo [HP]    網路路徑填 \\IP\%SHARE%
    echo.
    echo 注意：DHCP=Enabled 時 IP 可能變動，
    echo 請做路由器 DHCP 保留，或改用印表機進階空間
    echo 密碼不記錄在此檔案
) > "%INFO%"

echo.
echo ============================================
echo   完成！印表機端請填：
echo   主機 / 路徑 : \\上面的IP\%SHARE%
echo   使用者名稱  : %COMPUTERNAME%\%SCAN_USER%
echo   密碼        : 剛剛輸入的那組
echo.
echo   DHCP=Enabled → 記得處理 IP 固定問題
echo   資訊檔: %INFO%
echo ============================================
pause
