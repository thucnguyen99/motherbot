@echo off
rem Cau ca tu dong (chay rieng, khong theo lich). Nhan vat phai dung san o cho cau tren cau tau.
rem   cau_ca.bat           -> cau 30 con
rem   cau_ca.bat 50        -> cau 50 con
rem   cau_ca.bat 50 -KhongNguoi   -> tat gia lap nguoi (khong nghi, khong lech toa do)
set SO=%1
if "%SO%"=="" set SO=30
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cong_cu\cau_thu.ps1" -N %SO% %2 %3 %4 %5
