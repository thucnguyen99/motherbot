# =====================================================================
#  Thu cuoi tham hiem: phan rieng cua "ddtank_farm.ps1 -Job tham_hiem" (dot-source vao ddtank_farm.ps1,
#  dung chung Snap / Tap / Nap / Rnd / Log / Save-Shot / Add-Photo / Close-Popups / khoa thiet bi / Telegram / lich).
#  Sanh -> Day do -> Thu cuoi -> Thu cuoi Tham hiem -> 3 to doi:
#    Ket thuc -> Nhan -> (popup "Co thuong") -> Xuat phat | Chua co -> Xuat phat | dang chay -> doc gio con lai
#  Giong nong trai: hen lan sau = to doi xong som nhat + $ThDelayMin (-5 = vao TRUOC 5 phut), toi noi to doi nao
#  con <= $ThWaitMin phut la xong thi ngoi cho roi nhan + cho di tiep luon. Ghi chu, toa do, nguong: tham_hiem\GHI_CHU.md
#  !!! KHONG BAO GIO bam "Goi ve" (mat het chien loi pham). Nhan / Xuat phat / Goi ve nam CUNG 1 cho
#      -> moi lan bam deu chup lai va so ca 3 nut ngay truoc khi bam.
# =====================================================================
$ThDir     = Join-Path $Root "tham_hiem"
$ThMau     = Join-Path $ThDir "mau"
$ThDigits  = Join-Path $ThMau "so_tab.txt"      # mau chu so dong ho tren tab (TabTimer.cs)
$ThHours   = 12      # moi luot tham hiem 12 tieng
$ThDelayMin = -5     # hen lan sau: to doi xong som nhat - 5 phut (vao truoc roi cho, giong nong trai $AutoDelayMinutes)
$ThWaitMin  = 12     # toi noi ma to doi con <= 12 phut la xong -> ngoi cho, xong la nhan luon (giong nong trai $WaitRipeMinutes)
$ThSync     = $true  # 23/11: dong bo 3 to doi - to doi xong thi CHI nhan thuong, cho ca 3 xong / ranh roi moi Xuat phat ca 3 cung luc
                     # (gio ve trung nhau). Hen lan sau = to doi xong MUON nhat. $false = nhu cu (xong la nhan + cho di tiep ngay)
$ThTimerMaxDist = 6.0  # 19/11: chu so dung lech 0-2.6, chu so chua co mau lech 12.2 -> qua nguong thi khong tin
$ThHintMaxDist  = 15.0 # 23/11: doc "khong chac" (lech 6-15, vd 00:01:50 lech 9.70 la dung) chi dung de quyet dinh CO NGOI CHO khong
                       # (xong hay chua van xac nhan bang nut Nhan / Xuat phat), khong dung de hen lich
$ThRetryMin = 60     # khong biet gio to doi nao xong -> xem lai sau 60 phut
$ThBtn       = @(1408, 818)            # Nhan / Xuat phat / Goi ve (cung 1 cho, nut 305x92)
$ThBtnRegion = @(1220, 740, 380, 150)
# Nguong khop (do 19/11 tren 28 anh): dung nut 3.7-6.2, Nhan<->Xuat phat lech 19.2, man khac >= 48
$ThBtnMax = 12
$ThTabs = @(
    @{ Tap = @(175, 145); Clock = @(185, 122, 120, 44) },
    @{ Tap = @(470, 145); Clock = @(482, 122, 120, 44) },
    @{ Tap = @(768, 145); Clock = @(780, 122, 120, 44) }
)
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition (Get-Content (Join-Path $ThDir "cong_cu\TabTimer.cs") -Raw)

$script:ThLines   = @()    # dong tom tat tung to doi (Telegram)
$script:ThNext    = $null  # gio hen lan sau dua vao (to doi xong som nhat; $ThSync: muon nhat)
$script:ThNextWhy = $null  # ly do hen (Telegram / log)
$script:ThClaimed = 0      # so to doi da nhan thuong luot nay
$script:ThStarted = 0      # so to doi da cho xuat phat luot nay
$script:ThWaitedMin = 0    # so phut da ngoi cho to doi xong

