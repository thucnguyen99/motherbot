# Tu ket noi lai mang Wi-Fi khi mat Internet (dung chung cho ddtank_farm.ps1 va telegram_bot.ps1: dot-source file nay).
#  - Khong can quyen admin: "netsh wlan connect" vao Wi-Fi da luu (ten luu o state\wifi.txt khi con mang).
#    Card bao "connected" ma khong co Internet -> ngat ra roi ket noi lai.
#  - Can quyen admin (lich chay "Highest"): khoi dong lai card Wi-Fi (Restart-NetAdapter). Khong co quyen -> bo qua buoc nay.
# Khong doi cau hinh mang nao: chi ket noi lai vao Wi-Fi da luu san tren may.

$WifiStateFile = Join-Path $PSScriptRoot "state\wifi.txt"

# Doc trang thai card Wi-Fi tu "netsh wlan show interfaces" (Windows tieng Anh hoac tieng Viet)
function Get-WifiInfo {
    $ErrorActionPreference = 'Continue'
    $out = cmd /c "netsh wlan show interfaces 2>nul"
    $w = $null
    foreach ($l in $out) {
        if ($l -match '^\s*(Name|Tên)\s*:\s*(.+?)\s*$') { $w = [ordered]@{ Name = $Matches[2]; State = ''; SSID = ''; Profile = '' } }
        elseif ($w -and $l -match '^\s*(State|Trạng thái)\s*:\s*(.+?)\s*$') { $w.State = $Matches[2] }
        elseif ($w -and $l -match '^\s*SSID\s*:\s*(.+?)\s*$') { $w.SSID = $Matches[1] }
        elseif ($w -and $l -match '^\s*(Profile|Hồ sơ)\s*:\s*(.+?)\s*$') { $w.Profile = $Matches[2] }
    }
    if ($w) { return [pscustomobject]$w }
    return $null
}

# Co Internet khong: thu mo ket noi cong 443 toi vai may (chi can 1 may tra loi)
function Test-NetQuick {
    foreach ($h in @('api.telegram.org', 'www.google.com', '1.1.1.1')) {
        $c = New-Object System.Net.Sockets.TcpClient
        try { if ($c.ConnectAsync($h, 443).Wait(4000) -and $c.Connected) { return $true } } catch {} finally { $c.Close() }
    }
    return $false
}

# Song Wi-Fi bi tat (nut Wi-Fi trong Quick Settings / che do may bay) -> netsh khong lam gi duoc ("interface is powered down").
# Bat lai song bang Windows Radio API (khong can quyen admin). Tra ve: 'on' (da bat lai), 'already' (dang bat), 'fail: ...'
function Enable-WifiRadio {
    try {
        Add-Type -AssemblyName System.Runtime.WindowsRuntime
        $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
        $await = { param($op, [Type]$type) $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op)); [void]$t.Wait(10000); $t.Result }
        [void][Windows.Devices.Radios.Radio, Windows.System.Devices, ContentType = WindowsRuntime]
        $acc = & $await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus])
        if ("$acc" -ne 'Allowed') { return "fail: khong duoc phep ($acc)" }
        $radios = & $await ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
        $wifi = @($radios | Where-Object { "$($_.Kind)" -eq 'WiFi' }) | Select-Object -First 1
        if (-not $wifi) { return 'fail: khong thay song Wi-Fi' }
        if ("$($wifi.State)" -eq 'On') { return 'already' }
        $r = & $await ($wifi.SetStateAsync([Windows.Devices.Radios.RadioState]::On)) ([Windows.Devices.Radios.RadioAccessStatus])
        if ("$r" -eq 'Allowed') { return 'on' } else { return "fail: $r" }
    } catch { return "fail: $($_.Exception.Message)" }
}

# Ten cac Wi-Fi DA LUU tren may (ho so netsh). Chi chon trong danh sach nay, khong bao gio noi vao mang la / mang mo.
function Get-SavedWifiProfiles {
    $out = cmd /c "netsh wlan show profiles 2>nul"
    @($out | Where-Object { $_ -match '^\s*(All User Profile|User Profile|Hồ sơ người dùng[^:]*)\s*:\s*(.+?)\s*$' } | ForEach-Object { $Matches[2] })
}

