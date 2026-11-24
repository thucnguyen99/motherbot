# =====================================================================
#  Tuong Da (pho ban tuong khong lo): danh N tran (moi ngay 5 luot, THUA van nhan Xu Co).
#  Chay rieng nhu cau ca: thiet bi MuMu dang bat, dang o SANH CHINH (hoac phong cho / man chon che do).
#  Hoc tu ban ghi lam mau 20/11 21:50 (hoc_mau\ghi_20261120_215019, ghi chu: tuong_da\GHI_CHU.md):
#   Sanh -> the che do (goc duoi phai) -> "Pho tuong khong lo" -> "Kham pha" -> phong cho ("So thu thach con lai")
#   -> di vao cong sang -> TRAN: moi luot (nut PASS sang = toi luot minh) bam item theo hinh + POW + keo ban
#      dung nhu nguoi choi (kich ban 3 luot, xem $Turns) -> "That bai" / "Nhan de tiep tuc" -> ve phong cho.
#  Tham so: -N 1 (so tran), -ThietBi auto, -KhongNguoi (tat ngau nhien hoa)
#  Thoat giua tran (nguoi choi bam nut nguon -> "Xac nhan thoat chien dau", khong tru luot) -> script nhan ra, dung.
#  Ket qua: tuong_da\ket_qua\tuong_da_<ngay>_<gio>\ (log.txt + anh tung luot)
# =====================================================================
param([int]$N = 1, [string]$ThietBi = "auto", [string]$Serial = "", [switch]$KhongNguoi)
$ErrorActionPreference = "Stop"
$Root  = Split-Path $PSScriptRoot           # tuong_da\
$Mau   = Join-Path $Root "mau"
$out   = Join-Path $Root ("ket_qua\tuong_da_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Force $out | Out-Null
$LogFile = Join-Path $out "log.txt"
$Human = -not $KhongNguoi
function Say([string]$m, [switch]$NoTime) {
    $line = if ($NoTime) { $m } else { "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss.fff'), $m }
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}
Say ("===== TUONG DA {0:yyyy-MM-dd HH:mm:ss}: N={1} ThietBi={2} GiaLapNguoi={3} =====" -f (Get-Date), $N, $ThietBi, $Human) -NoTime

# ----------------------------- MuMu / ADB -----------------------------
# MuMu cai o C: hay D: tuy may (giong cau_thu.ps1)
$MuMuDir = @('D:\', 'C:\') + @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }) |
    ForEach-Object { [IO.Path]::Combine($_, "Program Files\Netease\MuMuPlayer\nx_main") } |
    Where-Object { Test-Path ([IO.Path]::Combine($_, "MuMuManager.exe")) } | Select-Object -First 1
if (-not $MuMuDir) { Say "Khong tim thay MuMu"; exit 1 }
$adb = Join-Path $MuMuDir "adb.exe"
if (-not $Serial) {
    $info = (& (Join-Path $MuMuDir "MuMuManager.exe") info -v all | Out-String | ConvertFrom-Json).PSObject.Properties.Value | Where-Object { $_.name -eq $ThietBi } | Select-Object -First 1
    if (-not $info -or -not $info.is_android_started -or -not $info.adb_port) { Say "Thiet bi '$ThietBi' chua bat"; exit 1 }
    $Serial = "$($info.adb_host_ip):$($info.adb_port)"
    & $adb connect $Serial | Out-Null
}
Say "Thiet bi '$ThietBi' -> ADB $Serial"
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition (Get-Content (Join-Path $PSScriptRoot "TdVision.cs") -Raw)
$Shot = Join-Path $env:TEMP "tuong_da_$PID.raw"

# Cham muc thap (giu ngon qua nhieu lenh de vua giu vua chup man hinh, dung khi ngam ban):
# ghi su kien vao thiet bi cam ung "Xiaomi Input" bang sendevent qua 1 shell adb mo san (giong bot cau ca).
# Toa do RAW doc: X = 900 - y, Y = x (man 1600x900).
$TouchDev = $null
foreach ($l in (& $adb -s $Serial shell getevent -p) -split "`n") {
    if ($l -match 'add device \d+:\s*(/dev/input/event\d+)') { $cur = $Matches[1] }
    elseif ($l -match '"Xiaomi Input"' -and $cur) { $TouchDev = $cur; break }
}
if (-not $TouchDev) { Say "Khong thay thiet bi cam ung 'Xiaomi Input' -> khong ngam ban duoc (se keo theo duong mau)" }
else { Say "Thiet bi cam ung: $TouchDev" }
$psi = New-Object Diagnostics.ProcessStartInfo $adb, "-s $Serial shell"
$psi.UseShellExecute = $false; $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
$Sh = [Diagnostics.Process]::Start($psi)
$Sh.add_OutputDataReceived({}); $Sh.BeginOutputReadLine(); $Sh.add_ErrorDataReceived({}); $Sh.BeginErrorReadLine()
function ShRun([string]$cmd) { $Sh.StandardInput.WriteLine($cmd); $Sh.StandardInput.Flush() }
function Ev([int]$a, [int]$b, [int]$c) { "sendevent $TouchDev $a $b $c" }
function TouchDown([int]$sx, [int]$sy) { ShRun ((Ev 3 57 7), (Ev 1 330 1), (Ev 3 53 (900 - $sy)), (Ev 3 54 $sx), (Ev 0 0 0) -join '; ') }
function TouchMove([int]$sx, [int]$sy) { ShRun ((Ev 3 53 (900 - $sy)), (Ev 3 54 $sx), (Ev 0 0 0) -join '; ') }
function TouchUp { ShRun ((Ev 3 57 -1), (Ev 1 330 0), (Ev 0 0 0) -join '; ') }

# ----------------------------- tien ich -----------------------------
function Rnd([int]$a, [int]$b) { Get-Random -Minimum $a -Maximum ($b + 1) }
function Nap([double]$sec) { if ($Human) { $sec = $sec * (0.9 + (Get-Random -Maximum 51) / 100.0) }; Start-Sleep -Milliseconds ([int]($sec * 1000)) }
function Adb([string]$a) { $o = & $adb -s $Serial @($a -split ' ') 2>&1; return $o }

# Chup man hinh -> $script:P (RGB 960x540, toa do anh mau)
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

# Bam (toa do 960x540 -> man hinh 1600x900), lech ngau nhien +-jit px (man 1600)
function Tap([double]$x, [double]$y, [int]$jit = 8) {
    $sx = [int]($x / 0.6); $sy = [int]($y / 0.6)
    if ($Human -and $jit -gt 0) { $sx += Rnd (-$jit) $jit; $sy += Rnd (-$jit) $jit }
    [void](Adb "shell input tap $sx $sy")
}
# Keo theo duong (toa do man 1600x900, thoi gian giay tu luc cham) bang motionevent trong 1 lenh shell
# Gia lap nguoi: lech moi diem +-3px, toc do 90-110%
function Drag($pts) {
    $f = if ($Human) { (Rnd 90 110) / 100.0 } else { 1.0 }
    $dx = if ($Human) { Rnd -3 3 } else { 0 }; $dy = if ($Human) { Rnd -3 3 } else { 0 }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    $c = New-Object System.Collections.Generic.List[string]
    $c.Add("input motionevent DOWN $($pts[0][1] + $dx) $($pts[0][2] + $dy)")
    for ($i = 1; $i -lt $pts.Count; $i++) {
        $wait = ($pts[$i][0] - $pts[$i - 1][0]) * $f
        if ($wait -gt 0.01) { $c.Add("sleep " + $wait.ToString('0.00', $inv)) }
        $c.Add("input motionevent MOVE $($pts[$i][1] + $dx) $($pts[$i][2] + $dy)")
    }
    $last = $pts[$pts.Count - 1]
    $c.Add("input motionevent UP $($last[1] + $dx) $($last[2] + $dy)")
    & $adb -s $Serial shell ($c -join '; ') | Out-Null
}

# ----------------------------- trang thai man hinh -----------------------------
# Nguong (do tren ban ghi 20/11, 960x540): dung cho 0-3.2, cho khac >= 40; PASS sang 0-5, PASS mo (cho) 20-30
function InLobby   { (TplScore 'sanh_thanh_duoi' 600 505) -lt 15 }
function InModes   { (TplScore 'the_pho_tuong' 395 315 10) -lt 20 }
function InKhamPha { (TplScore 'kham_pha_tieu_de' 405 36) -lt 15 }
function InRoom    { (TplScore 'phong_so_thu_thach' 330 8) -lt 15 }
# Trong tran: chu do "Dano:" (sat thuong) goc tren (trong tran 0-21, ngoai tran >= 62; luot dich / chuyen canh co luc mat)
# hoac PASS sang. (PASS mo khong dung duoc: o "Tim" cua bang che do cung giong PASS mo)
function InBattle  { ((TplScore 'tran_dano' 590 34 10) -lt 25) -or (MyTurn) }
function MyTurn    { (TplScore 'nut_pass' 868 40) -lt 12 }            # PASS sang = toi luot minh
function IsResult  { ((TplScore 'nhan_tiep_tuc' 795 490 10) -lt 20) -or ((TplScore 'that_bai' 380 10 10) -lt 20) }
function PowReady  { (TplScore 'pow_toi' 846 454 8) -gt 40 }          # POW toi (chua san sang) khop 0-6, san sang lech >= 85

# Item tren thanh (y ~474): tra ve tam o khop BEN TRAI NHAT (item dung xong bien mat; 2 o A -> lan 2 la o con lai)
function FindItem([string]$tpl) {
    # quet ngang thanh item; nguong 22 (do 20/11: dung 0-19, khong co item thi khong co diem < 22)
    $hits = @()
    for ($x0 = 200; $x0 -le 790; $x0 += 12) { $r = TplMatch $tpl $x0 456 6; if ($r[0] -lt 22) { $hits += , $r } }
    if (-not $hits.Count) { return $null }
    $left = 9999; foreach ($h in $hits) { if ($h[1] -lt $left) { $left = $h[1] } }
    # cac lan quet trung cung 1 o (lech < 20px): lay diem khop tot nhat
    $best = $null
    foreach ($h in $hits) { if ($h[1] -le $left + 20 -and (-not $best -or $h[0] -lt $best[0])) { $best = $h } }
    return , $best
}

# ----------------------------- kich ban tran (hoc tu nguoi choi) -----------------------------
# Item: A nguoi do mui ten len (10), B vong lua (30), C mui ten do "63%" (30), D rong xanh (10), POW nut tron lon goc duoi phai
# Keo ban: phat lai dung duong keo cua nguoi choi (tuong_da\mau\duong_keo.txt, toa do 1600x900)
$Paths = @{}
foreach ($l in Get-Content (Join-Path $Mau "duong_keo.txt")) {
    $a = $l -split '\|'
    $Paths[$a[0]] = @($a[2] -split ' ' | ForEach-Object { $q = $_ -split '[:,]'; , @([double]$q[0], [int]$q[1], [int]$q[2]) })
}
# Drags: duong keo phat lai nguyen (#12, #18: keo ngan truoc khi ban); 'BAN' = ngam ban theo diem yeu (AimShoot),
# khong ngam duoc thi keo theo duong mau Ban cua luot do.
$Turns = @(
    @{ Items = @('item_a', 'item_b', 'item_c', 'POW', 'item_d', 'item_a'); Drags = @('BAN'); Ban = '#13' },
    @{ Items = @('item_c', 'POW');                                       Drags = @('BAN'); Ban = '#19' },
    @{ Items = @('item_c', 'item_a', 'POW');                             Drags = @('BAN');        Ban = '#23' }
)

# ----------------------------- ngam ban theo diem yeu -----------------------------
# Diem yeu = hong tam cam do tren than tuong, DOI CHO giua cac luot va cac tran
#   (20/11: mau (790,232) (680,258) (680,328); bot chay 22:14 gap (680,136) (680,190) -> phat lai duong keo cu ban trat luot 3).
# Ban mau nguoi choi (hong tam man 960 -> duong keo): huong + do dai keo ban dau lay tu ban mau co hong tam GAN NHAT.
# Giu ngon (sendevent), chup man hinh, do cung net dut lech cao/thap so voi hong tam tai x hong tam (TdVision.ArcError),
# keo dai / ngan theo cung huong (= luc ban): lech > 0 (cung thap hon) -> keo dai them. Lap toi khi lech < 8px (toi da 5 lan, 5 giay) -> tha.
# Vong tron sang quanh nhan vat (hien khi toi luot): tam = nhan vat, ban kinh ~ do zoom (20/11: 232-248 man 960).
# Keo-tha PHAI nam trong vong tron. Nhan vat + zoom DOI theo tung tran ("Khoang cach" 11.5 / 10.0) -> moi toa do keo tinh
# theo vong tron (TdVision.FindCircle, Hough): don vi = ban kinh, goc = tam vong tron.
# Keo ngan doc (#12/#18 cua nguoi choi) = KEO MAN HINH xuong (nhan vat dich xuong ~120px) de lo hong tam o tren cao
# -> chi keo khi khong thay hong tam / hong tam sat mep (toi da 2 lan), roi do lai.
# Ban mau (man 960, do vong tron + hong tam ngay truoc khi ban):
$ShotsMau = @(
    @{ D = '#13'; C = @(222, 460); R = 246; T = @(790, 232) },
    @{ D = '#19'; C = @(226, 464); R = 232; T = @(680, 258) },
    @{ D = '#23'; C = @(224, 348); R = 240; T = @(680, 328) }
)
$RVongMax = 0.9   # diem keo cach tam toi da 0.9 ban kinh
function FindTarget {
    # 2 mau hong tam (tren cao luot 1 / duoi thap luot 3); khop dung 9-36 (co vong sang / hieu ung), cho khac >= 54
    $best = $null
    foreach ($t in 'hong_tam_1', 'hong_tam_2') {
        $cx = 0; $cy = 0; $s = [TdVision]::FindIn($script:P, (Join-Path $Mau "$t.png"), 540, 40, 420, 420, [ref]$cx, [ref]$cy)
        if (-not $best -or $s -lt $best[0]) { $best = @($s, $cx, $cy) }
    }
    return , $best
}
function TargetOk($T) { return ($T[0] -le 45 -and $T[2] -ge 150 -and $T[1] -le 900) }   # thay ro, khong o qua cao (cung vot khoi mep tren) / sat mep phai
function FindRing {
    # {cx, cy, r, diem}; diem dung 0.18-0.34 (20/11), duoi 0.12 coi nhu khong thay
    $c = [TdVision]::FindCircle($script:P, 190, 275, 0, 600, 240, 530)
    if ($c[3] -lt 0.12) { return $null }
    return , $c
}
function Clamp([double]$v, [int]$lo, [int]$hi) { return [int][math]::Max($lo, [math]::Min($hi, $v)) }
function TMove([double]$x, [double]$y) { TouchMove (Clamp ($x / 0.6) 2 1597) (Clamp ($y / 0.6) 2 897) }   # man 960 -> cham man 1600

function AimShoot([string]$tag) {
    if (-not $TouchDev) { return $false }
    # 1. tim hong tam; khong thay / sat mep -> keo man hinh xuong (nhu #12) roi tim lai
    $T = $null
    for ($pan = 0; $pan -le 2; $pan++) {
        Snap; $T = FindTarget
        if (TargetOk $T) { break }
        if ($pan -lt 2) { Say ("    hong tam chua ro (khop {0:0.0} tai ({1},{2})) -> keo man hinh xuong" -f $T[0], $T[1], $T[2]); Drag $Paths['#12']; Nap 1.0 }
    }
    if (-not (TargetOk $T)) { SaveShot "${tag}_khong_thay_hong_tam"; Say "    khong thay hong tam"; return $false }
    # 2. vong tron quanh nhan vat
    $C = FindRing
    if (-not $C) { SaveShot "${tag}_khong_thay_vong_tron"; Say "    khong thay vong tron quanh nhan vat"; return $false }
    $bg = $script:P; SaveShot "${tag}_nen"
    $Rv = $C[2]; $rx = ($T[1] - $C[0]) / $Rv; $ry = ($T[2] - $C[1]) / $Rv
    # 3. ban mau co hong tam gan nhat (don vi ban kinh); diem keo + huong theo ban mau, co gian theo ban kinh
    $m = $ShotsMau | Sort-Object { [math]::Pow(($_.T[0] - $_.C[0]) / $_.R - $rx, 2) + [math]::Pow(($_.T[1] - $_.C[1]) / $_.R - $ry, 2) } | Select-Object -First 1
    $path = $Paths[$m.D]; $f = $Rv / $m.R
    $sx = $C[0] + ($path[0][1] * 0.6 - $m.C[0]) * $f; $sy = $C[1] + ($path[0][2] * 0.6 - $m.C[1]) * $f
    $vx = ($path[-1][1] - $path[0][1]) * 0.6 * $f; $vy = ($path[-1][2] - $path[0][2]) * 0.6 * $f
    # k toi da de diem tha con trong vong tron: |S + k v - C| <= RVongMax * R
    $ax = $sx - $C[0]; $ay = $sy - $C[1]; $lim = $RVongMax * $Rv
    $qa = $vx * $vx + $vy * $vy; $qb = 2 * ($ax * $vx + $ay * $vy); $qc = $ax * $ax + $ay * $ay - $lim * $lim
    $kMax = 1.4; $disc = $qb * $qb - 4 * $qa * $qc
    if ($disc -ge 0) { $kMax = [math]::Min(1.4, (-$qb + [math]::Sqrt($disc)) / (2 * $qa)) }
    Say ("    vong tron ({0:0},{1:0}) r={2:0} diem {3:0.00}; hong tam ({4},{5}) khop {6:0.0} = ({7:0.00},{8:0.00})R; ban mau {9}; keo tu ({10:0},{11:0}), k toi da {12:0.00}" -f `
        $C[0], $C[1], $Rv, $C[3], $T[1], $T[2], $T[0], $rx, $ry, $m.D, $sx, $sy, $kMax)
    if ($qc -gt 0) { Say "    !!! diem bat dau keo nam ngoai vong tron -> bo"; return $false }
    $k = [math]::Min(1.0, $kMax); $kPrev = $null; $ePrev = $null
    TouchDown (Clamp ($sx / 0.6) 2 1597) (Clamp ($sy / 0.6) 2 897)
    try {
        for ($i = 1; $i -le 6; $i++) { TMove ($sx + $vx * $k * $i / 6) ($sy + $vy * $k * $i / 6); Start-Sleep -Milliseconds 80 }
        $t0 = Get-Date
        for ($it = 1; $it -le 5; $it++) {
            Start-Sleep -Milliseconds 350
            Snap
            # duong net dut NGAN, co khi khong toi hong tam -> lan theo chuoi cham + keo dai theo vat ly (trong luc ~4.5px/buoc o r=240)
            $arc = [TdVision]::ArcPredict($script:P, $bg, $T[1], $T[2], [int]($C[0] + 0.3 * $Rv), [int]($sx + $vx * $k), [int]($sy + $vy * $k), (4.5 * $Rv / 240), $null)
            SaveShot ("{0}_ngam{1}" -f $tag, $it)
            if ([double]::IsNaN($arc[0]) -or $arc[1] -lt 5) { Say ("    ngam {0}: k={1:0.000} khong lan duoc duong dan (chuoi {2} cham) -> tha" -f $it, $k, $arc[1]); break }
            $e = $arc[0]
            Say ("    ngam {0}: k={1:0.000} duong dan lech {2:0.0}px tai hong tam (chuoi {3} cham, keo dai {4:0.0} buoc)" -f $it, $k, $e, $arc[1], $arc[2])
            if ([math]::Abs($e) -lt 8) { break }
            if (((Get-Date) - $t0).TotalSeconds -gt 5) { Say "    het thoi gian ngam -> tha"; break }
            # e > 0: cung THAP hon hong tam -> keo dai (manh hon); e < 0 -> keo ngan
            if ($null -ne $ePrev -and [math]::Abs($e - $ePrev) -gt 1) { $kNew = $k - $e * ($k - $kPrev) / ($e - $ePrev) }
            else { $kNew = $k + [math]::Sign($e) * 0.05 }
            $kNew = [math]::Max(0.6, [math]::Min($kMax, $kNew))
            if ([math]::Abs($kNew - $k) -gt 0.15) { $kNew = $k + 0.15 * [math]::Sign($kNew - $k) }
            if ([math]::Abs($kNew - $k) -lt 0.005) { Say "    cham gioi han vong tron / khong chinh them duoc -> tha"; break }
            $kPrev = $k; $ePrev = $e; $k = $kNew
            TMove ($sx + $vx * $k) ($sy + $vy * $k)
        }
        Start-Sleep -Milliseconds (Rnd 150 350)
    } finally { TouchUp }
    Say ("    tha ngon (ban) k={0:0.000}" -f $k)
    return $true
}
# Cho PASS sang lai (sau moi lan bam item co hieu ung che man hinh ~5 giay)
function WaitMyTurn([double]$sec) {
    $dl = (Get-Date).AddSeconds($sec)
    do { Snap; if (MyTurn) { return $true }; if (IsResult) { return $false }; Start-Sleep -Milliseconds 300 } while ((Get-Date) -lt $dl)
    return $false
}

function DoTurn([int]$no, [int]$k) {
    $t = $Turns[[math]::Min($k, $Turns.Count - 1)]
    Say "  Luot $($k + 1): item $($t.Items -join ', ') ; keo $($t.Drags -join ', ')"
    SaveShot ("tran{0}_luot{1}_dau" -f $no, ($k + 1))
    $c0 = FindRing; if ($c0) { Say ("    vong tron dau luot ({0:0},{1:0}) r={2:0} diem {3:0.00}" -f $c0[0], $c0[1], $c0[2], $c0[3]) } else { Say "    dau luot khong thay vong tron" }
    foreach ($it in $t.Items) {
        if (-not (WaitMyTurn 8)) { Say "    het luot / het tran khi dang bam item"; return }
        if ($it -eq 'POW') {
            if (PowReady) { Say "    POW"; Tap 871 479 10 } else { Say "    POW chua san sang -> bo qua"; continue }
        } else {
            $f = FindItem $it
            if (-not $f) { Say "    $it khong co tren thanh -> bo qua"; continue }
            Say ("    {0} tai ({1},{2}) khop {3:0.0}" -f $it, $f[1], $f[2], $f[0]); Tap $f[1] $f[2] 6
        }
        Nap 0.9
    }
    foreach ($d in $t.Drags) {
        if (-not (WaitMyTurn 8)) { Say "    het luot / het tran truoc khi keo"; return }
        if ($d -eq 'BAN') {
            if (AimShoot ("tran{0}_luot{1}" -f $no, ($k + 1))) { Nap 0.8; continue }
            $d = $t.Ban; Say "    -> keo theo duong mau $d"
        }
        $p = $Paths[$d]
        Say ("    keo {0}: ({1},{2}) -> ({3},{4}) {5:0.0}s" -f $d, $p[0][1], $p[0][2], $p[-1][1], $p[-1][2], $p[-1][0])
        Drag $p
        Nap 0.8
    }
    Nap 1; Snap; SaveShot ("tran{0}_luot{1}_sau_ban" -f $no, ($k + 1))
}

# ----------------------------- vao phong cho -----------------------------
function WaitUntil([scriptblock]$cond, [double]$sec) {
    $dl = (Get-Date).AddSeconds($sec)
    do { Snap; if (& $cond) { return $true }; Start-Sleep -Milliseconds 400 } while ((Get-Date) -lt $dl)
    return $false
}

function EnterRoom {
    Snap
    if (InRoom) { Say "Dang o phong cho"; return }
    if (InLobby) {
        Say "Sanh -> the che do (goc duoi phai)"; $c = TplMatch 'sanh_the_mo' 715 270 10; Tap $c[1] $c[2] 10
        if (-not (WaitUntil { InModes } 8)) { SaveShot "loi_khong_thay_che_do"; throw "Không thấy bảng chọn chế độ" }
        Nap 0.8
    }
    if (InModes) {
        Say "Chon Pho tuong khong lo"; $c = TplMatch 'the_pho_tuong' 395 315 10; Tap $c[1] $c[2] 10
        if (-not (WaitUntil { InKhamPha } 8)) { SaveShot "loi_khong_thay_kham_pha"; throw "Không thấy hộp Khám phá" }
        Nap 0.8
    }
    if (InKhamPha) {
        Say "Bam Kham pha"; $c = TplMatch 'nut_kham_pha' 722 418 8; Tap $c[1] $c[2] 8
        if (-not (WaitUntil { InRoom } 30)) { SaveShot "loi_khong_vao_phong"; throw "Không vào được phòng chờ" }
        Say "Da vao phong cho"; return
    }
    SaveShot "loi_man_hinh_la"
    throw "Không ở sảnh / phòng chờ / bảng chế độ (xem anh loi_man_hinh_la)"
}

# Phong cho -> di vao cong sang (nguoi choi cham (808,487) roi (1091,418) tren man 1600x900)
function StartFight([int]$no) {
    for ($k = 1; $k -le 3; $k++) {
        Say "Di vao cong (lan $k)"
        Tap 485 292 10; Nap 1.6; Tap 663 260 10     # cong sang ~ (1100-1125, 420-470) man 1600x900
        if (WaitUntil { InBattle } 45) { Say "Vao tran $no"; return $true }
        Snap
        if (-not (InRoom)) { SaveShot "loi_vao_tran_$no"; throw "Đi vào cổng mà không vào trận, cũng không còn ở phòng chờ" }
    }
    SaveShot "khong_vao_duoc_tran_$no"
    return $false
}

# ----------------------------- 1 tran -----------------------------
function Fight([int]$no) {
    $k = 0; $dl = (Get-Date).AddMinutes(8)
    while ((Get-Date) -lt $dl) {
        Snap
        if (IsResult) {
            Nap 1.5; Snap; SaveShot "tran${no}_ket_qua"
            Say "  Ket thuc tran $no (anh tran${no}_ket_qua.jpg) -> nhan de tiep tuc"
            Tap 480 300 40
            if (WaitUntil { (InRoom) -or (InLobby) } 30) { return 'xong' }
            SaveShot "tran${no}_sau_ket_qua"; return 'xong_khong_ve_phong'
        }
        if (-not (InBattle)) {
            # nguoi choi thoat giua tran (khong tru luot) -> ve phong / sanh
            if ((InRoom) -or (InLobby)) { SaveShot "tran${no}_thoat"; return 'thoat' }
            Start-Sleep -Milliseconds 500; continue   # dang tai / hieu ung
        }
        if (MyTurn) {
            DoTurn $no $k; $k++
            # cho het luot minh (PASS mo / ket qua)
            $d2 = (Get-Date).AddSeconds(25)
            do { Start-Sleep -Milliseconds 500; Snap } while ((MyTurn) -and -not (IsResult) -and (Get-Date) -lt $d2)
            continue
        }
        Start-Sleep -Milliseconds 500
    }
    SaveShot "tran${no}_qua_8_phut"; return 'qua_gio'
}

# ----------------------------- MAIN -----------------------------
$done = 0
try {
    EnterRoom
    for ($i = 1; $i -le $N; $i++) {
        Say "===== Tran $i/$N =====" -NoTime
        if (-not (StartFight $i)) { Say "Khong vao duoc tran (het luot thu thach?) -> dung"; break }
        $r = Fight $i
        Say "  -> $r" -NoTime
        if ($r -eq 'thoat') { Say "Tran bi thoat giua chung (khong tru luot) -> dung"; break }
        if ($r -ne 'xong') { break }
        $done++
        Snap
        if (-not (InRoom)) { Say "Sau tran khong o phong cho -> dung"; break }
        Nap 2
    }
} catch {
    Say "LOI: $($_.Exception.Message)"
    try { Snap; SaveShot "loi" } catch {}
} finally {
    Remove-Item $Shot -Force -ErrorAction SilentlyContinue
    try { $Sh.StandardInput.WriteLine("exit"); $Sh.WaitForExit(2000) | Out-Null; $Sh.Kill() } catch {}
}
Say "Xong $done/$N tran. Anh + log: $out" -NoTime
