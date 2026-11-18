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
        this.adb = adb; this.serial = serial; this.outDir = outDir; Directory.CreateDirectory(outDir);
        tWait = Ring.LoadRgb(Path.Combine(tplDir, "doi_ca.png"), out tWaitW, out tWaitH);     // chu "Doi ca can cau..." (dang doi)
        tIdle = Ring.LoadRgb(Path.Combine(tplDir, "nut_luoi.png"), out tIdleW, out tIdleH);   // nut "Cau ca bang luoi" (chi hien khi cho bat dau)
        tBait = Ring.LoadRgb(Path.Combine(tplDir, "het_moi.png"), out tBaitW, out tBaitH);    // thong bao "Moi chua du"
        tBag = Ring.LoadRgb(Path.Combine(tplDir, "balo_day.png"), out tBagW, out tBagH);      // thong bao "Ba lo da day"
    }
    bool Waiting(byte[] p) { return Ring.MatchAt(p, W, H, tWait, tWaitW, tWaitH, 250, 256, 30) < 10; }   // vi tri doi theo cho dung
    bool Idle(byte[] p) { return Ring.MatchAt(p, W, H, tIdle, tIdleW, tIdleH, 425, 300, 6) < 20; }

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

    // Doc chu cham diem tren vong tron theo mau: Tuyet voi (vang cam) / Xuat sac (xanh duong) / Hut (do)
    static string Rating(byte[] p)
    {
        int yel = 0, blu = 0, red = 0;
        for (int y = Math.Max(0, Ring.CY - 20); y < Math.Min(H, Ring.CY + 40); y += 2)
            for (int x = Math.Max(0, Ring.CX - 84); x < Math.Min(W, Ring.CX + 76); x += 2)
            {
                int i = (y * W + x) * 3; int R = p[i], G = p[i + 1], B = p[i + 2];
                if (R > 220 && G > 140 && G < 230 && B < 90) yel++;
                else if (B > 200 && R < 120) blu++;
                else if (R > 150 && G < 80 && B < 80) red++;
            }
        // do 18/11: Hut do=152-278 (xanh 42-50 la vong xanh duong); Tuyet voi vang=187-247; Xuat sac xanh=107-444
        if (red >= 80) return "Hut";
        if (yel >= 80) return "Tuyet voi";
        if (blu >= 80) return "Xuat sac";
        return "?(vang " + yel + " xanh " + blu + " do " + red + ")";
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
        if (!File.Exists(path)) return;
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
    void Learn(string band, string rt)
    {
        double d = rt == "Xuat sac" ? -0.5 : rt == "Hut" ? 1.5 : 0;
        if (d == 0) return;
        Adj[band] = Math.Max(-10, Math.Min(10, AdjFor(band) + d));
        Log(string.Format(System.Globalization.CultureInfo.InvariantCulture, "  bu vong '{0}' -> {1:0.0} px", band, Adj[band]));
        if (AdjPath != null) try { File.WriteAllText(AdjPath, AdjText().Replace(" ", "\r\n") + "\r\n"); } catch { }
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
                int n = pts.Count - k0;
                if (pts[pts.Count - 1].Key - pts[k0].Key >= 0.08)
                {
                    double mt = 0, mr = 0; for (int i = k0; i < pts.Count; i++) { mt += pts[i].Key; mr += pts[i].Value; } mt /= n; mr /= n;
                    double sxy = 0, sxx = 0; for (int i = k0; i < pts.Count; i++) { sxy += (pts[i].Key - mt) * (pts[i].Value - mr); sxx += (pts[i].Key - mt) * (pts[i].Key - mt); }
                    if (sxx > 0) { v = Math.Max(50, Math.Min(320, -sxy / sxx)); fitA = mr + v * mt; fit = true; }   // r(t) = fitA - v*t
                }
            }
            // can >= 4 diem tren 0.1s (tranh nhieu: 80,80,35 -> toc do ao 320 px/s) va qua cau con tren man hinh (< 0.15s)
            if (pts.Count >= 4 && pts[pts.Count - 1].Key - pts[0].Key >= 0.1
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
                    Log(string.Format("BAM vong {0} tai {6}: r du doan {1:0} (do lan cuoi r={2}, toc do {3:0} px/s, con {5:0.00}s toi luc chum), {4:0.00}s sau Keo can, vong '{7}' bu {8:0.0}", round, pred, b.Value, v, (DateTime.Now - pullTap).TotalSeconds, pred / v, ringPt, band, adj));
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
            if (!Idle(p)) stable = DateTime.Now;
            if (DateTime.Now > dlIdle) { SaveFrame(p, no + "_loi_khong_o_cho_cau"); return "LOI: khong thay nut Bat dau cau ca (khong dung o cho cau?)"; }
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
                if (BagFull(p)) { SaveFrame(p, no + "_balo_day"); return "BALO DAY (game bao \"Ba lo da day\")"; }
                // da bat dau = nut "Cau ca bang luoi" bien mat lien tuc 0.5s (chu "Doi ca can cau" doi vi tri/nen theo cho dung)
                if (Idle(p)) gone = DateTime.MinValue;
                else { if (gone == DateTime.MinValue) gone = DateTime.Now; if ((DateTime.Now - gone).TotalSeconds >= 0.5 || Pull(p)) { started = true; break; } }
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
            long l2 = last; DateTime t2;
            Thread.Sleep(350); var pr = Next(ref l2, out t2); SaveFrame(pr, no + "_v" + round + "_sau_bam");
            string rt = Rating(pr);
            // khong bam ma van doc ra chu (18/11 lan 10: vong xanh duong doc nham thanh "Xuat sac") -> ghi ro la khong bam
            if (!tapped && rt != "Hut") rt = "Khong bam";
            Log("  ket qua vong " + round + ": " + rt);
            if (Ratings.ContainsKey(rt)) Ratings[rt]++; else Ratings[rt] = 1;
            if (tapBand != null) Learn(tapBand, rt);
            if (CsvPath != null)
                File.AppendAllText(CsvPath, string.Format(System.Globalization.CultureInfo.InvariantCulture,
                    "{0:yyyy-MM-dd HH:mm:ss},{1},{2},{3},{4},{5},{6},{7},\"{8}\",{9},{10}\r\n",
                    DateTime.Now, no, round, LastTap, TargetR, TapLatency, rt, Human ? 1 : 0, LastTrace.Trim(), Path.GetFileName(outDir), LastBand));
            // cho: man toi (xong) / vong sang moi o xa (vong tiep) / mat qua cau qua lau (truot)
            var dl2 = DateTime.Now.AddSeconds(4); DateTime noBall = DateTime.MinValue; bool nextRound = false;
            while (DateTime.Now < dl2)
            {
                p = Next(ref last, out t);
                if (Dark(p)) { gotResult = true; break; }
                if (Ball(p))
                {
                    noBall = DateTime.MinValue;
                    int sc; int r = Ring.Radius(p, bg, W, H, out sc);
                    if ((DateTime.Now - t2).TotalSeconds > 0.3 && r >= 75) { nextRound = true; Log("  -> vong tiep theo (vong " + (round + 1) + ")"); break; }
                }
                else
                {
                    if (noBall == DateTime.MinValue) noBall = DateTime.Now;
                    if ((DateTime.Now - noBall).TotalSeconds > 1.5) break;
                }
            }
            if (!gotResult && !nextRound) { SaveFrame(Next(ref last, out t), no + "_3_khong_chuc_mung"); return "TRUOT sau vong " + round + " (khong co man Chuc mung)"; }
        }
        if (!gotResult) return "TRUOT (qua 6 vong)";
        SleepRnd(800, 1800);  // xem ca vua cau duoc roi moi bam tiep
        SaveFrame(Next(ref last, out t), no + "_3_chuc_mung");
        Log("Bam Nhan de tiep tuc tai " + Tap(1435, 830));
        WaitFor(q => !Dark(q), 4, "het Chuc mung", ref last, out t);
        return "OK";
    }
}
