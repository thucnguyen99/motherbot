# =====================================================================
#  Bot Telegram dieu khien script nong trai DDTank
#
#  Chay nen tren may tinh (tu bat khi dang nhap Windows - cai bang cai_bot.bat),
#  hoi Telegram lien tuc xem co lenh moi khong (long polling, chi ket noi RA ngoai,
#  khong can mo cong mang). Dung chung bot_token + chat_id trong telegram.json.
#
#  An toan:
#   - CHI nhan lenh tu dung chat_id trong telegram.json, tin tu nguoi khac bi bo qua
#   - CHI chay cac lenh co san ben duoi, khong co lenh chay cau lenh tuy y
#   - Ten tai khoan / gio / chu ky duoc kiem tra hop le truoc khi dung
#   - Lenh cu hon 10 phut (vd gui luc may tat) bi bo qua, khong chay bat ngo
#
#  Chay tay de thu 1 lenh (tra loi gui ve Telegram that):
#    powershell -ExecutionPolicy Bypass -File telegram_bot.ps1 -Thu "/trangthai"
# =====================================================================
param(
    [string]$Thu   # xu ly 1 lenh nhu the vua nhan tu Telegram roi thoat (de test)
)

# --------------------------- CAU HINH --------------------------------
$MuMuDir    = "D:\Program Files\Netease\MuMuPlayer\nx_main"   # giong ddtank_farm.ps1
$DeviceName = "auto"
$Package    = "com.wan.ddten"
$TaskName   = "DDTank Farm"      # ten lich chay (lap_lich.ps1)
$MaxAgeSec  = 600                # lenh cu hon 10 phut thi bo qua
$ShowKeyboard = $false           # ban phim nut bam duoi o chat ($false = tat va go ban phim dang hien)
$AutoReconnect = $true           # mat mang -> tu ket noi lai Wi-Fi da luu (ket_noi_mang.ps1)
$NetRepairAfterSec = 60          # mat 60s: netsh ket noi lai; 120s: them khoi dong lai card (can admin); sau do 10 phut/lan
# ---------------------------------------------------------------------

$ErrorActionPreference = "Stop"
$Root    = $PSScriptRoot
$LogDir  = Join-Path $Root "logs"
. (Join-Path $Root "ket_noi_mang.ps1")   # Get-WifiInfo, Save-WifiProfile, Repair-Network
. (Join-Path $Root "hat_giong.ps1")      # $SeedTypes, ConvertTo-SeedKey (lenh /chay <tk> <hat>)
$Farm    = Join-Path $Root "ddtank_farm.ps1"
$Lap     = Join-Path $Root "lap_lich.ps1"
$Manager = Join-Path $MuMuDir "MuMuManager.exe"
$Adb     = Join-Path $MuMuDir "adb.exe"
$BotLog  = Join-Path $LogDir "bot.log"
$OffsetFile = Join-Path $LogDir "bot_offset.txt"
New-Item -ItemType Directory -Force $LogDir | Out-Null

function BLog($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "dd/MM HH:mm:ss"), $msg
    Write-Host $line
    Add-Content -Path $BotLog -Value $line -Encoding UTF8
}

# ------------------------------ TELEGRAM -----------------------------
$cfg = Get-Content (Join-Path $Root "telegram.json") -Raw | ConvertFrom-Json
$Token = [string]$cfg.bot_token; $ChatId = [string]$cfg.chat_id
if (-not $Token -or -not $ChatId -or $Token -match "DIEN_") { BLog "telegram.json chua dien bot_token/chat_id"; exit 1 }

Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Http = New-Object System.Net.Http.HttpClient
$Http.Timeout = [TimeSpan]::FromSeconds(90)

# Thong bao loi goc (bo cac lop boc "One or more errors occurred")
function Err-Msg($e) {
    if ($e -is [System.Management.Automation.ErrorRecord]) { $e = $e.Exception }
    while ($e.InnerException) { $e = $e.InnerException }
    if ($e -is [System.Threading.Tasks.TaskCanceledException]) { return "Het thoi gian cho (mang khong phan hoi)" }
    return $e.Message
}

function Tg($method, [hashtable]$params) {
    $pairs = New-Object 'System.Collections.Generic.List[System.Collections.Generic.KeyValuePair[string,string]]'
    foreach ($k in $params.Keys) {
        $pairs.Add((New-Object 'System.Collections.Generic.KeyValuePair[string,string]' -ArgumentList $k, ([string]$params[$k])))
    }
    $content = New-Object System.Net.Http.FormUrlEncodedContent -ArgumentList (, $pairs)
    # GetAwaiter().GetResult(): loi mang bao dung nguyen nhan (thay vi "null-valued expression")
    $resp = $Http.PostAsync("https://api.telegram.org/bot$Token/$method", $content).GetAwaiter().GetResult()
    $json = [Text.Encoding]::UTF8.GetString($resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult())
    $r = $json | ConvertFrom-Json
    if (-not $r.ok) { throw "Telegram $method loi: $($r.description)" }
    return $r
}

function Reply($text, $markup = $null) {
    if ($text.Length -gt 4000) { $text = $text.Substring(0, 4000) + "`n…" }
    $p = @{ chat_id = $ChatId; text = $text }
    if ($markup) { $p.reply_markup = $markup }
    [void](Tg "sendMessage" $p)
    $short = ($text -replace "`r?`n", " | "); if ($short.Length -gt 300) { $short = $short.Substring(0, 300) + "…" }
    BLog "  -> $short"
}

