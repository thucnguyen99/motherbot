@echo off
rem Con trung dai chien: danh N tran (moi tran ban Luoi, 64 diem = dat). Nhan vat o sanh chinh / quang truong con trung.
rem   con_trung.bat      -> 1 tran
rem   con_trung.bat 5    -> 5 tran
set SO=%1
if "%SO%"=="" set SO=1
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cong_cu\con_trung.ps1" -N %SO% %2 %3