# SSID cua 1 ho so (thuong trung ten ho so)
function Get-ProfileSsid([string]$Profile) {
    $out = cmd /c "netsh wlan show profile name=`"$Profile`" 2>nul"
    foreach ($l in $out) { if ($l -match '^\s*(SSID name|Tên SSID)\s*:\s*"(.+)"\s*$') { return $Matches[2] } }
    return $Profile
}

# Cac Wi-Fi dang bat duoc song: SSID -> song manh nhat (%) trong cac BSSID
function Get-VisibleWifi {
    $out = cmd /c "netsh wlan show networks mode=bssid 2>nul"
    $vis = @{}; $cur = $null
    foreach ($l in $out) {
        if ($l -match '^\s*SSID \d+\s*:\s*(.*?)\s*$') { $cur = $Matches[1] }
        elseif ($cur -and $l -match '^\s*(Signal|Tín hiệu)\s*:\s*(\d+)%') {
            $s = [int]$Matches[2]
            if (-not $vis.ContainsKey($cur) -or $vis[$cur] -lt $s) { $vis[$cur] = $s }
        }
    }
    return $vis
}

# Wi-Fi DA LUU dang bat duoc song, xep theo song manh nhat truoc
function Get-BestSavedWifi {
    $vis = Get-VisibleWifi
    $list = foreach ($p in Get-SavedWifiProfiles) {
        $ssid = Get-ProfileSsid $p
        if ($ssid -and $vis.ContainsKey($ssid)) { [pscustomobject]@{ Profile = $p; SSID = $ssid; Signal = $vis[$ssid] } }
    }
    @($list | Sort-Object Signal -Descending)
}

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Goi khi DANG CO mang: nho ten card + ho so Wi-Fi de luc mat mang biet ket noi lai vao dau
function Save-WifiProfile {
    try {
        $w = Get-WifiInfo
        if ($w -and $w.State -match '^connected$|đã kết nối' -and $w.Profile) {
            New-Item -ItemType Directory -Force (Split-Path $WifiStateFile) | Out-Null
            $line = "$($w.Name)|$($w.Profile)"
            if (-not (Test-Path $WifiStateFile) -or (Get-Content $WifiStateFile -Raw).Trim() -ne $line) {
                Set-Content -Path $WifiStateFile -Value $line -Encoding UTF8
            }
        }
    } catch {}
}

# Thu ket noi lai. $Level 1: netsh (khong can admin); 2: them khoi dong lai card (neu co quyen admin).
# $LogFn: scriptblock nhan 1 chuoi de ghi log. Tra ve mo ta da lam gi.
function Repair-Network([int]$Level = 1, [scriptblock]$LogFn = { param($m) }) {
    $ErrorActionPreference = 'Continue'
    $done = @()
    try {
        # 0. Song Wi-Fi bi tat -> bat lai truoc (Windows se tu ket noi Wi-Fi co che do Connect automatically)
        $rs = Enable-WifiRadio
        if ($rs -eq 'on') {
            & $LogFn "Ket noi lai mang: song Wi-Fi dang TAT -> da bat lai"
            $done += "bật lại sóng Wi-Fi"
            Start-Sleep 10
        } elseif ($rs -like 'fail*') { & $LogFn "Ket noi lai mang: khong kiem tra/bat duoc song Wi-Fi ($rs)" }
        $w = Get-WifiInfo
        $name = if ($w) { $w.Name } else { $null }
        $prof = if ($w -and $w.Profile) { $w.Profile } else { $null }
        if ((-not $name -or -not $prof) -and (Test-Path $WifiStateFile)) {
            $s = (Get-Content $WifiStateFile -Raw).Trim() -split '\|', 2
            if (-not $name) { $name = $s[0] }
            if (-not $prof -and $s.Count -gt 1) { $prof = $s[1] }
        }
        if (-not $name) { & $LogFn "Ket noi lai mang: khong thay card Wi-Fi nao"; return "không thấy card Wi-Fi" }
        $connected = $w -and $w.State -match '^connected$|đã kết nối'

        if ($Level -ge 2) {
            if (Test-IsAdmin) {
                & $LogFn "Ket noi lai mang: khoi dong lai card '$name'"
                Restart-NetAdapter -Name $name -Confirm:$false -ErrorAction SilentlyContinue
                Start-Sleep 8
                $done += "khởi động lại card Wi-Fi"
            } else {
                & $LogFn "Ket noi lai mang: khong co quyen admin -> bo qua khoi dong lai card (chi netsh)"
            }
        }
        # Danh sach thu: Wi-Fi DA LUU dang bat duoc song, song manh nhat truoc.
        # Dang noi vao 1 mang ma khong co Internet -> thu cac mang khac truoc, mang hien tai de cuoi.
        $cands = @(Get-BestSavedWifi)
        if ($connected -and $w.SSID) { $cands = @($cands | Where-Object { $_.SSID -ne $w.SSID }) + @($cands | Where-Object { $_.SSID -eq $w.SSID }) }
        if (-not $cands.Count -and $prof) {
            # chua quet thay mang nao (vd vua bat song) -> thu mu Wi-Fi dung lan truoc
            $cands = @([pscustomobject]@{ Profile = $prof; SSID = $prof; Signal = $null })
        }
        if (-not $cands.Count) { & $LogFn "Ket noi lai mang: khong thay Wi-Fi da luu nao dang co song"; return (($done + "THỬ kết nối lại Wi-Fi nhưng không thấy Wi-Fi đã lưu nào có sóng") -join ', ') }
        & $LogFn ("Ket noi lai mang: Wi-Fi da luu co song: " + (($cands | ForEach-Object { "$($_.SSID) $(if ($null -ne $_.Signal) { "$($_.Signal)%" } else { '?' })" }) -join ', '))
        if ($connected) {
            & $LogFn "Ket noi lai mang: card '$name' dang noi '$($w.SSID)' ma khong co Internet -> ngat"
            cmd /c "netsh wlan disconnect interface=`"$name`" >nul 2>&1"
            Start-Sleep 3
        }
        $fails = @()
        foreach ($c in ($cands | Select-Object -First 3)) {
            $sig = if ($null -ne $c.Signal) { " (sóng $($c.Signal)%)" } else { "" }
            & $LogFn "Ket noi lai mang: netsh wlan connect '$($c.Profile)'$sig tren card '$name'"
            $o = cmd /c "netsh wlan connect name=`"$($c.Profile)`" ssid=`"$($c.SSID)`" interface=`"$name`" 2>&1"
            $os = ($o | Where-Object { $_ }) -join ' '
            & $LogFn "  netsh: $os"
            if ($os -match 'powered down') { $fails += "sóng Wi-Fi đang tắt"; break }
            if ($os -notmatch 'completed successfully|thành công') { $fails += "'$($c.SSID)': $os"; continue }
            # netsh chi bao "da gui yeu cau" -> doi toi 20s xem co Internet that khong
            $ok = $false
            for ($i = 0; $i -lt 10 -and -not $ok; $i++) { Start-Sleep 2; $ok = Test-NetQuick }
            if ($ok) { $done += "kết nối Wi-Fi '$($c.SSID)'$sig"; break }
            & $LogFn "  '$($c.SSID)' noi duoc nhung 20s khong co Internet -> thu mang khac"
            $fails += "'$($c.SSID)' không có Internet"
        }
        # chi ghi la "da lam" khi co Internet that; that bai thi ghi ro
        if (-not ($done | Where-Object { $_ -like 'kết nối Wi-Fi*' }) -and $fails.Count) { $done += "THỬ kết nối lại Wi-Fi nhưng không được ($($fails -join '; '))" }
    } catch { & $LogFn "Ket noi lai mang loi: $($_.Exception.Message)" }
    return ($done -join ', ')
}
