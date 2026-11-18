# =====================================================================
#  Cai lich tu dong chay ddtank_farm.ps1 bang Windows Task Scheduler
#
#  Cach dung:  lap_lich.bat <gio bat dau> <chu ky> <tai khoan 7Road>
#    lap_lich.bat 23:00 8:05 tomcat12345            -> 23:00, moi 8 tieng 5 phut, tai khoan tomcat12345
#    lap_lich.bat 15:00 8 tomcat12345               -> 15:00, moi 8 tieng
#    lap_lich.bat "2026-11-18 07:30" 6 tomcat12345  -> ngay/gio cu the, moi 6 tieng
#    lap_lich.bat -Xem                              -> xem lich hien tai
#    lap_lich.bat -Xoa                              -> xoa lich
#  Chay lai lenh = ghi de lich cu.
# =====================================================================
param(
    [Parameter(Position = 0)][string]$GioBatDau,
    [Parameter(Position = 1)][string]$LapLaiSauGio,   # "8" = 8 tieng, "8:05" = 8 tieng 5 phut
    [Parameter(Position = 2)][string]$TaiKhoan,       # tai khoan 7Road da luu trong app
    [string]$TenTask = "DDTank Farm",
    [switch]$Xoa,
    [switch]$Xem,
    [string]$ScriptDir
)
$ErrorActionPreference = "Stop"
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

function Show-Task {
    $t = Get-ScheduledTask -TaskName $TenTask -ErrorAction SilentlyContinue
    if (-not $t) { Write-Host "Chua co lich '$TenTask'"; return }
    $i = $t | Get-ScheduledTaskInfo
    $rep = $t.Triggers[0].Repetition
    $dur = if ($rep.Duration) { $rep.Duration } else { "vo thoi han" }
    Write-Host "Lich         : $TenTask ($($t.State))"
    Write-Host "Bat dau      : $($t.Triggers[0].StartBoundary)"
    Write-Host "Lap lai      : $($rep.Interval) (thoi han: $dur)"
    Write-Host "Lan chay toi : $($i.NextRunTime)"
    Write-Host "Lan chay truoc: $($i.LastRunTime) (ket qua $($i.LastTaskResult))"
    Write-Host "Lenh         : $($t.Actions[0].Execute) $($t.Actions[0].Arguments)"
}

if ($Xem) { Show-Task; exit 0 }
if ($Xoa) {
    Unregister-ScheduledTask -TaskName $TenTask -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Da xoa lich '$TenTask'"; exit 0
}
# Chu ky: "8" / "8.5" (gio) hoac "8:05" (gio:phut)
$intervalMin = 0
if ($LapLaiSauGio -match '^\s*(\d+):(\d{1,2})\s*$') {
    $intervalMin = [int]$Matches[1] * 60 + [int]$Matches[2]
} elseif ($LapLaiSauGio) {
    $intervalMin = [int][Math]::Round([double]::Parse($LapLaiSauGio, [Globalization.CultureInfo]::InvariantCulture) * 60)
}
if (-not $GioBatDau -or $intervalMin -le 0 -or -not $TaiKhoan) {
    Write-Host "Cach dung: lap_lich.bat <gio bat dau> <chu ky> <tai khoan>   vd: lap_lich.bat 23:00 8:05 tomcat12345"
    exit 1
}
# Ten tai khoan 7Road: 6-18 chu cai/so
if ($TaiKhoan -notmatch '^[A-Za-z0-9_]{1,30}$') { Write-Host "Ten tai khoan khong hop le: '$TaiKhoan'"; exit 1 }
$intervalText = "{0} tieng {1:D2} phut" -f [Math]::Floor($intervalMin / 60), ($intervalMin % 60)

# "15:00" -> hom nay 15:00; "2026-11-18 07:30" -> dung ngay do
$start = [datetime]::Parse($GioBatDau)
if ($start -lt (Get-Date)) {
    Write-Host "Luu y: $start da qua - lan chay dau se la moc lap lai tiep theo."
}

$farm = Join-Path $ScriptDir "ddtank_farm.ps1"
if (-not (Test-Path $farm)) { throw "Khong thay $farm" }

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$farm`" -Account $TaiKhoan" `
    -WorkingDirectory $ScriptDir
$trigger = New-ScheduledTaskTrigger -Once -At $start `
    -RepetitionInterval (New-TimeSpan -Minutes $intervalMin)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -WakeToRun `
    -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 45)
# Chay khi nguoi dung dang dang nhap (MuMu can giao dien Windows)
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TenTask -Action $action -Trigger $trigger -Settings $settings `
    -Principal $principal -Description "Thu hoach + trong khoai DDTank tren MuMu (thiet bi 'auto')" -Force | Out-Null

Write-Host "Da cai lich: bat dau $start, lap lai moi $intervalText, tai khoan $TaiKhoan."
Show-Task
