@echo off
:: Args: addon-folder-path, output-file-path

echo Creating GMA file

FOR /F "tokens=2* skip=2" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 4000" /v "InstallLocation"') do set GmodPath=%%b

cd "%GmodPath%\bin"
gmad.exe create -folder "%1" -out "%2"

echo Finished