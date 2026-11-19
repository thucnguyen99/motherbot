# =====================================================================
#  DDTank - tu dong thu hoach nong trai + gieo hat (mac dinh khoai tay) (MuMu Player + ADB)
#  Quy trinh: mo thiet bi "auto" -> mo app DDTank -> vao game -> Ban be ->
#             Nong trai -> thu hoach (di theo duong ran) -> gieo hat 10 o (doc dong ho -> gio chin) ->
#             kiem tra -> tat app -> tat thiet bi
#  Chay:  run.bat -Account <ten tai khoan 7Road>
#  Tham so: -Account ten  (bat buoc khi game doi dang nhap: tai khoan 7Road da luu
#                          trong app - script chon tu danh sach, mat khau app tu dien)
#           -Seed nho     (loai hat lan nay; mac dinh khoai - danh sach trong hat_giong.ps1)
#  Tuy chon: -KeepDevice   (khong tat thiet bi khi xong - de test)
#            -SkipLaunch   (thiet bi da mo san va dang o trong game)
#            -LoginOnly    (chi dang nhap toi sanh chinh roi dung)
#            -StepShots    (luu anh tung buoc vao logs\)
#            -TestTelegram (chi gui thu anh len Telegram - kiem tra telegram.json)
#            -Manual       (chay tay: bo qua /tamdung - run.bat va lenh /chay tu them)
#            -ViewOnly     (chi chup anh ruong gui Telegram - lenh /xemruong)
#  Telegram: dien bot_token + chat_id vao telegram.json (xem README.md)
#  Tu lap lich: chay xong tu hen lan sau luc cay chin ($AutoSchedule, xem phan CAU HINH)
#  -Job tham_hiem: thay vi nong trai -> Thu cuoi tham hiem (nhan thuong 3 to doi + cho di tiep, hen lan sau luc
#                  to doi xong som nhat). Phan rieng: tham_hiem\cong_cu\tham_hiem.ps1; lich "DDTank Farm - <tk> - tham hiem"
# =====================================================================
param(
    [string]$Account,      # tai khoan 7Road
    [ValidateSet('nong_trai', 'tham_hiem')]
    [string]$Job = 'nong_trai',   # viec cua luot chay: nong trai (mac dinh) | thu cuoi tham hiem
    [string]$Seed,         # loai hat cho lan nay (khoai, le, nho, tao, thanhlong, ngo, bapcai, catim - xem hat_giong.ps1)
    [switch]$KeepDevice,
    [switch]$SkipLaunch,
    [switch]$StepShots,    # luu anh man hinh o tung buoc vao logs\ (de kiem tra)
    [switch]$LoginOnly,    # chi dang nhap toi sanh chinh roi dung (de test)
    [switch]$TestTelegram, # chi gui thu 2 anh gan nhat trong logs\ len Telegram roi thoat
    [switch]$Manual,       # chay tay (run.bat, /chay): van chay khi dang /tamdung
    [switch]$ViewOnly,     # chi vao nong trai chup anh ruong, khong thu hoach / gieo / lap lich (/xemruong)
    [switch]$StayOpen      # (phat trien) xong khong dong app, khong tat thiet bi - de quan sat / thu tiep bang tay
)

# ------------------------- KICH THUOC MAN HINH -------------------------
#  Thiet bi "auto" hien tai: 1600 x 900 (ngang), DPI 240
#    - MuMu: Cai dat > Hien thi > Tuy chinh 1600 x 900, DPI 240
#    - adb: "wm size" bao 900x1600 (chieu doc goc), game chay ngang nen anh chup = 1600x900
#  Moi so lieu pixel trong script deu do o kich thuoc nay:
#    - Anh mau trong templates\ (13 file): so khop tung pixel, KHONG tu co gian
#    - Toa do co dinh: $FarmWalkPoint, $BackRowWalkOffset, $PlotOffsets,
#      vung tim kiem (o dieu khoan, popup "Nhan de tiep tuc"), khoang cach hang (45 px)
#      va he so isometric (0.51 / 0.89 / 0.45) trong Harvest-All
#  Neu doi sang kich thuoc khac (vd 1280x720, 1920x1080) hoac doi DPI:
#    - Anh mau se khong con khop -> script khong thay nut, ban tay, bien go, hat giong...
#      -> bao loi "Khong vao duoc sanh chinh" / thu hoach 0 o / "Khong tim thay ruong"
#    - Toa do co dinh se bam lech -> nhan vat di sai cho, keo hat truot khoi o dat
#    - Phan dang nhap 7Road (doc giao dien Android bang uiautomator) van chay dung
#  => Tot nhat giu nguyen 1600x900 / DPI 240. Neu bat buoc doi: chup lai toan bo
#     anh mau o kich thuoc moi va do lai cac toa do/offset tren (hoac nhan he so ty le
#     moi chieu = rong_moi/1600, cao_moi/900 - chi dung khi giu ty le 16:9 va game
#     khong doi bo cuc giao dien).
# ---------------------------------------------------------------------

# ----------------------------- CAU HINH ------------------------------
# MuMu cai o D: hay C: tuy may (may DELL: C:) -> tim tren moi o dia, uu tien D:
$MuMuDir    = @('D:\', 'C:\') + @(Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root }) |
    ForEach-Object { [IO.Path]::Combine($_, "Program Files\Netease\MuMuPlayer\nx_main") } |   # khong dung Join-Path: may khong co o D: -> loi
    Where-Object { Test-Path ([IO.Path]::Combine($_, "MuMuManager.exe")) } | Select-Object -First 1
if (-not $MuMuDir) { $MuMuDir = "D:\Program Files\Netease\MuMuPlayer\nx_main" }
$DeviceName = "auto"
$Package    = "com.wan.ddten"     # app "DDTank"
$PlotCount  = 10
# /xemruong: thay giot nuoc / con sau tren o dat thi bam 1 cai de tuoi / bat sau ca ruong
$CareOnView    = $true
$WaterMaxScore = 20     # nguong anh mau giot nuoc (khop that 7.7-13.1)
$BugMaxScore   = 28     # nguong anh mau con sau (khop that 11.7-24.5, nen la thay doi sau bong bong nua trong suot)
# Diem bam (tren man hinh luc vua vao nong trai) de nhan vat di toi canh ruong
$FarmWalkPoint = @(600, 190)
# Xong hang truoc -> di toi diem nay (lech so voi ban tay o dau hang sau) roi moi thu hang sau
$BackRowWalkOffset = @(-133, -42)
# Cay dang lon (chua co o chin) thi cho them toi da bao nhieu phut (0 = khong cho, ket thuc luon).
# Di cung $AutoDelayMinutes am: lich hen truoc gio chin vai phut, vao toi noi thi cho cay chin roi thu luon.
$WaitRipeMinutes = 12
# Thoi gian khoai chin (gio) - dung de bao "thu hoach tiep theo" tren Telegram + tu lap lich
$GrowHours = 8

# Tu lap lich lan chay tiep theo cho TUNG tai khoan (task "DDTank Farm - <tai khoan>", chay 1 lan)
#  - Gieo xong: hen luc khoai chin + $AutoDelayMinutes phut (am = TRUOC gio chin; vd -5 = truoc 5 phut,
#    ket hop $WaitRipeMinutes = 12: vao ruong truoc gio chin, cho cay chin roi thu hoach + gieo ngay)
#  - Cay dang lon: hen theo gio chin da luu (state\<tai khoan>.json); qua gio chin ma van chua chin thi thu lai sau $RetryMinutes phut
#  - Loi: thu lai sau $ErrorRetryMinutes phut; qua $MaxRetries lan lien tiep thi dung chuoi
#  - Tat chuoi cua 1 tai khoan: lenh bot /huylich <tk> (tao file state\<tk>.off); /chay <tk> bat lai
$AutoSchedule      = $true
$AutoDelayMinutes  = -5
$RetryMinutes      = 10
$ErrorRetryMinutes = 30
$MaxRetries        = 3

# Mang Internet (vd Wi-Fi USB chua ket noi lai sau khi may thuc day)
#  - Truoc khi chay: cho co mang toi da $NetWaitMinutes phut
#  - Mat mang (luc bat dau hoac giua chung): hen lai sau $OfflineRetryMinutes phut, KHONG tinh vao $MaxRetries,
#    khong gui Telegram moi lan; co mang lai thi tin lan chay sau co dong "📵 Mat mang tu ..."
#  - Tin Telegram gui khong duoc -> luu vao logs\telegram_cho_gui\, lan chay sau co mang thi gui bu
$NetWaitMinutes      = 5
$OfflineRetryMinutes = 10
$NetTestHosts        = @('api.telegram.org', 'www.google.com', '1.1.1.1')   # thu ket noi cong 443
$AutoReconnect       = $true   # mat mang -> tu ket noi lai Wi-Fi da luu (ket_noi_mang.ps1)
$NetRepairAfterSec   = 60      # mat mang 60s -> netsh ket noi lai; 120s -> them khoi dong lai card Wi-Fi (can quyen admin)

# Gio bao tri game hang tuan, tinh theo GIO VIET NAM ($MaintTimeZone, dung du may de mui gio nao). Lich roi vao khung [Start - $MaintBeforeMin, End + $MaintAfterMin) se duoc doi
# sang sau gio bao tri; dang trong gio bao tri thi khong chay, loi trong gio bao tri khong tinh vao $MaxRetries.
# Day: Monday Tuesday Wednesday Thursday Friday Saturday Sunday. Them dong neu co nhieu khung gio.
$MaintenanceWindows = @(
    @{ Day = 'Thursday'; Start = '14:00'; End = '15:00' }    # thu 5, 14h-15h
)
$MaintBeforeMin = 25    # khong bat dau chay trong 25 phut truoc gio bao tri (1 luot: ~6 phut + cho chin toi da $WaitRipeMinutes)
$MaintAfterMin  = 5     # cho them 5 phut sau gio bao tri (phong bao tri keo dai)
$MaintTimeZone  = 'SE Asia Standard Time'   # UTC+7: Ha Noi / Bangkok
$MaintRetryMinutes = 30  # game BAO dang bao tri (popup "May chu dang duoc bao tri") ngoai khung tren (dot xuat / keo dai) -> thu lai sau bay nhieu phut, khong tinh loi
$MaintPopupMaxScore = 12 # nguong khop mau popup bao tri (templates\popup_baotri.png)

# Kiem tra may truoc khi mo MuMu (thiet bi can ~2-3 GB RAM). Thieu thi van chay nhung canh bao tren Telegram.
$MinFreeRamMB  = 2500   # RAM trong (Available) toi thieu
$MinFreeDiskGB = 5      # dung luong trong toi thieu o C: va o chua script
# Don log: xoa log + anh cac lan chay cu hon $KeepLogDays ngay (state\lich_su.jsonl cho /thongke duoc giu lai)
$KeepLogDays   = 14

# Thao tac giong nguoi (giam rui ro bi nhan ra la auto):
#  $DirectTouch: bam bang cach ghi thang su kien cham vao thiet bi cam ung cua MuMu ("Xiaomi Input" = dung duong click chuot that)
#                thay vi "input tap" (cu cham khong gan thiet bi nao). Loi thi tu quay ve "input tap".
#  $HumanLike  : lech toa do bam/vuot vai pixel, giu ngon 50-120ms, cho giua cac buoc dao dong, luot tu dong bat dau lech 0-60s.
$DirectTouch  = $true
$HumanLike    = $true
$TapJitterPx  = 5       # lech toa do bam toi da +-5px (man hinh 1600x900)
$StartJitterSec = 60    # luot tu dong (khong -Manual) cho ngau nhien 0-60s truoc khi mo MuMu

# Thu lai NGAY trong luot khi thao tac game loi (popup la, game lag, khong thay nut...): lan 1 mo lai game,
# lan 2 khoi dong lai thiet bi. Het so lan moi bao loi + hen lai sau $ErrorRetryMinutes nhu cu.
$StepRetries   = 3      # moi buoc nho (vao game, mo nong trai, thu hoach, gieo hat) loi thi lam lai buoc do, toi da 3 lan
$InRunRetries  = 1      # het lan thu cua 1 buoc -> khoi dong lai thiet bi va chay lai ca luot (1 lan)
$RetryBudgetMin = 35    # luot da chay qua 35 phut thi thoi thu lai (Task Scheduler diet luot sau 45 phut)
$SafetyRunMin   = 50    # dau luot hen san 1 luot du phong sau 50 phut (luot bi treo/bi diet van con luot sau). 0 = tat
$QueueWaitMin   = 15    # trung luot dang chay (tai khoan khac) -> cho toi da 15 phut roi chay luon; qua thi hen lai sau $RetryMinutes
# Loi ma thu lai cung vo ich -> bao loi luon (thieu cau hinh / tai khoan / het hat / sai ten hat)
$NoRetryErrors = 'chưa truyền -Account|chưa được app lưu mật khẩu|Không thấy tài khoản|Không tìm thấy hạt|Không có loại hạt|bản cập nhật quá'
# Game tai ban cap nhat (thuong ngay sau bao tri, vd 19/11 15:02: 90 MB) -> cho, KHONG tat app (game ghi "vui long khong thoat game").
$UpdateWaitMin  = 20     # cho game tai cap nhat toi da bay nhieu phut moi luot (dem tu lan dau thay man hinh cap nhat)
$UpdateMaxScore = 12     # nguong khop mau templates\update_screen.png (dong "Dang cap nhat den phien ban" goc duoi trai)

# Loai hat (danh sach trong hat_giong.ps1). -Seed / "/chay <tk> <hat>" chon cho 1 lan chay; khong ghi -> $DefaultSeed.
# Hat da chon het (khong con trong bang) -> gieo $DefaultSeed thay. Gieo xong hat khac khoai ma con o trong
# (hat khong du 10 o) -> keo them $DefaultSeed qua ca ruong cho kin ($FillWithDefault; o da co cay game tu bo qua).
$DefaultSeed     = 'khoai'
$FillWithDefault = $true
$SeedMaxScore    = 13    # nguong anh mau hat (khop that 0-10.4, hat khac >= 18.9)
# Gio chin: doc dong ho dem nguoc tren o dat ("03:06:53") ngay sau khi gieo (mau chu so: templates\timer_digits.txt).
# Khong doc duoc -> uoc luong $GrowHours (dung cho khoai). $TimerMaxDist: chu so lech qua nguong nay -> bo dong ho do.
$ReadTimers   = $true
$TimerMaxDist = 9.0     # 19/11: chu so dung lech 0-7.4 (nen duong da lech hon), chu so chua tung co mau lech >= 6.7
                        # -> nguong rong + Get-TimerRipe chi tin dong ho co it nhat 1 dong ho khac khop (+-90 giay)

# Toa do 10 o dat tinh tu tam bien go canh ruong (farm_sign).
# Thu tu keo hat: hang truoc phai -> trai, roi hang sau trai -> phai.
$PlotOffsets = @(
    @(253,336), @(163,286), @(73,236), @(-22,186), @(-117,136),   # hang truoc (gan nhan vat)
    @(-22,86),  @(73,136),  @(168,186), @(263,236), @(358,281)    # hang sau
)
# ---------------------------------------------------------------------

$ErrorActionPreference = "Stop"
$Root     = $PSScriptRoot
$Tpl      = Join-Path $Root "templates"
$LogDir   = Join-Path $Root "logs"
. (Join-Path $Root "ket_noi_mang.ps1")   # Get-WifiInfo, Save-WifiProfile, Repair-Network
. (Join-Path $Root "hat_giong.ps1")      # $SeedTypes, ConvertTo-SeedKey
# anh RAW (chup nhanh hon PNG), log van luu PNG. Moi luot 1 file rieng (theo PID): 19/11 adb treo cua luot truoc
# giu file chung -> luot sau loi "file dang duoc tien trinh khac su dung".
$Shot     = Join-Path $env:TEMP "ddtank_farm_screen_$PID.raw"
$Manager  = Join-Path $MuMuDir "MuMuManager.exe"
$Adb      = Join-Path $MuMuDir "adb.exe"
New-Item -ItemType Directory -Force $LogDir | Out-Null
$Stamp    = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile  = Join-Path $LogDir "run_$Stamp.log"

# Bien dich Vision.cs o che do toi uu (/optimize) -> so anh nhanh hon
$cp = New-Object System.CodeDom.Compiler.CompilerParameters
$cp.CompilerOptions = "/optimize+"
[void]$cp.ReferencedAssemblies.Add("System.Drawing.dll")
Add-Type -TypeDefinition (Get-Content (Join-Path $Root "Vision.cs") -Raw) -CompilerParameters $cp

# Viec cua luot chay (-Job). Moi viec co trang thai / lich / tieu de Telegram rieng de khong de len nhau:
#   state\<khoa>.json / .off / .offline, task "DDTank Farm - <tk>[ - tham hiem]"
$IsTH     = ($Job -eq 'tham_hiem')
$StateKey = if ($IsTH) { "$Account.tham_hiem" } else { $Account }
$TaskFull = if ($IsTH) { "DDTank Farm - $Account - tham hiem" } else { "DDTank Farm - $Account" }
$TgHead   = if ($IsTH) { "🐎 Thám hiểm [$Account]" } else { "🚜 DDTank [$Account]" }
if ($IsTH) { . (Join-Path $Root "tham_hiem\cong_cu\tham_hiem.ps1") }

function Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# ---------------------------- MuMu / ADB -----------------------------
function Get-MuMuInfo {
    # 19/11 10:50 + 10:56: vua bat thiet bi (may thieu RAM) MuMuManager ban, "info" qua 30 giay -> hong ca luot.
    # -> hoi lai toi da 3 lan truoc khi bao loi
    for ($k = 1; ; $k++) {
        try { $json = Invoke-MuMu "info -v all" 30; break }
        catch {
            if ($k -ge 3) { throw }
            Log "MuMuManager chua tra loi (lan $k/3): $($_.Exception.Message) -> hoi lai"
            Start-Sleep 5
        }
    }
    $all = $json | ConvertFrom-Json
    foreach ($p in $all.PSObject.Properties) {
        if ($p.Value.name -eq $DeviceName) { return $p.Value }
    }
    throw "Không tìm thấy thiết bị MuMu tên '$DeviceName'"
}

$script:Serial = $null
$script:Index  = $null

function Start-Device {
    $info = Get-MuMuInfo
    $script:Index = $info.index
    if (-not $info.is_android_started) {
        Log "Mo thiet bi '$DeviceName' (index $($info.index))..."
        [void](Invoke-MuMu "control -v $($info.index) launch" 90)
    } else {
        Log "Thiet bi '$DeviceName' da chay san"
    }
    # cho Android khoi dong xong VA co cong ADB
    $deadline = (Get-Date).AddMinutes(3)
    while (-not ($info.is_android_started -and $info.adb_port)) {
        if ((Get-Date) -gt $deadline) { throw "Thiết bị không khởi động được trong 3 phút" }
        Start-Sleep 3
        $info = Get-MuMuInfo
    }
    $script:Serial = "$($info.adb_host_ip):$($info.adb_port)"
    try { [void](Invoke-AdbTimed "connect $($script:Serial)" 15) } catch {}
    # cho ADB tra loi duoc (moi lenh toi da 15 giay, ca vong toi da ~1 phut)
    $deadline = (Get-Date).AddMinutes(1)
    while ($true) {
        $bc = try { Invoke-AdbTimed "-s $($script:Serial) shell getprop sys.boot_completed" 15 } catch { '' }
        if ($bc -match "1") { break }
        if ((Get-Date) -gt $deadline) { throw "ADB không kết nối được tới $script:Serial" }
        Start-Sleep 2
        try { [void](Invoke-AdbTimed "connect $($script:Serial)" 15) } catch {}
    }
    Start-Sleep 3
    Log "ADB: $script:Serial"
    Find-TouchDevice
}

# ---------------------- Bam / vuot giong nguoi ----------------------
$script:TouchDev = $null          # vd /dev/input/event4 (so thu tu co the doi sau khi khoi dong lai may ao)
$script:TouchPushed = @{}
$TouchTmp = Join-Path $env:TEMP "ddtank_farm_cham"

# LUU Y: script dat $ErrorActionPreference = "Stop"; PowerShell 5.1 bien moi dong stderr cua lenh ngoai (adb) thanh loi
# (ke ca khi "2>$null") -> cac ham duoi day tu dat 'Continue' trong pham vi ham va doc stderr qua cmd /c.
function Find-TouchDevice {
    if (-not $DirectTouch) { return }
    $ErrorActionPreference = 'Continue'
    $dev = $null
    try {
        # getevent luon in canh bao "could not get driver version ..." ra stderr -> chi doc stdout (dong rac khong khop mau)
        $lines = (Invoke-AdbTimed "-s $($script:Serial) shell getevent -p" 15) -split "`r?`n"
    } catch { $lines = @() }
    foreach ($l in $lines) {
        if ($l -match 'add device \d+:\s*(/dev/input/event\d+)') { $cur = $Matches[1] }
        elseif ($l -match 'name:\s*"Xiaomi Input"') { $dev = $cur; break }
    }
    $script:TouchDev = $dev
    $script:TouchPushed = @{}
    if ($dev) { Log "Thiet bi cam ung: $dev (bam bang ghi thang su kien)" } else { Log "Khong thay thiet bi cam ung 'Xiaomi Input' -> bam bang input tap" }
}

# Chut ngau nhien: so ngau nhien nguyen trong [a, b]
function Rnd([int]$a, [int]$b) { Get-Random -Minimum $a -Maximum ($b + 1) }

# Cho $sec giay, dao dong 90%-140% khi $HumanLike
function Nap([double]$sec) {
    if ($HumanLike) { $sec = $sec * (0.9 + (Get-Random -Maximum 51) / 100.0) }
    Start-Sleep -Milliseconds ([int]($sec * 1000))
}

# File nhi phan struct input_event (64-bit, 24 byte/su kien; gio = 0 -> he thong tu dong gio)
function New-TouchBin($path, $events) {
    $fs = [IO.File]::Create($path); $w = New-Object IO.BinaryWriter $fs
    foreach ($e in $events) { $w.Write([long]0); $w.Write([long]0); $w.Write([uint16]$e[0]); $w.Write([uint16]$e[1]); $w.Write([int]$e[2]) }
    $w.Close()
}

function Push-TouchFile($name, $events) {
    if ($script:TouchPushed[$name]) { return }
    $ErrorActionPreference = 'Continue'
    New-Item -ItemType Directory -Force $TouchTmp | Out-Null
    $local = Join-Path $TouchTmp "$name.bin"
    New-TouchBin $local $events
    $o = Invoke-AdbTimed "-s $($script:Serial) push `"$local`" /data/local/tmp/ddt_$name.bin" 20
    if ($script:AdbExit -ne 0) { throw "push $name loi: $o" }
    $script:TouchPushed[$name] = $true
}

function Tap($x, $y, [int]$jit = $TapJitterPx) {
    $ErrorActionPreference = 'Continue'   # xem LUU Y o Find-TouchDevice
    $x = [int]$x; $y = [int]$y
    if ($HumanLike -and $jit -gt 0) { $x += Rnd (-$jit) $jit; $y += Rnd (-$jit) $jit }
    $x = [Math]::Max(1, [Math]::Min(1598, $x)); $y = [Math]::Max(1, [Math]::Min(898, $y))
    if ($script:TouchDev) {
        try {
            # toa do RAW cua thiet bi cam ung (doc 900x1600): X = 900 - y, Y = x (do tu getevent luc nguoi choi click)
            Push-TouchFile 'len' @(@(3, 57, -1), @(1, 330, 0), @(0, 0, 0))
            $k = "x_${x}_$y"
            Push-TouchFile $k @(@(3, 57, 1), @(1, 330, 1), @(3, 53, (900 - $y)), @(3, 54, $x), @(0, 0, 0))
            $hold = if ($HumanLike) { (Rnd 50 120) / 1000.0 } else { 0.06 }
            $holdS = $hold.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
            $o = Invoke-AdbTimed "-s $($script:Serial) shell `"cat /data/local/tmp/ddt_$k.bin > $($script:TouchDev) && sleep $holdS && cat /data/local/tmp/ddt_len.bin > $($script:TouchDev)`"" 15
            if ($script:AdbExit -ne 0 -or "$o" -match 'denied|No such') { throw "$o" }
            return
        } catch {
            # adb treo -> nem loi de buoc duoc lam lai (khong phai loi cach bam)
            if ($_.Exception.Message -like 'adb không trả lời*') { Reset-Adb; throw }
            Log "Ghi su kien cham loi ($($_.Exception.Message)) -> tu gio dung input tap"
            $script:TouchDev = $null
        }
    }
    try { [void](Invoke-AdbTimed "-s $($script:Serial) shell input tap $x $y" 15) } catch { Reset-Adb; throw }
}

