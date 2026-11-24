using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;

// Ban thu: cau ca tu dong tai cau tau (nhan vat da dung san o cho cau, thay nut Bat dau cau ca)
public class Fisher
{
    const int W = 640, H = 360;
    string adb, serial, outDir;
    Process rec, sh;
    readonly object lk = new object();
    byte[] frame; DateTime frameT; long seq;
    public Action<string> Log = s => Console.WriteLine(s);
    // Bam khi r du doan <= TargetR + v * TapLatency.
    // Do thuc te 18/11: tre ca he thong ~0.12s; luc lenh toi game, r ~6-20 px -> "Tuyet voi", > ~20 -> "Xuat sac", < ~6 -> "Hut"
    public int TargetR = 11;   // 18/11: 11-12 cho ~72% Tuyet voi; 12 hoi som (Xuat sac o r 22-23 khi vong cham)
    public double TapLatency = 0.12;

    byte[] tWait, tIdle, tBait; int tWaitW, tWaitH, tIdleW, tIdleH, tBaitW, tBaitH;
    bool NoBait(byte[] p) { return Ring.MatchAt(p, W, H, tBait, tBaitW, tBaitH, 262, 90, 8) < 20; }   // thong bao "Moi chua du"
    byte[] tBag; int tBagW, tBagH;
    bool BagFull(byte[] p) { return Ring.MatchAt(p, W, H, tBag, tBagW, tBagH, 265, 90, 8) < 15; }      // thong bao "Ba lo da day" (khop 0; "Moi chua du" 33; khac ~81)
    public Fisher(string adb, string serial, string outDir, string tplDir)
    {
        this.adb = adb; this.serial = serial; this.outDir = outDir; this.tplDir = tplDir; Directory.CreateDirectory(outDir);
        tWait = Ring.LoadRgb(Path.Combine(tplDir, "doi_ca.png"), out tWaitW, out tWaitH);     // chu "Doi ca can cau..." (dang doi)
        tIdle = Ring.LoadRgb(Path.Combine(tplDir, "nut_luoi.png"), out tIdleW, out tIdleH);   // nut "Cau ca bang luoi" (chi hien khi cho bat dau)
        tBait = Ring.LoadRgb(Path.Combine(tplDir, "het_moi.png"), out tBaitW, out tBaitH);    // thong bao "Moi chua du"
        tBag = Ring.LoadRgb(Path.Combine(tplDir, "balo_day.png"), out tBagW, out tBagH);      // thong bao "Ba lo da day"
    }
    bool Waiting(byte[] p) { return Ring.MatchAt(p, W, H, tWait, tWaitW, tWaitH, 250, 256, 30) < 10; }   // vi tri doi theo cho dung
    // Nut "Cau ca bang luoi" trong suot (nen sau doi theo cho dung) + so luoi o goc (mau "1", 19/11 la "0"):
    // do 19/11 tren 345 anh co nut: diem <= 20.1, 740 anh dang cau / chuc mung: >= 50 -> nguong 35 (truoc la 20: sat mep, bao loi gia)
    double IdleScore(byte[] p) { return Ring.MatchAt(p, W, H, tIdle, tIdleW, tIdleH, 425, 300, 6); }
    bool Idle(byte[] p) { return IdleScore(p) < 35; }

    // ---------- luong hinh + shell bam ----------
    public string TouchDev = null;   // vd /dev/input/event4: tu do theo ten "Xiaomi Input" (so thu tu co the doi)

    void FindTouchDevice()
    {
        var p = Process.Start(new ProcessStartInfo(adb, "-s " + serial + " shell getevent -p") { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true });
        string cur = null;
        foreach (var l in p.StandardOutput.ReadToEnd().Split('\n'))
        {
            var m = System.Text.RegularExpressions.Regex.Match(l, @"add device \d+:\s*(/dev/input/event\d+)");
            if (m.Success) cur = m.Groups[1].Value;
            else if (l.Contains("\"Xiaomi Input\"") && cur != null) { TouchDev = cur; break; }
        }
        p.WaitForExit(3000);
        if (TouchDev == null) { FastTap = false; Log("Khong thay thiet bi cam ung 'Xiaomi Input' -> bam bang input tap"); }
        else Log("Thiet bi cam ung: " + TouchDev);
    }

    public void Start()
    {
        if (FastTap) FindTouchDevice();
        StartStream();
        var ps = new ProcessStartInfo(adb, "-s " + serial + " shell");
        ps.UseShellExecute = false; ps.RedirectStandardInput = true; ps.RedirectStandardOutput = true; ps.RedirectStandardError = true; ps.CreateNoWindow = true;
        sh = Process.Start(ps);
        sh.OutputDataReceived += (o, e) => { }; sh.BeginOutputReadLine();
        sh.ErrorDataReceived += (o, e) => { }; sh.BeginErrorReadLine();
        // lan dau sau khi adb connect / MuMu vua mo, screenrecord co the chua ra hinh -> thu lai toi da 2 lan
        for (int attempt = 0; seq == 0 && attempt < 3; attempt++)
        {
            if (attempt > 0) { Log("Chua co hinh -> khoi dong lai screenrecord (lan " + attempt + ")"); RestartStream(); }
            var dl = DateTime.Now.AddSeconds(5);
            while (seq == 0 && DateTime.Now < dl) Thread.Sleep(20);
        }
        if (seq == 0) throw new Exception("Khong nhan duoc luong hinh tu screenrecord (cua so MuMu dang thu nho?)");
    }

    void StartStream()
    {
        var psi = new ProcessStartInfo(adb, "-s " + serial + " exec-out screenrecord --output-format=raw-frames --size " + W + "x" + H + " -");
        psi.UseShellExecute = false; psi.RedirectStandardOutput = true; psi.RedirectStandardError = true; psi.CreateNoWindow = true;
        var proc = Process.Start(psi); rec = proc;
        var t = new Thread(() =>
        {
            var s = proc.StandardOutput.BaseStream; int fsz = W * H * 3;
            while (true)
            {
                var buf = new byte[fsz]; int got = 0;
                while (got < fsz) { int r; try { r = s.Read(buf, got, fsz - got); } catch { return; } if (r <= 0) return; got += r; }
                lock (lk) { frame = buf; frameT = DateTime.Now; seq++; }
            }
        });
        t.IsBackground = true; t.Start();
    }

