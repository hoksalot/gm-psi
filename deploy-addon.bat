@echo off
:: Args: path-to-gma, addon-workshop-id, changes-text, correct-branch

git branch | find "* %4" > nul & if errorlevel 1 (
    echo Error: For safety, you may only deploy from this branch: %4
    exit 1
)

FOR /F "tokens=2* skip=2" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Steam App 4000" /v "InstallLocation"') do set GmodPath=%%b

cd "%GmodPath%\bin"

gmpublish.exe update -addon "%1" -id "%2" -changes "%3"

echo New version deployed

echo Cleaning up %1
del "%1"
echo Finished