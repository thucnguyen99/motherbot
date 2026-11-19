# Danh sach loai hat giong (dung chung cho ddtank_farm.ps1 va telegram_bot.ps1)
#  Key   : ten go trong lenh (/chay akaka nho, hoac -Seed nho), khong dau, viet lien
#  Tpl   : anh mau trong templates\ (56x42, phan hinh qua tren tui hat, cat tu bang "gieo hat" ngay 19/11 - ruong akaka)
#  Name  : ten hien thi tren Telegram
# Them loai moi: cat anh mau 56x42 (giua hinh qua, khong lay so luong / vien o) roi them 1 dong vao day.
$SeedTypes = [ordered]@{
    khoai     = @{ Tpl = 'seed_potato';    Name = 'khoai tây';  Icon = '🥔' }
    le        = @{ Tpl = 'seed_le';        Name = 'lê';         Icon = '🍐' }
    nho       = @{ Tpl = 'seed_nho';       Name = 'nho';        Icon = '🍇' }
    tao       = @{ Tpl = 'seed_tao';       Name = 'táo';        Icon = '🍎' }
    thanhlong = @{ Tpl = 'seed_thanhlong'; Name = 'thanh long'; Icon = '🐉' }
    ngo       = @{ Tpl = 'seed_ngo';       Name = 'ngô';        Icon = '🌽' }
    bapcai    = @{ Tpl = 'seed_bapcai';    Name = 'bắp cải';    Icon = '🥬' }
    catim     = @{ Tpl = 'seed_catim';     Name = 'cà tím';     Icon = '🍆' }
}
# Ten goi khac -> key (go co dau / tieng Anh cung duoc)
$SeedAliases = @{ khoaitay = 'khoai'; potato = 'khoai'; bap = 'ngo'; corn = 'ngo'; bacai = 'bapcai'; caitim = 'catim' }

# "Thanh Long" / "thanh_long" / "ngô" / "cà tím" -> "thanhlong" / "ngo" / "catim". Khong nhan ra -> $null
function ConvertTo-SeedKey([string]$s) {
    if (-not $s) { return $null }
    $t = $s.ToLowerInvariant().Replace('đ', 'd').Normalize([Text.NormalizationForm]::FormD)
    $t = -join ($t.ToCharArray() | Where-Object { [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    $t = $t -replace '[^a-z]', ''
    if ($SeedTypes.Contains($t)) { return $t }
    if ($SeedAliases.ContainsKey($t)) { return $SeedAliases[$t] }
    return $null
}

function Get-SeedListText { ($SeedTypes.Keys | ForEach-Object { "$_ $($SeedTypes[$_].Icon)" }) -join ', ' }