    public void Stop()
    {
        try { rec.Kill(); } catch { }
        try { sh.StandardInput.WriteLine("pkill -x screenrecord; rm -f /data/local/tmp/ddt_*.bin; exit"); sh.WaitForExit(2000); sh.Kill(); } catch { }
    }


    // Cho khung hinh moi hon seq hien tai. Luong hinh dung (vd cua so MuMu thu nho) -> khoi dong lai screenrecord toi da 3 lan
    byte[] Next(ref long last, out DateTime t, int timeoutMs = 1500)
    {
        for (int attempt = 0; attempt <= 3; attempt++)
        {
            var dl = DateTime.Now.AddMilliseconds(attempt == 0 ? timeoutMs : 4000);
            while (DateTime.Now < dl)
            {
                lock (lk) { if (seq != last) { last = seq; t = frameT; return frame; } }
                Thread.Sleep(5);
            }
            if (attempt < 3) { Log("Luong hinh dung -> khoi dong lai screenrecord (lan " + (attempt + 1) + ")"); RestartStream(); }
        }
        throw new Exception("Luong hinh dung (khong co khung moi sau 3 lan khoi dong lai)");
    }

    void RestartStream()
    {
        try { rec.Kill(); } catch { }
        try { sh.StandardInput.WriteLine("pkill -x screenrecord"); sh.StandardInput.Flush(); } catch { }
        Thread.Sleep(500);
        StartStream();
    }

