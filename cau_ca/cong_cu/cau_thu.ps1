# Cau thu N con tren thiet bi auto (nhan vat phai dung san o cau tau, dang thay nut Bat dau cau ca)
#   -NghiSau 12,20   : cu cau ngau nhien 12-20 con thi nghi 1 lan
#   -NghiGiay 20,90  : moi lan nghi ngau nhien 20-90 giay
#   -KhongNguoi      : tat ngau nhien hoa (lech toa do, thoi gian giu ngon, cho giua cac buoc, nghi)
#   -ThietBi auto    : ten thiet bi MuMu (tu tim cong ADB; thiet bi phai dang bat va dang o cho cau)
# Moi lan chay luu vao ket_qua\cau_thu_<ngay>_<gio>\: log.txt (toan bo nhat ky, ca day ban kinh tung vong) + anh.
# Moi vong bam ghi them 1 dong vao hieu_chinh.csv (ca day ban kinh) de phan tich cac lan Hut / Xuat sac.
# Tu don: xoa thu muc ket_qua\cau_thu_* cu hon -GiuNgay ngay (mac dinh 7, 0 = khong xoa).
#   Khong dung ghi_hinh\ (mau cho cong cu test offline), mau\, hieu_chinh.csv, bu_vong_*.txt.
param([int]$N = 3, [string]$ThietBi = "auto", [string]$Serial = "", [int]$TargetR = 11, [double]$LeadSec = 0.12, [switch]$SlowTap,
      [string[]]$NghiSau = @(12, 20), [string[]]$NghiGiay = @(20, 90), [switch]$KhongNguoi, [int]$GiuNgay = 7)
# Goi qua "powershell -File ... -NghiSau 20,30" thi "20,30" toi day la 1 chuoi (de [int[]] se thanh 2030) -> tu tach thanh [min, max]
function Khoang([string[]]$v) { $n = [int[]]($v -split '[,;\s-]+' | Where-Object { $_ }); if ($n.Count -eq 1) { $n += $n[0] }; @($n[0], $n[1]) }
$NghiSau = Khoang $NghiSau; $NghiGiay = Khoang $NghiGiay
# MuMu cai o C: hay D: tuy may -> tim tren moi o dia
$MuMuDir = Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path $_.Root "Program Files\Netease\MuMuPlayer\nx_main" } |
    Where-Object { Test-Path (Join-Path $_ "MuMuManager.exe") } | Select-Object -First 1
