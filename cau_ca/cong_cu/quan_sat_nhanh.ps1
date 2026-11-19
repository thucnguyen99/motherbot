# Ghi nhanh: luong hinh screenrecord raw-frames (~12+ anh/giay, 640x360) -> JPG co gio may tinh + su kien cham
# Dung khi co stop.txt trong thu muc ra hoac het $MaxMin phut. KHONG bam gi vao thiet bi.
param([string]$Out, [int]$MaxMin = 10, [string]$ThietBi = "auto", [string]$Serial = "", [int]$W = 640, [int]$H = 360)
# MuMu cai o C: hay D: tuy may -> tim tren moi o dia (giong cau_thu.ps1)
$MuMuDir = Get-PSDrive -PSProvider FileSystem | ForEach-Object { Join-Path $_.Root "Program Files\Netease\MuMuPlayer\nx_main" } |
    Where-Object { Test-Path (Join-Path $_ "MuMuManager.exe") } | Select-Object -First 1
if (-not $MuMuDir) { Write-Host "Khong tim thay MuMu"; exit 1 }
$adb = Join-Path $MuMuDir "adb.exe"
if (-not $Serial) {
    $info = (& (Join-Path $MuMuDir "MuMuManager.exe") info -v all | Out-String | ConvertFrom-Json).PSObject.Properties.Value | Where-Object { $_.name -eq $ThietBi } | Select-Object -First 1
    if (-not $info -or -not $info.adb_port) { Write-Host "Thiet bi '$ThietBi' chua bat"; exit 1 }
    $Serial = "$($info.adb_host_ip):$($info.adb_port)"; & $adb connect $Serial | Out-Null
}
# thiet bi cam ung "Xiaomi Input" (so event co the doi)
$touch = "/dev/input/event4"; $cur = $null
foreach ($l in (& $adb -s $Serial shell getevent -p) -split "`n") {
    if ($l -match 'add device \d+:\s*(/dev/input/event\d+)') { $cur = $Matches[1] }
    elseif ($l -match '"Xiaomi Input"' -and $cur) { $touch = $cur; break }
}
Write-Host "ADB $Serial, cham $touch, ghi vao $Out (dung: tao file stop.txt trong thu muc do, hoac het $MaxMin phut)"
New-Item -ItemType Directory -Force $Out | Out-Null
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.IO; using System.Diagnostics; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class StreamRec {
    public static int Run(string adb, string serial, string outDir, int w, int h, int maxSec) {
        var psi = new ProcessStartInfo(adb, "-s " + serial + " exec-out screenrecord --output-format=raw-frames --size " + w + "x" + h + " -");
        psi.UseShellExecute = false; psi.RedirectStandardOutput = true; psi.RedirectStandardError = true; psi.CreateNoWindow = true;
        var p = Process.Start(psi);
        var s = p.StandardOutput.BaseStream;
        int fsz = w * h * 3; var buf = new byte[fsz]; int n = 0;
        var enc = Array.Find(ImageCodecInfo.GetImageEncoders(), e => e.MimeType == "image/jpeg");
        var ep = new EncoderParameters(1); ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 75L);
        var end = DateTime.Now.AddSeconds(maxSec); string stop = Path.Combine(outDir, "stop.txt");
        try {
            while (DateTime.Now < end && !File.Exists(stop)) {
                int got = 0;
                while (got < fsz) { int r = s.Read(buf, got, fsz - got); if (r <= 0) return n; got += r; }
                var t = DateTime.Now;
                for (int i = 0; i < fsz; i += 3) { byte tmp = buf[i]; buf[i] = buf[i + 2]; buf[i + 2] = tmp; } // RGB -> BGR
                using (var bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb)) {
                    var d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
                    for (int y = 0; y < h; y++) Marshal.Copy(buf, y * w * 3, d.Scan0 + y * d.Stride, w * 3);
                    bmp.UnlockBits(d);
                    bmp.Save(Path.Combine(outDir, t.ToString("HHmmss_fff") + ".jpg"), enc, ep);
                }
                n++;
            }
        } finally { try { p.Kill(); } catch {} }
        return n;
    }
}
'@
$up = (& $adb -s $Serial shell cat /proc/uptime).Split(' ')[0]
"host=$((Get-Date).ToString('HH:mm:ss.fff')) uptime=$up" | Set-Content (Join-Path $Out "moc_thoi_gian.txt")
$ev = Start-Process $adb -ArgumentList "-s $Serial shell getevent -lt $touch" -NoNewWindow -PassThru `
      -RedirectStandardOutput (Join-Path $Out "cham.txt") -RedirectStandardError (Join-Path $Out "cham_err.txt")
$t0 = Get-Date
try { $n = [StreamRec]::Run($adb, $Serial, $Out, $W, $H, $MaxMin * 60) }
finally {
    Stop-Process -Id $ev.Id -Force -ErrorAction SilentlyContinue
    # chi tat getevent: pkill screenrecord se tat luon luong hinh cua bot cau ca neu dang chay
    & $adb -s $Serial shell "pkill -x getevent" 2>$null | Out-Null
}
$sec = ((Get-Date) - $t0).TotalSeconds
"Xong: $n anh trong $([int]$sec) giay (~$([Math]::Round($n / [Math]::Max(1,$sec), 1)) anh/giay)"