    public void SaveFrame(byte[] p, string name)
    {
        var q = (byte[])p.Clone();
        for (int i = 0; i < q.Length; i += 3) { byte b = q[i]; q[i] = q[i + 2]; q[i + 2] = b; }
        using (var bmp = new Bitmap(W, H, PixelFormat.Format24bppRgb))
        {
            var d = bmp.LockBits(new Rectangle(0, 0, W, H), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
            for (int y = 0; y < H; y++) Marshal.Copy(q, y * W * 3, d.Scan0 + y * d.Stride, W * 3);
            bmp.UnlockBits(d);
            bmp.Save(Path.Combine(outDir, name + ".jpg"), ImageFormat.Jpeg);
        }
    }

    // ---------- trang thai ----------
    static bool Dark(byte[] p) { return Ring.Bright(p, W, H) < 120; }
    // Man "Chuc mung!" (cau duoc ca): toi HOAC co dong "Nhan de tiep tuc" goc duoi phai (mau nhan_tiep_tuc: chuc mung 0-19.9,
    // man khac >= 58). 20/11 23:18: Ca ngua (ky luc) -> man chuc mung sang + hien MUON (sau khi ve man cau) -> ban cu tuong truot.
    bool Congrats(byte[] p) { return Dark(p) || Score(p, "nhan_tiep_tuc", 505, 320, 6) < 35; }
    public int LateCatches = 0;   // so lan bang Chuc mung hien muon (da tinh la TRUOT o lan truoc)
    static bool Ball(byte[] p) { int x, y; return Ring.FindBall(p, W, H, out x, out y); }
    static bool Pull(byte[] p) { int x, y; return Ring.RedCount(p, W, H, out x, out y) >= 750 && !Ball(p); }

    delegate bool Cond(byte[] p);
    byte[] WaitFor(Cond c, double sec, string what, ref long last, out DateTime t)
    {
        var dl = DateTime.Now.AddSeconds(sec);
        while (DateTime.Now < dl) { var p = Next(ref last, out t); if (c(p)) return p; }
        t = DateTime.Now; return null;
    }

    public Dictionary<string, int> Ratings = new Dictionary<string, int>();

    // Doc chu cham diem MOI hien: Tuyet voi (vang cam) / Xuat sac (xanh duong) / Hut (do). null = chua co chu.
    // Chi dem dai ngang |dy| <= 25 quanh tam vong tron, bo qua cau (r < 16) va vong xanh duong (r 28-46):
    // ban cu dem ca vong xanh duong -> khong co chu van ra "Xuat sac" (19/11: 31/41 vong ghi Xuat sac la doc nham, chu yeu vong 3).
    // Chu cu cua vong truoc dang mo dan (nhat mau, troi len tren) khong dat nguong mau.
    // Do tren anh da luu: Tuyet voi vang 95-600+; Xuat sac xanh 16-32 (khong co chu 0-1); Hut do 83-97 (con lai <= 27)
    static string Rating(byte[] p)
    {
        int yel = 0, blu = 0, red = 0, cx = Ring.CX, cy = Ring.CY;   // chu che qua cau -> dung tam do luc vong tron hien
        for (int y = Math.Max(0, cy - 25); y <= Math.Min(H - 1, cy + 25); y += 2)
            for (int x = Math.Max(0, cx - 70); x <= Math.Min(W - 1, cx + 70); x += 2)
            {
                int dx = x - cx, dy = y - cy, d2 = dx * dx + dy * dy;
                if (d2 < 16 * 16 || (d2 >= 28 * 28 && d2 <= 46 * 46)) continue;
                int i = (y * W + x) * 3; int R = p[i], G = p[i + 1], B = p[i + 2];
                if (R > 220 && G > 140 && G < 230 && B < 90) yel++;
                else if (B > 200 && R < 120) blu++;
                else if (R > 150 && G < 80 && B < 80) red++;
            }
        if (red >= 50) return "Hut";
        if (yel >= 50) return "Tuyet voi";
        if (blu >= 10 && blu < 60) return "Xuat sac";   // >= 60: man hinh khac (19/11: 1 anh da chuyen canh, xanh 73)
        return null;
    }

    // ---------- bu rieng tung loai vong (tu hoc, luu theo may) ----------
    // Do 18/11 tren may 2 (LeadSec 0.03, 259 vong): vong cham (<130 px/s) 201/204 Tuyet voi; vong vua (130-190, vong 2) ~25% Xuat sac;
    // vong nhanh (>=190, vong 3) 100% Xuat sac -> bam som. Vong "thua khung" (do duoc ~14 diem/s thay vi ~30, 1 loai ca 2 vong,
    // vong 2 ~157 px/s) 4/4 Hut -> bam muon (hinh hien tre hon); vong 1 cua loai ca do (~104 px/s) 10/10 Tuyet voi.
    // Khoang cach do: khung thuong 0.030-0.041s, thua 0.065-0.069s -> nguong 0.05.
    // Bu (px, + = bam som hon) cong vao nguong bam, sau moi vong: Xuat sac -> -0.5 (bam muon hon), Hut -> +1.5 (som hon, vi Hut mat ca).
    // Can bang khi Xuat sac ~ 3 lan Hut.
    public Dictionary<string, double> Adj = new Dictionary<string, double> {
        { "cham", 0 }, { "vua", -1.5 }, { "nhanh", -3 }, { "thua_cham", 0 }, { "thua_vua", 4 }, { "thua_nhanh", 4 } };
    string AdjPath;
    string tapBand; bool tapped;   // loai vong vua bam (null = khong hoc: bam du phong / khung hinh cu) ; vong nay da bam chua
    static string Band(double v, double gap) { return (gap > 0.05 ? "thua_" : "") + (v < 130 ? "cham" : v < 190 ? "vua" : "nhanh"); }
    double AdjFor(string band) { double a; return Adj.TryGetValue(band, out a) ? a : 0; }

    public void LoadAdj(string path)
    {
        AdjPath = path;
        if (!File.Exists(path)) { SaveAdj(); return; }   // tao file voi gia tri khoi dau
        foreach (var l in File.ReadAllLines(path))
        {
            var kv = l.Split('='); double x;
            if (kv.Length == 2 && double.TryParse(kv[1], System.Globalization.NumberStyles.Float, System.Globalization.CultureInfo.InvariantCulture, out x)) Adj[kv[0].Trim()] = x;
        }
    }
    public string AdjText()
    {
        var parts = new List<string>();
        foreach (var kv in Adj) parts.Add(kv.Key + "=" + kv.Value.ToString("0.0", System.Globalization.CultureInfo.InvariantCulture));
        return string.Join(" ", parts.ToArray());
    }
    // Gioi han muc bu tung loai vong. 22/11: buoc hoc -0.5/+1.5 lam bu dao dong manh (vua -2..+4, nhanh -7..-0.5 trong 1 ngay)
    // -> vong vua 55/99 Tuyet voi, 11 Hut. Giam buoc hoc con -0.25/+0.75 (van can bang Xuat sac ~ 3 lan Hut) + chan khoang.
    static readonly Dictionary<string, double[]> AdjLimit = new Dictionary<string, double[]> {
        { "cham", new[] { -2.0, 3.0 } }, { "vua", new[] { -3.0, 2.0 } }, { "nhanh", new[] { -6.0, 0.0 } },
        { "thua_cham", new[] { -2.0, 4.0 } }, { "thua_vua", new[] { 0.0, 9.0 } }, { "thua_nhanh", new[] { -2.0, 8.0 } } };
    void Learn(string band, string rt)
    {
        double d = rt == "Xuat sac" ? -0.25 : rt == "Hut" ? 0.75 : 0;
        if (d == 0) return;
        double[] lim; if (!AdjLimit.TryGetValue(band, out lim)) lim = new[] { -10.0, 10.0 };
        Adj[band] = Math.Max(lim[0], Math.Min(lim[1], AdjFor(band) + d));
        Log(string.Format(System.Globalization.CultureInfo.InvariantCulture, "  bu vong '{0}' -> {1:0.0} px", band, Adj[band]));
        SaveAdj();
    }
    public void SaveAdj()
    {
        if (AdjPath == null) return;
        // dong '#' khong co '=' -> LoadAdj bo qua
        var head = "# Muc bu (px, + = bam som hon) tung loai vong, bot tu hoc tren may " + Environment.MachineName + ".\r\n"
                 + "# KHAC NHAU TUY MAY (do tre moi may khac nhau): khong chep sang may khac; xoa file de hoc lai tu dau.\r\n";
        try { File.WriteAllText(AdjPath, head + AdjText().Replace(" ", "\r\n") + "\r\n"); } catch { }
    }

    // Theo doi vong sang dang co vao va bam dung luc. bg = anh luc vong tron vua hien
    void TrackAndTap(byte[] bg, ref long last, int round, DateTime pullTap)
    {
        LastTrace = ""; tapBand = null; tapped = false;
        if (round > 1) PrepareFastTap();   // moi vong 1 diem bam lech khac (~20ms, vong sang moi bat dau tu r ~90)
        DateTime t0 = DateTime.Now, t;
        var pts = new List<KeyValuePair<double, int>>();   // (giay tu t0, ban kinh)
        int lastR = 999; double v = 85; string trace = "";
        double tFirst = 0, tLast = 0; int nMeas = 0;   // de tinh khoang cach trung binh giua 2 lan do duoc vong sang
        DateTime ballSeen = DateTime.Now;     // lan cuoi con thay qua cau cam: mat vong tron thi KHONG bam (bam vao dat -> nhan vat di cho khac)
        DateTime ringSeen = DateTime.MinValue; // lan cuoi do duoc vong sang dang co
        DateTime frameAt = DateTime.Now;       // lan cuoi nhan duoc khung hinh moi
        var dl = DateTime.Now.AddSeconds(3.2);
        while (DateTime.Now < dl)
        {
            // khong cho khung moi: giua 2 khung (~60ms) van tinh lai du doan moi ~2ms de bam dung luc (vong nhanh di ~12px/khung)
            byte[] p = null;
            lock (lk) { if (seq != last) { last = seq; t = frameT; p = frame; } else t = DateTime.Now; }
            if (p == null) { Thread.Sleep(2); }
            else { frameAt = DateTime.Now; if (Ball(p)) ballSeen = DateTime.Now; }
            // vong 2+: chu "Tuyet voi" cua vong truoc con che qua cau mot luc -> do duoc vong sang cung tinh la vong tron con hien
            // chi tinh thoi gian CO khung hinh moi: luong hinh khung lai (18/11 lan 10: dung 0.8s) khong co nghia la vong tron da mat
            DateTime alive = ballSeen > ringSeen ? ballSeen : ringSeen;
            if ((frameAt - alive).TotalSeconds > 0.8) { Log("Vong " + round + ": mat vong tron -> khong bam. ban kinh:" + trace); LastTap = ",,,"; return; }
            double ts = (t - t0).TotalSeconds;
            int sc; int r = p == null ? -1 : Ring.Radius(p, bg, W, H, out sc);
            if (r > 0 && r <= lastR + 3 && (lastR != 999 || r >= 50))
            {
                lastR = r; ringSeen = DateTime.Now; trace += string.Format(" {0:0.00}:{1}", ts, r); LastTrace = trace;
                if (nMeas++ == 0) tFirst = ts; tLast = ts;
                // r < 33: vong sang lan vao vong xanh duong (~37), do bi tre -> khong dung de tinh toc do / du doan
                // r 25-32 chi nhan khi khop toc do dang do (vong nhanh: tranh doan xa tu diem cu; vong cham: diem nho bi tre -> bo)
                if (r >= 33) pts.Add(new KeyValuePair<double, int>(ts, r));
                else if (r >= 25 && pts.Count > 0)
                {
                    var lp = pts[pts.Count - 1]; double dt = ts - lp.Key;
                    if (dt > 0.02 && (lp.Value - r) / dt >= v * 0.9) pts.Add(new KeyValuePair<double, int>(ts, r));
                }
            }
            // Moi vong co toc do rieng (62-253 px/s) nhung trong 1 vong vong sang co deu -> ke duong thang qua TAT CA diem do
            // cua vong (r <= 88) roi du doan theo duong do: giam nhieu do gio khung hinh toi lech +-50ms
            double fitA = 0; bool fit = false;
            if (pts.Count >= 3)
            {
                int k0 = 0; while (k0 < pts.Count - 3 && pts[k0].Value > 78) k0++;   // r > 78 do khong chuan (lan vong do ngoai)
                // luong hinh khung > 0.085s (vong 3 hay khung ngay sau diem dau: 75 @-0.01 roi 68 @0.10, 61, 54...) -> bo diem truoc
                // khoang khung neu sau do con >= 3 diem: diem cu keo toc do xuong (189 thay vi ~300 px/s) -> bam muon, Hut (19/11 lan 22).
                // Ca "thua khung" co khoang cach deu 0.065-0.069s -> khong bi anh huong
                for (int i = pts.Count - 3; i > k0; i--) if (pts[i].Key - pts[i - 1].Key > 0.085) { k0 = i; break; }
                int n = pts.Count - k0;
                if (pts[pts.Count - 1].Key - pts[k0].Key >= (round > 1 ? 0.05 : 0.08))
                {
                    double mt = 0, mr = 0; for (int i = k0; i < pts.Count; i++) { mt += pts[i].Key; mr += pts[i].Value; } mt /= n; mr /= n;
                    double sxy = 0, sxx = 0; for (int i = k0; i < pts.Count; i++) { sxy += (pts[i].Key - mt) * (pts[i].Value - mr); sxx += (pts[i].Key - mt) * (pts[i].Key - mt); }
                    if (sxx > 0) { v = Math.Max(50, Math.Min(320, -sxy / sxx)); fitA = mr + v * mt; fit = true; }   // r(t) = fitA - v*t
                }
            }
            // can >= 4 diem tren 0.1s (tranh nhieu: 80,80,35 -> toc do ao 320 px/s) va qua cau con tren man hinh (< 0.15s)
            bool enough = pts.Count >= 4 && pts[pts.Count - 1].Key - pts[0].Key >= 0.1;
            // vong 2+ rat nhanh (19/11: vong 3 bat dau do tu r 66-75, chum trong ~0.25s, 3 lan mat ca vi khong kip du 4 diem / 0.1s):
            // nhan 3 diem giam deu tren >= 0.05s khi vong da vao sau (r <= 40)
            bool urgent = false;
            if (!enough && round > 1 && fit && pts.Count >= 3 && lastR <= 40 && pts[pts.Count - 1].Key - pts[0].Key >= 0.05)
            {
                urgent = true;
                for (int i = 1; i < pts.Count; i++) if (pts[i].Value >= pts[i - 1].Value) { urgent = false; break; }
            }
            if ((enough || urgent)
                && ((DateTime.Now - ballSeen).TotalSeconds < 0.3 || (DateTime.Now - ringSeen).TotalSeconds < 0.15))
            {
                var b = pts[pts.Count - 1];
                double nowS = (DateTime.Now - t0).TotalSeconds;
                double pred = fit ? fitA - v * nowS : b.Value - v * (nowS - b.Key);
                double gap = nMeas > 1 ? (tLast - tFirst) / (nMeas - 1) : 0.033;
                string band = Band(v, gap); double adj = AdjFor(band);
                if (pred <= TargetR + v * TapLatency + adj)
                {
                    TapRing();
                    // khung hinh cuoi da cu > 0.2s (luong hinh khung) -> ket qua khong phan anh muc bu -> khong hoc
                    tapBand = nowS - b.Key > 0.2 ? null : band;
                    LastTap = string.Format("{0:0.0},{1},{2:0},{3:0.000}", pred, b.Value, v, (DateTime.Now - t0).TotalSeconds - b.Key);
                    LastBand = string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0}:{1:0.0}:{2:0.000}", band, adj, gap);
                    Log(string.Format("BAM vong {0} tai {6}: r du doan {1:0} (do lan cuoi r={2}, toc do {3:0} px/s, con {5:0.00}s toi luc chum), {4:0.00}s sau Keo can, vong '{7}' bu {8:0.0}{9}", round, pred, b.Value, v, (DateTime.Now - pullTap).TotalSeconds, pred / v, ringPt, band, adj, urgent ? " (vong rat nhanh: bam voi " + pts.Count + " diem)" : ""));
                    Log("  ban kinh:" + trace);
                    return;
                }
            }
        }
        LastTap = ",,,"; LastBand = "";
        if ((DateTime.Now - ballSeen).TotalSeconds < 0.3 || (DateTime.Now - ringSeen).TotalSeconds < 0.15) { TapRing(); Log("Vong " + round + ": khong do duoc vong sang -> bam du phong. ban kinh:" + trace); }
        else Log("Vong " + round + ": het gio, khong con qua cau -> khong bam. ban kinh:" + trace);
    }
    // ---------- bam ----------
    // Ghi thang su kien vao /dev/input/event4 (thiet bi cam ung "Xiaomi Input" cua MuMu = dung duong click chuot that):
    // cat file nhi phan qua shell mo san, tre 25-30ms va deu (input tap: 33-65ms, khong gan thiet bi nao -> de nhan ra).
    // Gia lap nguoi: lech toa do ngau nhien, thoi gian giu ngon ngau nhien, cho giua cac buoc ngau nhien.
    public bool FastTap = true;      // false: dung "input tap" nhu cu
    public bool Human = true;        // ngau nhien hoa
    readonly Random rng = new Random();
    readonly HashSet<string> pushed = new HashSet<string>();
    string ringKey;                  // file cham da day san cho vong tron hien tai
    string ringPt = "";              // diem bam vong tron that (man hinh 1600x900, da lech ngau nhien)

