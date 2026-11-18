# Chay Ring.cs tren anh da ghi: in ban kinh vong sang theo thoi gian quanh moi lan bam vong tron
param([string]$Dir = "D:\tools\ddtank-farm\cau_ca\ghi_hinh\ghi_nhanh_17fps", [string]$From, [string]$To)
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition (Get-Content (Join-Path $PSScriptRoot "Ring.cs") -Raw)
function Load($path) {
    $b = [Drawing.Bitmap]::FromFile($path); $w = $b.Width; $h = $b.Height
    $d = $b.LockBits((New-Object Drawing.Rectangle 0,0,$w,$h), 'ReadOnly', [Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $raw = New-Object byte[] ($d.Stride * $h); [Runtime.InteropServices.Marshal]::Copy($d.Scan0, $raw, 0, $raw.Length); $b.UnlockBits($d); $b.Dispose()
    $p = New-Object byte[] ($w * $h * 3)
    for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $s = $y * $d.Stride + $x * 3; $t = ($y * $w + $x) * 3; $p[$t] = $raw[$s+2]; $p[$t+1] = $raw[$s+1]; $p[$t+2] = $raw[$s] } }
    return ,$p
}
$f = Get-ChildItem "$Dir\*.jpg" | Where-Object { $_.BaseName -match '^\d{6}_\d{3}$' -and $_.BaseName -ge $From -and $_.BaseName -le $To } | Sort-Object Name
$bg = $null; $out = @()
foreach ($x in $f) {
    $p = Load $x.FullName
    $ball = [Ring]::HasBall($p, 640, 360); $pull = [Ring]::IsPullButton($p, 640, 360)
    if ($ball -and -not $bg) { $bg = $p }
    if (-not $ball) { $bg = $null }
    $r = -1; $sc = 0
    if ($bg) { $r = [Ring]::Radius($p, $bg, 640, 360, [ref]$sc) }
    $out += "{0} keo={1} cau={2} r={3,3} diem={4}" -f $x.BaseName, [int]$pull, [int]$ball, $r, $sc
}
$out