function ThFind($name, $maxScore, $region) {
    return ,@([Vision]::FindAll($Shot, (Join-Path $ThMau "$name.png"), $maxScore, $region[0], $region[1], $region[2], $region[3]))
}
function ThWait($name, $maxScore, $region, $sec) {
    $dl = (Get-Date).AddSeconds($sec)
    do {
        Snap | Out-Null
        $m = ThFind $name $maxScore $region
        if ($m.Count) { return $m[0] }
        Start-Sleep -Milliseconds 300
    } while ((Get-Date) -lt $dl)
    return $null
}

# Nut goc duoi phai cua to doi dang chon (tren anh chup moi nhat): 'nhan' | 'xuat_phat' | 'goi_ve' | $null
# Lay nut GIONG NHAT trong 3 (Nhan va Xuat phat cung xanh la, lech nhau 19.2)
function ThButton {
    $best = $null; $bs = $ThBtnMax
    foreach ($n in 'nhan', 'xuat_phat', 'goi_ve') {
        $m = ThFind "nut_$n" 60 $ThBtnRegion
        foreach ($x in $m) { if ($x.Score -lt $bs) { $bs = $x.Score; $best = $n } }
    }
    return $best
}

# Hop "Nhac nho" (vua lo bam Goi ve) dang hien -> bam Huy bo. KHONG BAO GIO bam Xac nhan.
function ThCancelRecall {
    if ((ThFind 'hop_nhac_nho' 15 @(640, 190, 320, 120)).Count) {
        Log "!!! Hop 'Nhac nho' (Goi ve) dang hien -> bam Huy bo"
        Tap 602 607 8; Nap 1.5
        return $true
    }
    return $false
}

# Bam nut goc duoi phai CHI KHI dung la nut $want (chup lai ngay truoc khi bam)
function ThPress($want) {
    Snap | Out-Null
    if (ThCancelRecall) { Snap | Out-Null }
    $b = ThButton
    if ($b -ne $want) { throw "Nút góc dưới phải đang là '$b', không phải '$want' – không bấm" }
    Tap $ThBtn[0] $ThBtn[1] 20    # nut 305x92: lech toi da 20px
}

# Sanh chinh -> man Thu cuoi tham hiem
function Open-ThamHiem {
    Close-Popups
    Snap | Out-Null
    if (ThButton) { Log "Dang o man Tham hiem"; return }   # lan thu lai: van con o man nay
    $menu = @(860, 300, 240, 200)
    $m = ThFind 'muc_thu_cuoi' 32 $menu   # menu Day do co the dang mo san
    if (-not $m.Count) {
        $d = ThFind 'nut_day_do' 12 @(1080, 760, 240, 140)
        if (-not $d.Count) { Save-Shot "loi_khong_thay_day_do"; throw "Không thấy nút Dạy dỗ ở sảnh chính" }
        Log "Bam Day do"; Tap $d[0].X $d[0].Y 8
        $m = @(ThWait 'muc_thu_cuoi' 32 $menu 8)
        if (-not $m[0]) { Save-Shot "loi_menu_day_do"; throw "Bấm Dạy dỗ không thấy mục Thú cưỡi" }
    }
    Nap 0.8
    Log "Bam Thu cuoi"; Tap $m[0].X $m[0].Y 10
    $t = ThWait 'muc_tham_hiem' 12 @(180, 360, 240, 160) 10
    if (-not $t) { Save-Shot "loi_man_thu_cuoi"; throw "Không vào được màn Thú cưỡi" }
    Nap 0.8
    Log "Bam Thu cuoi Tham hiem"; Tap $t.X ($t.Y - 25) 8    # mau la dong chu -> bam len hinh phia tren
    $dl = (Get-Date).AddSeconds(12)
    do {
        Nap 0.6; Snap | Out-Null
        if (ThButton) { Log "Da vao man Tham hiem"; return }
    } while ((Get-Date) -lt $dl)
    Save-Shot "loi_man_tham_hiem"
    throw "Không vào được màn Thú cưỡi thám hiểm"
}

