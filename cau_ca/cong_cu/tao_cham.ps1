# Tao file nhi phan su kien cham (struct input_event 64-bit: tv_sec 8 + tv_usec 8 + type 2 + code 2 + value 4 = 24 byte)
# Toa do man hinh ngang 1600x900 -> RAW doc: X = 900 - y, Y = x
param([int]$Sx, [int]$Sy, [string]$OutDir)
function Ev([System.IO.BinaryWriter]$w, [int]$type, [int]$code, [int]$value) { $w.Write([long]0); $w.Write([long]0); $w.Write([uint16]$type); $w.Write([uint16]$code); $w.Write([int]$value) }
$X = 900 - $Sy; $Y = $Sx
$d = [IO.File]::Create((Join-Path $OutDir "cham_xuong.bin")); $w = New-Object IO.BinaryWriter $d
Ev $w 3 57 1; Ev $w 1 330 1; Ev $w 3 53 $X; Ev $w 3 54 $Y; Ev $w 0 0 0; $w.Close()
$u = [IO.File]::Create((Join-Path $OutDir "cham_len.bin")); $w = New-Object IO.BinaryWriter $u
Ev $w 3 57 -1; Ev $w 1 330 0; Ev $w 0 0 0; $w.Close()
"X=$X Y=$Y"
