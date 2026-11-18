# Quan sat nguoi choi lam mau: chup man hinh ~1 anh/giay (JPG nho) + ghi su kien cham (getevent)
# Dung khi co file stop.txt trong thu muc ra, hoac het $MaxMin phut. KHONG bam gi vao thiet bi.
param([string]$Out, [int]$MaxMin = 20, [string]$Serial = "127.0.0.1:16416")
$adb = "D:\Program Files\Netease\MuMuPlayer\nx_main\adb.exe"
New-Item -ItemType Directory -Force $Out | Out-Null
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.IO; using System.Drawing; using System.Drawing.Imaging; using System.Runtime.InteropServices;
public static class RawJpg {
    public static void Save(string raw, string jpg, int outW) {
        byte[] b = File.ReadAllBytes(raw);
        int w = BitConverter.ToInt32(b, 0), h = BitConverter.ToInt32(b, 4);
        int hdr = b.Length - w * h * 4;
        var px = new byte[w * h * 4];
        for (int i = 0, s = hdr; i < w * h; i++, s += 4) { px[i*4] = b[s+2]; px[i*4+1] = b[s+1]; px[i*4+2] = b[s]; px[i*4+3] = 255; }
        using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb)) {
            var d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
            Marshal.Copy(px, 0, d.Scan0, px.Length); bmp.UnlockBits(d);
            int oh = h * outW / w;
            using (var sm = new Bitmap(outW, oh)) {
                using (var g = Graphics.FromImage(sm)) { g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBilinear; g.DrawImage(bmp, 0, 0, outW, oh); }
                var enc = Array.Find(ImageCodecInfo.GetImageEncoders(), e => e.MimeType == "image/jpeg");
                var ep = new EncoderParameters(1); ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 80L);
                sm.Save(jpg, enc, ep);
            }
        }
    }
}
'@
# Moc thoi gian: uptime cua may ao <-> gio may tinh (de khop su kien cham voi anh)
$up = (& $adb -s $Serial shell cat /proc/uptime).Split(' ')[0]
"host=$((Get-Date).ToString('HH:mm:ss.fff')) uptime=$up" | Set-Content (Join-Path $Out "moc_thoi_gian.txt")
$ev = Start-Process $adb -ArgumentList "-s $Serial shell getevent -lt /dev/input/event4" -NoNewWindow -PassThru `
      -RedirectStandardOutput (Join-Path $Out "cham.txt") -RedirectStandardError (Join-Path $Out "cham_err.txt")
$raw = Join-Path $Out "_tmp.raw"
$end = (Get-Date).AddMinutes($MaxMin); $n = 0
try {
    while ((Get-Date) -lt $end -and -not (Test-Path (Join-Path $Out "stop.txt"))) {
        $t = Get-Date
        cmd /c "`"$adb`" -s $Serial exec-out screencap > `"$raw`""
        try { [RawJpg]::Save($raw, (Join-Path $Out ("{0}.jpg" -f $t.ToString('HHmmss_fff'))), 960); $n++ } catch {}
        $wait = 900 - ((Get-Date) - $t).TotalMilliseconds
        if ($wait -gt 0) { Start-Sleep -Milliseconds $wait }
    }
} finally {
    Stop-Process -Id $ev.Id -Force -ErrorAction SilentlyContinue
    Remove-Item $raw -ErrorAction SilentlyContinue
    "Xong: $n anh, $((Get-Item (Join-Path $Out 'cham.txt')).Length) byte su kien cham"
}
