# In cac lan doi trang thai (do%/cau/toi) tren toan bo ban ghi nhanh, doi chieu voi lan cham
param([string]$Dir = "D:\tools\ddtank-farm\cau_ca\ghi_hinh\ghi_nhanh_17fps")
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition (Get-Content (Join-Path $PSScriptRoot "Ring.cs") -Raw)
$prev = ''
foreach ($f in (Get-ChildItem "$Dir\*.jpg" | Where-Object { $_.BaseName -match '^\d{6}_\d{3}$' } | Sort-Object Name)) {
    $w = 0; $h = 0; $p = [Ring]::LoadRgb($f.FullName, [ref]$w, [ref]$h)
    $red = [Ring]::RedPct($p, $w, $h); $ball = [Ring]::HasBall($p, $w, $h); $br = [Ring]::Bright($p, $w, $h)
    $st = if ($br -lt 120) { 'TOI(chuc mung)' } elseif ($ball) { 'VONG' } elseif ($red -ge 35) { 'KEO_CAN' } else { 'khac' }
    if ($st -ne $prev) { "{0} {1,-15} do={2,3}% sang={3}" -f $f.BaseName, $st, $red, $br; $prev = $st }
}