# 1 to doi: nhan thuong (neu xong) va cho xuat phat (neu chua chay).
# Tra ve 'dang_chay' | 'xuat_phat' | 'nhan_xuat_phat'; -NoStart (dong bo): khong bam Xuat phat -> 'da_nhan' (vua nhan) | 'ranh'
function ThTeam([int]$k, [switch]$NoStart) {
    $tab = $ThTabs[$k - 1]
    Tap $tab.Tap[0] $tab.Tap[1] 8; Nap 1.2
    $b = $null
    for ($i = 0; $i -lt 6 -and -not $b; $i++) {
        Snap | Out-Null
        [void](ThCancelRecall)
        $b = ThButton
        if (-not $b) { Nap 0.7 }
    }
    if (-not $b) { Save-Shot "loi_to_doi$k"; throw "Tổ đội ${k}: không nhận ra nút Nhận / Xuất phát / Gọi về" }
    if ($b -eq 'goi_ve') { Log "To doi ${k}: dang tham hiem"; return 'dang_chay' }

    $res = 'xuat_phat'
    if ($b -eq 'nhan') {
        Log "To doi ${k}: ket thuc -> bam Nhan"
        ThPress 'nhan'
        $p = $null; $dl = (Get-Date).AddSeconds(6)
        do { Nap 0.6; Snap | Out-Null; $p = ThFind 'popup_co_thuong' 25 @(540, 190, 520, 180) } while (-not $p.Count -and (Get-Date) -lt $dl)
        if ($p.Count) {
            Nap 0.8   # cho hien het danh sach qua
            Save-Shot "tham_hiem_doi${k}_thuong"
            Add-Photo (Caption "🎁 Tổ đội ${k}: đã nhận thưởng")
        } else { Log "Khong thay popup 'Co thuong' (van tiep tuc)" }
        $script:ThClaimed++
        # dong popup: cham GIUA man hinh (dong "Nhan de tiep tuc" o goc duoi phai de len nut Xuat phat)
        $b = $null; $dl = (Get-Date).AddSeconds(10)
        do {
            Nap 1; Tap 700 400 40; Nap 1.2
            Snap | Out-Null; $b = ThButton
        } while ($b -ne 'xuat_phat' -and (Get-Date) -lt $dl)
        if ($b -ne 'xuat_phat') { Save-Shot "loi_to_doi${k}_sau_nhan"; throw "Tổ đội ${k}: nhận xong không thấy nút Xuất phát" }
        if ($NoStart) { Log "To doi ${k}: da nhan, CHUA xuat phat (cho du 3 to doi de di cung luc)"; return 'da_nhan' }
        $res = 'nhan_xuat_phat'
    } elseif ($NoStart) { Log "To doi ${k}: dang ranh, CHUA xuat phat (cho du 3 to doi de di cung luc)"; return 'ranh' }
    ThGo $k
    return $res
}

# Dang o tab to doi $k, thay nut Xuat phat -> bam, cho toi khi to doi bat dau (nut thanh Goi ve)
function ThGo([int]$k) {
    Nap 0.6
    Log "To doi ${k}: bam Xuat phat"
    ThPress 'xuat_phat'
    $dl = (Get-Date).AddSeconds(8)
    do { Nap 0.8; Snap | Out-Null; $b = ThButton } while ($b -ne 'goi_ve' -and (Get-Date) -lt $dl)
    if ($b -ne 'goi_ve') { Save-Shot "loi_to_doi${k}_xuat_phat"; throw "Tổ đội ${k}: bấm Xuất phát mà chưa thấy bắt đầu thám hiểm" }
    $script:ThStarted++
}

