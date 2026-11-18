# Ghep cac anh lien tiep trong khoang [From, To] (HHmmss) thanh 1 to, moi o 480x270
# -Crop x,y,w,h (toa do anh 960x540) de phong to 1 vung
param([string]$Dir, [string]$From, [string]$To, [int]$Step = 1, [string]$OutName = "day", [int]$Cols = 4, [int[]]$Crop = $null)
Add-Type -AssemblyName System.Drawing
$f = Get-ChildItem "$Dir\*.jpg" | Where-Object { $_.BaseName -match '^\d{6}_\d{3}$' -and $_.BaseName -ge $From -and $_.BaseName -le "${To}_999" } | Sort-Object Name
$f = @($f | Where-Object { ([array]::IndexOf($f, $_)) % $Step -eq 0 })
$tw = 480; $th = 270; $lh = 16
$rows = [Math]::Ceiling($f.Count / $Cols)
$sheet = New-Object Drawing.Bitmap ($Cols * $tw), ($rows * ($th + $lh))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::Black)
$font = New-Object Drawing.Font 'Arial', 10
for ($k = 0; $k -lt $f.Count; $k++) {
    $cx = ($k % $Cols) * $tw; $cy = [Math]::Floor($k / $Cols) * ($th + $lh)
    $img = [Drawing.Image]::FromFile($f[$k].FullName)
    if ($Crop) { $g.DrawImage($img, (New-Object Drawing.Rectangle $cx, ($cy + $lh), $tw, $th), (New-Object Drawing.Rectangle $Crop[0], $Crop[1], $Crop[2], $Crop[3]), [Drawing.GraphicsUnit]::Pixel) }
    else { $g.DrawImage($img, $cx, $cy + $lh, $tw, $th) }
    $img.Dispose()
    $g.DrawString($f[$k].BaseName, $font, [Drawing.Brushes]::Yellow, $cx + 2, $cy)
}
$out = Join-Path $Dir "$OutName.jpg"; $sheet.Save($out, [Drawing.Imaging.ImageFormat]::Jpeg); $g.Dispose(); $sheet.Dispose()
"$out ($($f.Count) anh)"