    int Rnd(int a, int b) { return rng.Next(a, b + 1); }
    void SleepRnd(int a, int b) { Thread.Sleep(Human ? Rnd(a, b) : (a + b) / 2); }

    static byte[] BuildEvents(int[][] evs)
    {
        // struct input_event 64-bit (24 byte): tv_sec, tv_usec (0 -> he thong tu dong gio), type, code, value
        var ms = new MemoryStream(); var bw = new BinaryWriter(ms);
        foreach (var e in evs) { bw.Write(0L); bw.Write(0L); bw.Write((ushort)e[0]); bw.Write((ushort)e[1]); bw.Write(e[2]); }
        bw.Flush(); return ms.ToArray();
    }

    void Push(string local, string remote)
    {
        var p = Process.Start(new ProcessStartInfo(adb, "-s " + serial + " push \"" + local + "\" " + remote) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardOutput = true, RedirectStandardError = true });
        p.WaitForExit(5000);
    }

    // Day file "cham xuong" cho toa do (sx,sy) len may ao (moi toa do 1 lan) -> tra ve khoa
    string EnsureTapFile(int sx, int sy)
    {
        string td = Path.Combine(Path.GetTempPath(), "ddt_cham"); Directory.CreateDirectory(td);
        if (!pushed.Contains("len"))
        {
            File.WriteAllBytes(Path.Combine(td, "len.bin"), BuildEvents(new[] { new[] { 3, 57, -1 }, new[] { 1, 330, 0 }, new[] { 0, 0, 0 } }));
            Push(Path.Combine(td, "len.bin"), "/data/local/tmp/ddt_len.bin"); pushed.Add("len");
        }
        string key = sx + "_" + sy;
        if (!pushed.Contains(key))
        {
            // toa do RAW doc: X = 900 - y, Y = x (do tu getevent luc nguoi choi lam mau)
            var down = BuildEvents(new[] { new[] { 3, 57, 1 }, new[] { 1, 330, 1 }, new[] { 3, 53, 900 - sy }, new[] { 3, 54, sx }, new[] { 0, 0, 0 } });
            File.WriteAllBytes(Path.Combine(td, "x_" + key + ".bin"), down);
            Push(Path.Combine(td, "x_" + key + ".bin"), "/data/local/tmp/ddt_x_" + key + ".bin"); pushed.Add(key);
        }
        return key;
    }

    void Inject(string key, int holdMs)
    {
        sh.StandardInput.WriteLine("cat /data/local/tmp/ddt_x_" + key + ".bin > " + TouchDev + "; sleep "
            + (holdMs / 1000.0).ToString("0.000", System.Globalization.CultureInfo.InvariantCulture)
            + "; cat /data/local/tmp/ddt_len.bin > " + TouchDev);
        sh.StandardInput.Flush();
    }

    // Bam nut thuong (Bat dau, Keo can, Nhan de tiep tuc): lech toi da +-jit px, giu 45-120ms
    // tra ve diem bam that (sau khi lech ngau nhien) de ghi log
    string Tap(int x, int y, int jit = 8)
    {
        if (Human) { x += Rnd(-jit, jit); y += Rnd(-jit, jit); }
        if (!FastTap) { sh.StandardInput.WriteLine("input tap " + x + " " + y); sh.StandardInput.Flush(); }
        else Inject(EnsureTapFile(x, y), Human ? Rnd(45, 120) : 60);
        return "(" + x + "," + y + ")";
    }

    // Chuan bi cham cho vong tron: chon diem lech ngau nhien quanh tam qua cau (+-6px man hinh, qua cau ban kinh ~32px)
    // va day file truoc, de luc bam chi con 1 lenh cat (khong tre them)
    void PrepareFastTap()
    {
        int sx = (int)(Ring.CX * 2.5), sy = (int)(Ring.CY * 2.5);
        if (Human) { sx += Rnd(-6, 6); sy += Rnd(-6, 6); }
        ringKey = FastTap ? EnsureTapFile(sx, sy) : sx + "_" + sy;
        ringPt = "(" + sx + "," + sy + ")";
    }
    void TapRing()
    {
        tapped = true;
        if (FastTap && ringKey != null) Inject(ringKey, Human ? Rnd(40, 90) : 50);
        else ringPt = Tap((int)(Ring.CX * 2.5), (int)(Ring.CY * 2.5), 6);
    }
    string LastTap = ",,,";
    string LastTrace = "";   // day "giay:ban_kinh" cua vong vua bam (de phan tich lan Hut / Xuat sac)
    string LastBand = "";    // "loai_vong:bu_px:khoang_cach_do_s" luc bam
    public string CsvPath;   // ghi moi vong: gio, lan, vong, r_du_doan, r_cuoi, toc_do, ngoai_suy_s, TargetR, TapLatency, ket_qua

    // ---------- don ba lo khi day (-BaloDay don) ----------
    // Ba lo (HUD cho cau) -> tab Ca (ba lo mo o tab Mua vu!) -> Loai bo -> tick Tat ca -> Xac nhan ->
    // hop "Ban co chac chan muon tha ca da chon?" -> Xac nhan -> "Tha thanh cong" -> Quay lai ve cho cau.
    // Tick "Tat ca" KHONG chon Moi (o dau tab Ca; 20/11 tha thu: moi 1139 con nguyen). Van kiem tra truoc khi Xac nhan:
    // o dau phai la Moi va KHONG co dau tick (diem xanh la: o co tick 230, o moi 0) -> sai thi Huy bo, KHONG tha.
    // Anh mau balo_*.png (640x360, cat tu anh chup 1600x900 thu nho, khop lai luong hinh 20/11): dung cho 0-1.8, cho khac >= 23.
    public bool ClearBagOnFull = false;
    public int MaxBagClears = 5;
    public int BagClears = 0;
    string ClearNote = null;      // ly do don ba lo khong duoc (vd game hoi mat khau cap 2)
    string tplDir;
    readonly Dictionary<string, KeyValuePair<byte[], int[]>> tpls = new Dictionary<string, KeyValuePair<byte[], int[]>>();

    double Score(byte[] p, string name, int x0, int y0, int r = 4)
    {
        KeyValuePair<byte[], int[]> t;
        if (!tpls.TryGetValue(name, out t))
        {
            int w, h; var b = Ring.LoadRgb(Path.Combine(tplDir, name + ".png"), out w, out h);
            t = new KeyValuePair<byte[], int[]>(b, new[] { w, h }); tpls[name] = t;
        }
        return Ring.MatchAt(p, W, H, t.Key, t.Value[0], t.Value[1], x0, y0, r);
    }
    // so diem xanh la (dau tick) trong 1 o 45x44 cua luoi Ba lo
    static int TickGreen(byte[] p, int x0, int y0)
    {
        int n = 0;
        for (int y = y0; y < y0 + 44; y++) for (int x = x0; x < x0 + 45; x++)
        { int i = (y * W + x) * 3; if (p[i + 1] > 170 && p[i] < 110 && p[i + 2] < 110) n++; }
        return n;
    }
    // Tim o Moi trong luoi tab Ca (o: x = 298 + 54*cot, y = 98 + 53*hang, 5 cot; chi 4 hang tren - hang 5 bi cat mep duoi,
    // khong dem dung dau tick). Tra ve {x0, y0, diem khop} hoac null. Mau balo_o_moi: o Moi 0-11.7, o ca >= 60.
    int[] FindBaitCell(byte[] p)
    {
        int[] best = null; double bs = 15;
        for (int r = 0; r < 4; r++)
            for (int c = 0; c < 5; c++)
            {
                int x0 = 298 + c * 54, y0 = 98 + r * 53;
                double s = Score(p, "balo_o_moi", x0, y0, 5);
                if (s < bs) { bs = s; best = new[] { x0, y0, (int)Math.Round(s) }; }
            }
        return best;
    }
    bool InBag(byte[] p) { return Score(p, "balo_tab_ca", 586, 136) < 15 && Score(p, "balo_loai_bo", 485, 60) < 15; }   // tab Ca, che do xem
    bool InSelect(byte[] p) { return Score(p, "balo_o_trong", 310, 62) < 13 || Score(p, "balo_o_tick", 310, 62) < 13; } // che do chon loai bo

    // Thoat Ba lo ve cho cau (Huy che do chon neu dang chon, Quay lai toi khi thay nut "Cau ca bang luoi")
    bool LeaveBag(ref long last)
    {
        DateTime t;
        for (int k = 0; k < 4; k++)
        {
            var p = Next(ref last, out t);
            if (Idle(p)) return true;
            if (Score(p, "balo_hoi_tha", 194, 166) < 20) { Log("  Huy hop tha ca"); Tap(602, 607, 8); }   // hop xac nhan con mo -> Huy
            else if (InSelect(p)) { Log("  Huy che do chon"); Tap(1157, 177, 6); }
            else { Log("  Quay lai"); Tap(75, 45, 8); }
            SleepRnd(1200, 1800);
        }
        var q = WaitFor(Idle, 4, "cho cau", ref last, out t);
        return q != null;
    }

    bool ClearBag(int no, ref long last)
    {
        DateTime t; byte[] p;
        Log("Ba lo day -> don: Ba lo -> Ca -> Loai bo -> Tat ca -> Xac nhan (lan " + (BagClears + 1) + ")");
        SleepRnd(1500, 2500);   // cho thong bao "Ba lo da day" tat
        p = Next(ref last, out t);
        // chi lay LOI bieu tuong (balo_nut_loi): mau co nen (balo_nut) lech 24.4 khi nhan vat dung cho khac (20/11 22:58) -> bao nham "khong thay"
        // loi: cho cau 0-13.9, dang mo ba lo >= 50
        if (Score(p, "balo_nut_loi", 590, 203) > 25) { SaveFrame(p, no + "_don_khong_thay_balo"); Log("  Khong thay nut Ba lo"); return false; }
        Log("  Bam Ba lo"); Tap(1505, 550, 8);
        p = WaitFor(q => Score(q, "balo_nut_loi", 590, 203) > 35, 5, "mo ba lo", ref last, out t);
        if (p == null) { Log("  Ba lo khong mo"); return false; }
        SleepRnd(700, 1200);
        // 1. tab Ca (ba lo mo o tab Mua vu: hat giong / nong san -> KHONG BAO GIO loai bo o day)
        Log("  Bam tab Ca"); Tap(1525, 415, 8);
        p = WaitFor(InBag, 5, "tab Ca", ref last, out t);
        if (p == null) { SaveFrame(Next(ref last, out t), no + "_don_khong_thay_tab_ca"); Log("  Khong vao duoc tab Ca"); LeaveBag(ref last); return false; }
        SleepRnd(500, 900);
        // 2. Loai bo -> che do chon
        Log("  Bam Loai bo"); Tap(1287, 177, 8);
        // 20/11 23:15: bam Loai bo -> game hoi MAT KHAU CAP 2 ("Xac minh danh tinh", ban phim so). Bot KHONG BAO GIO nhap mat khau:
        // dong bang, thoat ba lo, bao nguoi choi nhap tay 1 lan (sau do trong phien game khong hoi lai) roi chay lai.
        p = WaitFor(q => InSelect(q) || Score(q, "balo_mat_khau", 262, 54) < 25, 5, "che do chon", ref last, out t);
        if (p != null && Score(p, "balo_mat_khau", 262, 54) < 25)
        {
            SaveFrame(p, no + "_don_mat_khau");
            Log("  !!! Game hoi mat khau cap 2 (Xac minh danh tinh) -> KHONG nhap, dong bang. Nhap tay 1 lan roi chay lai");
            ClearNote = "game hoi mat khau cap 2 - nhap tay 1 lan roi chay lai";
            Tap(1132, 142, 4); SleepRnd(800, 1200);   // nut X cua bang
            LeaveBag(ref last); return false;
        }
        if (p == null) { SaveFrame(Next(ref last, out t), no + "_don_khong_chon_duoc"); Log("  Khong vao che do chon"); LeaveBag(ref last); return false; }
        SleepRnd(500, 900);
        // 3. tick Tat ca
        if (Score(p, "balo_o_tick", 310, 62) >= 13) { Log("  Tick Tat ca"); Tap(800, 180, 5); }
        p = WaitFor(q => Score(q, "balo_o_tick", 310, 62) < 13 && Score(q, "balo_xac_nhan", 502, 60) < 15, 4, "da chon", ref last, out t);
        if (p == null) { SaveFrame(Next(ref last, out t), no + "_don_khong_co_ca"); Log("  Tick Tat ca ma nut Xac nhan khong sang (khong co ca?)"); LeaveBag(ref last); return false; }
        SleepRnd(400, 800);
        p = Next(ref last, out t);
        // 4. Tick "Tat ca" mac dinh KHONG chon Moi (nguoi choi xac nhan 23/11; 9 lan don: o Moi 0 diem xanh) -> khong can bo chon tay.
        //    Moi khong luon o o dau (ca moi "NEW" xep len truoc) -> khong bat Moi phai o o dau, khong cuon tim.
        //    Chi 1 kiem tra nhe: neu THAY o Moi trong 4 hang dang hien ma lai co dau tick (khong le xay ra) -> Huy.
        int[] bait = FindBaitCell(p);
        if (bait != null && TickGreen(p, bait[0], bait[1]) > 60)
        {
            SaveFrame(p, no + "_don_moi_bi_chon");
            Log(string.Format("  !!! Moi bi tick (o {0},{1}) -> Huy, KHONG tha", bait[0], bait[1]));
            LeaveBag(ref last); return false;
        }
        SaveFrame(p, no + "_don_da_chon");
        Log("  Da chon tat ca ca (Moi mac dinh khong chon" + (bait != null ? string.Format(", thay o Moi ({0},{1}) khong tick", bait[0], bait[1]) : "") + ") -> bam Xac nhan");
        Tap(1306, 177, 6);
        // 5. hop "Ban co chac chan muon tha ca da chon?"
        p = WaitFor(q => Score(q, "balo_hoi_tha", 194, 166) < 20, 4, "hop tha ca", ref last, out t);
        if (p == null) { SaveFrame(Next(ref last, out t), no + "_don_khong_hoi"); Log("  Khong thay hop xac nhan tha ca"); LeaveBag(ref last); return false; }
        SleepRnd(500, 1000);
        Log("  Xac nhan tha ca"); Tap(998, 607, 10);
        // 6. tha xong: het hop hoi, ve lai che do xem (nut Loai bo)
        p = WaitFor(q => Score(q, "balo_hoi_tha", 194, 166) > 30 && Score(q, "balo_loai_bo", 485, 60) < 15, 5, "tha xong", ref last, out t);
        if (p != null) { SleepRnd(800, 1200); SaveFrame(Next(ref last, out t), no + "_don_xong"); Log("  Tha thanh cong"); }
        else Log("  Chua thay man sau khi tha (van ve cho cau)");
        // 7. ve cho cau
        SleepRnd(600, 1200);
        if (!LeaveBag(ref last)) { SaveFrame(Next(ref last, out t), no + "_don_khong_ve_cho_cau"); Log("  Khong ve duoc cho cau"); return false; }
        Log("  Da ve cho cau -> cau tiep");
        return p != null;
    }

    // Mot lan cau. Tra ve mo ta ket qua
    public string CastOnce(int no)
    {
        long last = 0; DateTime t;
        var p = Next(ref last, out t);
        // 1. phai thay nut "Cau ca bang luoi" (trang thai cho bat dau) on dinh 1 giay
        var stable = DateTime.Now; var dlIdle = DateTime.Now.AddSeconds(30);   // co the dang do 1 lan cau (doi ca + ca tuot ~20s)
        while ((DateTime.Now - stable).TotalSeconds < 1.0)
        {
            p = Next(ref last, out t);
            if (Congrats(p))
            {
                // bang Chuc mung cua lan truoc hien muon, con che man hinh -> bam tiep tuc roi cho nut Bat dau
                LateCatches++; SaveFrame(p, no + "_chuc_mung_muon");
                Log("Bang Chuc mung (lan truoc, hien muon) con mo -> bam Nhan de tiep tuc tai " + Tap(1435, 830));
                SleepRnd(1500, 2200); stable = DateTime.Now; continue;
            }
            if (!Idle(p)) stable = DateTime.Now;
            if (DateTime.Now > dlIdle) { SaveFrame(p, no + "_loi_khong_o_cho_cau"); return string.Format("LOI: khong thay nut Bat dau cau ca (khong dung o cho cau?) - diem khop nut luoi {0:0.0}, can < 35", IdleScore(p)); }
        }
        SaveFrame(p, no + "_0_truoc");
        SleepRnd(200, 1500);  // nguoi khong bam lai ngay khi nut vua hien
        // bam Bat dau; 3 giay chua sang trang thai dang doi thi bam lai (toi da 3 lan)
        bool started = false;
        for (int k = 1; k <= 3 && !started; k++)
        {
            p = Next(ref last, out t);
            if (!Idle(p)) break;           // khong con o man cho -> khong bam them (tranh bam trung nut Rut can)
            Log("Bam Bat dau cau ca" + (k > 1 ? " (lan " + k + ")" : "") + " tai " + Tap(1435, 760));
            var dls = DateTime.Now.AddSeconds(3);
            bool noBait = false; DateTime gone = DateTime.MinValue;
            while (DateTime.Now < dls)
            {
                p = Next(ref last, out t);
                if (NoBait(p)) { noBait = true; break; }
                if (BagFull(p))
                {
                    SaveFrame(p, no + "_balo_day");
                    // -BaloDay don: tha het ca trong Ba lo roi cau tiep (toi da $MaxBagClears lan/luot, phong lap vo han)
                    if (ClearBagOnFull && BagClears < MaxBagClears)
                    {
                        if (ClearBag(no, ref last)) { BagClears++; return "DON BALO (da tha het ca, cau tiep)"; }
                        return "BALO DAY (" + (ClearNote ?? "don ba lo khong duoc - xem anh " + no + "_don_*") + ")";
                    }
                    return "BALO DAY (game bao \"Ba lo da day\")";
                }
                // da bat dau = nut "Cau ca bang luoi" bien mat lien tuc 0.5s (chu "Doi ca can cau" doi vi tri/nen theo cho dung)
                if (Idle(p)) gone = DateTime.MinValue;
                else { if (gone == DateTime.MinValue) gone = DateTime.Now; if ((DateTime.Now - gone).TotalSeconds >= 0.5 || Pull(p)) { started = true; Log(string.Format("  da bat dau (diem khop nut luoi {0:0.0})", IdleScore(p))); break; } }
            }
            if (noBait) { SaveFrame(p, no + "_het_moi"); return "HET MOI (game bao \"Moi chua du\")"; }
        }
        if (!started) { SaveFrame(Next(ref last, out t), no + "_loi_khong_bat_dau"); return "LOI: bam Bat dau cau ca 3 lan khong duoc (het luot?)"; }

        // 2. cho ca can cau -> nut Keo can do
        p = WaitFor(Pull, 30, "Keo can", ref last, out t);
        if (p == null) { SaveFrame(Next(ref last, out t), no + "_loi_khong_thay_keo_can"); return "LOI: 30s khong thay nut Keo can"; }
        int kx, ky; Ring.RedCount(p, W, H, out kx, out ky);   // tam diem do ~ tam nut Keo can (hoi lech len do vong cung do)
        SleepRnd(220, 700);   // nguoi thay nut do roi moi bam (con ~5s moi tuot ca)
        // tam nut = tam cum diem do (man hinh 1600x900); diem bam that lech ngau nhien quanh tam
        Log(string.Format("Ca can cau -> bam Keo can tai {2} (tam nut ({0},{1}))", (int)(kx * 2.5), (int)((ky + 12) * 2.5), Tap((int)(kx * 2.5), (int)((ky + 12) * 2.5))));
        var pullTap = DateTime.Now;

        // 3. vong tron
        p = WaitFor(Ball, 3, "vong tron", ref last, out t);
        if (p == null) { SaveFrame(Next(ref last, out t), no + "_loi_khong_thay_vong"); return "LOI: khong thay vong tron sau khi Keo can"; }
        var bg = p;
        int bx, by; Ring.FindBall(p, W, H, out bx, out by); Ring.CX = bx; Ring.CY = by;
        PrepareFastTap();   // ~20ms, vong sang con > 1s moi toi luc bam
        Log(string.Format("Vong tron hien sau {0:0.00}s, tam qua cau ({1},{2}) tren anh 640x360", (t - pullTap).TotalSeconds, bx, by));

        // 4. co the co nhieu vong lien tiep (ca kho): vong nao co vao thi bam vong do, toi khi ra man Chuc mung
        bool gotResult = false;
        for (int round = 1; round <= 6 && !gotResult; round++)
        {
            TrackAndTap(bg, ref last, round, pullTap);
            DateTime tapAt = DateTime.Now;
            long l2 = last; DateTime t2;
            // vong 2-3: chu ket qua moi thuong hien muon hon 350ms (chu vong truoc con tren man hinh)
            // -> doc chu tren moi khung toi khi thay chu moi (toi da 1.5s), xen ke voi cho vong tiep / man Chuc mung
            Thread.Sleep(250); var pr = Next(ref l2, out t2);
            string rt = Rating(pr); double rtSec = (DateTime.Now - tapAt).TotalSeconds;
            if (rt != null) SaveFrame(pr, no + "_v" + round + "_sau_bam");
            // cho: man toi (xong) / vong sang moi o xa (vong tiep) / mat qua cau qua lau (truot)
            // cho toi 8s: Chuc mung co the hien muon (ca ky luc), mat qua cau 5s moi tinh truot
            var dl2 = DateTime.Now.AddSeconds(8); DateTime noBall = DateTime.MinValue; bool nextRound = false;
            while (DateTime.Now < dl2)
            {
                p = Next(ref last, out t);
                if (Congrats(p)) { gotResult = true; break; }
                if (rt == null && (DateTime.Now - tapAt).TotalSeconds < 1.5)
                {
                    rt = Rating(p); rtSec = (DateTime.Now - tapAt).TotalSeconds;
                    if (rt != null) SaveFrame(p, no + "_v" + round + "_sau_bam");
                }
                if (Ball(p))
                {
                    noBall = DateTime.MinValue;
                    int sc; int r = Ring.Radius(p, bg, W, H, out sc);
                    if ((DateTime.Now - t2).TotalSeconds > 0.3 && r >= 75) { nextRound = true; Log("  -> vong tiep theo (vong " + (round + 1) + ")"); break; }
                }
                else
                {
                    if (noBall == DateTime.MinValue) noBall = DateTime.Now;
                    if ((DateTime.Now - noBall).TotalSeconds > 5.0) break;
                }
            }
            // khong thay chu moi -> "Khong ro", KHONG hoc (ban cu doc nham vong xanh duong thanh "Xuat sac" -> bu vong nhanh troi toi -10)
            if (rt == null) { SaveFrame(pr, no + "_v" + round + "_sau_bam"); rt = tapped ? "Khong ro" : "Khong bam"; }
            else if (!tapped && rt != "Hut") rt = "Khong bam";
            Log(string.Format("  ket qua vong {0}: {1}{2}", round, rt, rt == "Khong ro" || rt == "Khong bam" ? "" : string.Format(" (chu hien sau {0:0.00}s)", rtSec)));
            if (Ratings.ContainsKey(rt)) Ratings[rt]++; else Ratings[rt] = 1;
            if (tapBand != null) Learn(tapBand, rt);
            if (CsvPath != null)
                File.AppendAllText(CsvPath, string.Format(System.Globalization.CultureInfo.InvariantCulture,
                    "{0:yyyy-MM-dd HH:mm:ss},{1},{2},{3},{4},{5},{6},{7},\"{8}\",{9},{10}\r\n",
                    DateTime.Now, no, round, LastTap, TargetR, TapLatency, rt, Human ? 1 : 0, LastTrace.Trim(), Path.GetFileName(outDir), LastBand));
            if (!gotResult && !nextRound) { SaveFrame(Next(ref last, out t), no + "_3_khong_chuc_mung"); return "TRUOT sau vong " + round + " (khong co man Chuc mung)"; }
        }
        if (!gotResult) return "TRUOT (qua 6 vong)";
        SleepRnd(800, 1800);  // xem ca vua cau duoc roi moi bam tiep
        SaveFrame(Next(ref last, out t), no + "_3_chuc_mung");
        Log("Bam Nhan de tiep tuc tai " + Tap(1435, 830));
        WaitFor(q => !Congrats(q), 4, "het Chuc mung", ref last, out t);
        return "OK";
    }
}