# Dong bo: chon tab to doi $k (da nhan / dang ranh) roi Xuat phat
function ThStart([int]$k) {
    $tab = $ThTabs[$k - 1]
    Tap $tab.Tap[0] $tab.Tap[1] 8; Nap 1.2
    $b = $null
    for ($i = 0; $i -lt 6 -and -not $b; $i++) {
        Snap | Out-Null
        [void](ThCancelRecall)
        $b = ThButton
        if (-not $b) { Nap 0.7 }
    }
    if ($b -eq 'goi_ve') { Log "To doi ${k}: da dang tham hiem san (bo qua)"; return }
    if ($b -ne 'xuat_phat') { Save-Shot "loi_to_doi${k}_xuat_phat"; throw "Tổ đội ${k}: không thấy nút Xuất phát (đang là '$b')" }
    ThGo $k
}
# Doc gio con lai cua 3 to doi. Chi doc duoc o tab KHONG chon (tab dang chon nen kem -> nhieu):
# chon tab 1 doc tab 2, 3; chon tab 2 doc tab 1; to doi nao chua doc chac thi chon tab 3 doc lai 1, 2 (23/11).
# Tra ve @{ k = TimeSpan } cho to doi doc duoc chac chan. Doc "khong chac" (lech <= $ThHintMaxDist) -> $script:ThHint[k]
function ThReadTimers {
    $rem = @{}; $script:ThHint = @{}
    foreach ($pair in @(@(1, @(2, 3)), @(2, @(1)), @(3, @(1, 2)))) {
        $todo = @($pair[1] | Where-Object { -not $rem.ContainsKey($_) })
        if (-not $todo.Count) { continue }
        $sel = $ThTabs[$pair[0] - 1]
        Tap $sel.Tap[0] $sel.Tap[1] 8; Nap 1.2
        Snap | Out-Null
        foreach ($k in $todo) {
            $c = $ThTabs[$k - 1].Clock
            $r = [TabTimer]::Read($Shot, $ThDigits, $c[0], $c[1], $c[2], $c[3])
            if ($r -match '^(\d\d):(\d\d):(\d\d) ([\d.]+)$' -and [double]$Matches[4] -le $ThTimerMaxDist) {
                $rem[$k] = New-TimeSpan -Hours ([int]$Matches[1]) -Minutes ([int]$Matches[2]) -Seconds ([int]$Matches[3])
                $script:ThHint.Remove($k)
                Log "To doi ${k}: con $($Matches[1]):$($Matches[2]):$($Matches[3]) (lech $($Matches[4]))$(if ($pair[0] -eq 3) { ' – doc lai tu tab 3' })"
            } else {
                if ($r -match '^(\d\d):(\d\d):(\d\d) ([\d.]+)$' -and [double]$Matches[4] -le $ThHintMaxDist) {
                    $script:ThHint[$k] = New-TimeSpan -Hours ([int]$Matches[1]) -Minutes ([int]$Matches[2]) -Seconds ([int]$Matches[3])
                }
                Log "To doi ${k}: khong doc chac duoc dong ho ('$r')"
                # giu anh de lay them mau chu so (vd chu so 6 chua co mau)
                try { [Vision]::SavePng($Shot, (Join-Path $LogDir "${Stamp}_dong_ho_doi${k}_khong_doc_duoc.png")) } catch {}
            }
        }
    }
    return $rem
}

# Man Tham hiem -> sanh chinh: Quay lai 2 lan (-> man Thu cuoi -> sanh, menu Day do van mo) roi bam Day do de dong menu
function Exit-ThamHiem {
    for ($i = 0; $i -lt 2; $i++) { Tap 75 45 8; Nap 1.8 }
    Snap | Out-Null
    if ((ThFind 'muc_thu_cuoi' 32 @(860, 300, 240, 200)).Count) {
        $d = ThFind 'nut_day_do' 12 @(1080, 760, 240, 140)
        if ($d.Count) { Log "Dong menu Day do"; Tap $d[0].X $d[0].Y 8; Nap 1 }
    }
}

