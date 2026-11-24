@echo off
rem Tuong Da (pho ban tuong khong lo): danh N tran. Nhan vat dang o sanh chinh (hoac phong cho).
rem   tuong_da.bat        -> 1 tran
rem   tuong_da.bat 5      -> 5 tran
set SO=%1
if "%SO%"=="" set SO=1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cong_cu\tuong_da.ps1" -N %SO% %2 %3
