# =====================================================================
#  Thanh vat - nhan ruong "Dat duoc" (thuong treo may, tich toi da 9 gio, 6 phut/lan).
#  Chay trong MOI luot nong trai (ddtank_farm.ps1, $ThanhVat = $true): vao sanh -> nhan ruong -> ve sanh -> thu hoach.
#  Dot-source vao ddtank_farm.ps1, dung chung Snap / Tap / Nap / Log / Save-Shot / Add-Photo / Close-Popups / Find.
#  Sanh -> Day do -> Thanh vat -> Dat duoc (goc tren trai) -> ruong (goc duoi phai) -> popup "Thoi gian bo tri":
#    nut Nhan XANH -> bam -> "Co thuong" -> cham giua man hinh; nut Nhan XAM (chua co gi) -> dong popup (X)
#  -> Quay lai 1 lan (ve thang sanh, menu Day do con mo) -> bam Day do dong menu.
#  Ghi chu, toa do, nguong: thanh_vat\GHI_CHU.md
# =====================================================================
$TvMau = Join-Path $Root "thanh_vat\mau"
# Nguong khop (do 19/11 tren 14 anh): dung cho 0-6.3, cho khac >= 38; Nhan xanh <-> xam lech 56
$TvMenu   = @(860, 300, 600, 460)     # luoi bieu tuong menu Day do
$TvPopup  = @(600, 20, 400, 110)      # tieu de "Thoi gian bo tri"
$TvNhan   = @(600, 670, 400, 150)     # nut Nhan trong popup
$TvChest  = @(1410, 760)              # ruong o man Dat duoc
$script:ThanhVatNote = $null          # dong tom tat Telegram
$script:ThanhVatGot  = $false

function TvFind($name, $maxScore, $region) {
    return ,@([Vision]::FindAll($Shot, (Join-Path $TvMau "$name.png"), $maxScore, $region[0], $region[1], $region[2], $region[3]))
}
function TvWait($name, $maxScore, $region, $sec) {
    $dl = (Get-Date).AddSeconds($sec)
    do {
        Snap | Out-Null
        $m = TvFind $name $maxScore $region
        if ($m.Count) { return $m[0] }
        Start-Sleep -Milliseconds 300
    } while ((Get-Date) -lt $dl)
    return $null
}
function TvInLobby { return ((Find "btn_friends" 15).Count -and -not (Find "popup_close" 12).Count) }

# Ve sanh chinh (sach): dong popup "Thoi gian bo tri" neu con, Quay lai toi khi thay sanh, dong menu Day do.
# Chi bam Quay lai khi CHUA o sanh (o sanh, goc tren trai la anh dai dien -> mo man thong tin nhan vat).
function TvBackToLobby {
    for ($i = 0; $i -lt 4; $i++) {
        Snap | Out-Null
        $x = TvFind 'nut_dong' 12 @(1400, 10, 200, 150)
        if ($x.Count) { Log "Dong popup Thanh vat"; Tap $x[0].X $x[0].Y 6; Nap 1.2; continue }
        if (TvInLobby) { break }
        Log "Quay lai"; Tap 75 45 8; Nap 1.8
    }
    Snap | Out-Null
    if (-not (TvInLobby)) { throw "Thánh vật: không về được sảnh chính" }
    # menu Day do con mo -> bam Day do de dong
    if ((TvFind 'muc_thanh_vat' 12 $TvMenu).Count) {
        $d = TvFind 'nut_day_do' 12 @(1080, 760, 240, 140)
        if ($d.Count) { Log "Dong menu Day do"; Tap $d[0].X $d[0].Y 8; Nap 1 }
    }
}

# Ca buoc Thanh vat (dang o sanh chinh). Loi -> nem ra ngoai (Retry-Step lam lai; het lan -> luot nong trai van chay tiep)
function Invoke-ThanhVat {
    $script:ThanhVatNote = $null; $script:ThanhVatGot = $false
    Close-Popups
    Snap | Out-Null
    # 1. Day do -> Thanh vat (menu co the dang mo san)
    $m = TvFind 'muc_thanh_vat' 12 $TvMenu
    if (-not $m.Count) {
        $d = TvFind 'nut_day_do' 12 @(1080, 760, 240, 140)
        if (-not $d.Count) { Save-Shot "loi_tv_khong_thay_day_do"; throw "Thánh vật: không thấy nút Dạy dỗ ở sảnh chính" }
        Log "Bam Day do"; Tap $d[0].X $d[0].Y 8
        $m = @(TvWait 'muc_thanh_vat' 12 $TvMenu 8)
        if (-not $m[0]) { Save-Shot "loi_tv_menu"; throw "Thánh vật: bấm Dạy dỗ không thấy mục Thánh vật" }
    }
    Nap 0.8
    Log "Bam Thanh vat"; Tap $m[0].X $m[0].Y 10
    # 2. Dat duoc
    $dd = TvWait 'nut_dat_duoc' 12 @(0, 110, 250, 200) 10
    if (-not $dd) { Save-Shot "loi_tv_man_thanh_vat"; throw "Thánh vật: không vào được màn Thánh vật" }
    Nap 0.8
    Log "Bam Dat duoc"; Tap $dd.X $dd.Y 8
    if (-not (TvWait 'man_dat_duoc' 12 @(1400, 100, 200, 180) 10)) { Save-Shot "loi_tv_dat_duoc"; throw "Thánh vật: không vào được màn Đạt được" }
    Nap 1
    # 3. Ruong -> popup "Thoi gian bo tri"
    Log "Bam ruong"; Tap $TvChest[0] $TvChest[1] 25
    if (-not (TvWait 'popup_bo_tri' 18 $TvPopup 8)) { Save-Shot "loi_tv_ruong"; throw "Thánh vật: bấm rương không thấy bảng Thời gian bố trí" }
    Nap 0.8; Snap | Out-Null
    $green = TvFind 'nut_nhan' 15 $TvNhan
    $gray  = TvFind 'nut_nhan_xam' 15 $TvNhan
    if ($green.Count) {
        Log "Ruong co thuong -> bam Nhan"; Tap $green[0].X $green[0].Y 20
        $p = TvWait 'popup_co_thuong' 25 @(540, 190, 520, 180) 6
        if ($p) {
            Nap 0.8
            Save-Shot "thanh_vat_thuong"
            Add-Photo (Caption "🎁 Thánh vật: đã nhận rương Đạt được")
        } else { Log "Khong thay popup 'Co thuong' (van tiep tuc)" }
        $script:ThanhVatGot = $true
        $script:ThanhVatNote = "🎁 Thánh vật: đã nhận rương Đạt được"
        Nap 0.8; Tap 700 420 40; Nap 1.2     # cham giua man hinh dong "Co thuong"
    } elseif ($gray.Count) {
        Log "Ruong chua co thuong (nut Nhan xam)"
        $script:ThanhVatNote = "🎁 Thánh vật: rương chưa có thưởng"
    } else {
        Save-Shot "loi_tv_nut_nhan"; throw "Thánh vật: không nhận ra nút Nhận"
    }
    # 4. Ve sanh
    TvBackToLobby
    Log "Thanh vat xong -> tiep tuc nong trai"
}
