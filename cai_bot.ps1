# =====================================================================
#  Cai bot Telegram (telegram_bot.ps1) tu chay nen moi khi dang nhap Windows
#
#  Cach dung:
#    cai_bot.bat          -> cai + bat bot ngay
#    cai_bot.bat -Xem     -> xem bot co dang chay khong
#    cai_bot.bat -Xoa     -> tat bot + go cai dat
#  Chay lai lenh cai = ghi de + khoi dong lai bot (vd sau khi sua telegram_bot.ps1)
# =====================================================================
param(
    [switch]$Xoa,
    [switch]$Xem,
    [string]$TenTask = "DDTank Bot"
)
$ErrorActionPreference = "Stop"
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$bot = Join-Path $dir "telegram_bot.ps1"

function Get-BotProcs {
    @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -like '*telegram_bot.ps1*' -and $_.CommandLine -notlike '*-Thu*' })
}
function Stop-Bot {
    Stop-ScheduledTask -TaskName $TenTask -ErrorAction SilentlyContinue
    @(Get-BotProcs) | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}
function Show-Bot {
    $t = Get-ScheduledTask -TaskName $TenTask -ErrorAction SilentlyContinue
    if ($t) { Write-Host "Cai dat     : co ($TenTask, tu chay khi dang nhap Windows)" } else { Write-Host "Cai dat     : chua cai" }
    $p = @(Get-BotProcs)
    if ($p.Count) { Write-Host "Bot         : DANG CHAY (PID $(($p | ForEach-Object { $_.ProcessId }) -join ', '))" } else { Write-Host "Bot         : khong chay" }
    $log = Join-Path $dir "logs\bot.log"
    if (Test-Path $log) { Write-Host "Log bot     : $log"; Get-Content $log -Encoding UTF8 -Tail 5 | ForEach-Object { Write-Host "   $_" } }
}

if ($Xem) { Show-Bot; exit 0 }
if ($Xoa) {
    Stop-Bot
    Unregister-ScheduledTask -TaskName $TenTask -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Da tat bot va go cai dat '$TenTask'"; exit 0
}

if (-not (Test-Path $bot)) { throw "Khong thay $bot" }
if (-not (Test-Path (Join-Path $dir "telegram.json"))) { throw "Chua co telegram.json (xem README muc 5)" }

$user = "$env:USERDOMAIN\$env:USERNAME"
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$bot`"" -WorkingDirectory $dir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
# Chay mai (khong gioi han thoi gian), tu khoi dong lai neu bi loi
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited

Stop-Bot
Register-ScheduledTask -TaskName $TenTask -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Description "Bot Telegram dieu khien script nong trai DDTank" -Force | Out-Null
Start-ScheduledTask -TaskName $TenTask
Start-Sleep 5
Write-Host "Da cai bot '$TenTask' (tu chay moi khi dang nhap Windows) va bat bot ngay."
Show-Bot