# Vuot (cuon danh sach): lech diem dau/cuoi vai pixel, thoi gian vuot dao dong 85%-125%
function Swipe($x1, $y1, $x2, $y2, [int]$ms) {
    if ($HumanLike) {
        $x1 = [int]$x1 + (Rnd -4 4); $y1 = [int]$y1 + (Rnd -4 4); $x2 = [int]$x2 + (Rnd -4 4); $y2 = [int]$y2 + (Rnd -4 4)
        $ms = [int]($ms * (Rnd 85 125) / 100)
    }
    try { [void](Invoke-AdbTimed "-s $($script:Serial) shell input swipe $([int]$x1) $([int]$y1) $([int]$x2) $([int]$y2) $ms" 20) } catch { Reset-Adb; throw }
}

# Thu lai trong luot: tat app (va neu -Device thi tat + bat lai ca thiet bi). Enter-Game se tu mo lai app.
$script:RetryNotes = @()
$script:NetRepairDone = @()

# Co the thu lai tiep khong (chua het thoi gian, khong tam dung / bao tri / mat mang, loi khong thuoc loai vo ich)
function Can-Retry([string]$msg) {
    if ($script:Paused -or $script:InMaintenance) { return $false }
    if ($msg -match $NoRetryErrors) { return $false }
    if (((Get-Date) - $script:StartTime).TotalMinutes -gt $RetryBudgetMin) { Log "Da chay qua $RetryBudgetMin phut -> khong thu lai nua"; return $false }
    if (-not $Manual -and (Get-MaintenanceEnd (Get-Date))) { return $false }   # chay tay trong gio bao tri (bao tri xong som) van lam lai buoc loi
    if (-not (Test-Internet)) { return $false }
    return $true
}

# Dong cac popup co nut X dang che man hinh (toi da 3 cai)
function Close-Popups {
    for ($k = 0; $k -lt 3; $k++) {
        Snap | Out-Null
        $x = Find "popup_close" 12
        if (-not $x.Count) { return }
        Log "Dong popup tai ($($x[0].X),$($x[0].Y))"; Tap $x[0].X $x[0].Y; Nap 1.5
    }
}

# Chay 1 buoc nho; loi thi sua ($Fix, mac dinh: dong popup) roi lam lai CHINH BUOC DO, toi da $StepRetries lan.
# Het lan -> nem loi ra ngoai (vong ngoai se khoi dong lai thiet bi / bao loi).
function Retry-Step([string]$Key, [string]$Label, [scriptblock]$Do, [scriptblock]$Fix = { Close-Popups }) {
    for ($k = 1; ; $k++) {
        try { return (& $Do) }
        catch {
            $msg = $_.Exception.Message
            if ($k -ge $StepRetries -or -not (Can-Retry $msg)) { throw }
            Log "Buoc '$Key' loi (lan $k/$StepRetries): $msg -> lam lai buoc nay"
            $script:RetryNotes += "🔁 Bước $Label lỗi lần ${k}: $(Short-Err $msg) → làm lại bước"
            try { Save-Shot "loi_${Key}_$k" } catch {}
            try { & $Fix } catch { Log "Sua truoc khi thu lai loi: $($_.Exception.Message)" }
            Nap 2
        }
    }
}
function Restart-Game([switch]$Device) {
    try { [void](Invoke-MuMu "control -v $($script:Index) app close -pkg $Package" 30) } catch {}
    Nap 3
    if ($Device) {
        Log "Tat thiet bi '$DeviceName' de khoi dong lai..."
        try { [void](Invoke-MuMu "control -v $($script:Index) shutdown" 90) } catch { Log "Tat thiet bi: $($_.Exception.Message)" }
        $dl = (Get-Date).AddSeconds(90)
        do { Start-Sleep 3; $i = Get-MuMuInfo } while ($i.is_android_started -and (Get-Date) -lt $dl)
        Start-Sleep 3
        Start-Device
    }
}

