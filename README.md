@echo off
chcp 437 >nul
setlocal enabledelayedexpansion

REM Get current date and time
for /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') do set "dt=%%a"
set "year=2100"
set "month=!dt:~4,2!"
set "day=!dt:~6,2!"
set "hour=!dt:~8,2!"
set "minute=!dt:~10,2!"
set "second=!dt:~12,2!"

echo Changing file dates to 2100-%month%-%day% %hour%:%minute%:%second%
echo.

REM Process files in current directory
for %%f in (*) do (
    if not "%%f"=="%~nx0" (
        echo Modifying: %%f
        powershell -command "$f=Get-Item '%%f'; $d=Get-Date -Year 2100 -Month !month! -Day !day! -Hour !hour! -Minute !minute! -Second !second!; $f.LastWriteTime=$d; $f.CreationTime=$d; $f.LastAccessTime=$d"
    )
)

echo.
echo Operation completed successfully!
echo All files have been set to: 2100-%month%-%day% %hour%:%minute%:%second%
timeout /t 