if (-not $MuMuDir) { Write-Host "Khong tim thay MuMu (<o dia>:\Program Files\Netease\MuMuPlayer\nx_main)"; exit 1 }
$adb = Join-Path $MuMuDir "adb.exe"
$out = Join-Path (Split-Path $PSScriptRoot) ("ket_qua\cau_thu_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$LogFile = Join-Path $out "log.txt"
# In ra man hinh + ghi vao log.txt
function Say([string]$m, [switch]$NoTime) {
    $line = if ($NoTime) { $m } else { "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m }
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
Say ("===== CAU CA {0:yyyy-MM-dd HH:mm:ss}: N={1} ThietBi={2} TargetR={3} LeadSec={4} GiaLapNguoi={5} BamNhanh={6} NghiSau={7} NghiGiay={8} =====" -f (Get-Date), $N, $ThietBi, $TargetR, $LeadSec, (-not $KhongNguoi), (-not $SlowTap), ($NghiSau -join '-'), ($NghiGiay -join '-')) -NoTime
if ($GiuNgay -gt 0) {
    try {
        $cut = (Get-Date).AddDays(-$GiuNgay)
        $old = @(Get-ChildItem (Split-Path $out) -Directory -Filter "cau_thu_*" -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $out -and $_.LastWriteTime -lt $cut })
        if ($old.Count) {
            $mb = [math]::Round((($old | ForEach-Object { Get-ChildItem $_.FullName -Recurse -File }) | Measure-Object Length -Sum).Sum / 1MB, 1)
            $old | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Say "Don ket qua cu: xoa $($old.Count) thu muc cau_thu_* cu hon $GiuNgay ngay ($mb MB)"
        }
    } catch { Say "Don ket qua cu loi: $($_.Exception.Message)" }
}

if (-not $Serial) {
    # cong ADB doi moi lan MuMu khoi dong -> hoi MuMuManager
    $info = (& (Join-Path $MuMuDir "MuMuManager.exe") info -v all | Out-String | ConvertFrom-Json).PSObject.Properties.Value | Where-Object { $_.name -eq $ThietBi } | Select-Object -First 1
    if (-not $info) { Say "Khong thay thiet bi MuMu ten '$ThietBi'"; exit 1 }
    if (-not $info.is_android_started -or -not $info.adb_port) { Say "Thiet bi '$ThietBi' chua bat. Mo MuMu, vao game, dung o cho cau roi chay lai."; exit 1 }
    $Serial = "$($info.adb_host_ip):$($info.adb_port)"
    & $adb connect $Serial | Out-Null
    Say "Thiet bi '$ThietBi' -> ADB $Serial"
}
$src = (Get-Content (Join-Path $PSScriptRoot "Ring.cs") -Raw) + "`n" + (Get-Content (Join-Path $PSScriptRoot "Fisher.cs") -Raw)
# gop using len dau. Tach dong theo ca CRLF lan LF: git (core.autocrlf) co the de Ring.cs LF, Fisher.cs CRLF
# -> "using System;`r" khac "using System;" -> trung using -> loi bien dich (gap 19/11 sau khi gop code).
$srcLines = $src -split "`r?`n"
$usings = ($srcLines | Where-Object { $_ -match '^using ' } | ForEach-Object { $_.Trim() } | Sort-Object -Unique) -join "`n"
$body = ($srcLines | Where-Object { $_ -notmatch '^using ' }) -join "`n"
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition ($usings + "`n" + $body)
$f = New-Object Fisher $adb, $Serial, $out, (Join-Path (Split-Path $PSScriptRoot) "mau")
$f.TargetR = $TargetR; $f.TapLatency = $LeadSec; $f.FastTap = -not $SlowTap; $f.Human = -not $KhongNguoi

# hieu_chinh.csv: moi vong bam 1 dong. Cot moi (18/11 15:40): nguoi (1 = gia lap nguoi), vet_ban_kinh ("giay:ban_kinh ..."), lan_chay (thu muc ket_qua)
$f.CsvPath = Join-Path (Split-Path $PSScriptRoot) "hieu_chinh.csv"
# Cot loai_vong (18/11 22:40): "loai:bu_px:khoang_cach_do_s" luc bam (xem bu vong tu hoc trong Fisher.cs)
$header = "gio,lan,vong,r_du_doan,r_cuoi,toc_do,ngoai_suy_s,TargetR,TapLatency,ket_qua,nguoi,vet_ban_kinh,lan_chay,loai_vong"
if (-not (Test-Path $f.CsvPath)) { $header | Set-Content $f.CsvPath -Encoding UTF8 }
else {
    $lines = [IO.File]::ReadAllLines($f.CsvPath)
    if ($lines.Count -and $lines[0] -ne $header) { $lines[0] = $header; [IO.File]::WriteAllLines($f.CsvPath, $lines) }
}

$f.Log = [Action[string]]{ param($m) Say $m }
# Muc bu tung loai vong tu hoc theo ket qua, luu rieng tung may (do tre moi may khac nhau)
$f.LoadAdj((Join-Path (Split-Path $PSScriptRoot) ("bu_vong_" + $env:COMPUTERNAME + ".txt")))
Say "Bu vong (px, + = bam som): $($f.AdjText())"
$tong = 0; $duoc = 0
try {
    $f.Start()
    $nextBreak = Get-Random -Minimum $NghiSau[0] -Maximum ($NghiSau[1] + 1)
    for ($i = 1; $i -le $N; $i++) {
        Say "===== Lan $i/$N =====" -NoTime
        $r = $f.CastOnce($i)
        Say "  -> $r" -NoTime
        if ($r -like 'LOI*' -or $r -like 'HET MOI*' -or $r -like 'BALO DAY*') { break }
        $tong++; if ($r -eq 'OK') { $duoc++ }
        if (-not $KhongNguoi -and $i -lt $N -and $i -ge $nextBreak) {
            $s = Get-Random -Minimum $NghiGiay[0] -Maximum ($NghiGiay[1] + 1)
            Say "Nghi $s giay (gia lap nguoi)"
            Start-Sleep -Seconds $s
            $nextBreak = $i + (Get-Random -Minimum $NghiSau[0] -Maximum ($NghiSau[1] + 1))
        }
    }
} catch {
    Say "LOI KHONG MONG DOI: $($_.Exception.InnerException.Message) $($_.Exception.Message)"
} finally { $f.Stop() }
Say ("Cau duoc: {0}/{1} con. Cham diem cac vong: {2}" -f $duoc, $tong, (($f.Ratings.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', ')) -NoTime
Say "Bu vong sau lan chay: $($f.AdjText())" -NoTime
Say "Anh + log: $out" -NoTime