function Reply-Photo($path, $caption) {
    $form = New-Object System.Net.Http.MultipartFormDataContent
    $form.Add((New-Object System.Net.Http.StringContent($ChatId)), "chat_id")
    $form.Add((New-Object System.Net.Http.StringContent($caption)), "caption")
    $file = New-Object System.Net.Http.ByteArrayContent -ArgumentList (, [IO.File]::ReadAllBytes($path))
    $file.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
    $form.Add($file, "photo", (Split-Path $path -Leaf))
    $resp = $Http.PostAsync("https://api.telegram.org/bot$Token/sendPhoto", $form).GetAwaiter().GetResult()
    if (-not $resp.IsSuccessStatusCode) { throw "Gui anh loi: $($resp.Content.ReadAsStringAsync().GetAwaiter().GetResult())" }
    BLog "  -> [anh] $caption"
}

# ------------------------------ TIEN ICH -----------------------------
function Get-FarmProcs {
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
      Where-Object { $_.CommandLine -like '*ddtank_farm.ps1*' -and $_.CommandLine -notlike '*-TestTelegram*' })
}

function Get-Device {
    $all = ((& $Manager info -v all) -join "`n") | ConvertFrom-Json
    foreach ($p in $all.PSObject.Properties) { if ($p.Value.name -eq $DeviceName) { return $p.Value } }
    return $null
}

function Latest-RunLog {
    Get-ChildItem (Join-Path $LogDir "run_*.log") -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
}

function Tail($file, $n) { @(Get-Content $file.FullName -Encoding UTF8 -Tail $n) -join "`n" }

# Chay lap_lich.ps1 (process rieng) va lay noi dung in ra
function Run-Lap([string[]]$a) {
    $out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Lap @a 2>&1 | Out-String
    return $out.Trim()
}

$ValidAcc = '^[A-Za-z0-9_]{1,30}$'
$StateDir = Join-Path $Root "state"

# Tat ca lich: lich co dinh "DDTank Farm" + lich tu lap "DDTank Farm - <tai khoan>"
function Get-ScheduleLines {
    $out = @()
    $tasks = @(Get-ScheduledTask -TaskName "$TaskName*" -ErrorAction SilentlyContinue | Sort-Object TaskName)
    foreach ($t in $tasks) {
        $i = $t | Get-ScheduledTaskInfo
        $acc = if ($t.Actions[0].Arguments -match '-Account\s+(\S+)') { $Matches[1] } else { '(chưa có tài khoản)' }
        $next = if ($i.NextRunTime) { $i.NextRunTime.ToString('HH:mm dd/MM/yyyy') } else { 'không còn lần chạy' }
        if ($t.TaskName -eq $TaskName) {
            $kind = "lịch cố định"
            try { $iv = [Xml.XmlConvert]::ToTimeSpan($t.Triggers[0].Repetition.Interval); $kind += ", mỗi {0}:{1:D2}" -f [int][Math]::Floor($iv.TotalHours), $iv.Minutes } catch {}
        } else { $kind = "tự lập lịch" }
        $k = Get-AccountSeed $StateDir $acc
        $seedTxt = if ($k) { ", gieo $($SeedTypes[$k].Icon) $($SeedTypes[$k].Name)" } else { "" }
        $out += "⏰ ${acc}: $next ($kind$seedTxt)"
    }
    if (-not $out.Count) { $out += "⏰ Chưa có lịch tự động nào" }
    $off = @(Get-ChildItem (Join-Path $StateDir "*.off") -ErrorAction SilentlyContinue | ForEach-Object { $_.BaseName })
    if ($off.Count) { $out += "⏸️ Đã tắt tự lập lịch: $($off -join ', ')" }
    $pu = Get-PauseUntil
    if ($pu) { $out += "⏸️ Đang tạm dừng mọi lịch tự động tới $($pu.ToString('HH:mm dd/MM/yyyy')) (bật lại: /tiep)" }
    return $out
}

# ------------------------------ TAM DUNG -----------------------------
$PauseFile = Join-Path $StateDir "_tamdung.txt"
function Get-PauseUntil {
    if (-not (Test-Path $PauseFile)) { return $null }
    try { return [datetime]::ParseExact((Get-Content $PauseFile -Raw).Trim(), 'yyyy-MM-dd HH:mm:ss', $null) } catch { return $null }
}

# Tai khoan da tung chay (co state\<tk>.json), bo tai khoan test zz_*
function Get-Accounts {
    @(Get-ChildItem (Join-Path $StateDir "*.json") -ErrorAction SilentlyContinue |
      Where-Object { $_.BaseName -match $ValidAcc -and $_.BaseName -notlike 'zz_*' } | ForEach-Object { $_.BaseName })
}

# Lich tu lap da qua gio chin (bi doi toi het tam dung) -> keo ve chay som (2 phut nua, moi tai khoan cach nhau 1 phut)
function Resume-OverdueTasks {
    $moved = @(); $k = 0
    foreach ($acc in Get-Accounts) {
        $t = Get-ScheduledTask -TaskName "$TaskName - $acc" -ErrorAction SilentlyContinue
        if (-not $t) { continue }
        try { $st = Get-Content (Join-Path $StateDir "$acc.json") -Raw | ConvertFrom-Json; $ripe = [datetime]::ParseExact($st.ripe, 'yyyy-MM-dd HH:mm:ss', $null) } catch { continue }
        $next = ($t | Get-ScheduledTaskInfo).NextRunTime
        $due = $ripe.AddMinutes(-5)
        if ($due -lt (Get-Date).AddMinutes(2) -and (-not $next -or $next -gt (Get-Date).AddMinutes(3))) {
            $at = (Get-Date).AddMinutes(2 + $k); $k++
            Set-ScheduledTask -TaskName "$TaskName - $acc" -Trigger (New-ScheduledTaskTrigger -Once -At $at) | Out-Null
            $moved += "$acc → $($at.ToString('HH:mm'))"
        }
    }
    return $moved
}

