# =====================================================================
#  Con trung dai chien (bat sau bo): danh N tran. Moi tran BAT DU 64 DIEM = DAT, thap hon = khong dat.
#  Chay rieng nhu cau ca: thiet bi MuMu dang bat, dang o SANH CHINH / bang chon che do / QUANG TRUONG con trung.
#  Hoc tu ban ghi lam mau 24/11 07:56 (hoc_mau\bat_bo_20261124_075614, ghi chu: con_trung\GHI_CHU.md):
#   Sanh -> the che do -> "Con trung Dai chien" -> QUANG TRUONG (bo rua / buom di lang thang, "Dem nguoc")
#   -> het dem nguoc thi cham vao BO RUA -> VS -> TRAN (3 luot, moi luot 15 giay, PASS sang = toi luot minh):
#      di chuyen (giu nut > goc duoi trai) toi khi thanh mau nhan vat o x = 272 (man 960, "mom khung long sat chu Khoang cach")
#      -> bam Luoi -> keo tu nhan vat xuong duoi trai (-50, +216 man 1600) -> tha = ban luoi -> "Diem bat sau: 64"
#      -> cac luot con lai bam PASS -> "Chien thang" -> cham tiep tuc -> ve quang truong.
#  Tham so: -N 1 (so tran), -ThietBi auto, -KhongNguoi (tat ngau nhien hoa), -KhongLuoi (ban thu: chi keo tha, KHONG bam Luoi)
#  Thong so ban (vi tri dung, duong keo) o con_trung\thong_so.txt -> chinh lai sau khi xem lich_su_ban.csv
#  Ket qua: con_trung\ket_qua\con_trung_<ngay>_<gio>\ (log.txt + anh) ; moi phat ban 1 dong vao con_trung\lich_su_ban.csv
# =====================================================================
param([int]$N = 1, [string]$ThietBi = "auto", [string]$Serial = "", [switch]$KhongNguoi, [switch]$KhongLuoi)
$ErrorActionPreference = "Stop"
$Root  = Split-Path $PSScriptRoot           # con_trung\
$Mau   = Join-Path $Root "mau"
$out   = Join-Path $Root ("ket_qua\con_trung_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$LogFile = Join-Path $out "log.txt"
$Human = -not $KhongNguoi
function Say([string]$m, [switch]$NoTime) {
    $line = if ($NoTime) { $m } else { "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m }
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
Say ("===== CON TRUNG {0:yyyy-MM-dd HH:mm:ss}: N={1} ThietBi={2} GiaLapNguoi={3} =====" -f (Get-Date), $N, $ThietBi, $Human) -NoTime

# ----------------------------- thong so ban (doc tu file) -----------------------------
# DichX   : x thanh mau nhan vat (tam mau thanh_mau, man 960) khi dung dung cho. 2 tran mau deu dung o 272.
# SaiSoX  : lech toi da cho phep (px man 960)
# KeoX/KeoY : vector keo (man 1600): diem tha - diem cham. 2 tran mau: (-50,216) va (-51,215) -> goc ~77 do
# ChamX/ChamY : diem cham dau tien so voi tam thanh mau (man 1600). Mau: (-3,-130) va (-9,-147)
$Cfg = @{ DichX = 272; SaiSoX = 3; KeoX = -50; KeoY = 216; ChamX = -5; ChamY = -138; DinhX = 60; DinhY = -219 }
$CfgFile = Join-Path $Root "thong_so.txt"
if (Test-Path $CfgFile) {
    foreach ($l in Get-Content $CfgFile) {
        if ($l -match '^\s*(\w+)\s*=\s*(-?[\d.]+)') { $Cfg[$Matches[1]] = [double]$Matches[2] }
    }
}
Say ("Thong so: dung x={0} (+-{1}), keo ({2},{3}) tu tam thanh mau + ({4},{5})" -f $Cfg.DichX, $Cfg.SaiSoX, $Cfg.KeoX, $Cfg.KeoY, $Cfg.ChamX, $Cfg.ChamY)

# ----------------------------- MuMu / ADB -----------------------------
# MuMu cai o C: hay D: tuy may (giong cau_thu.ps1)
$MuMuDir = Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path $_.Root "Program Files\Netease\MuMuPlayer\nx_main" } |
    Where-Object { Test-Path (Join-Path $_ "MuMuManager.exe") } | Select-Object -First 1
if (-not $MuMuDir) { Say "Khong tim thay MuMu"; exit 1 }
$adb = Join-Path $MuMuDir "adb.exe"
if (-not $Serial) {
    $info = (& (Join-Path $MuMuDir "MuMuManager.exe") info -v all | Out-String | ConvertFrom-Json).PSObject.Properties.Value | Where-Object { $_.name -eq $ThietBi } | Select-Object -First 1
    if (-not $info -or -not $info.is_android_started -or -not $info.adb_port) { Say "Thiet bi '$ThietBi' chua bat"; exit 1 }
    $Serial = "$($info.adb_host_ip):$($info.adb_port)"
    & $adb connect $Serial | Out-Null
}
Say "Thiet bi '$ThietBi' -> ADB $Serial"
# Nhan dien: dung chung TdVision.cs cua Tuong Da (so mau 960x540) + CtVision.cs (tim bo rua). Gop using len dau.
$srcLines = ((Get-Content (Join-Path $Root "..\tuong_da\cong_cu\TdVision.cs") -Raw) + "`n" + (Get-Content (Join-Path $PSScriptRoot "CtVision.cs") -Raw)) -split "`r?`n"
$usings = ($srcLines | Where-Object { $_ -match '^using ' } | ForEach-Object { $_.Trim() } | Sort-Object -Unique) -join "`n"
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition ($usings + "`n" + (($srcLines | Where-Object { $_ -notmatch '^using ' }) -join "`n"))
$Shot = Join-Path $env:TEMP "con_trung_$PID.raw"

# Cham muc thap (giu ngon: di chuyen + keo ban) qua sendevent vao "Xiaomi Input" (giong Tuong Da). Toa do RAW: X = 900 - y, Y = x.
$TouchDev = $null
foreach ($l in (& $adb -s $Serial shell getevent -p) -split "`n") {
    if ($l -match 'add device \d+:\s*(/dev/input/event\d+)') { $cur = $Matches[1] }
    elseif ($l -match '"Xiaomi Input"' -and $cur) { $TouchDev = $cur; break }
}
if (-not $TouchDev) { Say "Khong thay thiet bi cam ung 'Xiaomi Input' -> khong giu ngon duoc"; exit 1 }
Say "Thiet bi cam ung: $TouchDev"
$psi = New-Object Diagnostics.ProcessStartInfo $adb, "-s $Serial shell"
$psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
$Sh = [Diagnostics.Process]::Start($psi)
$Sh.add_ErrorDataReceived({}); $Sh.BeginErrorReadLine()   # stdout doc dong bo (ShSync); sendevent khong in gi ra
function ShRun([string]$cmd) { $Sh.StandardInput.WriteLine($cmd); $Sh.StandardInput.Flush() }
# Moi sendevent tren may ao mat ~40ms -> 1 lan di chuyen (4 lenh) ~170ms: lenh xep hang, thiet bi chay CHAM hon lenh gui
# (24/11 08:21: keo "2 giay" thuc te 5 giay, chup anh ngam luc moi keo nua duong). ShSync: cho thiet bi chay het lenh da gui.
function ShSync([int]$timeoutSec = 10) {
    $tag = "XONG$(Get-Random)"; ShRun "echo $tag"
    $dl = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $dl) {
        if (-not $script:ShTask) { $script:ShTask = $Sh.StandardOutput.ReadLineAsync() }
        if ($script:ShTask.Wait(200)) { $l = $script:ShTask.Result; $script:ShTask = $null; if ($null -eq $l -or $l.Trim() -eq $tag) { return $true } }
    }
    return $false
}
function Ev([int]$a, [int]$b, [int]$c) { "sendevent $TouchDev $a $b $c" }
# Giong het chuoi su kien khi nguoi choi keo (ban ghi 24/11): TRACKING_ID 1, moi lan di chuyen deu kem BTN_TOUCH DOWN
function TouchDown([int]$sx, [int]$sy) { ShRun ((Ev 3 57 1), (Ev 1 330 1), (Ev 3 53 (900 - $sy)), (Ev 3 54 $sx), (Ev 0 0 0) -join '; ') }
function TouchMove([int]$sx, [int]$sy) { ShRun ((Ev 1 330 1), (Ev 3 53 (900 - $sy)), (Ev 3 54 $sx), (Ev 0 0 0) -join '; ') }
function TouchUp { ShRun ((Ev 3 57 -1), (Ev 1 330 0), (Ev 0 0 0) -join '; ') }

# ----------------------------- tien ich -----------------------------
function Rnd([int]$a, [int]$b) { Get-Random -Minimum $a -Maximum ($b + 1) }
function Nap([double]$sec) { if ($Human) { $sec = $sec * (0.9 + (Get-Random -Maximum 31) / 100.0) }; Start-Sleep -Milliseconds ([int]($sec * 1000)) }
function Snap {
    for ($k = 1; $k -le 3; $k++) {
        cmd /c "`"$adb`" -s $Serial exec-out screencap > `"$Shot`"" 2>$null
        if ((Test-Path $Shot) -and (Get-Item $Shot).Length -gt 1600 * 900 * 4) { $script:P = [TdVision]::Screen($Shot); return }
        Start-Sleep -Milliseconds 400
    }
    throw "Chup man hinh loi 3 lan"
}
function SaveShot([string]$name) { try { [TdVision]::SaveJpg($Shot, (Join-Path $out "$name.jpg")) } catch {} }
function TplScore([string]$tpl, [int]$x0, [int]$y0, [int]$r = 6) { return [TdVision]::Score($script:P, (Join-Path $Mau "$tpl.png"), $x0, $y0, $r) }
function TplMatch([string]$tpl, [int]$x0, [int]$y0, [int]$r = 6) { $cx = 0; $cy = 0; $s = [TdVision]::Match($script:P, (Join-Path $Mau "$tpl.png"), $x0, $y0, $r, [ref]$cx, [ref]$cy); return @($s, $cx, $cy) }
# Bam (toa do man 960x540 -> 1600x900), lech ngau nhien +-jit px (man 1600)
function Tap([double]$x, [double]$y, [int]$jit = 8) {
    $sx = [int]($x / 0.6); $sy = [int]($y / 0.6)
    if ($Human -and $jit -gt 0) { $sx += Rnd (-$jit) $jit; $sy += Rnd (-$jit) $jit }
    & $adb -s $Serial shell input tap $sx $sy | Out-Null
}

# ----------------------------- trang thai man hinh -----------------------------
# Nguong do tren ban ghi 24/11 (man 960x540):
#  sanh_thanh_duoi: sanh 0.9-1.1, cho khac >= 61 | the_con_trung: bang che do 0.1 (14 luc dang hien), cho khac >= 19
#  qt_bxh (nut BXH ben phai quang truong): quang truong 0-35, cho khac >= 63 | dem_nguoc: dang dem 9-17, het dem >= 36
#  ket_qua (bang "Ket qua" trong tran): 0-0.7, cho khac >= 33 | pass_sang: toi luot minh 0-7.3, khong 24-26
#  chien_thang (man ket thuc tran): 0, cho khac >= 67
function InLobby    { (TplScore 'sanh_thanh_duoi' 600 505) -lt 15 }
function InModes    { (TplScore 'the_con_trung' 690 330 10) -lt 12 }
function InPlaza    { (TplScore 'qt_bxh' 883 88) -lt 45 }
function Counting   { (TplScore 'dem_nguoc' 420 106) -lt 28 }
function InMatch    { (TplScore 'ket_qua' 790 64 4) -lt 15 }
function MyTurn     { ((TplScore 'pass_sang' 700 4 4) -lt 12) -and ([CtTimer]::Orange($script:P) -ge 60) }   # PASS sang + DONG HO dang dem (09:02: mo man PASS sang ma chua cho di)
function IsWin      { (TplScore 'chien_thang' 400 15 8) -lt 30 }
# Diem bat sau (bang Ket qua): doc theo NET CHU XANH LA (CtDigits, 0-1). So mau RGB hong khi Bo Hung dung sau bang
# (24/11 08:37: 64 diem that ma mau RGB lech -> tuong khong dat -> ban them luoi). Mat na: dung 0.90-1.00, so khac 0.26-0.37.
function Score64    { [CtDigits]::Match($script:P, (Join-Path $Mau "diem_64.png"), 882, 186, 3) -ge 0.7 }
function Score0     { [CtDigits]::Match($script:P, (Join-Path $Mau "diem_0.png"), 882, 186, 3) -ge 0.7 }
# Thanh mau nhan vat (huy hieu cap + thanh mau xanh): {diem, x, y} tam mau (man 960); 2 mau (2 tran), lay khop tot hon.
# Dung 0.2-39 (nen sau thanh doi theo cho dung), nham cho khac >= 44
# thanh_mau_3: thanh mau nam DUOI nut di chuyen ban trong suot (nhan vat sat mep trai, x ~100-175, y ~455):
#   24/11 08:30 ca tran khong thay nhan vat (mau 1/2 lech 41-44). Mau 3 khop 0-17 o do nhung nham cho khac ~33 -> chi nhan < 25.
$BarTpl = @(@('thanh_mau_1', 41), @('thanh_mau_2', 41), @('thanh_mau_3', 25))
function FindBar {
    $best = $null
    foreach ($t in $BarTpl) {
        $cx = 0; $cy = 0; $s = [TdVision]::FindIn($script:P, (Join-Path $Mau "$($t[0]).png"), 0, 250, 760, 250, [ref]$cx, [ref]$cy)
        if ($s -le $t[1] -and (-not $best -or $s -lt $best[0])) { $best = @($s, $cx, $cy) }
    }
    return , $best
}

# ----------------------------- nut bam (man 960x540) -----------------------------
$BtnLeft  = @(52, 472)     # nut < (di sang trai)
$BtnRight = @(182, 472)    # nut > (di sang phai) - nguoi choi giu (299,783) man 1600
$BtnNet   = @(415, 466)    # Luoi (nguoi choi (695,774) man 1600)
$BtnPass  = @(731, 20)     # PASS (nguoi choi (1218,30) man 1600)
$BtnWinOk = @(637, 504)    # cham tiep tuc o man Chien thang (nguoi choi (1061,840) / (1040,813))
function Hold($btn) { TouchDown ([int]($btn[0] / 0.6 + (Rnd -6 6))) ([int]($btn[1] / 0.6 + (Rnd -6 6))) }

# ----------------------------- di chuyen toi cho ban -----------------------------
# Nhan vat di ~20 px/giay (man 960). Giu nut toi khi con cach dich <= 6px (bu tre chup man hinh), roi cham ngan de chinh.
# NHAN VAT PHAI QUAY MAT SANG PHAI khi ban (24/11 chay that: di lo -> cham < lui lai -> quay trai -> keo sai, chi 16 diem).
# -> buoc cuoi luon la di sang PHAI: di lo thi lui qua dich ~5px roi cham > tien lai; chua biet huong mat thi lui 1 chut roi tien.
# 24/11 08:19: giu nut + nhin man hinh -> chup man hinh tre ~0.5s -> lan nao cung lo ~30px, lac qua lac lai het 2 luot.
# -> doan ngan (<= 40px): giu nut DUNG THOI GIAN tinh truoc = px / toc do (toc do tu do lai sau moi lan, bat dau 20 px/giay);
#    doan dai: giu + nhin, nha khi con 15px.
# 24/11 08:33: THE LUC CO HAN (thanh xanh "100/100" duoi man, nguoi choi nhac) -> di lo / lac qua lai = phi the luc.
#   Do duoc 25-27 px/giay. Giu+nhin 44px van lo toi 290 (+18). -> giu tinh gio cho doan <= 60px, doan dai nha khi con 25px,
#   di sang PHAI thi co y thieu 1px (buoc cuoi van la sang phai, khong phai lui).
#   08:34: giu+nhin 118px (nha khi con 25px) van lo toi 288 vi moi lan chup+tim mat ~0.7s -> BO HAN giu+nhin:
#   moi doan deu giu TINH GIO; doan dai (> 40px) co y thieu 6px, doan ngan thieu 1px (sang phai), roi chinh.
$script:Speed = 26.0
function Step([string]$dir, [int]$px, [datetime]$deadline, [int]$goal) {
    $btn = if ($dir -eq 'phai') { $BtnRight } else { $BtnLeft }
    # 09:31-09:37: doan dai thieu 6px van lo 100->284 roi het the luc khi lui -> doan dai thieu 15px
    $want = if ($px -gt 40) { $px - 15 } elseif ($dir -eq 'phai' -and $px -ge 3) { $px - 1 } else { $px }
    $ms = [int][math]::Max(60, 1000.0 * $want / $script:Speed)
    $left = ($deadline - (Get-Date)).TotalMilliseconds; if ($ms -gt $left) { $ms = [int][math]::Max(60, $left) }
    Hold $btn; Start-Sleep -Milliseconds $ms; TouchUp
    $script:LastMove = @{ Ms = $ms }
    $script:Facing = $dir
    Start-Sleep -Milliseconds 400
}
function MoveTo([datetime]$deadline) {
    $dich = [int]$Cfg.DichX; $tol = [int]$Cfg.SaiSoX; $miss = 0; $xPrev = $null
    for ($step = 1; $step -le 16 -and (Get-Date) -lt $deadline; $step++) {
        Snap; $b = FindBar
        if (-not $b) {
            $miss++
            if ($miss -eq 2 -and $null -eq $xPrev) {
                # chua thay lan nao trong luot: vao tran nhan vat luon o BEN TRAI cho ban (x 48-212) -> di phai 1.5s cho ra khoi vung bi che
                Say "    chua thay thanh mau nhan vat -> di phai 1.5 giay roi tim lai"
                Hold $BtnRight; Start-Sleep -Milliseconds 1500; TouchUp; $script:Facing = 'phai'; Start-Sleep -Milliseconds 400; continue
            }
            if ($miss -ge 4) { SaveShot ("khong_thay_nhan_vat_{0:HHmmss}" -f (Get-Date)); Say "    khong thay thanh mau nhan vat"; return $null }
            Start-Sleep -Milliseconds 300; continue
        }
        # do lai toc do tu lan giu nut tinh gio vua roi (chi lan >= 150ms, di duoc >= 3px)
        if ($script:LastMove -and $null -ne $xPrev -and $script:LastMove.Ms -ge 150) {
            $moved = [math]::Abs($b[1] - $xPrev)
            if ($moved -lt 2 -and $script:LastMove.Ms -ge 500) {
                # 24/11 08:34 luot 1: giu nut 13 giay ma nhan vat dung yen (het the luc?) -> luu anh, thoi di chuyen luot nay
                SaveShot ("khong_di_chuyen_duoc_{0:HHmmss}" -f (Get-Date))
                Say ("    giu nut {0}ms ma nhan vat khong nhuc nhich (het the luc?) -> thoi di chuyen luot nay" -f $script:LastMove.Ms)
                return $null
            }
            if ($moved -ge 3) {
                $v = 1000.0 * $moved / $script:LastMove.Ms
                $script:Speed = [math]::Max(8, [math]::Min(40, 0.5 * $script:Speed + 0.5 * $v))
                Say ("      (giu {0}ms di {1}px -> toc do {2:0.0} px/giay)" -f $script:LastMove.Ms, $moved, $script:Speed)
            }
        }
        $xPrev = $b[1]
        $err = $dich - $b[1]
        if ([math]::Abs($err) -le $tol -and $script:Facing -eq 'phai') { return $b }
        if ($err -gt $tol) {
            Say ("    nhan vat x={0} (khop {1:0.0}) -> sang PHAI {2} px" -f $b[1], $b[0], $err)
            Step 'phai' $err $deadline $dich
        } elseif ($err -lt -$tol) {
            $px = -$err + 5
            Say ("    nhan vat x={0} (khop {1:0.0}) di lo -> lui TRAI {2} px (qua dich 5px) roi tien lai" -f $b[1], $b[0], $px)
            Step 'trai' $px $deadline ($dich - 5)
        } else {
            Say ("    nhan vat x={0} dung cho nhung mat chua chac quay PHAI ({1}) -> lui trai 1 chut roi tien" -f $b[1], $(if ($script:Facing) { $script:Facing } else { 'chua ro' }))
            Step 'trai' 5 $deadline ($dich - 5)
        }
    }
    Snap; $b = FindBar
    if ($b -and [math]::Abs([int]$Cfg.DichX - $b[1]) -le $tol -and $script:Facing -eq 'phai') { return $b }
    return $null
}

# ----------------------------- ban luoi -----------------------------
$HistFile = Join-Path $Root "lich_su_ban.csv"
if (-not (Test-Path $HistFile)) { "gio,tran,luot,x_nhan_vat,y_nhan_vat,cham_x,cham_y,keo_x,keo_y,ket_qua,anh" | Set-Content $HistFile -Encoding UTF8 }
function Shoot([int]$no, [int]$turn) {
    $tag = "tran{0}_luot{1}" -f $no, $turn
    if ($KhongLuoi) { Say "    (-KhongLuoi: khong bam Luoi, chi keo tha ban thu)" } else { Say "    bam Luoi (1 van chi 1 luoi)"; Tap $BtnNet[0] $BtnNet[1] 5; $script:NetUsed = $true; Nap 0.7 }
    # Camera con truot doc dau luot (thanh mau y 449 -> 419 -> 327...). 24/11 luot 2: do luc camera dang truot -> cham trung
    # thanh mau -> hien bang "Trang thai tam thoi" thay vi ngam. -> cho 2 lan chup lien tiep thanh mau dung yen (lech <= 2px).
    $b = $null; $prev = $null
    for ($k = 0; $k -lt 8; $k++) {
        Snap; $b = FindBar
        if ($b -and $prev -and [math]::Abs($b[1] - $prev[1]) -le 2 -and [math]::Abs($b[2] - $prev[2]) -le 2) { break }
        $prev = $b; Start-Sleep -Milliseconds 150
    }
    if (-not $b) { SaveShot "${tag}_mat_nhan_vat"; Say "    sau khi bam Luoi khong thay nhan vat -> khong ban"; return 'khong_ban' }
    $sx = [int]($b[1] / 0.6 + $Cfg.ChamX); $sy = [int]($b[2] / 0.6 + $Cfg.ChamY)
    $vx = [int]$Cfg.KeoX; $vy = [int]$Cfg.KeoY
    Say ("    keo ban: nhan vat ({0},{1}) mat quay {2} -> cham ({3},{4}) keo ({5},{6}) theo duong tay nguoi choi" -f $b[1], $b[2], $script:Facing, $sx, $sy, $vx, $vy)
    # Phat lai duong keo cua nguoi choi (mau\duong_keo.txt "giay:dx,dy", tran 1 ngay 24/11, 2 giay), co gian de diem cuoi = (KeoX, KeoY)
    $pts = @((Get-Content (Join-Path $Mau "duong_keo.txt") -Raw).Trim() -split '\s+' | ForEach-Object { $q = $_ -split '[:,]'; , @([double]$q[0], [double]$q[1], [double]$q[2]) })
    $fx = $vx / $pts[-1][1]; $fy = $vy / $pts[-1][2]; $sp = if ($Human) { (Rnd 90 110) / 100.0 } else { 1.0 }
    # ~12 diem (moi diem ~170ms tren thiet bi) -> keo ~2 giay nhu nguoi choi; luon giu diem cuoi
    $keep = @(); $stepI = [math]::Max(1, [math]::Ceiling(($pts.Count - 1) / 12.0))
    for ($i = $stepI; $i -lt $pts.Count - 1; $i += $stepI) { $keep += , $pts[$i] }; $keep += , $pts[-1]
    $t0 = Get-Date; $bg = $script:P                  # anh nen truoc khi cham (de tach cham cung net dut)
    TouchDown $sx $sy
    try {
        $prevT = 0.0
        foreach ($q in $keep) {
            $w = [int](($q[0] - $prevT) * 1000 * $sp) - 170; if ($w -gt 0) { Start-Sleep -Milliseconds $w }; $prevT = $q[0]
            TouchMove ([int]($sx + $q[1] * $fx)) ([int]($sy + $q[2] * $fy))
        }
        if (-not (ShSync)) { Say "    (thiet bi chay lenh keo qua lau)" }
        Say ("    keo xong sau {0:0.0} giay ({1} diem) -> giu yen, tu ngam theo dinh cung" -f ((Get-Date) - $t0).TotalSeconds, $keep.Count)
        # ---- TU NGAM (24/11: doi trang phuc -> cung khac, keo y het chi 30 diem) ----
        # Dinh cung net dut so voi thanh mau phai = (DinhX, DinhY) (mau dat 64 cua bot va nguoi choi: (60,-219), +-5px).
        # Dinh thap qua -> keo dai (do cao ~ luc^2); dinh lech ngang -> xoay huong keo (goc nghieng hon -> dinh xa hon).
        $L = [math]::Sqrt($vx * $vx + $vy * $vy); $phi = [math]::Atan2(-$vx, $vy)
        $pPhi = $null; $pEx = $null; $g = 0.2 * [math]::PI / 180   # rad / px (dinh dich ~5px moi do)
        $fx0 = [int]($sx * 0.6); $fy0 = [int]($sy * 0.6)
        for ($it = 1; $it -le 6; $it++) {
            Start-Sleep -Milliseconds 300; Snap
            $a = [CtArc]::Apex($script:P, $bg, $b[1], $b[2], $fx0, $fy0, 40, [int]$Cfg.DinhX, [int]$Cfg.DinhY)
            if (-not $a) { Say "      ngam $it`: khong thay cung net dut -> do lai"; if (($script:TurnEnd - (Get-Date)).TotalSeconds -lt 2.2) { break }; continue }
            $ex = $a[0] - $Cfg.DinhX; $ey = $a[1] - $Cfg.DinhY
            Say ("      ngam {0}: dinh cung ({1:0},{2:0}) lech ({3:+0;-0;0},{4:+0;-0;0}) [{5} cham]  keo ({6},{7})" -f $it, $a[0], $a[1], $ex, $ey, $a[3], $vx, $vy)
            if ([math]::Abs($ex) -le 5 -and [math]::Abs($ey) -le 5) { break }
            if ($it -ge 6) { break }                    # lan cuoi: khong keo them ma khong do lai
            if (($script:TurnEnd - (Get-Date)).TotalSeconds -lt 2.2) { Say "      het gio ngam -> tha"; break }
            # luc: do cao dinh ~ L^2 -> L *= sqrt(Ht/H)
            # 09:04: mu 0.5 chinh qua tay (thap 10 -> cao 7) -> mu 0.35 (do cao nhay hon ~L^2)
            $r = [math]::Pow([math]::Max(0.6, [math]::Min(1.6, (-$Cfg.DinhY) / (-$a[1]))), 0.35)
            # goc: du doan dinh x sau khi doi luc (~ L^2) roi xoay cho dung; he so g cap nhat theo 2 lan do lien tiep
            $exPred = $a[0] * [math]::Pow($r, 2.8) - $Cfg.DinhX
            if ($null -ne $pEx -and [math]::Abs($ex - $pEx) -gt 2 -and [math]::Abs($phi - $pPhi) -gt 0.001) { $g = [math]::Max(0.0005, [math]::Min(0.02, ($phi - $pPhi) / ($ex - $pEx))) }
            $pPhi = $phi; $pEx = $exPred
            $dphi = [math]::Max(-0.1, [math]::Min(0.1, -$exPred * $g))
            $L = $L * $r; $phi = $phi + $dphi
            $vx = [int][math]::Round(-$L * [math]::Sin($phi)); $vy = [int][math]::Round($L * [math]::Cos($phi))
            TouchMove ($sx + $vx) ($sy + $vy); [void](ShSync 3)
        }
        Start-Sleep -Milliseconds (Rnd 150 300)
        Snap; SaveShot "${tag}_ngam"                    # anh duong cung net dut luc sap tha
    } finally { TouchUp }
    Say ("    tha (ban) keo ({0},{1})" -f $vx, $vy)
    # Diem cap nhat ~2.6 giay sau khi tha (luoi bung ra)
    # (24/11 08:22: cho 9 giay -> luot sau da bat dau ma khong hay -> mat luot 3) -> cho toi 6 giay, thay luot moi thi dung
    $res = 'chua_ro'; $tr = Get-Date; $dl = $tr.AddSeconds(6)
    do {
        Start-Sleep -Milliseconds 500; Snap
        if (Score64) { $res = '64'; break }
        if (IsWin) { break }
        if (((Get-Date) - $tr).TotalSeconds -gt 3 -and (MyTurn)) { break }
    } while ((Get-Date) -lt $dl)
    if ($res -ne '64') { if (Score0) { $res = '0' } else { $res = 'khac' } }
    SaveShot "${tag}_sau_ban_$res"
    ("{0:yyyy-MM-dd HH:mm:ss},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}" -f (Get-Date), $no, $turn, $b[1], $b[2], $sx, $sy, $vx, $vy, $res, ($out | Split-Path -Leaf) + "\${tag}_ngam.jpg") | Add-Content $HistFile -Encoding UTF8
    if ($res -eq '64' -and ($vx -ne [int]$Cfg.KeoX -or $vy -ne [int]$Cfg.KeoY)) {
        # hoc: luu duong keo vua dat 64 lam diem bat dau lan sau (doi trang phuc thi tu ngam lai tu day)
        $txt = Get-Content $CfgFile -Raw
        $txt = $txt -replace '(?m)^KeoX\s*=\s*-?\d+', "KeoX = $vx" -replace '(?m)^KeoY\s*=\s*-?\d+', "KeoY = $vy"
        [IO.File]::WriteAllText($CfgFile, $txt, (New-Object Text.UTF8Encoding $true)); $Cfg.KeoX = $vx; $Cfg.KeoY = $vy
        Say "    -> luu keo ($vx,$vy) vao thong_so.txt"
    }
    if ($res -eq '64') { Say "    DAT: Diem bat sau 64" } else { Say "    KHONG DAT (diem: $res) - anh ${tag}_ngam.jpg / ${tag}_sau_ban_$res.jpg" }
    return $res
}

# ----------------------------- 1 luot cua minh -----------------------------
function DoTurn([int]$no, [int]$turn) {
    $tStart = (Get-Date).AddSeconds(-0.3)            # luot 15 giay tinh tu luc PASS sang
    $end = $tStart.AddSeconds(15); $script:TurnEnd = $end
    Say "  Luot $turn (toi luot minh)"
    # 1 VAN CHI DUNG 1 LUOI (nguoi choi 24/11): da ban luoi (dat hay khong) -> cac luot sau PASS
    if ($script:Got64 -or $script:NetUsed) { Nap 1.0; Say $(if ($script:Got64) { '    da du 64 diem -> PASS' } else { '    da dung 1 luoi van nay -> PASS' }); Tap $BtnPass[0] $BtnPass[1] 6; return }
    Nap 1.2                                           # camera dich + chu "Den luot ban do"
    $b = MoveTo ($end.AddSeconds(-0.8))         # di toi gan het luot (khong kip ban thi luot sau ban)
    if (-not $b) {
        Say "    chua toi cho ban -> PASS, luot sau di tiep"
        Snap; if (MyTurn) { Tap $BtnPass[0] $BtnPass[1] 6 }
        return
    }
    Say ("    da toi cho ban: x={0} (khop {1:0.0}), con {2:0.0} giay" -f $b[1], $b[0], ($end - (Get-Date)).TotalSeconds)
    # can ~7 giay: Luoi + cho camera + keo 2 giay + tu ngam (moi lan ~1 giay). Khong du -> PASS, luot sau ban (Luoi chua bam)
    if (($end - (Get-Date)).TotalSeconds -lt 7) { Say "    khong du thoi gian ban (can 7 giay) -> PASS"; Tap $BtnPass[0] $BtnPass[1] 6; return }
    $r = Shoot $no $turn
    if ($r -eq '64') { $script:Got64 = $true }
    # HET LUOI thi ban KHONG CO DIEM (nguoi choi 24/11) -> ban luoi ma diem van 0 = nghi het luoi
    if ($r -eq '0' -and $script:NetUsed) { $script:NoPoints = $true }
}

# ----------------------------- 1 tran -----------------------------
function Fight([int]$no) {
    $script:Got64 = $false; $script:NetUsed = $false; $script:NoPoints = $false; $script:Facing = $null; $turn = 0; $dl = (Get-Date).AddMinutes(4)
    while ((Get-Date) -lt $dl) {
        Snap
        if (IsWin) {
            Nap 1.0; Snap; SaveShot "tran${no}_chien_thang"
            Say "  Chien thang -> cham tiep tuc"; Tap $BtnWinOk[0] $BtnWinOk[1] 15
            return $(if ($script:Got64) { 'dat' } else { 'khong_dat' })
        }
        if ((InMatch) -and (MyTurn)) {
            $turn++; DoTurn $no $turn
            # cho het luot minh: CHI toi het 15 giay cua luot nay (PASS sang sau do = luot moi, khong duoc nuot mat)
            while ((Get-Date) -lt $script:TurnEnd.AddSeconds(0.5)) { Snap; if (-not (MyTurn) -or (IsWin)) { break }; Start-Sleep -Milliseconds 400 }
            continue
        }
        if (InPlaza) { SaveShot "tran${no}_ve_quang_truong"; return 've_quang_truong' }
        Start-Sleep -Milliseconds 400
    }
    SaveShot "tran${no}_qua_4_phut"; return 'qua_gio'
}

# ----------------------------- vao quang truong / vao tran -----------------------------
function WaitUntil([scriptblock]$cond, [double]$sec) {
    $dl = (Get-Date).AddSeconds($sec)
    do { Snap; if (& $cond) { return $true }; Start-Sleep -Milliseconds 400 } while ((Get-Date) -lt $dl)
    return $false
}
function EnterPlaza {
    # dang man tai (vd vua het tran) -> cho toi 25 giay ra man quen
    if (-not (WaitUntil { (InPlaza) -or (InMatch) -or (InLobby) -or (InModes) } 25)) { Snap }
    if ((InPlaza) -or (InMatch)) { return }
    if (InLobby) {
        Say "Sanh -> the che do"; $c = TplMatch 'sanh_the_mo' 715 270 10; Tap $c[1] $c[2] 10
        if (-not (WaitUntil { InModes } 8)) { SaveShot "loi_khong_thay_che_do"; throw "Không thấy bảng chọn chế độ" }
        Nap 0.8
    }
    if (InModes) {
        Say "Chon Con trung Dai chien"; $c = TplMatch 'the_con_trung' 690 330 10; Tap $c[1] $c[2] 10
        if (-not (WaitUntil { InPlaza } 20)) { SaveShot "loi_khong_vao_quang_truong"; throw "Không vào được quảng trường côn trùng" }
        Say "Da vao quang truong"; return
    }
    SaveShot "loi_man_hinh_la"
    throw "Không ở sảnh / bảng chế độ / quảng trường côn trùng (xem anh loi_man_hinh_la)"
}
# Quang truong: het "Dem nguoc" thi cham vao bo rua (nhan vat chay toi -> VS -> tran)
# Quang truong rong hon man hinh, bo rua lang thang ra ngoai khung nhin (24/11 08:46 / 08:48: khong thay bo rua 3-7 lan, van 5 bo).
# -> tim ca sat mep duoi (tru thanh item goc duoi phai); khong thay thi cham cho nhan vat di cho khac (camera lia theo) roi tim lai.
$WalkPts = @(@(200, 300), @(760, 320), @(480, 430), @(160, 420), @(800, 200))
# Uu tien bo rua; khong co thi BUOM (nguoi choi 24/11: cham buom cung vao tran). Buom quang truong ~1265 diem, khung 79x40;
# trung xanh tim duoi chan tuong ~460 diem 28x31 -> buom can >= 700 diem. Tra ve {x, y, diem, so cum, loai}
function FindBug {
    $a = [CtVision]::FindLadybug($script:P, 20, 130, 860, 440, 300, 1500)
    $b = [CtVision]::FindLadybug($script:P, 20, 440, 620, 510, 300, 1500)
    $r = if ($b[2] -gt $a[2]) { $b } else { $a }
    if ($r[2] -gt 0) { return , @($r[0], $r[1], $r[2], $r[3], "bo rua") }
    $a = [CtVision]::FindButterfly($script:P, 70, 160, 860, 440, 700, 3000)
    $b = [CtVision]::FindButterfly($script:P, 70, 440, 620, 515, 700, 3000)
    $r = if ($b[2] -gt $a[2]) { $b } else { $a }
    return , @($r[0], $r[1], $r[2], $r[3], "buom")
}
function StartMatch([int]$no) {
    $walk = 0
    for ($k = 1; $k -le 12; $k++) {
        Snap
        if (InMatch) { return $true }
        if (-not (InPlaza)) {
            # 24/11 08:49: 3 lan roi vao day, mat ~70 giay khong ro vi sao -> ghi log + anh
            Say "  (lan $k) khong o quang truong / chua vao tran -> cho 15 giay"; SaveShot "tran${no}_cho_quang_truong_$k"
            if (WaitUntil { (InMatch) -or (InPlaza) } 15) { if (InMatch) { return $true } }; continue
        }
        if (Counting) { Say "  dang dem nguoc -> cho"; [void](WaitUntil { -not (Counting) } 20); continue }
        $lb = FindBug
        if ($lb[2] -eq 0) {
            $w = $WalkPts[$walk % $WalkPts.Count]; $walk++
            Say ("  khong thay bo rua / buom (lan {0}) -> cho nhan vat di toi ({1},{2}) de camera lia, tim lai" -f $k, $w[0], $w[1])
            SaveShot "tran${no}_khong_thay_bo_rua_$k"; Tap $w[0] $w[1] 15; Nap 2.5; continue
        }
        Say ("  cham {4} tai ({0},{1}) ({2} diem mau) lan {3}" -f $lb[0], $lb[1], $lb[2], $k, $lb[4])
        Tap $lb[0] $lb[1] 6
        # bo di lien tuc (24/11 08:55: cham 7 lan moi vao) -> ~1.5 giay/lan chup lai, cham vao cho moi cua no (toi da 4 lan)
        $left = $false
        for ($c = 1; $c -le 4; $c++) {
            Start-Sleep -Milliseconds 1200; Snap
            if (-not (InPlaza)) { $left = $true; break }
            $nb = FindBug; if ($nb[2] -gt 0) { Tap $nb[0] $nb[1] 6 }
        }
        if ($left -or (WaitUntil { -not (InPlaza) } 3)) {
            if (WaitUntil { InMatch } 20) { Say "Vao tran $no"; return $true }
        }
    }
    SaveShot "tran${no}_khong_vao_duoc_tran"
    return $false
}

# ----------------------------- MAIN -----------------------------
$done = 0; $dat = 0
try {
    EnterPlaza
    for ($i = 1; $i -le $N; $i++) {
        Say "===== Tran $i/$N =====" -NoTime
        if (-not (StartMatch $i)) { Say "Khong vao duoc tran -> dung"; break }
        $r = Fight $i
        Say "  -> $r" -NoTime
        if ($r -eq 'dat' -or $r -eq 'khong_dat') { $done++; if ($r -eq 'dat') { $dat++ } } else { break }
        if ($script:NoPoints) { Say "Ban luoi ma Diem bat sau van 0 -> nghi HET LUOI -> dung"; break }
        if (-not (WaitUntil { InPlaza } 30)) { SaveShot "sau_tran_$i"; Say "Sau tran khong ve quang truong -> dung"; break }
        Nap 1.5
    }
} catch {
    Say "LOI: $($_.Exception.Message)"
    try { Snap; SaveShot "loi" } catch {}
} finally {
    try { TouchUp } catch {}
    Remove-Item $Shot -Force -ErrorAction SilentlyContinue
    try { $Sh.StandardInput.WriteLine("exit"); $Sh.WaitForExit(2000) | Out-Null; $Sh.Kill() } catch {}
}
Say "Xong $done/$N tran, dat 64 diem: $dat. Anh + log: $out" -NoTime
