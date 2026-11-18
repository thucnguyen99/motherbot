# Phan tich vet ban kinh trong log cau thu: vong sang co deu hay nhanh dan? lien quan ket qua?
param([string[]]$Logs)
$rows = @()
foreach ($log in $Logs) {
    $lines = Get-Content $log
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match 'BAM vong (\d+): r du doan (\d+).*toc do (\d+) px/s') {
            $round = [int]$Matches[1]; $pred = [int]$Matches[2]; $v = [int]$Matches[3]
            $tr = $lines[$i + 1]; $kq = ''
            for ($j = $i + 2; $j -lt [Math]::Min($i + 4, $lines.Count); $j++) { if ($lines[$j] -match 'ket qua vong \d+: (.+)$') { $kq = $Matches[1].Trim(); break } }
            $pts = [regex]::Matches($tr, '(\d+\.\d+):(\d+)') | ForEach-Object { [pscustomobject]@{ t = [double]$_.Groups[1].Value; r = [int]$_.Groups[2].Value } }
            $use = @($pts | Where-Object { $_.r -le 78 -and $_.r -ge 25 })
            if ($use.Count -lt 6) { continue }
            # toc do dau (r 78..50) va cuoi (r < 50)
            $early = @($use | Where-Object { $_.r -ge 50 }); $late = @($use | Where-Object { $_.r -lt 50 })
            function Slope($p) { if ($p.Count -lt 2) { return $null }; $mt = ($p | Measure-Object t -Average).Average; $mr = ($p | Measure-Object r -Average).Average; $sxy = 0; $sxx = 0; foreach ($q in $p) { $sxy += ($q.t - $mt) * ($q.r - $mr); $sxx += ($q.t - $mt) * ($q.t - $mt) }; if ($sxx -eq 0) { return $null }; return -$sxy / $sxx }
            $ve = Slope $early; $vl = Slope $late
            $rows += [pscustomobject]@{ vong = $round; kq = $kq; pred = $pred; v = $v; v_dau = [int]$ve; v_cuoi = [int]$vl; ti_le = $(if ($ve -and $vl) { [Math]::Round($vl / $ve, 2) } else { $null }); n = $use.Count }
        }
    }
}
$rows | Sort-Object kq, ti_le | Format-Table -AutoSize
"--- trung binh ti le toc do cuoi/dau theo ket qua"
$rows | Where-Object { $_.ti_le } | Group-Object kq | ForEach-Object { "{0,-10} {1,3} vong  ti_le TB {2:N2}  (min {3:N2} max {4:N2})" -f $_.Name, $_.Count, ($_.Group | Measure-Object ti_le -Average).Average, ($_.Group | Measure-Object ti_le -Minimum).Minimum, ($_.Group | Measure-Object ti_le -Maximum).Maximum }
