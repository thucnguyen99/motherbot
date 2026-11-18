# Ghep anh truoc/sau moi lan cham thanh to lien (contact sheet), danh dau diem cham
# Do: map A (sx=Y, sy=900-X)  Xanh: map B (sx=1600-Y, sy=X)   (toa do man hinh 1600x900, anh luu 960x540)
param([string]$Dir, [int]$From = 1, [int]$To = 999, [string]$OutName = "sheet", [int]$Cols = 4, [double]$After = 1.5)
Add-Type -AssemblyName System.Drawing
$m = (Get-Content "$Dir\moc_thoi_gian.txt") -match 'host=(\S+) uptime=(\S+)'
$host0 = [datetime]::ParseExact($Matches[1], 'HH:mm:ss.fff', $null); $up0 = [double]$Matches[2]
$frames = Get-ChildItem "$Dir\*.jpg" | ForEach-Object { [pscustomobject]@{ P = $_.FullName; T = [datetime]::ParseExact($_.BaseName, 'HHmmss_fff', $null) } } | Sort-Object T
function FrameAt($t, [switch]$Before) {
    if ($Before) { $frames | Where-Object { $_.T -le $t } | Select-Object -Last 1 } else { $frames | Where-Object { $_.T -ge $t } | Select-Object -First 1 }
}
# doc lai cac lan cham
$x = $null; $y = $null; $cur = $null; $taps = @()
foreach ($l in Get-Content "$Dir\cham.txt") {
    if ($l -notmatch '^\[\s*([\d.]+)\]\s+(\S+)\s+(\S+)\s+(\S+)') { continue }
    $t = [double]$Matches[1]; $code = $Matches[3]; $val = $Matches[4]
    if ($code -eq 'ABS_MT_POSITION_X') { $x = [Convert]::ToInt32($val, 16) }
    elseif ($code -eq 'ABS_MT_POSITION_Y') { $y = [Convert]::ToInt32($val, 16) }
    elseif ($code -eq 'BTN_TOUCH' -and $val -eq 'DOWN' -and -not $cur) { $cur = @{ t0 = $t } }
    elseif ($code -eq 'BTN_TOUCH' -and $val -eq 'UP' -and $cur) { $cur.t1 = $t; $cur.x = $x; $cur.y = $y; $taps += [pscustomobject]$cur; $cur = $null }
    elseif ($code -eq 'SYN_REPORT' -and $cur -and -not $cur.x0) { $cur.x0 = $x; $cur.y0 = $y }
}
$sel = @(); for ($i = $From; $i -le [Math]::Min($To, $taps.Count); $i++) { $sel += $i }
$tw = 480; $th = 270; $lh = 18
$rows = [Math]::Ceiling($sel.Count * 2 / $Cols)
$sheet = New-Object Drawing.Bitmap ($Cols * $tw), ($rows * ($th + $lh))
$g = [Drawing.Graphics]::FromImage($sheet); $g.Clear([Drawing.Color]::Black)
$font = New-Object Drawing.Font 'Arial', 10
$k = 0
foreach ($i in $sel) {
    $tp = $taps[$i - 1]
    $tDown = $host0.AddSeconds($tp.t0 - $up0)
    foreach ($phase in 'truoc', 'sau') {
        $f = if ($phase -eq 'truoc') { FrameAt $tDown -Before } else { FrameAt ($tDown.AddSeconds($After)) }
        $cx = ($k % $Cols) * $tw; $cy = [Math]::Floor($k / $Cols) * ($th + $lh)
        if ($f) {
            $img = [Drawing.Image]::FromFile($f.P); $g.DrawImage($img, $cx, $cy + $lh, $tw, $th); $img.Dispose()
            if ($phase -eq 'truoc') {
                $s = $tw / 1600.0
                $ax = $tp.y0 * $s; $ay = (900 - $tp.x0) * $s; $bx = (1600 - $tp.y0) * $s; $by = $tp.x0 * $s
                $g.DrawEllipse((New-Object Drawing.Pen ([Drawing.Color]::Red), 3), $cx + $ax - 9, $cy + $lh + $ay - 9, 18, 18)
                $g.DrawEllipse((New-Object Drawing.Pen ([Drawing.Color]::Cyan), 2), $cx + $bx - 7, $cy + $lh + $by - 7, 14, 14)
            }
            $lbl = "#$i $phase $($f.T.ToString('HH:mm:ss.f'))" + $(if ($phase -eq 'truoc') { " giu $([Math]::Round($tp.t1 - $tp.t0, 2))s" } else { "" })
        } else { $lbl = "#$i $phase (khong co anh)" }
        $g.DrawString($lbl, $font, [Drawing.Brushes]::Yellow, $cx + 2, $cy + 1)
        $k++
    }
}
$out = Join-Path $Dir "$OutName.jpg"; $sheet.Save($out, [Drawing.Imaging.ImageFormat]::Jpeg); $g.Dispose(); $sheet.Dispose()
$out