function Stop-Device {
    if ($null -eq $script:Index) { return }
    Log "Tat app DDTank..."
    if ($script:Serial) { try { [void](Invoke-AdbTimed "-s $($script:Serial) shell `"rm -f /data/local/tmp/ddt_*.bin`"" 10) } catch {} }   # file cham tam
    try { [void](Invoke-MuMu "control -v $($script:Index) app close -pkg $Package" 30) } catch { Log "Tat app: $($_.Exception.Message)" }
    Start-Sleep 2
    if ($KeepDevice) { Log "Giu thiet bi (-KeepDevice)"; return }
    Log "Tat thiet bi '$DeviceName'..."
    [void](Invoke-MuMu "control -v $($script:Index) shutdown" 90)
}

# Chay adb voi GIOI HAN THOI GIAN. adb co the treo vo han (19/11 00:31: "exec-out screencap" treo -> ca luot dung im
# toi khi Task Scheduler diet sau 45 phut, khong hen duoc lich moi). Qua gio -> diet adb, nem loi -> buoc duoc lam lai.
# $OutFile: ghi stdout (nhi phan) ra file; khong co thi tra ve chuoi stdout+stderr. $script:AdbExit = ma thoat.
function Invoke-AdbTimed([string]$ArgLine, [int]$TimeoutSec = 20, [string]$OutFile = $null, [string]$Exe = $Adb) {
    $psi = New-Object Diagnostics.ProcessStartInfo $Exe, $ArgLine
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $p = [Diagnostics.Process]::Start($psi)
    $fs = $null; $copy = $null; $outTask = $null
    if ($OutFile) { $fs = [IO.File]::Create($OutFile); $copy = $p.StandardOutput.BaseStream.CopyToAsync($fs) }
    else { $outTask = $p.StandardOutput.ReadToEndAsync() }
    $errTask = $p.StandardError.ReadToEndAsync()
    if (-not $p.WaitForExit($TimeoutSec * 1000)) {
        try { $p.Kill() } catch {}
        if ($fs) { try { [void]$copy.Wait(2000) } catch {}; $fs.Dispose() }
        $script:AdbExit = -1
        throw "$(if ($Exe -eq $Adb) { 'adb' } else { [IO.Path]::GetFileNameWithoutExtension($Exe) }) không trả lời sau $TimeoutSec giây ($($ArgLine -replace '^-s \S+ ', ''))"
    }
    $script:AdbExit = $p.ExitCode
    if ($fs) { try { [void]$copy.Wait(5000) } catch {}; $fs.Dispose(); return }
    return ($outTask.Result + $errTask.Result)
}

# Dau luot: diet lenh "adb exec-out screencap" con treo tu luot truoc (> 3 phut) va xoa file anh tam cu
function Clear-StaleAdb {
    try {
        $old = @(Get-CimInstance Win32_Process -Filter "Name='adb.exe'" | Where-Object {
            $_.CommandLine -match 'exec-out screencap' -and $_.CreationDate -lt (Get-Date).AddMinutes(-3) })
        foreach ($p in $old) { Log "Diet adb chup man hinh bi treo tu $($p.CreationDate.ToString('HH:mm dd/MM')) (PID $($p.ProcessId))"; Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue }
    } catch {}
    Get-ChildItem (Join-Path $env:TEMP "ddtank_farm_screen*.raw") -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $Shot -and $_.LastWriteTime -lt (Get-Date).AddHours(-1) } |
        ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }
}

# MuMuManager (bat/tat thiet bi, mo/dong app) cung co gioi han thoi gian: thiet bi treo thi lenh nay co the treo theo
function Invoke-MuMu([string]$ArgLine, [int]$TimeoutSec = 60) { Invoke-AdbTimed $ArgLine $TimeoutSec $null $Manager }

# adb treo -> ngat va ket noi lai (lenh sau thuong chay lai binh thuong)
function Reset-Adb {
    try { [void](Invoke-AdbTimed "disconnect $($script:Serial)" 10) } catch {}
    try { [void](Invoke-AdbTimed "connect $($script:Serial)" 15) } catch {}
}

function Snap {
    # RAW (khong -p): may ao khong phai nen PNG -> ~0.7s thay vi ~1.3s moi lan chup. Toi da 15 giay.
    # 19/11 10:48: may con 1,1 GB RAM -> anh tra ve bi cat cut ("Anh RAW khong hop le") -> hong ca buoc.
    # Kiem tra du kich thuoc (header w,h + w*h*4 byte), thieu thi chup lai ngay (toi da 3 lan).
    for ($k = 1; $k -le 3; $k++) {
        try { Invoke-AdbTimed "-s $($script:Serial) exec-out screencap" 15 $Shot }
        catch { Log "Chup man hinh: $($_.Exception.Message) -> ket noi lai adb"; Reset-Adb; throw "Chụp màn hình bị treo (adb không trả lời 15 giây)" }
        $why = Test-RawShot $Shot
        if (-not $why) { [Vision]::Reset(); return $Shot }
        Log "Anh chup loi ($why) -> chup lai (lan $k/3)"
        Start-Sleep -Milliseconds 500
    }
    Reset-Adb
    throw "Ảnh chụp màn hình bị lỗi 3 lần liên tiếp ($why)"
}

# Anh RAW cua screencap hop le -> $null; loi -> mo ta ngan
function Test-RawShot($path) {
    try {
        $len = (Get-Item $path -ErrorAction Stop).Length
        if ($len -lt 16) { return "rỗng ($len byte)" }
        $fs = [IO.File]::OpenRead($path)
        try { $h = New-Object byte[] 8; [void]$fs.Read($h, 0, 8) } finally { $fs.Close() }
        $w = [BitConverter]::ToInt32($h, 0); $ht = [BitConverter]::ToInt32($h, 4)
        if ($w -le 0 -or $ht -le 0 -or $w -gt 10000 -or $ht -gt 10000) { return "header sai ${w}x$ht" }
        $need = [long]$w * $ht * 4 + 12
        if ($len -lt $need) { return "cụt $len/$need byte" }
        return $null
    } catch { return "không đọc được: $($_.Exception.Message)" }
}

function Save-Shot($name) {
    $dst = Join-Path $LogDir "${Stamp}_$name.png"
    [Vision]::SavePng((Snap), $dst)
    $script:LastShot = $dst
    Log "Da luu anh: $dst"
}

# ------------------------------ TELEGRAM ------------------------------
# Anh se gui len Telegram khi script chay xong (cau hinh trong telegram.json)
$script:Photos = New-Object System.Collections.Generic.List[object]
function Add-Photo($caption) {
    if ($script:LastShot) { $script:Photos.Add(@{ Path = $script:LastShot; Caption = $caption }) }
}

# Dong tong ket gan vao chu thich anh dau tien: gio xong viec, gio khoai chin, lan chay toi
# $nextLine: ket qua tu lap lich (Plan-NextRun); khong co thi lay lich co dinh "DDTank Farm"
function Build-Summary($sowTime, $nextLine) {
    $lines = @("✅ Xong việc lúc: $(Get-Date -Format 'HH:mm dd/MM/yyyy')")
    if ($IsTH) {
        # Thu cuoi tham hiem: tung to doi (nhan thuong / xuat phat / dang chay, gio xong)
        if ($script:ThLines.Count) { $lines += $script:ThLines }
    } elseif ($sowTime) {
        $r = if ($script:SowRipe) { $script:SowRipe } else { $sowTime.AddHours($GrowHours) }
        $lines += "🌾 Thu hoạch tiếp theo (cây chín): $($r.ToString('HH:mm dd/MM/yyyy'))"
    } elseif ($script:GrowRipe) {
        $lines += "🌾 Cây chín lúc: $($script:GrowRipe.ToString('HH:mm dd/MM/yyyy')) (theo đồng hồ trên ô đất)"
    } elseif ($script:RipeAt -and $script:RipeAt -gt (Get-Date)) {
        $lines += "🌾 Cây chín lúc: $($script:RipeAt.ToString('HH:mm dd/MM/yyyy')) (theo lần gieo trước)"
    } elseif ($ViewOnly -and $script:RipeAt) {
        $lines += "🌾 Cây chín lúc: $($script:RipeAt.ToString('HH:mm dd/MM/yyyy')) (đã tới giờ chín)"
    } else {
        $lines += "🌾 Thu hoạch tiếp theo: chưa xác định (lần này không gieo)"
    }
    foreach ($w in @($script:SeedNotes | Select-Object -Unique)) { if ($w) { $lines += $w } }
    if (-not $IsTH -and -not $ViewOnly -and $Account -and $script:SeedKey -and $script:SeedKey -ne $DefaultSeed) {
        $lines += "🌱 Hạt cố định của $($Account): $(Seed-Text $script:SeedKey) (về khoai: /chay $Account khoai)"
    }
    if ($script:QueuedMin) { $lines += "⏳ Trùng lượt đang chạy → đã xếp hàng chờ $($script:QueuedMin) phút" }
    if ($script:UpdateStart) {
        $ue = if ($script:UpdateEnd) { $script:UpdateEnd } else { Get-Date }
        $um = [math]::Max(1, [int][math]::Round(($ue - $script:UpdateStart).TotalMinutes))
        $lines += "⬇️ Game tải bản cập nhật $um phút$(if (-not $script:UpdateEnd) { ' (chưa xong)' })"
    }
    if ($script:OfflineNote) { $lines += $script:OfflineNote }
    foreach ($w in @($script:RetryNotes)) { if ($w) { $lines += $w } }
    if ($script:NetRepairNote) { $lines += $script:NetRepairNote }
    foreach ($w in @($script:MachineWarn)) { if ($w) { $lines += $w } }
    if ($nextLine) { $lines += $nextLine }
    else {
        try {
            $next = (Get-ScheduledTaskInfo -TaskName "DDTank Farm" -ErrorAction Stop).NextRunTime
            if ($next) { $lines += "⏰ Lần chạy tự động tới: $($next.ToString('HH:mm dd/MM/yyyy'))" }
        } catch {}
    }
    return ($lines -join "`n")
}

# Loi rut gon cho Telegram: bo "Exception calling "X" with "N" argument(s): ", toi da 140 ky tu
function Short-Err([string]$m) {
    $m = ($m -replace 'Exception calling "[^"]+" with "\d+" argument\(s\): ', '').Trim().Trim('"')
    if ($m.Length -gt 140) { $m = $m.Substring(0, 137) + '...' }
    return $m
}

# Thong bao loi goc (bo cac lop boc "One or more errors occurred")
function Err-Msg($e) {
    if ($e -is [System.Management.Automation.ErrorRecord]) { $e = $e.Exception }
    while ($e.InnerException) { $e = $e.InnerException }
    if ($e -is [System.Threading.Tasks.TaskCanceledException]) { return "Het thoi gian cho (mang khong phan hoi)" }
    return $e.Message
}

# Co Internet khong: thu ket noi cong 443 toi vai may chu, moi may toi da 5 giay
function Test-Internet {
    foreach ($h in $NetTestHosts) {
        $c = New-Object System.Net.Sockets.TcpClient
        try { if ($c.ConnectAsync($h, 443).Wait(5000) -and $c.Connected) { return $true } } catch {} finally { $c.Close() }
    }
    return $false
}

# Cho co mang toi da $minutes phut (0 = chi kiem tra 1 lan)
# Mat mang: sau $NetRepairAfterSec giay tu ket noi lai Wi-Fi (netsh), them $NetRepairAfterSec giay nua ma van mat
# thi khoi dong lai card Wi-Fi (chi khi lich chay co quyen admin). Xem ket_noi_mang.ps1.
function Wait-Internet([double]$minutes) {
    if (Test-Internet) { Save-WifiProfile; return $true }
    $start = Get-Date
    $deadline = $start.AddMinutes($minutes)
    if ($minutes -gt 0) { Log "Chua co mang Internet -> cho toi da $minutes phut..." }
    $level = 0
    while ((Get-Date) -lt $deadline) {
        Start-Sleep 15
        if (Test-Internet) {
            Log "Da co mang Internet"
            if ($level -gt 0) {
                $ok = @($script:NetRepairDone | ForEach-Object { $_ -split ', ' } | Where-Object { $_ -and $_ -notlike 'THỬ*' } | Select-Object -Unique)
                $what = if ($ok.Count) { "đã tự $($ok -join ', ')" } else { "đã thử kết nối lại (không được, mạng tự có lại)" }
                $script:NetRepairNote = "🔧 Mất mạng lúc $($start.ToString('HH:mm')) – $what, có mạng lại lúc $(Get-Date -Format 'HH:mm')"
            }
            return $true
        }
        $off = ((Get-Date) - $start).TotalSeconds
        if ($AutoReconnect -and $level -lt 2 -and $off -ge $NetRepairAfterSec * ($level + 1)) {
            $level++
            $script:NetRepairDone += (Repair-Network -Level $level -LogFn { param($m) Log $m })
        }
    }
    if ($minutes -gt 0) { Log "Van chua co mang sau $minutes phut" }
    return $false
}

# Gui anh + chu thich len Telegram, thu toi da 3 lan.
# Tra ve $true khi xong (gui duoc, hoac khong can / khong the gui lai), $false khi loi mang -> nen gui bu sau
function Post-Telegram($paths, $text, [double]$netWaitMin = 2) {
    $paths = @($paths | Where-Object { $_ -and (Test-Path $_) })
    if (-not $paths.Count -and -not $text) { return $true }   # khong anh + khong chu: khong gui (0 anh = tin chu)
    # Gioi han Telegram: chu thich anh 1024 ky tu, tin chu 4096. 19/11 04:24 chu thich qua dai -> loi 400, mat tin.
    # Qua dai -> gui anh kem phan dau, phan con lai gui thanh tin chu ngay sau.
    if ($paths.Count -and $text.Length -gt 1000) {
        $lines = $text -split "`n"; $cap = ''; $i = 0
        while ($i -lt $lines.Count -and ($cap.Length + $lines[$i].Length + 1) -le 950) { $cap += $lines[$i] + "`n"; $i++ }
        if ($i -eq 0) { $cap = $text.Substring(0, 950); $rest = $text.Substring(950) }
        else { $rest = ($lines[$i..($lines.Count - 1)] -join "`n") }
        $ok = Post-Telegram $paths ($cap.TrimEnd() + "`n…(xem tiếp tin sau)") $netWaitMin
        if ($ok -and $rest.Trim()) { [void](Post-Telegram @() $rest 0) }
        return $ok
    }
    if (-not $paths.Count -and $text.Length -gt 4000) { $text = $text.Substring(0, 4000) + "`n…(đã cắt bớt)" }
    $cfgPath = Join-Path $Root "telegram.json"
    if (-not (Test-Path $cfgPath)) { Log "Chua co telegram.json -> bo qua gui Telegram"; return $true }
    $cfg = Get-Content $cfgPath -Raw | ConvertFrom-Json
    $token = [string]$cfg.bot_token; $chat = [string]$cfg.chat_id
    if (-not $token -or -not $chat -or $token -match "DIEN_") { Log "telegram.json chua dien bot_token/chat_id -> bo qua"; return $true }
    if (-not (Wait-Internet $netWaitMin)) { Log "Khong co mang -> chua gui duoc Telegram"; return $false }

    Add-Type -AssemblyName System.Net.Http
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    for ($try = 1; $try -le 3; $try++) {
        $client = New-Object System.Net.Http.HttpClient
        $client.Timeout = [TimeSpan]::FromSeconds(90)
        try {
            # Telegram chi hien chu thich ngoai album khi CHI 1 anh co chu thich
            # -> gop tat ca noi dung vao chu thich anh dau tien, cac anh sau de trong
            $form = New-Object System.Net.Http.MultipartFormDataContent
            $form.Add((New-Object System.Net.Http.StringContent($chat)), "chat_id")
            $media = @()
            for ($i = 0; $i -lt $paths.Count; $i++) {
                $file = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, [IO.File]::ReadAllBytes($paths[$i]))
                $file.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
                if ($paths.Count -eq 1) {
                    $form.Add((New-Object System.Net.Http.StringContent($text)), "caption")
                    $form.Add($file, "photo", (Split-Path $paths[$i] -Leaf))
                } else {
                    $form.Add($file, "p$i", (Split-Path $paths[$i] -Leaf))
                    $m = @{ type = "photo"; media = "attach://p$i" }
                    if ($i -eq 0) { $m.caption = $text }
                    $media += $m
                }
            }
            if ($paths.Count -eq 0) {
                $method = "sendMessage"
                $form.Add((New-Object System.Net.Http.StringContent($text)), "text")
            } elseif ($paths.Count -eq 1) { $method = "sendPhoto" }
            else {
                $method = "sendMediaGroup"
                $form.Add((New-Object System.Net.Http.StringContent((ConvertTo-Json @($media) -Compress))), "media")
            }
            # GetAwaiter().GetResult(): loi mang bao dung nguyen nhan (thay vi "null-valued expression")
            $resp = $client.PostAsync("https://api.telegram.org/bot$token/$method", $form).GetAwaiter().GetResult()
            $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
            $code = [int]$resp.StatusCode
            if ($resp.IsSuccessStatusCode) { Log "Da gui $(if ($paths.Count) { "$($paths.Count) anh" } else { 'tin nhan' }) len Telegram"; return $true }
            Log "Gui Telegram loi ($code): $body"
            if ($code -lt 500 -and $code -ne 429) { return $true }   # sai token / noi dung: gui lai cung vay
        } catch {
            Log "Gui Telegram loi (lan $try/3): $(Err-Msg $_)"
        } finally { $client.Dispose() }
        if ($try -lt 3) { Start-Sleep 20 }
    }
    return $false
}

# Tin chua gui duoc (mat mang) -> luu lai, lan chay sau co mang thi gui bu
$PendingDir = Join-Path $LogDir "telegram_cho_gui"
function Save-PendingTelegram($paths, $text) {
    New-Item -ItemType Directory -Force $PendingDir | Out-Null
    $f = Join-Path $PendingDir "${Stamp}_$Account.json"
    [ordered]@{ paths = @($paths); text = $text } | ConvertTo-Json | Set-Content -Path $f -Encoding UTF8
    Log "Luu tin Telegram de gui bu khi co mang: $f"
}
function Send-PendingTelegram {
    if (-not (Test-Path $PendingDir)) { return }
    $files = @(Get-ChildItem $PendingDir -Filter "*.json" | Sort-Object Name)
    if (-not $files.Count -or -not (Test-Internet)) { return }
    foreach ($f in $files) {
        try { $p = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Remove-Item $f.FullName -Force; continue }
        Log "Gui bu tin Telegram: $($f.Name)"
        if (Post-Telegram @($p.paths) ("📨 Tin gửi trễ (lúc đó mất mạng):`n" + $p.text) 0) { Remove-Item $f.FullName -Force }
        else { break }
    }
}

function Send-Telegram($photos, $summary, [double]$netWaitMin = 2) {
    $photos = @($photos | Where-Object { $_.Path -and (Test-Path $_.Path) })
    if (-not $photos.Count) {
        # 19/11 10:56: loi truoc khi chup duoc anh (vd luc bat thiet bi) -> truoc day khong gui gi, ban khong biet luot da hong.
        # Co loi (tru mat mang - da co co che bao rieng) -> gui tin chu.
        if (-not $script:ErrText -or $script:Outcome -eq 'offline') { return }
        $text = "$TgHead $(Get-Date -Format 'dd/MM HH:mm')`n❌ LỖI: $(Short-Err $script:ErrText)"
        if ($summary) { $text += "`n`n$summary" }
        Log ("Telegram <- (tin chu)`n    " + ($text -replace "`n", "`n    "))
        if (-not (Post-Telegram @() $text $netWaitMin)) { Save-PendingTelegram @() $text }
        return
    }
    $text = "$TgHead $(Get-Date -Format 'dd/MM HH:mm')`n" + (($photos | ForEach-Object { $_.Caption }) -join "`n")
    if ($summary) { $text += "`n`n$summary" }
    $paths = @($photos | ForEach-Object { $_.Path })
    Log ("Telegram <- {0}`n    {1}" -f (($paths | ForEach-Object { Split-Path $_ -Leaf }) -join ", "), ($text -replace "`n", "`n    "))
    if (-not (Post-Telegram $paths $text $netWaitMin)) { Save-PendingTelegram $paths $text }
}

# Noi dung tung anh (dong tieu de DDTank [tai khoan] gio duoc them 1 lan khi gui)
function Caption($text) { $text }

$script:StepNo = 0
# Luu anh chup gan nhat (khong chup moi) khi bat -StepShots
function Step($name) {
    if (-not $StepShots) { return }
    $script:StepNo++
    $dst = Join-Path $LogDir ("{0}_step{1:D2}_{2}.png" -f $Stamp, $script:StepNo, $name)
    [Vision]::SavePng($Shot, $dst)
    Log "  [step $script:StepNo] $name"
}


# Tim template tren anh chup moi nhat. $region = @(x,y,w,h) hoac $null (ca man hinh)
function Find($name, $maxScore, $region = $null) {
    if (-not $region) { $region = @(0,0,0,0) }
    $r = [Vision]::FindAll($Shot, (Join-Path $Tpl "$name.png"), $maxScore,
                           $region[0], $region[1], $region[2], $region[3])
    return ,@($r)
}

# Chup lien tuc cho toi khi thay template (hoac het thoi gian)
function WaitFor($name, $maxScore, $timeoutSec, $region = $null) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    do {
        Snap | Out-Null
        $r = Find $name $maxScore $region
        if ($r.Count) { return $r[0] }
        Start-Sleep -Milliseconds 300
    } while ((Get-Date) -lt $deadline)
    return $null
}

# Giu va keo qua nhieu diem (motionevent DOWN/MOVE/UP trong 1 lenh shell)
function Drag-Path($points) {
    # $HumanLike: lech moi diem +-3px (o dat rong ~90px), giu 0.5-0.8s truoc khi keo, buoc keo 34-46px
    if ($HumanLike) { $points = @($points | ForEach-Object { , @(([int]$_[0] + (Rnd -3 3)), ([int]$_[1] + (Rnd -3 3))) }) }
    $hold = if ($HumanLike) { ((Rnd 50 80) / 100.0).ToString('0.00', [Globalization.CultureInfo]::InvariantCulture) } else { '0.6' }
    $stepPx = if ($HumanLike) { Rnd 34 46 } else { 40 }
    $cmds = New-Object System.Collections.Generic.List[string]
    $cmds.Add("input motionevent DOWN $($points[0][0]) $($points[0][1])")
    $cmds.Add("sleep $hold")
    for ($i = 1; $i -lt $points.Count; $i++) {
        $a = $points[$i-1]; $b = $points[$i]
        $dist  = [Math]::Sqrt([Math]::Pow($b[0]-$a[0],2) + [Math]::Pow($b[1]-$a[1],2))
        $steps = [Math]::Max(1, [int]($dist / $stepPx))
        for ($k = 1; $k -le $steps; $k++) {
            $x = [int]($a[0] + ($b[0]-$a[0]) * $k / $steps)
            $y = [int]($a[1] + ($b[1]-$a[1]) * $k / $steps)
            $cmds.Add("input motionevent MOVE $x $y")
        }
    }
    $last = $points[$points.Count-1]
    $cmds.Add("input motionevent UP $($last[0]) $($last[1])")
    try { [void](Invoke-AdbTimed "-s $($script:Serial) shell `"$($cmds -join '; ')`"" 60) } catch { Reset-Adb; throw }
}

# ------------------------------ GAME ---------------------------------
# ----------------------- Giao dien Android (uiautomator) ---------------------
# Hop dang nhap 7Road la giao dien Android goc -> doc duoc id/chu chinh xac
function Get-UiNodes {
    try {
        [void](Invoke-AdbTimed "-s $($script:Serial) shell uiautomator dump /sdcard/ddt_ui.xml" 30)
        $raw = (Invoke-AdbTimed "-s $($script:Serial) shell cat /sdcard/ddt_ui.xml" 15) -replace "`r?`n", ""
    } catch { Reset-Adb; throw }
    $nodes = @()
    try { $xml = [xml]$raw } catch { return ,$nodes }
    foreach ($n in $xml.SelectNodes("//node")) {
        if ($n.bounds -match '\[(\d+),(\d+)\]\[(\d+),(\d+)\]') {
            $nodes += [pscustomobject]@{
                Id = ($n.'resource-id' -replace '^.*:id/', ''); Text = $n.text
                X1 = [int]$Matches[1]; Y1 = [int]$Matches[2]; X2 = [int]$Matches[3]; Y2 = [int]$Matches[4]
                X = [int](([int]$Matches[1] + [int]$Matches[3]) / 2); Y = [int](([int]$Matches[2] + [int]$Matches[4]) / 2)
            }
        }
    }
    return ,$nodes
}

function Find-Ui($nodes, $id, $text = $null) {
    $nodes | Where-Object { $_.Id -eq $id -and ($null -eq $text -or $_.Text -eq $text) } | Select-Object -First 1
}

# Cho toi khi thay node co id (va chu) mong muon
function WaitUi($id, $text, $timeoutSec) {
    $deadline = (Get-Date).AddSeconds($timeoutSec)
    do {
        $n = Find-Ui (Get-UiNodes) $id $text
        if ($n) { return $n }
        Nap 1
    } while ((Get-Date) -lt $deadline)
    return $null
}

# Man hinh "Dang nhap" -> 7Road Login -> chon tai khoan da luu -> Login
function Login-7Road {
    if (-not $Account) { Save-Shot "loi_thieu_tai_khoan"; throw "Game đang đợi đăng nhập nhưng chưa truyền -Account <tên tài khoản>" }
    Log "Dang nhap 7Road bang tai khoan '$Account'"
    # Hop chon cach dang nhap (co the bo qua neu app vao thang form 7Road)
    $deadline = (Get-Date).AddSeconds(15)
    $form = $null
    while (-not $form -and (Get-Date) -lt $deadline) {
        $ui = Get-UiNodes
        $form = Find-Ui $ui "txt_account"
        if ($form) { break }
        # Game tu dang nhap bang phien truoc (vd vua dang nhap may phut truoc) -> khong hien form, nhay thang toi "Vao game"
        Snap | Out-Null
        if ((Find "btn_vaogame" 15).Count) {
            Log "Game tu dang nhap bang phien truoc (khong hien form 7Road) -> bam Vao game"
            Step "tu_dang_nhap"
            return
        }
        $m = Find-Ui $ui "txt_login_des" "7Road Login"
        if ($m) { Log "Bam 7Road Login"; Tap $m.X $m.Y; Nap 2 }
        else { Nap 1 }
    }
    if (-not $form) { Save-Shot "loi_7road"; throw "Không mở được form đăng nhập 7Road" }
    Snap | Out-Null; Step "form_7road"

    $ui = Get-UiNodes
    if ((Find-Ui $ui "txt_account").Text -ne $Account) {
        # Mo danh sach tai khoan da luu, tim dung ten, cuon xuong neu chua thay
        $sel = Find-Ui $ui "view_acc_select"
        Tap $sel.X $sel.Y; Nap 1.5
        $picked = $false; $lastNames = ""
        for ($page = 0; $page -lt 15 -and -not $picked; $page++) {
            $ui = Get-UiNodes
            $names = @($ui | Where-Object { $_.Id -eq "txt_name" })
            $hit = $names | Where-Object { $_.Text -eq $Account } | Select-Object -First 1
            if ($hit) {
                # bam vao TEN (txt_name), khong bam nut X (btn_close = xoa tai khoan da luu)
                Log "Chon tai khoan '$Account'"; Tap $hit.X $hit.Y; Nap 1.5; $picked = $true; break
            }
            $now = ($names | ForEach-Object { $_.Text }) -join "|"
            if (-not $names.Count -or $now -eq $lastNames) { break }   # het danh sach
            $lastNames = $now
            $list = Find-Ui $ui "list_select"
            Log "Chua thay '$Account', cuon danh sach..."
            Swipe $list.X ($list.Y2 - 15) $list.X ($list.Y1 + 15) 500
            Nap 1.2
        }
        if (-not $picked) { Save-Shot "loi_khong_thay_tai_khoan"; throw "Không thấy tài khoản '$Account' trong danh sách đã lưu" }
    }

    $ui = Get-UiNodes
    $acc = Find-Ui $ui "txt_account"; $pass = Find-Ui $ui "txt_password"
    if ($acc.Text -ne $Account) { Save-Shot "loi_chon_tai_khoan"; throw "Ô tài khoản đang là '$($acc.Text)', không phải '$Account'" }
    if (-not $pass.Text -or $pass.Text -like "Password*") {
        Save-Shot "loi_chua_luu_mat_khau"; throw "Tài khoản '$Account' chưa được app lưu mật khẩu – hãy đăng nhập tay 1 lần"
    }
    Snap | Out-Null; Step "chon_tai_khoan"
    $btn = Find-Ui $ui "btn_login"
    Log "Bam Login"; Tap $btn.X $btn.Y
    $script:LoggedInThisRun = $true    # tu day man "Vao game" la phien cua $Account
    Nap 5
}

# Game bao "May chu dang duoc bao tri, vui long kien nhan va thu lai sau!" (popup Nhac nho hien ngay khi mo app, 19/11 14:01)
# -> dung luot, ket qua maintenance (khong tinh loi, khong thu lai trong luot), hen lai sau gio bao tri / $MaintRetryMinutes phut
$script:MaintSeen = $false
$script:UpdateStart = $null; $script:UpdateEnd = $null   # luc bat dau / xong cho game tai ban cap nhat
# Game co dang o tren man hinh khong (19/11 15:15: cap nhat xong game tu thoat ra man hinh chinh Android -> script ngoi cho 3 phut)
function Test-GameForeground {
    try { $o = Invoke-AdbTimed "-s $($script:Serial) shell dumpsys window" 15 } catch { return $true }   # khong hoi duoc -> coi nhu van o game
    return [bool]($o -match ("mCurrentFocus=Window\{[^}]*" + [regex]::Escape($Package)))
}
function Test-UpdateScreen { (Find "update_screen" $UpdateMaxScore @(0,800,600,100)).Count -gt 0 }
function Test-MaintPopup { (Find "popup_baotri" $MaintPopupMaxScore @(380,300,840,300)).Count -gt 0 }
function Stop-ForMaintenance {
    Log "Game bao may chu dang bao tri -> dung luot nay (khong tinh loi)"
    Step "bao_tri"
    try { Save-Shot "bao_tri" } catch {}
    $script:InMaintenance = $true; $script:MaintSeen = $true
    throw "Máy chủ game đang bảo trì (game báo: Máy chủ đang được bảo trì, vui lòng thử lại sau)"
}

$script:LoggedInThisRun = $false   # luot nay da tu dang nhap 7Road bang $Account chua
$script:LogoutTries = 0
function Enter-Game {
    Log "Mo app DDTank..."
    [void](Invoke-MuMu "control -v $($script:Index) app launch -pkg $Package" 60)
    $deadline = (Get-Date).AddMinutes(3)   # x3 lan thu (Retry-Step)
    $idle = 0
    while ((Get-Date) -lt $deadline) {
        Nap 1
        Snap | Out-Null
        if (Test-MaintPopup) { Stop-ForMaintenance }
        # Game dang tai / giai nen ban cap nhat -> cho tiep (gia han $deadline), khong tat app; tong toi da $UpdateWaitMin phut
        if (Test-UpdateScreen) {
            if (-not $script:UpdateStart) {
                $script:UpdateStart = Get-Date
                Step "cap_nhat"
                Log "Game dang tai ban cap nhat -> cho, khong tat app (toi da $UpdateWaitMin phut)"
            }
            $script:UpdateEnd = $null
            if (((Get-Date) - $script:UpdateStart).TotalMinutes -ge $UpdateWaitMin) {
                Save-Shot "loi_cap_nhat"
                throw "Game tải bản cập nhật quá $UpdateWaitMin phút chưa xong"
            }
            $deadline = (Get-Date).AddMinutes(3); $idle = 0
            Nap 5
            continue
        }
        if ($script:UpdateStart -and -not $script:UpdateEnd) {
            $script:UpdateEnd = Get-Date
            Log "Game cap nhat xong sau $([math]::Max(1, [int][math]::Round(($script:UpdateEnd - $script:UpdateStart).TotalMinutes))) phut"
        }
        if ((Find "btn_friends" 15).Count -and -not (Find "popup_close" 12).Count) {
            Log "Da vao sanh chinh"
            Step "sanh_chinh"
            return
        }
        # Chua dang nhap: man hinh co nut "Dang nhap"
        $dn = Find "btn_dangnhap" 15
        if ($dn.Count) {
            Step "chua_dang_nhap"
            $chk = Find "chk_unticked" 8 @(380,760,160,100)
            if ($chk.Count) { Log "Tick o dong y dieu khoan"; Tap $chk[0].X $chk[0].Y 2; Nap 1 }   # o tick nho: lech toi da 2px
            Log "Bam Dang nhap"; Tap $dn[0].X $dn[0].Y
            Nap 2
            Login-7Road
            continue
        }
        $vg = Find "btn_vaogame" 15
        if ($vg.Count) {
            # Man "Vao game" ma luot nay CHUA tu dang nhap = game dang nho phien cu, KHONG ghi la tai khoan nao
            # (19/11: vua dang nhap tai khoan 1 -> mo lai game hien thang "Vao game" -> chay tai khoan 2 se vao nham tai khoan 1).
            # -> bam nut "Tai khoan" (= dang xuat, ve man "Dang nhap") roi dang nhap lai dung $Account.
            if ($Account -and -not $script:LoggedInThisRun) {
                $sw = Find "btn_taikhoan" 25
                if ($sw.Count -and $script:LogoutTries -lt 3) {
                    $script:LogoutTries++
                    Step "phien_cu"
                    Log "Game dang nho phien dang nhap cu (khong biet tai khoan nao) -> bam 'Tai khoan' de dang xuat, dang nhap lai bang '$Account'"
                    Tap $sw[0].X $sw[0].Y; Nap 3
                    continue
                }
                Save-Shot "loi_phien_cu"
                throw "Game đang nhớ phiên đăng nhập cũ, không đăng xuất được để vào đúng tài khoản '$Account'"
            }
            Step "dang_nhap"
            $chk = Find "chk_unticked" 8 @(380,760,160,100)
            if ($chk.Count) { Log "Tick o dong y dieu khoan"; Tap $chk[0].X $chk[0].Y 2; Nap 1 }   # o tick nho: lech toi da 2px
            Log "Bam Vao game"; Tap $vg[0].X $vg[0].Y
            Nap 2
            continue
        }
        # Popup quang cao / su kien (tuy tai khoan): bam nut X do
        $x = Find "popup_close" 12
        if ($x.Count) { Step "popup"; Log "Dong popup tai ($($x[0].X),$($x[0].Y))"; Tap $x[0].X $x[0].Y; continue }

        # Khong nhan ra man hinh nao: co the dang mo san hop dang nhap 7Road (giao dien Android)
        $idle++
        if ($idle % 3 -eq 0) {
            if (-not (Test-GameForeground)) {
                Log "Game khong con tren man hinh (vd tu thoat sau khi cap nhat) -> mo lai app"
                Step "game_thoat"
                [void](Invoke-MuMu "control -v $($script:Index) app launch -pkg $Package" 60)
                Nap 3
                continue
            }
            $ui = Get-UiNodes
            if ((Find-Ui $ui "txt_account") -or (Find-Ui $ui "txt_login_des" "7Road Login")) {
                Login-7Road
            }
        }
    }
    Save-Shot "loi_vao_game"
    throw "Không vào được sảnh chính sau 3 phút"
}

function Open-Farm {
    # Sanh vua hien co the con dang tai -> lan bam dau co the bi bo qua: thu toi da 3 lan
    Nap 1.5
    $farm = $null
    for ($try = 1; $try -le 4 -and -not $farm; $try++) {
        Snap | Out-Null
        # Popup hien muon sau khi da vao sanh (vd "Bao danh moi ngay" lan dang nhap dau ngay) che nut Ban be -> dong truoc
        for ($k = 0; $k -lt 3; $k++) {
            $x = Find "popup_close" 12
            if (-not $x.Count) { break }
            Step "popup_sanh"; Log "Dong popup o sanh tai ($($x[0].X),$($x[0].Y))"; Tap $x[0].X $x[0].Y; Nap 1.5
            Snap | Out-Null
        }
        $f = Find "btn_friends" 15
        if ($f.Count) { Log "Bam Ban be (lan $try)"; Tap $f[0].X $f[0].Y }
        $farm = WaitFor "btn_farm" 20 6
    }
    if (-not $farm) { Save-Shot "loi_ban_be"; throw "Không thấy nút nông trại trong bảng Bạn bè" }
    Step "ban_be"
    Log "Bam nut Nong trai"; Tap $farm.X $farm.Y
    $sow = WaitFor "btn_sow" 15 30
    if (-not $sow) { Save-Shot "loi_nong_trai"; throw "Không vào được nông trại" }
    Log "Da vao nong trai"
    Nap 1
    Snap | Out-Null; Step "nong_trai"
    # Diem vao nong trai co dinh, ruong bi khuat o mep tren man hinh.
    # Cho nhan vat di toi bai co ngay duoi goc phai ruong -> camera dua ca ruong vao khung hinh
    Log "Di toi canh ruong"
    Tap $FarmWalkPoint[0] $FarmWalkPoint[1]
    Nap 4
    Snap | Out-Null; Step "canh_ruong"
}

# Thu hoach: hang truoc tu phai sang trai, sau do hang sau tu trai sang phai
function Harvest-All {
    $sawTwoRows = $false; $movedToBackRow = $false; $miss = 0; $taps = 0
    for ($i = 0; $i -lt 50 -and $miss -lt 3; $i++) {
        Snap | Out-Null
        # popup "Co thuong": diem khop ~15-26, man hinh thuong >= 58
        $c = Find "continue" 40 @(1000,700,600,200)
        if ($c.Count) { Step "phan_thuong"; Log "Dong popup Co thuong"; Tap $c[0].X $c[0].Y; Nap 1; $miss = 0; continue }

        $hands = Find "hand" 25
        if (-not $hands.Count) { $miss++; Nap 1; continue }
        $miss = 0

        # Gom cac ban tay thanh hang (truc isometric): V = do sau hang, U = vi tri doc hang
        $items = $hands | ForEach-Object {
            [pscustomobject]@{ X = $_.X; Y = $_.Y; V = $_.Y - 0.51 * $_.X; U = 0.89 * $_.X + 0.45 * $_.Y }
        } | Sort-Object V -Descending
        $rows = New-Object System.Collections.ArrayList
        foreach ($it in $items) {
            if ($rows.Count -and ($rows[$rows.Count-1][0].V - $it.V) -lt 45) { $rows[$rows.Count-1].Add($it) | Out-Null }
            else { $l = New-Object System.Collections.ArrayList; $l.Add($it) | Out-Null; $rows.Add($l) | Out-Null }
        }
        if ($rows.Count -ge 2) { $sawTwoRows = $true }
        $row = $rows[0]
        if ($rows.Count -eq 1 -and $sawTwoRows) {
            $t = $row | Sort-Object U | Select-Object -First 1      # hang sau: trai -> phai
            if (-not $movedToBackRow) {
                # Xong hang truoc: di ra ngoai ruong (phia tren-trai o dau hang sau) roi moi thu hang sau
                $movedToBackRow = $true
                $bx = [Math]::Max(10, $t.X + $BackRowWalkOffset[0])
                $by = [Math]::Max(10, $t.Y + $BackRowWalkOffset[1])
                Step "chuyen_hang_x$([int]$bx)_y$([int]$by)"
                Log "Xong hang truoc, di ra ($([int]$bx),$([int]$by)) truoc khi thu hang sau"
                Tap $bx $by
                Nap 3.5
                continue   # chup lai vi camera da di chuyen
            }
        } else {
            $t = $row | Sort-Object U -Descending | Select-Object -First 1  # hang truoc: phai -> trai
        }
        $taps++
        Log ("Thu hoach o ({0},{1}) - con {2} o chin, {3} hang" -f $t.X, $t.Y, $hands.Count, $rows.Count)
        Step ("thu_hoach_{0}_x{1}_y{2}" -f $taps, $t.X, $t.Y)
        Tap $t.X $t.Y
        # Cho popup "Nhan de tiep tuc", bam no roi moi quet tiep
        $c = WaitFor "continue" 40 8 @(1000,700,600,200)
        if ($c) {
            Step "phan_thuong"
            Log "Bam Nhan de tiep tuc"
            Tap $c.X $c.Y
            Nap 1
        } else {
            Log "Khong thay popup thuong (co the nhan vat chi di toi o dat)"
        }
    }
    Log "Thu hoach xong ($taps lan bam)"
    return $taps
}

# Lich chay 8 tieng ma khoai cung can dung 8 tieng -> co the toi som vai phut.
# Chua co o chin thi cho them toi da $WaitRipeMinutes phut, 30 giay kiem tra 1 lan.
function Wait-Ripe {
    # Doc dong ho tren o dat: biet con bao lau moi chin -> lau hon $WaitRipeMinutes thi khong cho, hen dung gio
    $tr = Get-TimerRipe
    if ($tr) {
        $script:GrowRipe = $tr.At
        Log "Dong ho o dat: o chin som nhat con $($tr.Left) (luc $($tr.At.ToString('HH:mm dd/MM')))"
        if ($tr.Left.TotalMinutes -gt $WaitRipeMinutes) { Log "Con lau hon $WaitRipeMinutes phut -> khong cho"; return $false }
    }
    if ($WaitRipeMinutes -le 0) { return $false }
    Log "Chua co o chin, cho toi da $WaitRipeMinutes phut..."
    $start = Get-Date
    $deadline = $start.AddMinutes($WaitRipeMinutes)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep 30
        Snap | Out-Null
        if ((Find "hand" 25).Count) {
            $script:WaitedRipeMin = [math]::Max(1, [int][math]::Round(((Get-Date) - $start).TotalMinutes))
            Log "Cay da chin (cho $script:WaitedRipeMin phut)"
            return $true
        }
    }
    Log "Het $WaitRipeMinutes phut van chua chin"
    $script:WaitedRipeMin = $WaitRipeMinutes
    return $false
}

function Find-FarmSign {
    for ($try = 0; $try -lt 4; $try++) {
        Snap | Out-Null
        $c = Find "continue" 40 @(1000,700,600,200)
        if ($c.Count) { Log "Dong popup Co thuong"; Tap $c[0].X $c[0].Y; Nap 1.5; continue }
        $s = Find "farm_sign" 20
        if ($s.Count) { return $s[0] }
        Nap 1
    }
    return $null
}

# Dem so o dang co cay: co thanh thoi gian (cay dang lon) hoac mam cay (vua gieo).
# Ruong trong: khong o nao co. Thanh thoi gian: diem khop 0-16 khi cay dang lon, ~30 khi vua gieo, o trong >= 35.
function Count-Planted($sign) {
    Snap | Out-Null
    $n = 0
    foreach ($o in $PlotOffsets) {
        $x = $sign.X + $o[0]; $y = $sign.Y + $o[1]
        if ((Find "plot_timer" 25 @(($x-90), ($y-90), 110, 80)).Count -or
            (Find "sprout" 18 @(($x-70), ($y-80), 140, 120)).Count) { $n++ }
    }
    return $n
}

# Dem thanh thoi gian tren CA man hinh, khong can bien go (cay lon co the che mat bien go).
# Mau plot_timer nho (10x7) khop nhieu diem lien nhau tren 1 thanh -> gom diem cung hang Y, cach nhau < 30px thanh 1 thanh.
# Diem khop that: 1-18 (ke ca thanh bi chu chat che 1 phan); ruong trong / sau thu hoach: 0 diem.
function Count-TimerBars {
    Snap | Out-Null
    $pts = Find "plot_timer" 22 | Sort-Object Y, X
    $bars = New-Object System.Collections.ArrayList
    foreach ($p in $pts) {
        $b = $bars | Where-Object { [Math]::Abs($_.Y - $p.Y) -le 12 -and ($p.X - $_.MaxX) -lt 30 -and ($p.X - $_.MaxX) -ge -30 } | Select-Object -First 1
        if ($b) { $b.MaxX = [Math]::Max($b.MaxX, $p.X) }
        else { [void]$bars.Add([pscustomobject]@{ Y = $p.Y; MaxX = $p.X }) }
    }
    return [Math]::Min($bars.Count, $PlotCount)
}

function Sow-Seeds($harvested) {
    # Khong thu hoach duoc o nao va ruong khong trong -> cay dang lon, khong gieo
    if ($harvested -eq 0 -and -not $script:FieldEmpty) {
        Log "Khong co o chin, cay dang lon -> bo qua gieo hat"
        Save-Shot "dang_trong"
        $waitNote = if ($script:WaitedRipeMin) { " (đã chờ $($script:WaitedRipeMin) phút)" } else { "" }
        Add-Photo (Caption "🌱 Chưa có ô chín (cây đang lớn)$waitNote – không thu hoạch, không gieo")
        return $null
    }
    $sign = Find-FarmSign
    if (-not $sign) { Save-Shot "loi_tim_ruong"; throw "Không tìm thấy ruộng (biển gỗ)" }
    Log "Bien go ruong tai ($($sign.X),$($sign.Y))"
    Step "ruong_trong"

    $key = $script:SeedKey
    $title = Open-SeedPanel
    $seed = Find-Seed $title $key
    $used = $key
    if (-not $seed -and $key -ne $DefaultSeed) {
        Log "Khong con hat $key trong bang -> gieo $DefaultSeed thay"
        $script:SeedNotes += "⚠️ Hết hạt $(Seed-Text $key) → gieo $(Seed-Text $DefaultSeed) thay"
        $seed = Find-Seed $title $DefaultSeed; $used = $DefaultSeed
    }
    if (-not $seed) {
        Save-Shot "loi_khong_co_hat"
        if ($used -eq 'khoai') { throw "Không tìm thấy hạt khoai tây" } else { throw "Không tìm thấy hạt $(Seed-Text $used)" }
    }
    Step "bang_hat"
    if (Sow-Drag $seed $sign $used) { $script:SowTime = Get-Date; $script:SownSeeds += $used }

    # Hat da chon co the khong du 10 o -> keo them hat mac dinh qua ca ruong (o da co cay game bo qua, khong hien hop xac nhan)
    if ($FillWithDefault -and $script:SowTime -and $used -ne $DefaultSeed) {
        Nap 2
        $title = Open-SeedPanel
        $seed = Find-Seed $title $DefaultSeed
        if ($seed) {
            if (Sow-Drag $seed $sign $DefaultSeed -Fill) {
                $script:SownSeeds += $DefaultSeed
                $script:SeedNotes += "ℹ️ Hạt $(Seed-Text $used) không đủ cả ruộng → gieo thêm $(Seed-Text $DefaultSeed) vào ô còn trống"
            }
        } else { Log "Khong thay hat $DefaultSeed de gieo kin ruong (bo qua)" }
    }
    return $sign
}

# Ten hat de hien thi: "🍇 nho"
function Seed-Text($key) { "$($SeedTypes[$key].Icon) $($SeedTypes[$key].Name)" }

# Bang hat dang mo thi dung luon, chua mo thi bam nut "gieo hat"
function Open-SeedPanel {
    Snap | Out-Null
    $t = Find "seed_panel_title" 15
    if ($t.Count) { return $t[0] }
    # 19/11: vua nhan thuong xong bam "gieo hat" game chua nhan -> bam lai 1 lan truoc khi bao loi
    for ($k = 1; $k -le 2; $k++) {
        Snap | Out-Null
        $b = Find "btn_sow" 15
        if (-not $b.Count) { Save-Shot "loi_nut_gieo"; throw "Không thấy nút Gieo hạt" }
        Log "Bam Gieo hat$(if ($k -gt 1) { ' (lan 2)' })"; Tap $b[0].X $b[0].Y
        $t = WaitFor "seed_panel_title" 15 8
        if ($t) { return $t }
    }
    Save-Shot "loi_bang_hat"; throw "Không mở được bảng hạt giống"
}

# Tim hat $key trong bang (cuon xuong toi 5 lan, roi cuon nguoc len). Khong co -> $null (het hat / chua tung co)
function Find-Seed($title, $key) {
    # KHONG dat ten bien $tpl: PowerShell khong phan biet hoa thuong + pham vi dong -> Find se doc nham thanh $Tpl (thu muc mau)
    $seedTpl = $SeedTypes[$key].Tpl
    $region = @(($title.X - 220), ($title.Y + 50), 440, 380)
    for ($k = 0; $k -le 12; $k++) {
        Snap | Out-Null
        $r = Find $seedTpl $SeedMaxScore $region
        if ($r.Count) { Log "Hat $key tai ($($r[0].X),$($r[0].Y)) score=$([math]::Round($r[0].Score,1))"; return $r[0] }
        if ($k -eq 12) { break }
        if ($k -lt 5) { Log "Chua thay hat $key, cuon danh sach xuong..."; Swipe $title.X ($title.Y + 330) $title.X ($title.Y + 150) 600 }
        else { Log "Chua thay hat $key, cuon danh sach len..."; Swipe $title.X ($title.Y + 150) $title.X ($title.Y + 330) 600 }
        Nap 1.5
    }
    return $null
}

# Keo hat tu bang qua 10 o dat roi bam xac nhan. Tra ve $true neu co hop xac nhan (= co o duoc gieo)
function Sow-Drag($seed, $sign, $key, [switch]$Fill) {
    $pts = @(, @($seed.X, $seed.Y))
    foreach ($o in $PlotOffsets) {
        $x = [Math]::Min(1590, [Math]::Max(10, $sign.X + $o[0]))
        $y = [Math]::Min(890,  [Math]::Max(10, $sign.Y + $o[1]))
        $pts += , @($x, $y)
    }
    Log "Keo hat $key qua $PlotCount o dat$(if ($Fill) { ' (gieo kin o con trong)' })..."
    Drag-Path $pts
    $ok = WaitFor "btn_confirm" 12 6
    if ($ok) { Step "xac_nhan"; Log "Xac nhan gieo $key"; Tap $ok.X $ok.Y; Nap 3; return $true }
    if ($Fill) { Log "Khong co hop xac nhan -> ruong da kin, khong can gieo them" }
    else { Log "Khong thay hop xac nhan (co the o dat khong trong)" }
    return $false
}

# ---- Dong ho dem nguoc tren o dat ----
# Doc tren anh chup moi nhat. Tra ve danh sach TimeSpan (bo dong ho co chu so khong chac).
function Read-PlotTimers {
    $out = New-Object System.Collections.ArrayList
    if (-not $ReadTimers) { return ,$out }
    try { $lines = [Vision]::ReadTimers($Shot, (Join-Path $Tpl "timer_digits.txt"), 0, 40, 1300, 660) }
    catch { Log "Doc dong ho loi: $($_.Exception.Message)"; return ,$out }
    foreach ($l in $lines) {
        $p = $l -split ' '
        if ($p.Count -lt 4 -or $p[2] -notmatch '^(\d\d):([0-5]\d):([0-5]\d)$') { continue }
        $ts = New-Object TimeSpan ([int]$Matches[1]), ([int]$Matches[2]), ([int]$Matches[3])
        $d = [double]::Parse($p[3], [Globalization.CultureInfo]::InvariantCulture)
        if ($d -le $TimerMaxDist) { [void]$out.Add($ts) }
    }
    return ,$out
}

# Gio chin som nhat theo dong ho (chup toi da 3 lan). Lay dong ho ngan nhat co it nhat 1 dong ho khac khop (+-90 giay)
# de 1 dong ho doc sai khong lam hen som. Tra ve { At, Left, Count } hoac $null.
function Get-TimerRipe {
    if (-not $ReadTimers) { return $null }
    for ($k = 0; $k -lt 3; $k++) {
        if ($k) { Nap 1 }
        Snap | Out-Null
        $raw = Read-PlotTimers                 # ArrayList (,$out) -> gan bien truoc roi moi pipe de duoc tung phan tu
        $ts = @($raw | Sort-Object)
        if (-not $ts.Count) { continue }
        $pick = $null
        for ($i = 0; $i -lt $ts.Count -and $null -eq $pick; $i++) {
            for ($j = 0; $j -lt $ts.Count; $j++) {
                if ($i -ne $j -and [Math]::Abs(($ts[$i] - $ts[$j]).TotalSeconds) -le 90) { $pick = $ts[$i]; break }
            }
        }
        if ($null -eq $pick -and $ts.Count -eq 1) { $pick = $ts[0] }
        if ($null -ne $pick) { return [pscustomobject]@{ At = (Get-Date).Add($pick); Left = $pick; Count = $ts.Count } }
    }
    return $null
}

function Format-Left([TimeSpan]$t) { if ($t.TotalHours -ge 1) { "{0}h{1:D2}" -f [int][math]::Floor($t.TotalHours), $t.Minutes } else { "$([int][math]::Ceiling($t.TotalMinutes)) phút" } }

# Thoi gian lon tung loai hat (hoc tu dong ho luc vua gieo): state\thoi_gian_lon.json { "nho": "06:00:00", ... }
function Get-GrowTimes {
    $f = Join-Path $StateDir "thoi_gian_lon.json"
    $h = @{}
    if (Test-Path $f) { try { (Get-Content $f -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $h[$_.Name] = [TimeSpan]::Parse($_.Value) } } catch {} }
    return $h
}
function Save-GrowTime($key, [TimeSpan]$t) {
    $h = Get-GrowTimes
    $h[$key] = New-Object TimeSpan ([int][math]::Floor($t.TotalHours)), ([int][math]::Round($t.Minutes / 5.0) * 5), 0   # lam tron 5 phut
    $o = [ordered]@{}; foreach ($k in ($h.Keys | Sort-Object)) { $o[$k] = $h[$k].ToString() }
    New-Item -ItemType Directory -Force $StateDir | Out-Null
    $o | ConvertTo-Json | Set-Content -Path (Join-Path $StateDir "thoi_gian_lon.json") -Encoding UTF8
}

function Verify-Sown($sign) {
    Snap | Out-Null
    $found = 0
    foreach ($o in $PlotOffsets) {
        $x = $sign.X + $o[0]; $y = $sign.Y + $o[1]
        if ((Find "sprout" 18 @(($x-70), ($y-80), 140, 120)).Count) { $found++ }
    }
    Save-Shot "ket_qua"
    # mam khoai (anh mau sprout) hoac dong ho dem nguoc (moi loai hat deu co) - lay so lon hon
    $tr = Get-TimerRipe
    $timerN = if ($tr) { $tr.Count } else { 0 }
    $seen = [Math]::Max($found, $timerN)
    $script:Sprouts = $seen
    $used = @($script:SownSeeds | Select-Object -Unique)
    $grow = Get-GrowTimes
    if ($tr) {
        $script:SowRipe = $tr.At
        Log "Dong ho o dat: chin som nhat sau $($tr.Left) -> $($tr.At.ToString('HH:mm dd/MM')) (doc duoc $timerN dong ho)"
        if ($used.Count -eq 1) { Save-GrowTime $used[0] ($tr.Left + ((Get-Date) - $script:SowTime)) }
    } else {
        $first = $used[0]
        $est = if ($first -and $grow.ContainsKey($first)) { $grow[$first] } else { [TimeSpan]::FromHours($GrowHours) }
        $script:SowRipe = $script:SowTime.Add($est)
        Log "Khong doc duoc dong ho -> uoc luong chin sau $est ($($script:SowRipe.ToString('HH:mm dd/MM')))"
        $script:SeedNotes += "⚠️ Không đọc được đồng hồ trên ô đất → giờ chín ước lượng ($(Format-Left $est))"
    }
    $what = ($used | ForEach-Object { Seed-Text $_ }) -join ' + '
    # nhan vat / ten nhan vat co the che 1-2 o
    if ($seen -ge ($PlotCount - 2)) {
        Log "KIEM TRA OK: thay cay moi o $seen/$PlotCount o (mam $found, dong ho $timerN)"
        Add-Photo (Caption "2/2 Sau khi trồng $($what): OK – thấy cây mới ở $seen/$PlotCount ô")
    } else {
        Log "CANH BAO: chi thay cay moi o $seen/$PlotCount o (mam $found, dong ho $timerN) - xem anh ket_qua"
        Add-Photo (Caption "2/2 Sau khi trồng $($what): ⚠️ CẢNH BÁO – chỉ thấy cây mới ở $seen/$PlotCount ô")
    }
}

# --------------------------- TU LAP LICH -----------------------------
# state\<tai khoan>.json: { ripe = gio khoai chin (lan gieo gan nhat), retries = so lan thu lai lien tiep }
$StateDir = Join-Path $Root "state"
$script:RipeAt = $null
$script:SowRipe = $null      # gio chin cua lan gieo nay (dong ho o dat, hoac uoc luong)
$script:GrowRipe = $null     # gio chin doc tu dong ho khi cay dang lon (khong gieo)
$script:SownSeeds = @()      # cac loai hat da gieo lan nay
$script:SeedNotes = @()      # dong ghi chu ve hat tren Telegram

function Get-FarmState {
    $f = Join-Path $StateDir "$StateKey.json"
    if (Test-Path $f) { try { return (Get-Content $f -Raw | ConvertFrom-Json) } catch {} }
    return $null
}

function Save-FarmState($ripe, [int]$retries) {
    New-Item -ItemType Directory -Force $StateDir | Out-Null
    $o = [ordered]@{ ripe = $(if ($ripe) { $ripe.ToString('yyyy-MM-dd HH:mm:ss') } else { $null }); retries = $retries }
    $o | ConvertTo-Json | Set-Content -Path (Join-Path $StateDir "$StateKey.json") -Encoding UTF8
}

# Task "DDTank Farm - <tai khoan>" chay 1 lan luc $at (ghi de neu da co)
function Register-NextRun([datetime]$at) {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$(Join-Path $Root 'ddtank_farm.ps1')`" -Account $Account$(if ($IsTH) { ' -Job tham_hiem' })" `
        -WorkingDirectory $Root
    $trigger = New-ScheduledTaskTrigger -Once -At $at
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 45)
    # giu quyen dang co (ban co the nang task len Highest de khoi dong lai card Wi-Fi, xem README) - khong ha xuong Limited
    $rl = 'Limited'
    try { $old = Get-ScheduledTask -TaskName $TaskFull -ErrorAction Stop; if ("$($old.Principal.RunLevel)" -eq 'Highest') { $rl = 'Highest' } } catch {}
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel $rl
    Register-ScheduledTask -TaskName $TaskFull -Action $action -Trigger $trigger -Settings $settings `
        -Principal $principal -Description "Tu lap lich: $(if ($IsTH) { 'thu cuoi tham hiem' } else { 'thu hoach + gieo hat' }) cho $Account" -Force | Out-Null
}

# Thoi diem $t (gio may) co roi vao gio bao tri game khong.
# Co -> tra ve luc het bao tri (+ $MaintAfterMin, theo gio may); khong -> $null
function Get-MaintenanceEnd([datetime]$t) {
    $tz = [TimeZoneInfo]::FindSystemTimeZoneById($MaintTimeZone)
    $vn = [TimeZoneInfo]::ConvertTime($t, [TimeZoneInfo]::Local, $tz)
    foreach ($w in $MaintenanceWindows) {
        if ($vn.DayOfWeek -ne [DayOfWeek]$w.Day) { continue }
        $s = $vn.Date.Add([TimeSpan]::Parse($w.Start)).AddMinutes(-$MaintBeforeMin)
        $e = $vn.Date.Add([TimeSpan]::Parse($w.End)).AddMinutes($MaintAfterMin)
        if ($vn -ge $s -and $vn -lt $e) {
            return [TimeZoneInfo]::ConvertTime([datetime]::SpecifyKind($e, 'Unspecified'), $tz, [TimeZoneInfo]::Local)
        }
    }
    return $null
}
function Maint-Text {
    ($MaintenanceWindows | ForEach-Object { "$(@{Monday='thứ 2';Tuesday='thứ 3';Wednesday='thứ 4';Thursday='thứ 5';Friday='thứ 6';Saturday='thứ 7';Sunday='CN'}[$_.Day]) $($_.Start)–$($_.End)" }) -join ', '
}

# Mat mang: state\<tai khoan>.offline = "gio bat dau mat mang|so lan thu" (xoa khi co mang lai)
function Mark-Offline {
    $f = Join-Path $StateDir "$StateKey.offline"
    $since = Get-Date; $n = 0
    if (Test-Path $f) {
        $a = (Get-Content $f -Raw).Trim() -split '\|'
        try { $since = [datetime]::ParseExact($a[0], 'yyyy-MM-dd HH:mm:ss', $null); $n = [int]$a[1] } catch {}
    }
    $n++
    New-Item -ItemType Directory -Force $StateDir | Out-Null
    Set-Content -Path $f -Value "$($since.ToString('yyyy-MM-dd HH:mm:ss'))|$n"
    Log "Mat mang tu $($since.ToString('HH:mm dd/MM')), lan thu $n"
}
# Co mang lai: tra ve 1 dong bao tren Telegram ($null neu truoc do khong mat mang)
function Pop-OfflineNote {
    $f = Join-Path $StateDir "$StateKey.offline"
    if (-not (Test-Path $f)) { return $null }
    $a = (Get-Content $f -Raw).Trim() -split '\|'
    Remove-Item $f -Force
    try { $since = [datetime]::ParseExact($a[0], 'yyyy-MM-dd HH:mm:ss', $null); $n = [int]$a[1] } catch { return $null }
    Log "Co mang lai (mat tu $($since.ToString('HH:mm dd/MM')), da thu $n lan)"
    return "📵 Mất mạng từ $($since.ToString('HH:mm dd/MM')) đến $(Get-Date -Format 'HH:mm dd/MM') – đã thử lại $n lần (không tính là lỗi)"
}

# $outcome: sown (vua gieo) | growing (cay dang lon / khong gieo) | error (loi) | busy (dang co lan chay khac)
#           | offline (mat mang) | maintenance (dang gio bao tri game) | paused (dang /tamdung)
# Tra ve 1 dong mo ta de gan vao tin Telegram ($null neu khong tu lap lich)
function Plan-NextRun([string]$outcome) {
    if (-not $AutoSchedule -or -not $Account) { return $null }
    if (Test-Path (Join-Path $StateDir "$StateKey.off")) {
        Log "Tu lap lich dang tat cho $StateKey (state\$StateKey.off)"
        return "⏸️ Tự lập lịch đang tắt cho $Account (bật lại: /chay $Account)"
    }
    $st = Get-FarmState
    $retries = if ($st -and $st.retries) { [int]$st.retries } else { 0 }
    $ripe = $null
    if ($st -and $st.ripe) { $ripe = [datetime]::ParseExact($st.ripe, 'yyyy-MM-dd HH:mm:ss', $null) }
    $now = Get-Date; $at = $null; $why = ""

    switch ($outcome) {
        'tham_hiem' {
            # Thu cuoi tham hiem: hen luc to doi xong som nhat (doc dong ho tren tab, hoac luc xuat phat + 12 tieng)
            $retries = 0
            if ($script:ThNext) {
                $ripe = $script:ThNext
                $at = $script:ThNext.AddMinutes($ThDelayMin); $why = "tổ đội xong sớm nhất lúc $($script:ThNext.ToString('HH:mm dd/MM'))"
            } else {
                $at = $now.AddMinutes($ThRetryMin); $why = "không đọc được giờ tổ đội xong, xem lại sau $ThRetryMin phút"
            }
        }
        'sown' {
            $ripe = if ($script:SowRipe) { $script:SowRipe } else { $script:SowTime.AddHours($GrowHours) }; $retries = 0
            $at = $ripe.AddMinutes($AutoDelayMinutes); $why = "cây chín $($ripe.ToString('HH:mm'))"
        }
        'growing' {
            if ($script:GrowRipe) {
                # vua doc dong ho tren o dat -> chinh xac hon gio luu tu lan gieo truoc
                $ripe = $script:GrowRipe; $retries = 0
                $at = $ripe.AddMinutes($AutoDelayMinutes); $why = "cây chín $($ripe.ToString('HH:mm')), theo đồng hồ trên ô đất"
            } elseif ($ripe -and $ripe -gt $now) {
                $retries = 0; $at = $ripe.AddMinutes($AutoDelayMinutes); $why = "cây chín $($ripe.ToString('HH:mm')), theo lần gieo trước"
            } elseif ($ripe -and $retries -lt $MaxRetries) {
                $retries++; $at = $now.AddMinutes($RetryMinutes); $why = "cây chưa chín, thử lại lần $retries/$MaxRetries"
            } else {
                Save-FarmState $ripe $retries
                Log "Khong biet gio cay chin -> khong tu lap lich"
                return "⚠️ Không biết giờ cây chín → chưa tự lập lịch. Gửi /chay $Account khi cây chín."
            }
        }
        'busy' { $at = $now.AddMinutes($RetryMinutes); $why = "đang có lượt chạy khác, thử lại" }        'offline' { $at = $now.AddMinutes($OfflineRetryMinutes); $why = "mất mạng, thử lại – không tính là lỗi" }
        'paused' {
            $pu = Get-PauseUntil
            $at = if ($pu) { $pu.AddMinutes(1) } else { $now.AddMinutes($RetryMinutes) }
            $why = "đang tạm dừng (/tamdung), chạy lại khi hết tạm dừng"
        }
        'maintenance' {
            $at = Get-MaintenanceEnd $now
            if ($at) { $why = "game bảo trì, chạy lại sau giờ bảo trì – không tính là lỗi" }
            else {
                # game bao bao tri ngoai khung gio co dinh (dot xuat / keo dai) -> thu lai cho toi khi het
                $at = $now.AddMinutes($MaintRetryMinutes)
                $why = "game đang bảo trì (đột xuất / kéo dài), thử lại sau $MaintRetryMinutes phút – không tính là lỗi"
            }
        }
        default {
            if ($retries -lt $MaxRetries) {
                $retries++; $at = $now.AddMinutes($ErrorRetryMinutes); $why = "bị lỗi, thử lại lần $retries/$MaxRetries"
            } else {
                Save-FarmState $ripe $retries
                Log "Loi $MaxRetries lan lien tiep -> dung tu lap lich"
                return "⛔ Lỗi $MaxRetries lần liên tiếp → dừng tự lập lịch. Sửa xong gửi /chay $Account để chạy lại."
            }
        }
    }
    # Gio hen da qua / qua sat (vd $AutoDelayMinutes am ma gio chin chi con vai phut) -> hen 2 phut nua
    if ($at -lt $now.AddMinutes(2)) { $at = $now.AddMinutes(2) }
    # Gio hen roi vao gio bao tri game -> doi sang sau gio bao tri
    $mEnd = Get-MaintenanceEnd $at
    if ($mEnd) {
        Log "Gio hen $($at.ToString('HH:mm dd/MM')) roi vao gio bao tri game -> doi sang $($mEnd.ToString('HH:mm dd/MM'))"
        if ($outcome -ne 'maintenance') { $why += "; dời qua giờ bảo trì game $(Maint-Text)" }
        $at = $mEnd
    }
    $script:RipeAt = $ripe
    Save-FarmState $ripe $retries
    try {
        Register-NextRun $at
        Log "Tu lap lich '$Account' luc $($at.ToString('HH:mm dd/MM/yyyy')) ($why)"
        return "⏰ Đã tự lập lịch lần tới: $($at.ToString('HH:mm dd/MM/yyyy')) ($why)"
    } catch {
        Log "Tu lap lich loi: $($_.Exception.Message)"
        return "⚠️ Tự lập lịch lỗi: $($_.Exception.Message)"
    }
}

# --------------------------- MAY TINH / LOG ---------------------------
# Kiem tra RAM trong + o dia truoc khi mo MuMu. Tra ve cac dong canh bao (rong = on)
function Check-Machine {
    $warn = @()
    try {
        $avail = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes
        $total = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
        Log "RAM trong: $avail MB / $total GB"
        if ($avail -lt $MinFreeRamMB) {
            $top = Get-Process | Group-Object ProcessName | ForEach-Object {
                [pscustomobject]@{ N = $_.Name; MB = [math]::Round(($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB) } } |
                Sort-Object MB -Descending | Select-Object -First 3 | ForEach-Object { "$($_.N) $([math]::Round($_.MB/1024,1)) GB" }
            $warn += "⚠️ Máy sắp hết RAM: còn $([math]::Round($avail/1024,1)) GB trống / $total GB (dùng nhiều: $($top -join ', ')). Nên đóng bớt để MuMu chạy ổn định."
        }
    } catch { Log "Khong doc duoc RAM: $($_.Exception.Message)" }
    $drives = @('C', (Split-Path $Root -Qualifier).TrimEnd(':')) | Select-Object -Unique
    foreach ($d in $drives) {
        try {
            $free = [math]::Round((Get-PSDrive $d -ErrorAction Stop).Free / 1GB, 1)
            if ($free -lt $MinFreeDiskGB) { $warn += "⚠️ Ổ ${d}: chỉ còn $free GB trống." }
        } catch {}
    }
    foreach ($w in $warn) { Log "CANH BAO MAY: $w" }
    return ,$warn
}

# Xoa log + anh cua cac lan chay cu hon $KeepLogDays ngay (khong dung bot.log, bot_offset, hang doi Telegram)
function Clean-OldLogs {
    if ($KeepLogDays -le 0) { return }
    $cut = (Get-Date).AddDays(-$KeepLogDays)
    $old = @(Get-ChildItem $LogDir -File -ErrorAction SilentlyContinue | Where-Object {
        $_.LastWriteTime -lt $cut -and ($_.Name -like 'run_*.log' -or $_.Name -match '^\d{8}_\d{6}_.*\.png$') })
    if (-not $old.Count) { return }
    $mb = [math]::Round(($old | Measure-Object Length -Sum).Sum / 1MB, 1)
    $old | Remove-Item -Force -ErrorAction SilentlyContinue
    Log "Don log: xoa $($old.Count) file cu hon $KeepLogDays ngay ($mb MB)"
}

# /tamdung: state\_tamdung.txt = "yyyy-MM-dd HH:mm:ss" (het han thi tu xoa). Tra ve gio het tam dung hoac $null
function Get-PauseUntil {
    $f = Join-Path $StateDir "_tamdung.txt"
    if (-not (Test-Path $f)) { return $null }
    try { $u = [datetime]::ParseExact((Get-Content $f -Raw).Trim(), 'yyyy-MM-dd HH:mm:ss', $null) } catch { return $null }
    if ($u -le (Get-Date)) { Remove-Item $f -Force -ErrorAction SilentlyContinue; return $null }
    return $u
}

# /xemruong: chup ruong, doan trang thai, khong bam gi them
# Bieu tuong tren o dat (anh mau 19/11, ruong akaka):
#   hand  = ban tay  -> o da chin
#   water = giot nuoc, bug = con sau (trong bong bong nua trong suot) -> cay chua chin, can cham soc.
#   Bam 1 bieu tuong bat ky la game tuoi / bat sau CA RUONG (thu 19/11: 7 giot nuoc + 3 con sau bien mat sau 1 lan bam).
function Find-CareIcons {
    Snap | Out-Null
    # Find tra ve ,@(...) -> gan vao bien truoc (KHONG boc @(Find ...): se thanh mang 1 phan tu chua ca danh sach)
    $w = Find "water" $WaterMaxScore; $b = Find "bug" $BugMaxScore
    $all = New-Object System.Collections.ArrayList
    foreach ($m in $w) { [void]$all.Add($m) }; foreach ($m in $b) { [void]$all.Add($m) }
    return [pscustomobject]@{ Water = $w; Bug = $b; All = $all }
}

function View-Farm {
    $hands = (Find "hand" 25).Count
    # Uu tien dem thanh thoi gian (cay lon che mat bien go); khong thay thanh nao moi can bien go
    $planted = Count-TimerBars
    if ($planted -eq 0) {
        $s = Find-FarmSign
        $planted = if ($s) { Count-Planted $s } else { -1 }
    }
    $tr = Get-TimerRipe
    if ($tr) {
        $script:GrowRipe = $tr.At
        Log "Dong ho o dat: o chin som nhat con $($tr.Left) (luc $($tr.At.ToString('HH:mm dd/MM')), doc duoc $($tr.Count) dong ho)"
        if ($planted -lt $tr.Count) { $planted = [Math]::Min($tr.Count, $PlotCount) }
    }
    $care = Find-CareIcons
    $state = if ($hands) { "có ô đã chín (thấy $hands bàn tay thu hoạch)" }
             elseif ($planted -gt 0 -and $tr) { "cây đang lớn ở $planted/$PlotCount ô, ô chín sớm nhất còn $(Format-Left $tr.Left) (lúc $($tr.At.ToString('HH:mm')))" }
             elseif ($planted -gt 0) { "cây đang lớn ở $planted/$PlotCount ô" }
             elseif ($planted -eq 0) { "ruộng trống" }
             else { "không xác định được (không thấy thanh thời gian lẫn biển gỗ cạnh ruộng)" }
    $need = @()
    if ($care.Water.Count) { $need += "$($care.Water.Count) ô cần tưới 💧" }
    if ($care.Bug.Count) { $need += "$($care.Bug.Count) ô có sâu 🐛" }
    if ($need.Count) { $state += " – " + ($need -join ', ') }
    Log "Xem ruong: $state"
    Save-Shot "xem_ruong"
    Add-Photo (Caption "👀 Xem ruộng: $state")

    # Cham soc: bam 1 bieu tuong (giot nuoc / con sau) -> game tuoi / bat sau ca ruong. Kiem tra bieu tuong da het chua.
    if ($CareOnView -and $care.All.Count) {
        $result = $null
        for ($k = 1; $k -le 3 -and -not $result; $k++) {
            $t = $care.All[0]
            $kind = if ($care.Water.Count) { 'tuoi cay' } else { 'bat sau' }
            Log "Cham soc ruong (lan $k): bam bieu tuong $kind tai ($($t.X),$($t.Y))"
            Tap $t.X $t.Y 3    # bieu tuong rong ~40px: lech it
            for ($i = 0; $i -lt 6; $i++) {
                Nap 1
                $care = Find-CareIcons
                if (-not $care.All.Count) { $result = 'ok'; break }
            }
        }
        if ($result) {
            Log "Da tuoi cay / bat sau ca ruong"
            Save-Shot "sau_cham_soc"
            Add-Photo (Caption "💧 Đã tưới cây / bắt sâu cả ruộng (bấm 1 lần)")
        } else {
            Log "Bam 3 lan van con $($care.All.Count) bieu tuong giot nuoc / con sau"
            Save-Shot "cham_soc_chua_xong"
            Add-Photo (Caption "⚠️ Bấm 3 lần vẫn còn $($care.All.Count) biểu tượng 💧/🐛 – xem ảnh")
        }
    }
}

# Lich su moi lan chay (cho lenh /thongke): state\lich_su.jsonl, moi dong 1 lan chay
function Add-History {
    if (-not $Account -or $Account -like 'zz_*') { return }
    try {
        New-Item -ItemType Directory -Force $StateDir | Out-Null
        $o = [ordered]@{
            t    = $script:StartTime.ToString('yyyy-MM-dd HH:mm:ss')
            end  = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            acc  = $Account
            job  = $Job
            kq   = $(if ($ViewOnly -and $script:Outcome -ne 'error') { 'view' } else { [string]$script:Outcome })
            nhan = $(if ($IsTH) { [int]$script:ThClaimed } else { 0 })    # tham hiem: so to doi nhan thuong / cho xuat phat
            di   = $(if ($IsTH) { [int]$script:ThStarted } else { 0 })
            thu  = [int]$harvested
            gieo = [bool]$script:SowTime
            hat  = (@($script:SownSeeds | Select-Object -Unique) -join '+')
            mam  = [int]$script:Sprouts
            cho  = [int]$script:WaitedRipeMin
            loi  = [string]$script:ErrText
        }
        Add-Content -Path (Join-Path $StateDir "lich_su.jsonl") -Value ($o | ConvertTo-Json -Compress) -Encoding UTF8
    } catch { Log "Ghi lich su loi: $($_.Exception.Message)" }
}

# ------------------------------ MAIN ---------------------------------
if ($TestTelegram) {
    Log "Gui thu Telegram (khong mo thiet bi)"
    # Lay tam anh co san trong logs\: anh sau thu hoach (hoac anh ruong trong cua lan chay truoc) + anh ket qua
    $test = @(); $sow = $null
    foreach ($item in @(@("*_sau_thu_hoach.png", "*_ruong_trong.png"), @("*_ket_qua.png"))) {
        $f = $null
        foreach ($pat in $item) {
            $f = Get-ChildItem (Join-Path $LogDir $pat) -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
            if ($f) { break }
        }
        if (-not $f) { continue }
        if ($f.Name -like "*ket_qua*") { $sow = $f.LastWriteTime; $label = "2/2 Sau khi trồng" } else { $label = "1/2 Sau khi thu hoạch" }
        $test += @{ Path = $f.FullName; Caption = (Caption "[GỬI THỬ] $label ($($f.Name))") }
    }
    if (-not $test.Count) { Log "Chua co anh nao trong logs\ de gui thu"; exit 1 }
    Send-Telegram $test (Build-Summary $sow)
    exit 0
}

# Loai hat: -Seed (sai ten thi bao loi ngay, khong mo thiet bi, khong dong vao lich) -> LUU CO DINH cho tai khoan
# (state\<tk>.hat, cac luot tu dong sau gieo hat nay; -Seed khoai = ve mac dinh). Khong co -Seed -> hat da luu, khong co -> $DefaultSeed
$script:SeedKey = $DefaultSeed
$script:SeedFrom = 'mặc định'
if ($Seed) {
    $script:SeedKey = ConvertTo-SeedKey $Seed
    if (-not $script:SeedKey) { Log "LOI: Không có loại hạt '$Seed'. Các loại: $(Get-SeedListText)"; exit 1 }
    $script:SeedFrom = 'chọn lần này'
    if ($Account) { Set-AccountSeed (Join-Path $Root "state") $Account $script:SeedKey $DefaultSeed; $script:SeedFrom = 'đã lưu cố định cho tài khoản' }
} elseif ($Account) {
    $k = Get-AccountSeed (Join-Path $Root "state") $Account
    if ($k) { $script:SeedKey = $k; $script:SeedFrom = 'cố định của tài khoản' }
}

# Chi 1 lan chay mot luc tren thiet bi (lich tu dong va lenh /chay tu bot Telegram co the trung nhau).
# Trung luot -> XEP HANG CHO luot kia xong roi chay luon (toi da $QueueWaitMin phut), khong chay song song:
# may 7,9 GB RAM, moi thiet bi MuMu 3 GB -> 2 thiet bi cung luc se het RAM (19/11: chon xep hang thay vi dung them alt3).
$farmMutex = New-Object System.Threading.Mutex($false, "Local\DDTankFarmRun")
$gotMutex = $false
try { $gotMutex = $farmMutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $gotMutex = $true }
if (-not $gotMutex) {
    # Chinh tai khoan nay dang chay (vd /chay trung lich tu dong) -> khong xep hang chay lai lan nua
    $same = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -match 'ddtank_farm\.ps1' -and $Account -and
        $_.CommandLine -match ('-Account\s+"?' + [regex]::Escape($Account) + '"?(\s|$)') -and
        (($_.CommandLine -match '-Job\s+"?tham_hiem') -eq $IsTH) })   # cung tai khoan + CUNG viec (nong trai / tham hiem)
    if ($same.Count) {
        Log "Tai khoan $Account dang co luot chay khac (PID $($same[0].ProcessId)) -> thoat, luot do se tu hen lich"
        exit 2
    }
    $others = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessId -ne $PID -and $_.CommandLine -match 'ddtank_farm\.ps1' } | ForEach-Object { if ($_.CommandLine -match '-Account\s+"?([^"\s]+)') { $Matches[1] } })
    Log "Dang co luot chay khac ($($others -join ', ')) -> xep hang cho toi da $QueueWaitMin phut"
    $qStart = Get-Date
    while (-not $gotMutex -and ((Get-Date) - $qStart).TotalMinutes -lt $QueueWaitMin) {
        try { $gotMutex = $farmMutex.WaitOne(30000) } catch [System.Threading.AbandonedMutexException] { $gotMutex = $true }
    }
    if (-not $gotMutex) {
        Log "Cho $QueueWaitMin phut van chua toi luot -> hen lai"
        [void](Plan-NextRun 'busy')   # lich tu dong cua tai khoan nay khong bi mat: hen lai sau vai phut
        exit 2
    }
    $script:QueuedMin = [math]::Max(1, [int][math]::Round(((Get-Date) - $qStart).TotalMinutes))
    Log "Toi luot sau khi cho $($script:QueuedMin) phut"
}

