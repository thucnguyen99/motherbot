# Doc cham.txt (getevent -lt) -> danh sach lan cham: gio nhan/tha (gio may tinh), giu bao lau, toa do dau/cuoi (RAW doc 900x1600)
param([string]$Dir)
$m = (Get-Content "$Dir\moc_thoi_gian.txt") -match 'host=(\S+) uptime=(\S+)'
$host0 = [datetime]::ParseExact($Matches[1], 'HH:mm:ss.fff', $null); $up0 = [double]$Matches[2]
function HT($t) { $host0.AddSeconds($t - $up0).ToString('HH:mm:ss.fff') }
$x = $null; $y = $null; $cur = $null; $res = @()
foreach ($l in Get-Content "$Dir\cham.txt") {
    if ($l -notmatch '^\[\s*([\d.]+)\]\s+(\S+)\s+(\S+)\s+(\S+)') { continue }
    $t = [double]$Matches[1]; $code = $Matches[3]; $val = $Matches[4]
    switch ($code) {
        'ABS_MT_POSITION_X' { $x = [Convert]::ToInt32($val, 16) }
        'ABS_MT_POSITION_Y' { $y = [Convert]::ToInt32($val, 16) }
        'BTN_TOUCH' {
            if ($val -eq 'UP') { if ($cur) { $cur.t1 = $t; $cur.x1 = $x; $cur.y1 = $y; $res += $cur; $cur = $null } }
            elseif (-not $cur) { $cur = [pscustomobject]@{ t0 = $t; t1 = $null; x0 = $null; y0 = $null; x1 = $null; y1 = $null; n = 0 } }
        }
        'SYN_REPORT' { if ($cur) { if ($null -eq $cur.x0 -and $null -ne $x) { $cur.x0 = $x; $cur.y0 = $y }; $cur.n++ } }
    }
}
$i = 0
foreach ($c in $res) {
    $i++
    "{0,3} {1} -> {2}  giu {3,5:N2}s  RAW ({4},{5}) -> ({6},{7})  {8} moc" -f $i, (HT $c.t0), (HT $c.t1), ($c.t1 - $c.t0), $c.x0, $c.y0, $c.x1, $c.y1, $c.n
}