# ------------------------------ MAY TINH -----------------------------
function Get-MachineInfo {
    $L = @()
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $avail = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes
    $total = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $top = Get-Process | Group-Object ProcessName | ForEach-Object {
        [pscustomobject]@{ N = $_.Name; MB = ($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB } } |
        Sort-Object MB -Descending | Select-Object -First 3 | ForEach-Object { "$($_.N) $([math]::Round($_.MB/1024,1)) GB" }
    $ramIcon = if ($avail -lt 2500) { "⚠️" } else { "🧠" }
    $L += "$ramIcon RAM trống: $([math]::Round($avail/1024,1)) / $total GB (nhiều nhất: $($top -join ', '))"
    try { $cpu = [int](Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'").PercentProcessorTime; $L += "⚙️ CPU: $cpu%" } catch {}
    $disks = @()
    foreach ($d in Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null -and ($_.Used + $_.Free) -gt 0 }) {
        $free = [math]::Round($d.Free / 1GB, 1); $all = [math]::Round(($d.Used + $d.Free) / 1GB)
        $disks += "$($d.Name): $free/$all GB$(if ($free -lt 5) { ' ⚠️' })"
    }
    $L += "💾 Ổ trống: $($disks -join ' | ')"
    $up = (Get-Date) - $os.LastBootUpTime
    $L += "⏱️ Máy chạy được: $([int][math]::Floor($up.TotalDays)) ngày $($up.Hours) giờ $($up.Minutes) phút (khởi động lúc $($os.LastBootUpTime.ToString('HH:mm dd/MM')))"
    # Khoi dong lai bat thuong 7 ngay: man hinh xanh (1001), tat dot ngot (41)
    $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41, 1001; StartTime = (Get-Date).AddDays(-7) } -ErrorAction SilentlyContinue |
        Where-Object { $_.Id -eq 41 -or $_.ProviderName -match 'WER-SystemErrorReporting' } | Sort-Object TimeCreated)
    $bsod = @($ev | Where-Object Id -eq 1001); $crash = @($ev | Where-Object Id -eq 41)
    if ($crash.Count) {
        $last = $crash[-1].TimeCreated
        $code = ($bsod | Select-Object -Last 1 | ForEach-Object { if ($_.Message -match 'bugcheck was: (0x[0-9a-fA-F]+)') { $Matches[1] } })
        $L += "💥 Tắt/khởi động lại bất thường 7 ngày: $($crash.Count) lần, gần nhất $($last.ToString('HH:mm dd/MM'))$(if ($code) { " (màn hình xanh $code)" })"
    } else { $L += "✅ Không có lần tắt bất thường / màn hình xanh nào trong 7 ngày" }
    try {
        $w = netsh wlan show interfaces
        $ssid = ($w | Select-String '^\s+SSID\s+:\s+(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
        $sig = ($w | Select-String '^\s+Signal\s+:\s+(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
        $stt = ($w | Select-String '^\s+State\s+:\s+(.+)$' | Select-Object -First 1).Matches.Groups[1].Value
        if ($stt) { $L += "📶 Wi-Fi: $stt$(if ($ssid) { " '$ssid', sóng $sig" })" }
        $drops = @(Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-WLAN-AutoConfig/Operational'; Id = 8003; StartTime = (Get-Date).AddDays(-1) } -ErrorAction SilentlyContinue).Count
        $L += "   Rớt Wi-Fi 24 giờ qua: $drops lần"
    } catch {}
    $vpn = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -like '*VPN*' -and $_.Status -eq 'Up' }
    $L += if ($vpn) { "🔐 VPN đang bật: $(($vpn | ForEach-Object InterfaceDescription) -join ', ')" } else { "🔐 VPN: tắt" }
    try { $d = Get-Device; $L += if ($d -and $d.is_android_started) { "📱 MuMu '$DeviceName': đang bật" } else { "📱 MuMu '$DeviceName': tắt" } } catch {}
    $bp = Get-Process -Id $PID
    $L += "🤖 Bot: PID $PID, chạy từ $($bp.StartTime.ToString('HH:mm dd/MM')), RAM $([math]::Round($bp.WorkingSet64/1MB)) MB"
    $al = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue).AutoAdminLogon
    $L += if ($al -eq '1') { "🔑 Tự đăng nhập Windows: bật" } else { "🔑 Tự đăng nhập Windows: TẮT (máy tự khởi động lại sẽ dừng ở màn hình đăng nhập)" }
    return ($L -join "`n")
}

# ------------------------------ THONG KE -----------------------------
function Get-Stats([int]$days) {
    $f = Join-Path $StateDir "lich_su.jsonl"
    if (-not (Test-Path $f)) { return "Chưa có lịch sử chạy nào (state\lich_su.jsonl)." }
    $from = (Get-Date).Date.AddDays(-($days - 1))
    $rows = @(Get-Content $f -Encoding UTF8 | ForEach-Object { try { $_ | ConvertFrom-Json } catch {} } |
        Where-Object { $_ -and [datetime]::ParseExact($_.t, 'yyyy-MM-dd HH:mm:ss', $null) -ge $from })
    if (-not $rows.Count) { return "Không có lượt chạy nào trong $days ngày qua." }
    $L = @("📊 Thống kê $days ngày ($($from.ToString('dd/MM')) – $(Get-Date -Format 'dd/MM')):")
    foreach ($g in ($rows | Group-Object acc | Sort-Object Name)) {
        $r = @($g.Group)
        $c = { param($k) @($r | Where-Object kq -eq $k).Count }
        $sown = @($r | Where-Object { $_.gieo }).Count
        $plots = ($r | Measure-Object thu -Sum).Sum
        $harvRuns = @($r | Where-Object { $_.thu -gt 0 }).Count
        $dur = @($r | Where-Object { $_.kq -in 'sown', 'growing' } | ForEach-Object {
            ([datetime]::ParseExact($_.end, 'yyyy-MM-dd HH:mm:ss', $null) - [datetime]::ParseExact($_.t, 'yyyy-MM-dd HH:mm:ss', $null)).TotalMinutes })
        $avg = if ($dur.Count) { [math]::Round(($dur | Measure-Object -Average).Average, 1) } else { '-' }
        $waits = @($r | Where-Object { $_.cho -gt 0 -and $_.thu -gt 0 })
        $L += ""
        $L += "👤 $($g.Name): $($r.Count) lượt chạy (TB $avg phút/lượt thành công)"
        $L += "   🌾 Thu hoạch: $harvRuns lượt, $plots ô | 🥔 Gieo: $sown lượt"
        if ($waits.Count) { $L += "   ⏳ Chờ cây chín rồi thu: $($waits.Count) lượt (TB $([math]::Round(($waits | Measure-Object cho -Average).Average,1)) phút)" }
        $L += "   🌱 Cây chưa chín: $(& $c 'growing') | 👀 Xem ruộng: $(& $c 'view') | ⏸️ Tạm dừng: $(& $c 'paused')"
        $L += "   ❌ Lỗi: $(& $c 'error') | 📵 Mất mạng: $(& $c 'offline') | 🛠️ Bảo trì: $(& $c 'maintenance')"
        $lastErr = $r | Where-Object kq -eq 'error' | Select-Object -Last 1
        if ($lastErr) { $L += "   Lỗi gần nhất ($(([datetime]::ParseExact($lastErr.t,'yyyy-MM-dd HH:mm:ss',$null)).ToString('HH:mm dd/MM'))): $($lastErr.loi)" }
    }
    return ($L -join "`n")
}

# ------------------------------ NUT BAM ------------------------------
# Ban phim Telegram (hien duoi o chat): lenh hay dung + /chay, /xemruong cho tung tai khoan
function Get-Keyboard {
    if (-not $ShowKeyboard) { return '{"remove_keyboard":true}' }   # tat: go ban phim cu (neu dang hien)
    $rows = @(
        @('/trangthai', '/lich', '/anh'),
        @('/maytinh', '/thongke', '/log')
    )
    foreach ($acc in (Get-Accounts | Select-Object -First 3)) { $rows += , @("/chay $acc", "/xemruong $acc") }
    $rows += , @('/tamdung 2', '/tiep', '/help')
    $kb = @{ keyboard = @($rows | ForEach-Object { , @($_ | ForEach-Object { @{ text = $_ } }) }); resize_keyboard = $true; is_persistent = $true }
    return ($kb | ConvertTo-Json -Depth 5 -Compress)
}

$Help = @"
🤖 Lệnh bot DDTank:
/chay <tài khoản> [loại hạt] – chạy ngay thu hoạch + trồng (vd: /chay akaka, /chay akaka nho). Ghi hạt = lưu cố định cho tài khoản, các lượt tự động sau cũng gieo loại đó (về khoai: /chay akaka khoai). Xong tự lập lịch lần sau lúc cây chín
   Loại hạt: $(Get-SeedListText)
/xemruong <tài khoản> – vào game chụp ruộng, không thu hoạch / gieo, không đổi lịch (vd: /xemruong akaka)
/trangthai – script có đang chạy không, thiết bị, lịch, log gần nhất
/anh – chụp màn hình thiết bị auto
/log – log lần chạy gần nhất
/lich – xem tất cả lịch tự động
/thongke [số ngày] – thống kê thu hoạch / gieo / lỗi (mặc định 7 ngày, vd: /thongke 30)
/maytinh – RAM, ổ đĩa, CPU, Wi-Fi, VPN, lần khởi động lại / màn hình xanh gần nhất
/tamdung <số giờ> – tạm dừng mọi lịch tự động (vd: /tamdung 2, /tamdung 0.5). /chay vẫn chạy được
/tiep – bật lại lịch tự động ngay
/huylich <tài khoản> – dừng tự lập lịch của tài khoản (bật lại: /chay <tài khoản>)
/datlich <giờ> <chu kỳ> <tài khoản> – cài lịch cố định (vd: /datlich 23:00 8:05 akaka)
/xoalich – xoá lịch cố định
/dung – dừng lượt đang chạy, tắt app và thiết bị
/help – danh sách lệnh
"@

# ------------------------------ XU LY LENH ---------------------------
function Handle([string]$text) {
    $parts = @($text.Trim() -split '\s+')
    $cmd = ($parts[0] -replace '@.*$', '').ToLower()
    $arg = @($parts | Select-Object -Skip 1)
    BLog "Lenh: $text"

    switch ($cmd) {
        { $_ -in '/help', '/start' } { Reply $Help (Get-Keyboard) }

        '/xemruong' {
            if ($arg.Count -ne 1 -or $arg[0] -notmatch $ValidAcc) { Reply "Cách dùng: /xemruong <tài khoản>   vd: /xemruong akaka"; return }
            $run = @(Get-FarmProcs)
            # tai khoan nay dang chay -> tu choi; tai khoan khac dang chay -> luot moi tu xep hang cho (toi da 15 phut, ddtank_farm.ps1)
            $mine = @($run | Where-Object { $_.CommandLine -match ('-Account\s+"?' + [regex]::Escape($arg[0]) + '"?(\s|$)') })
            if ($mine.Count) { Reply "⏳ Tài khoản $($arg[0]) đang có lượt chạy rồi (PID $($mine[0].ProcessId)), chờ xong rồi gửi lại. Xem /trangthai"; return }
            $queueTxt = if ($run.Count) { "`n⏳ Đang có lượt khác chạy ($((@($run | ForEach-Object { if ($_.CommandLine -match '-Account\s+"?([^"\s]+)') { $Matches[1] } })) -join ', ')) → lượt này xếp hàng, chạy ngay khi lượt kia xong (chờ tối đa 15 phút)." } else { "" }
            $p = Start-Process powershell.exe -WindowStyle Hidden -WorkingDirectory $Root -PassThru -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$Farm`"", '-Account', $arg[0], '-ViewOnly', '-Manual')
            BLog "Xem ruong PID $($p.Id) tai khoan $($arg[0])"
            Reply "👀 Đang vào game xem ruộng của $($arg[0]) (PID $($p.Id)), khoảng 3–4 phút sẽ có ảnh. Không thu hoạch, không đổi lịch.$queueTxt"
        }

        '/tamdung' {
            $h = 0.0
            $ok = $arg.Count -eq 1 -and $arg[0] -match '^\d{1,3}([.,]\d{1,2})?$' -and [double]::TryParse(($arg[0] -replace ',', '.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$h) -and $h -gt 0 -and $h -le 168
            if (-not $ok) { Reply "Cách dùng: /tamdung <số giờ> (0.1 – 168)   vd: /tamdung 2  hoặc  /tamdung 0.5"; return }
            $until = (Get-Date).AddMinutes([math]::Round($h * 60))
            New-Item -ItemType Directory -Force $StateDir | Out-Null
            Set-Content -Path $PauseFile -Value $until.ToString('yyyy-MM-dd HH:mm:ss')
            BLog "Tam dung toi $until"
            $run = @(Get-FarmProcs)
            $note = if ($run.Count) { "`n⚠️ Lượt đang chạy (PID $($run[0].ProcessId)) vẫn chạy tiếp; muốn dừng ngay: /dung" } else { "" }
            Reply "⏸️ Đã tạm dừng mọi lịch tự động tới $($until.ToString('HH:mm dd/MM')).`nLượt nào tới hạn trong lúc này sẽ dời tới $($until.AddMinutes(1).ToString('HH:mm')). /chay và /xemruong vẫn dùng được.`nBật lại sớm: /tiep$note"
        }

        '/tiep' {
            $pu = Get-PauseUntil
            if (Test-Path $PauseFile) { Remove-Item $PauseFile -Force }
            $moved = @(Resume-OverdueTasks)
            BLog "Tiep tuc (truoc do tam dung toi $pu), keo lich: $($moved -join '; ')"
            $msg = if ($pu -and $pu -gt (Get-Date)) { "▶️ Đã bật lại lịch tự động (trước đó tạm dừng tới $($pu.ToString('HH:mm dd/MM')))." } else { "▶️ Lịch tự động đang chạy bình thường (không có tạm dừng)." }
            if ($moved.Count) { $msg += "`nLượt bị dời được chạy sớm: $($moved -join ', ')" }
            Reply ($msg + "`n" + ((Get-ScheduleLines) -join "`n"))
        }

        '/thongke' {
            $d = 7
            if ($arg.Count -ge 1) {
                if ($arg[0] -notmatch '^\d{1,2}$' -or [int]$arg[0] -lt 1 -or [int]$arg[0] -gt 60) { Reply "Cách dùng: /thongke [số ngày 1–60]   vd: /thongke 30"; return }
                $d = [int]$arg[0]
            }
            Reply (Get-Stats $d)
        }

        '/maytinh' { Reply (Get-MachineInfo) }

        '/chay' {
            if ($arg.Count -lt 1 -or $arg[0] -notmatch $ValidAcc) { Reply "Cách dùng: /chay <tài khoản> [loại hạt]   vd: /chay akaka  hoặc  /chay akaka nho`nLoại hạt: $(Get-SeedListText)"; return }
            # loai hat co the nhieu chu ("thanh long", "cà tím") -> ghep lai roi chuan hoa ve key trong hat_giong.ps1
            $seedKey = $null
            if ($arg.Count -gt 1) {
                $seedArg = ($arg | Select-Object -Skip 1) -join ' '
                $seedKey = ConvertTo-SeedKey $seedArg
                if (-not $seedKey) { Reply "❌ Không có loại hạt '$seedArg'.`nLoại hạt: $(Get-SeedListText)"; return }
            }
            $run = @(Get-FarmProcs)
            # tai khoan nay dang chay -> tu choi; tai khoan khac dang chay -> luot moi tu xep hang cho (toi da 15 phut, ddtank_farm.ps1)
            $mine = @($run | Where-Object { $_.CommandLine -match ('-Account\s+"?' + [regex]::Escape($arg[0]) + '"?(\s|$)') })
            if ($mine.Count) { Reply "⏳ Tài khoản $($arg[0]) đang có lượt chạy rồi (PID $($mine[0].ProcessId)), chờ xong rồi gửi lại. Xem /trangthai"; return }
            $queueTxt = if ($run.Count) { "`n⏳ Đang có lượt khác chạy ($((@($run | ForEach-Object { if ($_.CommandLine -match '-Account\s+"?([^"\s]+)') { $Matches[1] } })) -join ', ')) → lượt này xếp hàng, chạy ngay khi lượt kia xong (chờ tối đa 15 phút)." } else { "" }
            # /chay = bat lai tu lap lich (neu da /huylich) + xoa dem loi
            $extra = ""
            $offFile = Join-Path $StateDir "$($arg[0]).off"
            if (Test-Path $offFile) { Remove-Item $offFile -Force; $extra = " Đã bật lại tự lập lịch." }
            $stFile = Join-Path $StateDir "$($arg[0]).json"
            if (Test-Path $stFile) {
                try { $st = Get-Content $stFile -Raw | ConvertFrom-Json; $st.retries = 0; $st | ConvertTo-Json | Set-Content $stFile -Encoding UTF8 } catch {}
            }
            $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$Farm`"", '-Account', $arg[0], '-Manual')
            if ($seedKey) { $argv += @('-Seed', $seedKey) }
            $p = Start-Process powershell.exe -WindowStyle Hidden -WorkingDirectory $Root -PassThru -ArgumentList $argv
            $seedTxt = if ($seedKey -and $seedKey -ne 'khoai') { " – gieo $($SeedTypes[$seedKey].Icon) $($SeedTypes[$seedKey].Name), các lượt tự động sau cũng gieo loại này (về khoai: /chay $($arg[0]) khoai)" }
                       elseif ($seedKey) { " – gieo 🥔 khoai tây (bỏ hạt cố định nếu có)" }
                       else { $k = Get-AccountSeed $StateDir $arg[0]; if ($k) { " – gieo $($SeedTypes[$k].Icon) $($SeedTypes[$k].Name) (hạt cố định của tài khoản)" } else { "" } }
            BLog "Chay farm PID $($p.Id) tai khoan $($arg[0]) hat $seedKey"
            Reply "▶️ Bắt đầu chạy cho tài khoản $($arg[0])$seedTxt (PID $($p.Id)). Xong sẽ có ảnh gửi về.$extra Xem tiến độ: /trangthai$queueTxt"
        }

        '/trangthai' {
            $lines = @()
            $run = @(Get-FarmProcs)
            if ($run.Count) {
                foreach ($r in $run) {
                    $acc = if ($r.CommandLine -match '-Account\s+(\S+)') { $Matches[1] } else { '-' }
                    $lines += "▶️ Đang chạy: tài khoản $acc, PID $($r.ProcessId), từ $($r.CreationDate.ToString('HH:mm:ss'))"
                }
            } else { $lines += "⏸️ Script không chạy" }
            try {
                $d = Get-Device
                $lines += if (-not $d) { "📱 Không thấy thiết bị '$DeviceName'" } elseif ($d.is_android_started) { "📱 Thiết bị ${DeviceName}: đang bật" } else { "📱 Thiết bị ${DeviceName}: đang tắt" }
            } catch { $lines += "📱 Không đọc được trạng thái MuMu" }
            try { $lines += Get-ScheduleLines } catch { $lines += "⏰ Không đọc được lịch" }
            $log = Latest-RunLog
            if ($log) { $lines += ""; $lines += "📄 $($log.Name) (6 dòng cuối):"; $lines += (Tail $log 6) }
            Reply ($lines -join "`n")
        }

        '/anh' {
            $d = Get-Device
            if (-not $d -or -not $d.is_android_started -or -not $d.adb_port) { Reply "📱 Thiết bị $DeviceName đang tắt, không chụp được"; return }
            $serial = "$($d.adb_host_ip):$($d.adb_port)"
            & $Adb connect $serial | Out-Null
            $png = Join-Path $env:TEMP "ddtank_bot_screen.png"
            cmd /c "`"$Adb`" -s $serial exec-out screencap -p > `"$png`""
            if (-not (Test-Path $png) -or (Get-Item $png).Length -lt 1000) { Reply "❌ Chụp màn hình lỗi"; return }
            Reply-Photo $png "📸 Màn hình $DeviceName lúc $(Get-Date -Format 'HH:mm:ss dd/MM')"
        }

        '/log' {
            $log = Latest-RunLog
            if (-not $log) { Reply "Chưa có log nào"; return }
            Reply ("📄 $($log.Name) (40 dòng cuối):`n" + (Tail $log 40))
        }

        '/lich' { Reply ("🗓️ Lịch tự động:`n" + ((Get-ScheduleLines) -join "`n")) }

        '/huylich' {
            if ($arg.Count -ne 1 -or $arg[0] -notmatch $ValidAcc) { Reply "Cách dùng: /huylich <tài khoản>   vd: /huylich akaka"; return }
            $acc = $arg[0]
            New-Item -ItemType Directory -Force $StateDir | Out-Null
            Set-Content -Path (Join-Path $StateDir "$acc.off") -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
            $t = Get-ScheduledTask -TaskName "$TaskName - $acc" -ErrorAction SilentlyContinue
            if ($t) { Unregister-ScheduledTask -TaskName "$TaskName - $acc" -Confirm:$false }
            $msg = if ($t) { "🛑 Đã huỷ lịch tự lập của $acc và tắt tự lập lịch." } else { "🛑 $acc chưa có lịch tự lập; đã tắt tự lập lịch." }
            Reply "$msg Bật lại: /chay $acc"
        }

        '/datlich' {
            # /datlich 23:00 8:05 tk   hoac   /datlich 2026-11-18 07:30 8:05 tk
            if ($arg.Count -eq 4) { $start = "$($arg[0]) $($arg[1])"; $cyc = $arg[2]; $acc = $arg[3] }
            elseif ($arg.Count -eq 3) { $start = $arg[0]; $cyc = $arg[1]; $acc = $arg[2] }
            else { Reply "Cách dùng: /datlich <giờ> <chu kỳ> <tài khoản>`nvd: /datlich 23:00 8:05 tomcat12345"; return }
            $okStart = $start -match '^(\d{4}-\d{2}-\d{2} )?\d{1,2}:\d{2}$'
            $okCyc = $cyc -match '^\d{1,2}(:\d{1,2}|\.\d+)?$'
            if (-not ($okStart -and $okCyc -and $acc -match $ValidAcc)) { Reply "❌ Tham số không hợp lệ. vd: /datlich 23:00 8:05 tomcat12345"; return }
            Reply ("🗓️ " + (Run-Lap @($start, $cyc, $acc)))
        }

        '/xoalich' { Reply ("🗑️ " + (Run-Lap @('-Xoa'))) }

        '/dung' {
            $run = @(Get-FarmProcs)
            $msg = @()
            if ($run.Count) {
                foreach ($r in $run) {
                    # dung ca cac tien trinh con (cmd/adb) cua script
                    Get-CimInstance Win32_Process -Filter "ParentProcessId=$($r.ProcessId)" | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                    Stop-Process -Id $r.ProcessId -Force -ErrorAction SilentlyContinue
                    BLog "Da dung farm PID $($r.ProcessId)"
                }
                $msg += "⏹️ Đã dừng script (PID $(($run | ForEach-Object { $_.ProcessId }) -join ', '))"
            } else { $msg += "Script không chạy" }
            try {
                $d = Get-Device
                if ($d -and $d.is_android_started) {
                    & $Manager control -v $d.index app close -pkg $Package | Out-Null
                    Start-Sleep 2
                    & $Manager control -v $d.index shutdown | Out-Null
                    $msg += "📴 Đã tắt app DDTank và thiết bị $DeviceName"
                } else { $msg += "📴 Thiết bị $DeviceName đã tắt sẵn" }
            } catch { $msg += "❌ Tắt thiết bị lỗi: $($_.Exception.Message)" }
            Reply ($msg -join "`n")
        }

        default { Reply "Không hiểu lệnh '$($parts[0])'. Gõ /help để xem danh sách lệnh." }
    }
}

function Safe-Handle([string]$text) {
    try { Handle $text }
    catch {
        BLog "Loi xu ly '$text': $($_.Exception.Message)"
        try { Reply "❌ Lỗi khi xử lý '$text': $($_.Exception.Message)" } catch {}
    }
}

# ------------------------------ CHAY ---------------------------------
if ($Thu) { Safe-Handle $Thu; exit 0 }

# Chi 1 bot chay mot luc
$mtx = New-Object System.Threading.Mutex($false, "Local\DDTankTelegramBot")
$got = $false
try { $got = $mtx.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $got = $true }
if (-not $got) { BLog "Bot da chay o tien trinh khac -> thoat"; exit 0 }

# bot.log lon hon 1 MB -> chi giu 3000 dong cuoi
function Trim-BotLog {
    try {
        if ((Test-Path $BotLog) -and (Get-Item $BotLog).Length -gt 1MB) {
            $keep = Get-Content $BotLog -Encoding UTF8 -Tail 3000
            Set-Content -Path $BotLog -Value $keep -Encoding UTF8
            BLog "Da rut gon bot.log (giu 3000 dong cuoi)"
        }
    } catch {}
}
Trim-BotLog

BLog "===== BOT BAT DAU (PID $PID) ====="
# Menu lenh hien khi go "/" trong Telegram
try {
    $cmds = @(
        @{ command = "chay";      description = "Chạy ngay: /chay <tài khoản> [loại hạt]" },
        @{ command = "xemruong";  description = "Chụp ruộng, không thu hoạch: /xemruong <tài khoản>" },
        @{ command = "trangthai"; description = "Trạng thái script, thiết bị, log" },
        @{ command = "anh";       description = "Chụp màn hình thiết bị auto" },
        @{ command = "log";       description = "Log lần chạy gần nhất" },
        @{ command = "lich";      description = "Xem tất cả lịch tự động" },
        @{ command = "thongke";   description = "Thống kê: /thongke [số ngày]" },
        @{ command = "maytinh";   description = "RAM, ổ đĩa, Wi-Fi, khởi động lại gần nhất" },
        @{ command = "tamdung";   description = "Tạm dừng lịch tự động: /tamdung <số giờ>" },
        @{ command = "tiep";      description = "Bật lại lịch tự động" },
        @{ command = "huylich";   description = "Dừng tự lập lịch: /huylich <tài khoản>" },
        @{ command = "datlich";   description = "Cài lịch cố định: /datlich 23:00 8:05 <tài khoản>" },
        @{ command = "xoalich";   description = "Xoá lịch cố định" },
        @{ command = "dung";      description = "Dừng lượt đang chạy, tắt thiết bị" },
        @{ command = "help";      description = "Danh sách lệnh" }
    )
    [void](Tg "setMyCommands" @{ commands = (ConvertTo-Json $cmds -Compress) })
} catch { BLog "setMyCommands loi: $($_.Exception.Message)" }
try { Reply "🤖 Bot DDTank đã sẵn sàng. Gõ /help để xem lệnh$(if ($ShowKeyboard) { ' hoặc bấm nút bên dưới' })." (Get-Keyboard) } catch { BLog "Gui tin khoi dong loi: $($_.Exception.Message)" }
$lastTrim = Get-Date

$offset = 0
if (Test-Path $OffsetFile) { [long]::TryParse((Get-Content $OffsetFile -Raw).Trim(), [ref]$offset) | Out-Null }

# Mat ket noi: chi ghi log luc bat dau mat + 30 phut/lan (khong ghi moi 10 giay), co lai thi bao len Telegram
$offSince = $null; $offLogAt = $null
$repairLevel = 0; $repairAt = $null; $repairDone = @()
Save-WifiProfile; $wifiSavedAt = Get-Date
while ($true) {
    $reqStart = Get-Date   # luc bat dau hoi: neu loi thi tinh mat mang tu day (chinh xac hon luc bao loi)
    # Het /tamdung -> xoa file + bao (lich bi doi da hen dung luc het tam dung)
    $pu = Get-PauseUntil
    if ($pu -and $pu -le (Get-Date)) {
        Remove-Item $PauseFile -Force -ErrorAction SilentlyContinue
        BLog "Het tam dung ($pu)"
        try { Reply "▶️ Hết tạm dừng ($($pu.ToString('HH:mm dd/MM'))), lịch tự động chạy lại bình thường.`n$((Get-ScheduleLines) -join "`n")" } catch {}
    }
    if (((Get-Date) - $lastTrim).TotalHours -ge 24) { Trim-BotLog; $lastTrim = Get-Date }
    try {
        $r = Tg "getUpdates" @{ offset = $offset; timeout = 50; allowed_updates = '["message"]' }
        if ($offSince) {
            $mins = [int]((Get-Date) - $offSince).TotalMinutes
            BLog "Co ket noi lai (mat tu $($offSince.ToString('HH:mm dd/MM')), $mins phut)"
            if ($mins -ge 2) {
                $parts = @($repairDone | ForEach-Object { $_ -split ', ' } | Where-Object { $_ } | Select-Object -Unique)
                $ok = @($parts | Where-Object { $_ -notlike 'THỬ*' }); $bad = @($parts | Where-Object { $_ -like 'THỬ*' })
                $fix = if ($ok.Count) { " Bot đã tự $($ok -join ', ')." }
                       elseif ($bad.Count) { " Bot đã $(($bad | ForEach-Object { $_.Replace('THỬ', 'thử') }) -join '; '); mạng có lại do Windows hoặc bạn tự kết nối." }
                       else { "" }
                try { Reply "📶 Bot có mạng lại. Mất kết nối từ $($offSince.ToString('HH:mm dd/MM')) đến $(Get-Date -Format 'HH:mm dd/MM') ($mins phút).$fix Lệnh gửi trong lúc đó quá 10 phút sẽ bị bỏ qua, gửi lại nếu cần." } catch {}
            }
            $offSince = $null; $repairLevel = 0; $repairAt = $null; $repairDone = @()
        }
        # 6 tieng/lan nho lai ten Wi-Fi dang dung (de luc mat mang biet ket noi lai vao dau)
        if (((Get-Date) - $wifiSavedAt).TotalHours -ge 6) { Save-WifiProfile; $wifiSavedAt = Get-Date }
        foreach ($u in $r.result) {
            $offset = [long]$u.update_id + 1
            Set-Content -Path $OffsetFile -Value $offset
            $m = $u.message
            if (-not $m -or -not $m.text) { continue }
            if ([string]$m.chat.id -ne $ChatId) { BLog "Bo qua tin tu chat la $($m.chat.id)"; continue }
            if (-not $m.text.StartsWith("/")) { continue }
            $age = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - [long]$m.date
            if ($age -gt $MaxAgeSec) {
                $sent = [DateTimeOffset]::FromUnixTimeSeconds([long]$m.date).ToLocalTime().ToString('HH:mm dd/MM')
                BLog "Bo qua lenh cu ($age s): $($m.text)"
                Reply "⏭️ Bỏ qua lệnh cũ '$($m.text)' (gửi lúc $sent, quá 10 phút). Gửi lại nếu vẫn cần."
                continue
            }
            Safe-Handle $m.text
        }
    } catch {
        $msg = Err-Msg $_
        if (-not $offSince) {
            $offSince = $reqStart; $offLogAt = Get-Date
            BLog "Mat ket noi Telegram: $msg (thu lai moi 10 giay)"
        } elseif (((Get-Date) - $offLogAt).TotalMinutes -ge 30) {
            $offLogAt = Get-Date
            BLog "Van mat ket noi tu $($offSince.ToString('HH:mm dd/MM')): $msg"
        }
        # Tu ket noi lai Wi-Fi: 60s -> netsh; 120s -> them khoi dong lai card (neu admin); sau do 10 phut/lan.
        # Chi khi that su khong co Internet (khong phai rieng Telegram loi).
        if ($AutoReconnect) {
            $offSec = ((Get-Date) - $offSince).TotalSeconds
            $due = if ($repairLevel -lt 2) { $offSec -ge $NetRepairAfterSec * ($repairLevel + 1) } else { ((Get-Date) - $repairAt).TotalMinutes -ge 10 }
            if ($due -and -not (Test-NetQuick)) {
                $lv = [Math]::Min(2, $repairLevel + 1)
                $d = Repair-Network -Level $lv -LogFn { param($m) BLog $m }
                if ($d) { $repairDone += $d }
                $repairLevel = $lv; $repairAt = Get-Date
            }
        }
        Start-Sleep 10
    }
}