$exitCode = 0
$script:StartTime = Get-Date
$harvested = 0
try {
    Log "===== BAT DAU (tai khoan: $(if ($Account) { $Account } else { '-' })$(if ($IsTH) { ', thu cuoi tham hiem' } elseif ($ViewOnly) { ', chi xem ruong' } else { ", hat: $($script:SeedKey) ($($script:SeedFrom))" })$(if ($Manual) { ', chay tay' })) ====="
    try { Clean-OldLogs } catch { Log "Don log loi: $($_.Exception.Message)" }
    Clear-StaleAdb
    # Dang /tamdung -> lich tu dong khong chay (chay tay -Manual / xem ruong van chay), hen lai khi het tam dung
    if (-not $Manual -and -not $ViewOnly -and -not $LoginOnly -and -not $SkipLaunch) {
        $pu = Get-PauseUntil
        if ($pu) { $script:Paused = $true; throw "Đang tạm dừng tới $($pu.ToString('HH:mm dd/MM')) – lượt tự động này không chạy" }
    }
    # Lich TU DONG roi vao gio bao tri game (vd lich chay bu) -> khong chay, hen lai sau gio bao tri.
    # Chay tay (/chay, /xemruong = -Manual) van vao game: bao tri co the xong som; con bao tri thi Enter-Game thay popup -> dung, khong tinh loi
    if (-not $SkipLaunch -and -not $LoginOnly -and -not $Manual) {
        $mEnd = Get-MaintenanceEnd (Get-Date)
        if ($mEnd) {
            $script:InMaintenance = $true
            throw "Đang trong giờ bảo trì game ($(Maint-Text), giờ Việt Nam) – không chạy, hẹn lại $($mEnd.ToString('HH:mm dd/MM'))"
        }
    }
    # Can Internet de vao game + gui Telegram (Wi-Fi co the chua ket noi lai ngay sau khi may thuc day)
    if (-not (Wait-Internet $NetWaitMinutes)) {
        $script:Offline = $true
        throw "Mất mạng: không kết nối được Internet sau $NetWaitMinutes phút"
    }
    $script:OfflineNote = Pop-OfflineNote
    Send-PendingTelegram
    $script:MachineWarn = Check-Machine
    # Luot tu dong khong bat dau dung y giay theo lich (giong nguoi): cho ngau nhien 0-$StartJitterSec giay
    if ($HumanLike -and -not $Manual -and -not $ViewOnly -and -not $SkipLaunch -and $StartJitterSec -gt 0) {
        $d = Rnd 0 $StartJitterSec; Log "Cho ngau nhien $d giay truoc khi bat dau"; Start-Sleep -Seconds $d
    }
    # Lich du phong: hen san 1 luot sau $SafetyRunMin phut. Luot nay bi treo / bi Task Scheduler diet (45 phut) thi van con
    # luot sau (19/11 00:26 bi diet giua chung -> mat lich toi khi chay tay). Xong binh thuong thi Plan-NextRun ghi de.
    if ($AutoSchedule -and $Account -and -not $ViewOnly -and -not $LoginOnly -and -not $SkipLaunch -and $SafetyRunMin -gt 0 -and
        -not (Test-Path (Join-Path $StateDir "$StateKey.off"))) {   # /huylich: khong hen lich du phong (Plan-NextRun cung khong ghi de)
        try {
            $safe = (Get-Date).AddMinutes($SafetyRunMin)
            Register-NextRun $safe
            Log "Lich du phong $($safe.ToString('HH:mm dd/MM')) (phong luot nay bi treo/bi diet; xong se hen lai dung gio)"
        } catch { Log "Dat lich du phong loi: $($_.Exception.Message)" }
    }
    Start-Device
    # Phan thao tac game. Loi giua chung (popup la, game lag, khong thay nut...) -> THU LAI NGAY trong luot nay
    # ($InRunRetries lan: lan 1 mo lai game, lan 2 khoi dong lai ca thiet bi) thay vi tat may roi hen 30 phut.
    $harvestedBefore = 0
    $flow = {
    # vao game loi -> tat app roi lam lai (Enter-Game tu mo lai app)
    if (-not $SkipLaunch) { Retry-Step 'vao_game' 'vào game' { Enter-Game } { [void](Invoke-MuMu "control -v $($script:Index) app close -pkg $Package" 30); Nap 3 } }
    if ($LoginOnly) { Log "===== DA VAO SANH (-LoginOnly) ====="; return }
    if ($IsTH) {
        # Thu cuoi tham hiem (tham_hiem\cong_cu\tham_hiem.ps1): loi giua chung -> lam lai buoc (to doi da xong thi lan sau la "dang chay")
        Retry-Step 'tham_hiem' 'thám hiểm' { Invoke-ThamHiem }
        $script:Outcome = 'tham_hiem'
        Log "===== HOAN THANH (tham hiem) ====="
        return
    }
    if (-not $SkipLaunch) { Retry-Step 'mo_nong_trai' 'mở nông trại' { Open-Farm } }
    if ($ViewOnly) {
        View-Farm
        $st = Get-FarmState
        if ($st -and $st.ripe) { $script:RipeAt = [datetime]::ParseExact($st.ripe, 'yyyy-MM-dd HH:mm:ss', $null) }
        $script:Outcome = 'view'
        Log "===== XEM RUONG XONG ====="
        return
    }
    # lan thu lai: cong don so o da thu hoach o lan truoc (ruong da thu hoach -> lan nay 0 o chin nhung van phai gieo)
    $harvested = $harvestedBefore + (Retry-Step 'thu_hoach' 'thu hoạch' { Harvest-All })
    $script:FieldEmpty = $false
    if ($harvested -eq 0) {
        # Khong co o chin. Ruong TRONG that (khong o nao co thanh thoi gian / mam cay) -> gieo luon, khong cho.
        # Con cay dang lon -> ket thuc luon (hoac cho them $WaitRipeMinutes phut neu dat > 0).
        $s = $null
        $planted = Count-TimerBars          # cay lon co the che bien go -> dem thanh thoi gian truoc
        if ($planted -eq 0) {
            $s = Find-FarmSign
            $planted = if ($s) { Count-Planted $s } else { -1 }
        }
        if ($s -and $planted -eq 0) {
            $script:FieldEmpty = $true
            Log "Ruong trong (khong o nao co cay) -> trong moi luon, khong cho"
            Save-Shot "ruong_trong"
            Add-Photo (Caption "1/2 Ruộng trống – không có cây để thu hoạch, trồng mới luôn")
        } else {
            if ($planted -gt 0) { Log "Cay dang lon o $planted/$PlotCount o (thay thanh thoi gian / mam cay)" }
            if (Wait-Ripe) { $harvested = Harvest-All }
        }
    }
    if ($harvested -gt $harvestedBefore) {    # chay lai ca luot ma lan nay khong thu them o nao -> khong gui lai anh
        Start-Sleep 1
        Save-Shot "sau_thu_hoach"
        $waitNote = if ($script:WaitedRipeMin) { " (đã chờ cây chín $($script:WaitedRipeMin) phút)" } else { "" }
        Add-Photo (Caption "1/2 Sau khi thu hoạch: $harvested ô$waitNote")
    }
    $sign = Retry-Step 'gieo_hat' 'gieo hạt' { Sow-Seeds $harvested }
    if ($sign) { Verify-Sown $sign }
    $script:Outcome = if ($script:SowTime) { 'sown' } else { 'growing' }
    Log "===== HOAN THANH ====="
    }   # het $flow

    for ($attempt = 1; ; $attempt++) {
        try { . $flow; break }
        catch {
            $msg = $_.Exception.Message
            # Mot buoc da het $StepRetries lan thu (hoac loi khong thu lai duoc) -> khoi dong lai thiet bi, chay lai ca luot
            if ($SkipLaunch -or $attempt -gt $InRunRetries -or -not (Can-Retry $msg)) { throw }
            if ($harvested -gt $harvestedBefore) { $harvestedBefore = $harvested }
            try { Save-Shot "loi_ca_luot_$attempt" } catch {}
            Log "LOI ca luot (lan $attempt/$($InRunRetries + 1)): $msg -> khoi dong lai thiet bi, chay lai tu dau"
            $script:RetryNotes += "🔁 Lượt lỗi lần ${attempt}: $(Short-Err $msg) → đã khởi động lại thiết bị, chạy lại từ đầu"
            Restart-Game -Device
        }
    }
}
catch {
    $exitCode = 1
    $err = $_.Exception.Message
    Log "LOI: $err"
    # Dang /tamdung -> khong phai loi, chi hen lai
    if ($script:Paused) {
        $script:Outcome = 'paused'; $exitCode = 5
    }    # Loi trong gio bao tri game (luc bat dau, hoac game dong cua giua chung) -> khong tinh vao so lan loi
    elseif ($script:InMaintenance -or (Get-MaintenanceEnd (Get-Date))) {
        $script:Outcome = 'maintenance'; $exitCode = 4
        if (-not $script:InMaintenance) { $err += " (đang giờ bảo trì game)" }
    }
    # Loi do mat mang (luc bat dau, hoac giua chung ma gio van khong co mang) -> khong tinh vao so lan loi
    elseif ($script:Offline -or -not (Test-Internet)) {
        $script:Outcome = 'offline'; $exitCode = 3
        Mark-Offline
        if (-not $script:Offline) { $err += " (đang mất mạng)" }
    } else {
        $script:Outcome = 'error'
    }
    $script:ErrText = $err
    if (-not $script:Offline -and -not $script:InMaintenance -and -not $script:Paused) { try { Save-Shot "loi"; Add-Photo (Caption "❌ LỖI: $err") } catch {} }
}
finally {
    if ($StayOpen) { Log "Giu nguyen app + thiet bi (-StayOpen)" }
    else { try { Stop-Device } catch { Log "Loi khi tat: $($_.Exception.Message)" } }
    Remove-Item $Shot -Force -ErrorAction SilentlyContinue
    if (-not $LoginOnly) {
        $nextLine = $null
        # /xemruong khong dong vao lich; cac lan chay khac tu hen lan sau
        if ($ViewOnly) {
            try {
                $i = Get-ScheduledTask -TaskName $TaskFull -ErrorAction Stop | Get-ScheduledTaskInfo
                if ($i.NextRunTime) { $nextLine = "⏰ Lịch thu hoạch tới: $($i.NextRunTime.ToString('HH:mm dd/MM/yyyy')) (không đổi)" }
            } catch { $nextLine = "⏰ Tài khoản này chưa có lịch tự lập" }
        } elseif (-not $SkipLaunch) { try { $nextLine = Plan-NextRun $script:Outcome } catch { Log "Tu lap lich loi: $($_.Exception.Message)" } }
        if ($script:Paused) {
            # Ban da chu dong tam dung -> khong nhan tin moi lan, chi ghi log
            Log "Dang tam dung -> khong gui Telegram. $nextLine"
        } elseif ($script:InMaintenance) {
            if ($script:MaintSeen) {
                # Da mo game va game bao bao tri -> gui kem anh popup
                $msg = "$TgHead $(Get-Date -Format 'dd/MM HH:mm')`n🛠️ Game đang bảo trì (máy chủ báo bảo trì khi vào game) – không chạy lượt này, không tính là lỗi."
                if ($nextLine) { $msg += "`n$nextLine" }
                Log ("Telegram <- $(if ($script:LastShot) { Split-Path $script:LastShot -Leaf })`n    " + ($msg -replace "`n", "`n    "))
                [void](Post-Telegram @($script:LastShot) $msg)
            } else {
                # Chua mo thiet bi -> khong co anh: gui 1 tin chu
                $msg = "$TgHead $(Get-Date -Format 'dd/MM HH:mm')`n🛠️ Đang giờ bảo trì game ($(Maint-Text)) – không chạy lượt này."
                if ($nextLine) { $msg += "`n$nextLine" }
                Log ("Telegram <- (tin chu)`n    " + ($msg -replace "`n", "`n    "))
                [void](Post-Telegram @() $msg)
            }
        } elseif ($script:Outcome -eq 'offline') {
            # Mat mang tu dau: khong co anh, khong gui duoc -> chi ghi log; co mang lai se bao 1 dong "📵 Mat mang tu ..."
            Send-Telegram $script:Photos (Build-Summary $script:SowTime $nextLine) 0
        } else {
            Send-Telegram $script:Photos (Build-Summary $script:SowTime $nextLine)
        }
    }
    if (-not $LoginOnly -and -not $SkipLaunch) { Add-History }
}
exit $exitCode