# Ca luot tham hiem (sau Enter-Game, dang o sanh chinh)
# $ThSync (23/11): to doi xong -> chi nhan; chi khi KHONG con to doi nao dang chay moi Xuat phat ca 3 cung luc.
# Con to doi dang chay (qua $ThWaitMin phut) -> giu to doi da nhan / dang ranh, hen lai luc to doi xong muon nhat.
function Invoke-ThamHiem {
    $script:ThLines = @(); $script:ThNext = $null; $script:ThNextWhy = $null
    $script:ThClaimed = 0; $script:ThStarted = 0; $script:ThWaitedMin = 0
    Open-ThamHiem
    $state = @{}; $startAt = @{}
    $started = { param($s) $s -in 'nhan_xuat_phat', 'xuat_phat' }
    for ($k = 1; $k -le 3; $k++) {
        $state[$k] = ThTeam $k -NoStart:$ThSync
        if (& $started $state[$k]) { $startAt[$k] = Get-Date }
        Nap ((Rnd 6 15) / 10.0)   # nghi ngan giua 2 to doi
    }
    $rem = ThReadTimers
    # Giong nong trai cho cay chin: to doi nao con <= $ThWaitMin phut la xong -> ngoi cho tai man Tham hiem, xong la nhan
    if ($ThWaitMin -gt 0) {
        $now = Get-Date; $waitEnd = $now.AddMinutes($ThWaitMin)
        # gio con lai: doc chac, hoac doc khong chac (23/11: to doi 2 "00:01:50 lech 9.70" bi bo qua -> xong ma khong nhan)
        $left0 = @{}
        foreach ($k in 1..3) { if ($rem.ContainsKey($k)) { $left0[$k] = $rem[$k] } elseif ($script:ThHint.ContainsKey($k)) { $left0[$k] = $script:ThHint[$k] } }
        $soon = @(1..3 | Where-Object { $state[$_] -eq 'dang_chay' -and $left0.ContainsKey($_) -and $now.Add($left0[$_]) -le $waitEnd } |
            Sort-Object { $left0[$_] })
        if ($soon.Count) {
            $w0 = Get-Date
            foreach ($k in $soon) {
                $end = $now.Add($left0[$k])
                if (-not $rem.ContainsKey($k)) { Log "To doi ${k}: dung gio doc khong chac ($($left0[$k])) de quyet dinh ngoi cho" }
                $left = [int][math]::Ceiling(($end - (Get-Date)).TotalSeconds)
                if ($left -gt 0) {
                    Log "To doi ${k}: con $left giay la xong -> ngoi cho (toi da $ThWaitMin phut)"
                    Start-Sleep -Seconds ($left + (Rnd 5 15))
                }
                # dong ho co the lech vai chuc giay -> kiem tra lai toi da 3 phut, 20 giay 1 lan
                $dl = (Get-Date).AddMinutes(3)
                do {
                    $r = ThTeam $k -NoStart:$ThSync
                    if ($r -ne 'dang_chay') { $state[$k] = $r; if (& $started $r) { $startAt[$k] = Get-Date }; break }
                    Log "To doi ${k}: chua xong, cho them 20 giay"; Start-Sleep -Seconds 20
                } while ((Get-Date) -lt $dl)
                if ($state[$k] -eq 'dang_chay') { Log "To doi ${k}: cho qua gio ma van chua xong -> de lan sau" }
                Nap ((Rnd 6 15) / 10.0)
            }
            $script:ThWaitedMin = [math]::Max(1, [int][math]::Round(((Get-Date) - $w0).TotalMinutes))
            Log "Da cho to doi xong $($script:ThWaitedMin) phut"
            $rem = ThReadTimers
        }
    }
    # 23/11: to doi khong doc duoc gio co the da xong trong luc ngoi cho to doi khac -> bam vao kiem tra lai 1 lan
    $unk = @(1..3 | Where-Object { $state[$_] -eq 'dang_chay' -and -not $rem.ContainsKey($_) })
    if ($unk.Count) {
        foreach ($k in $unk) {
            Log "To doi ${k}: khong biet gio xong -> kiem tra lai truoc khi ve"
            $r = ThTeam $k -NoStart:$ThSync
            if ($r -ne 'dang_chay') { $state[$k] = $r; if (& $started $r) { $startAt[$k] = Get-Date } }
            Nap ((Rnd 6 15) / 10.0)
        }
        $rem = ThReadTimers
    }
    # Dong bo: khong con to doi nao dang chay -> Xuat phat tat ca to doi da nhan / dang ranh CUNG LUC
    $ready = @(1..3 | Where-Object { $state[$_] -in 'da_nhan', 'ranh' })
    $running = @(1..3 | Where-Object { $state[$_] -eq 'dang_chay' })
    if ($ready.Count -and -not $running.Count) {
        Log "Ca 3 to doi da xong / ranh -> xuat phat cung luc"
        foreach ($k in $ready) {
            ThStart $k
            $state[$k] = if ($state[$k] -eq 'da_nhan') { 'nhan_xuat_phat' } else { 'xuat_phat' }
            $startAt[$k] = Get-Date
            Nap ((Rnd 4 9) / 10.0)
        }
        $rem = ThReadTimers
    } elseif ($ready.Count) {
        Log "Giu to doi $($ready -join ', ') (chua xuat phat) cho to doi $($running -join ', ') xong de xuat phat cung luc"
    }
    Save-Shot "tham_hiem_tong_ket"
    Add-Photo (Caption "🐎 Thú cưỡi thám hiểm: 3 tổ đội sau lượt này")
    $now = Get-Date
    $ends = @{}
    for ($k = 1; $k -le 3; $k++) {
        if ($state[$k] -in 'da_nhan', 'ranh') {
            $what = if ($state[$k] -eq 'da_nhan') { "đã nhận thưởng" } else { "đang rảnh" }
            $script:ThLines += "🐎 Tổ đội ${k}: $what – chưa xuất phát, chờ tổ $($running -join ', ') xong để đi cùng lúc"
            continue
        }
        $end = $null; $how = ""
        if ($rem.ContainsKey($k)) { $end = $now.Add($rem[$k]) }
        elseif ($startAt.ContainsKey($k)) { $end = $startAt[$k].AddHours($ThHours); $how = " (ước tính)" }
        $what = switch ($state[$k]) { 'nhan_xuat_phat' { "nhận thưởng, đi tiếp" } 'xuat_phat' { "xuất phát" } default { "đang thám hiểm" } }
        $endTxt = if ($end) { "xong lúc $($end.ToString('HH:mm dd/MM'))$how" } else { "không đọc được giờ xong" }
        $script:ThLines += "🐎 Tổ đội ${k}: $what – $endTxt"
        if ($end) { $ends[$k] = $end }
    }
    # Hen lan sau
    if ($ends.Count) {
        $min = ($ends.Values | Measure-Object -Minimum).Minimum; $max = ($ends.Values | Measure-Object -Maximum).Maximum
        $unknownRunning = @(1..3 | Where-Object { $state[$_] -eq 'dang_chay' -and -not $ends.ContainsKey($_) })
        if ($ThSync -and -not $unknownRunning.Count) {
            # dong bo: luc to doi xong muon nhat ca 3 deu xong -> nhan het + xuat phat cung luc
            $script:ThNext = $max
            $script:ThNextWhy = "tổ đội xong muộn nhất lúc $($max.ToString('HH:mm dd/MM')) – đủ 3 tổ thì xuất phát cùng lúc"
        } else {
            $script:ThNext = $min
            $script:ThNextWhy = "tổ đội xong sớm nhất lúc $($min.ToString('HH:mm dd/MM'))$(if ($ThSync) { ' (có tổ không đọc được giờ)' })"
        }
    }
    if ($script:ThWaitedMin) { $script:ThLines += "⏳ Đã chờ tổ đội xong $($script:ThWaitedMin) phút" }
    Log ("Tham hiem: nhan $($script:ThClaimed), xuat phat $($script:ThStarted); " + ($script:ThLines -join ' | '))
    try { Exit-ThamHiem } catch { Log "Ve sanh loi (bo qua): $($_.Exception.Message)" }
}