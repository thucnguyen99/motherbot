// Template matching cho script nong trai DDTank (C# 5, bien dich boi PowerShell 5.1 Add-Type, che do /optimize)
//
// Toi uu toc do (ket qua giong het ban cu - da so 168/168 lan tim tren anh chup that):
//  - Anh chup man hinh doc dang RAW tu "adb exec-out screencap" (khong nen PNG tren may ao -> chup nhanh hon)
//  - Anh chup va anh mau duoc giu trong bo nho, khong doc lai file moi lan tim
//  - Loc nhieu tang: thu 32 -> 128 -> 512 diem ngau nhien, lech qua xa thi bo vi tri do ngay;
//    chi vi tri con lai moi so day du nhu cu (cung tap diem, cung cong thuc diem)
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

public class VMatch
{
    public int X;      // tam (center) cua mau tim thay
    public int Y;
    public double Score; // sai khac trung binh moi kenh mau (0 = giong het, cang nho cang giong)
    public override string ToString() { return string.Format("({0},{1}) score={2:F1}", X, Y, Score); }
}

public static class Vision
{
    class Img { public int W, H; public byte[] P; } // BGR, 3 byte / pixel

    // ---------- doc anh ----------
    static Img LoadPng(string path)
    {
        using (var src = new Bitmap(path))
        using (var bmp = src.Clone(new Rectangle(0, 0, src.Width, src.Height), PixelFormat.Format24bppRgb))
        {
            var d = bmp.LockBits(new Rectangle(0, 0, bmp.Width, bmp.Height), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
            var img = new Img { W = bmp.Width, H = bmp.Height, P = new byte[bmp.Width * bmp.Height * 3] };
            var row = new byte[d.Stride];
            for (int y = 0; y < bmp.Height; y++)
            {
                Marshal.Copy(d.Scan0 + y * d.Stride, row, 0, d.Stride);
                Buffer.BlockCopy(row, 0, img.P, y * bmp.Width * 3, bmp.Width * 3);
            }
            bmp.UnlockBits(d);
            return img;
        }
    }

    // RAW cua screencap: header (12 byte, Android 12+ la 16 byte: w, h, format[, colorspace]) + RGBA 4 byte/pixel
    static Img LoadRaw(string path)
    {
        byte[] b = File.ReadAllBytes(path);
        int w = BitConverter.ToInt32(b, 0), h = BitConverter.ToInt32(b, 4);
        if (w <= 0 || h <= 0 || (long)w * h * 4 > b.Length) throw new Exception("Anh RAW khong hop le: " + path);
        int hdr = b.Length - w * h * 4;
        var img = new Img { W = w, H = h, P = new byte[w * h * 3] };
        for (int i = 0, s = hdr, d = 0; i < w * h; i++, s += 4, d += 3)
        {
            img.P[d] = b[s + 2]; img.P[d + 1] = b[s + 1]; img.P[d + 2] = b[s]; // RGBA -> BGR
        }
        return img;
    }

    static Img Load(string path)
    {
        return path.EndsWith(".raw", StringComparison.OrdinalIgnoreCase) ? LoadRaw(path) : LoadPng(path);
    }

    // ---------- bo nho dem ----------
    static readonly Dictionary<string, Img> tplCache = new Dictionary<string, Img>(StringComparer.OrdinalIgnoreCase);
    static string scrPath; static DateTime scrTime; static long scrLen; static Img scr;

    // Goi sau moi lan chup man hinh moi
    public static void Reset() { scr = null; }

    static Img Screen(string path)
    {
        var fi = new FileInfo(path);
        if (scr == null || !string.Equals(path, scrPath, StringComparison.OrdinalIgnoreCase)
            || fi.LastWriteTimeUtc != scrTime || fi.Length != scrLen)
        {
            scr = Load(path); scrPath = path; scrTime = fi.LastWriteTimeUtc; scrLen = fi.Length;
        }
        return scr;
    }

    static Img Tpl(string path)
    {
        Img t;
        if (!tplCache.TryGetValue(path, out t)) { t = Load(path); tplCache[path] = t; }
        return t;
    }

    // ---------- tim mau ----------
    // Tim tat ca vi tri khop mau trong vung (rx,ry,rw,rh) cua anh chup; rw/rh <= 0 = ca anh.
    public static List<VMatch> FindAll(string screenPath, string tplPath, double maxScore,
                                       int rx, int ry, int rw, int rh)
    {
        Img s = Screen(screenPath), t = Tpl(tplPath);
        if (rw <= 0) rw = s.W; if (rh <= 0) rh = s.H;
        int x0 = Math.Max(0, rx), y0 = Math.Max(0, ry);
        int x1 = Math.Min(s.W - t.W, rx + rw - t.W), y1 = Math.Min(s.H - t.H, ry + rh - t.H);

        // lay mau pixel thua (moi 2 pixel), tron thu tu co dinh (seed) de loai nhanh vi tri khong khop
        var pts = new List<int>();
        for (int ty = 0; ty < t.H; ty += 2) for (int tx = 0; tx < t.W; tx += 2) pts.Add(ty * t.W + tx);
        int n = pts.Count;
        var rnd = new Random(12345);
        for (int i = n - 1; i > 0; i--) { int j = rnd.Next(i + 1); int tmp = pts[i]; pts[i] = pts[j]; pts[j] = tmp; }
        var off = new int[n]; var tb = new int[n]; var tg = new int[n]; var tr = new int[n];
        for (int i = 0; i < n; i++)
        {
            int tp = pts[i], tx = tp % t.W, ty = tp / t.W;
            off[i] = (ty * s.W + tx) * 3;
            tb[i] = t.P[tp * 3]; tg[i] = t.P[tp * 3 + 1]; tr[i] = t.P[tp * 3 + 2];
        }
        long limit = (long)(maxScore * n * 3);

        // Cac tang loc: sau k diem, trung binh lech vuot nguong noi long -> chac chan khong khop.
        // (vi tri khop that chi dung toi da ~66% nguong tang khi do tren anh chup that)
        int[] cpN = { 32, 128, 512 };
        double[] cpM = { Math.Max(maxScore * 3, maxScore + 25), Math.Max(maxScore * 2, maxScore + 15), Math.Max(maxScore * 1.5, maxScore + 8) };
        var cps = new List<int>(); var cpL = new List<long>();
        for (int k = 0; k < cpN.Length; k++) if (cpN[k] < n) { cps.Add(cpN[k]); cpL.Add((long)(cpM[k] * cpN[k] * 3)); }
        int ncp = cps.Count;
        byte[] P = s.P;

        var found = new List<VMatch>();
        for (int y = y0; y <= y1; y += 2)
        {
            int rowBase = y * s.W * 3;
            for (int x = x0; x <= x1; x += 2)
            {
                int b0 = rowBase + x * 3;
                long sum = 0; int i = 0; bool rej = false;
                for (int c = 0; c < ncp && !rej; c++)
                {
                    int end = cps[c];
                    for (; i < end; i++)
                    {
                        int si = b0 + off[i];
                        int d0 = P[si] - tb[i], d1 = P[si + 1] - tg[i], d2 = P[si + 2] - tr[i];
                        sum += (d0 < 0 ? -d0 : d0) + (d1 < 0 ? -d1 : d1) + (d2 < 0 ? -d2 : d2);
                    }
                    if (sum > cpL[c]) rej = true;
                }
                if (rej) continue;
                for (; i < n && sum <= limit; i++)
                {
                    int si = b0 + off[i];
                    int d0 = P[si] - tb[i], d1 = P[si + 1] - tg[i], d2 = P[si + 2] - tr[i];
                    sum += (d0 < 0 ? -d0 : d0) + (d1 < 0 ? -d1 : d1) + (d2 < 0 ? -d2 : d2);
                }
                if (sum <= limit)
                    found.Add(new VMatch { X = x + t.W / 2, Y = y + t.H / 2, Score = sum / (double)(n * 3) });
            }
        }

        // bo cac diem trung nhau (non-max suppression)
        found.Sort((a, b) => a.Score.CompareTo(b.Score));
        var result = new List<VMatch>();
        foreach (var m in found)
        {
            bool dup = false;
            foreach (var r in result)
                if (Math.Abs(r.X - m.X) < t.W && Math.Abs(r.Y - m.Y) < t.H) { dup = true; break; }
            if (!dup) result.Add(m);
        }
        return result;
    }

    // ---------- tien ich ----------
    static Bitmap ToBitmap(Img img)
    {
        var bmp = new Bitmap(img.W, img.H, PixelFormat.Format24bppRgb);
        var d = bmp.LockBits(new Rectangle(0, 0, img.W, img.H), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
        for (int y = 0; y < img.H; y++) Marshal.Copy(img.P, y * img.W * 3, d.Scan0 + y * d.Stride, img.W * 3);
        bmp.UnlockBits(d);
        return bmp;
    }

    // Luu anh (RAW hoac PNG) ra file PNG - dung cho anh log / gui Telegram
    public static void SavePng(string src, string dst)
    {
        using (var bmp = ToBitmap(Load(src))) bmp.Save(dst, ImageFormat.Png);
    }

    // Lay mau tai (x,y) - dung de debug
    public static string PixelAt(string path, int x, int y)
    {
        Img s = Load(path); int i = (y * s.W + x) * 3;
        return string.Format("R={0} G={1} B={2}", s.P[i + 2], s.P[i + 1], s.P[i]);
    }

    // Cat mot vung anh (RAW hoac PNG) ra file PNG (dung de tao template)
    public static void Crop(string src, string dst, int x, int y, int w, int h)
    {
        using (var b = ToBitmap(Load(src)))
        using (var c = b.Clone(new Rectangle(x, y, w, h), PixelFormat.Format24bppRgb))
            c.Save(dst, ImageFormat.Png);
    }

    // ---------- doc dong ho dem nguoc tren o dat ("03:06:53") ----------
    // Chu dong ho: ruot xanh xam nhat (G,B >= 150, G~B, R<=G), vien xanh dam -> lay ruot lam mat na.
    // Tim moi cum diem ruot cao 7-16px lam "hat giong", quanh do tach cot thanh ky tu, giu chuoi dung mau dd:dd:dd.
    // Chu so phan loai bang lang gieng gan nhat (luoi 6x10 + ti le rong/cao) voi mau trong templates\timer_digits.txt.
    const int GW = 6, GH = 10;
    class Glyph { public int X0, X1, Y0, Y1; public bool Colon; public double[] F; }

    static bool TFill(Img s, int x, int y)
    {
        if (x < 0 || y < 0 || x >= s.W || y >= s.H) return false;
        int i = (y * s.W + x) * 3; int B = s.P[i], G = s.P[i + 1], R = s.P[i + 2];
        return G >= 150 && B >= 150 && Math.Abs(G - B) <= 35 && R <= G + 5;
    }

    static List<Glyph> Segment(Img s, int rx, int ry, int rw, int rh)
    {
        var res = new List<Glyph>();
        int[] rowCnt = new int[rh];
        for (int y = 0; y < rh; y++) for (int x = 0; x < rw; x++) if (TFill(s, rx + x, ry + y)) rowCnt[y]++;
        int bestA = -1, bestB = -1, a = -1, gap = 0;
        for (int y = 0; y <= rh; y++)
        {
            bool on = y < rh && rowCnt[y] >= 3;
            if (on) { if (a < 0) a = y; gap = 0; }
            else if (a >= 0)
            {
                gap++;
                if (gap > 1 || y == rh)
                {
                    int b = y - gap;
                    if (b - a > bestB - bestA) { bestA = a; bestB = b; }
                    a = -1; gap = 0;
                }
            }
        }
        if (bestA < 0 || bestB - bestA < 6) return res;
        int y0 = ry + bestA, y1 = ry + bestB, th = y1 - y0 + 1, c0 = -1;
        for (int x = 0; x <= rw; x++)
        {
            bool on = false;
            if (x < rw) for (int y = y0; y <= y1; y++) if (TFill(s, rx + x, y)) { on = true; break; }
            if (on) { if (c0 < 0) c0 = x; }
            else if (c0 >= 0) { AddGlyph(s, res, rx + c0, rx + x - 1, y0, y1, th); c0 = -1; }
        }
        return res;
    }

    static void AddGlyph(Img s, List<Glyph> res, int x0, int x1, int y0, int y1, int th)
    {
        int w = x1 - x0 + 1;
        if (w > th * 0.75 + 1)   // 2 chu dinh nhau -> tach o cot it diem nhat
        {
            int best = -1, bestC = int.MaxValue;
            for (int x = x0 + w / 3; x <= x1 - w / 3; x++)
            {
                int c = 0; for (int y = y0; y <= y1; y++) if (TFill(s, x, y)) c++;
                if (c < bestC) { bestC = c; best = x; }
            }
            AddGlyph(s, res, x0, best - 1, y0, y1, th); AddGlyph(s, res, best + 1, x1, y0, y1, th);
            return;
        }
        int gy0 = y1, gy1 = y0, cnt = 0;
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) if (TFill(s, x, y)) { cnt++; if (y < gy0) gy0 = y; if (y > gy1) gy1 = y; }
        if (cnt < 2) return;
        var g = new Glyph { X0 = x0, X1 = x1, Y0 = gy0, Y1 = gy1 };
        if (w <= 3 && cnt <= 12) g.Colon = true;
        else if (w <= 2 && (gy1 - gy0 + 1) < th * 0.6) return;
        if (!g.Colon)
        {
            g.F = new double[GW * GH + 1];
            int hh = y1 - y0 + 1;
            for (int gy = 0; gy < GH; gy++) for (int gx = 0; gx < GW; gx++)
            {
                int ax = x0 + gx * w / GW, bx = x0 + (gx + 1) * w / GW; if (bx <= ax) bx = ax + 1;
                int ay = y0 + gy * hh / GH, by = y0 + (gy + 1) * hh / GH; if (by <= ay) by = ay + 1;
                int on = 0, tot = 0;
                for (int y = ay; y < by; y++) for (int x = ax; x < bx; x++) { tot++; if (TFill(s, x, y)) on++; }
                g.F[gy * GW + gx] = tot > 0 ? on / (double)tot : 0;
            }
            g.F[GW * GH] = w / (double)hh * 2;
        }
        res.Add(g);
    }

    static List<KeyValuePair<char, double[]>> digitModel; static string digitModelPath;
    static List<KeyValuePair<char, double[]>> Model(string path)
    {
        if (digitModel != null && digitModelPath == path) return digitModel;
        var m = new List<KeyValuePair<char, double[]>>();
        if (File.Exists(path))
            foreach (var line in File.ReadAllLines(path))
            {
                var p = line.Trim().Split(' ');
                if (p.Length != GW * GH + 2 || p[0].Length != 1) continue;
                var f = new double[GW * GH + 1];
                for (int i = 0; i < f.Length; i++) f[i] = double.Parse(p[i + 1], System.Globalization.CultureInfo.InvariantCulture);
                m.Add(new KeyValuePair<char, double[]>(p[0][0], f));
            }
        digitModel = m; digitModelPath = path; return m;
    }

    static char Classify(double[] f, List<KeyValuePair<char, double[]>> model, out double dist)
    {
        char best = '?'; dist = double.MaxValue;
        foreach (var kv in model)
        {
            double d = 0; for (int i = 0; i < f.Length; i++) { double e = f[i] - kv.Value[i]; d += e * e; }
            if (d < dist) { dist = d; best = kv.Key; }
        }
        return best;
    }

    // Tim cac chuoi 8 ky tu dd:dd:dd trong vung. Tra ve danh sach glyph (8 cai) + vi tri.
    static List<List<Glyph>> FindTimerGlyphs(Img s, int rx, int ry, int rw, int rh)
    {
        if (rw <= 0) rw = s.W; if (rh <= 0) rh = s.H;
        int x0 = Math.Max(0, rx), y0 = Math.Max(0, ry), x1 = Math.Min(s.W, rx + rw), y1 = Math.Min(s.H, ry + rh);
        // hat giong: cot co >= 7 diem ruot lien tiep (net doc cua chu so)
        var seeds = new List<int[]>();
        for (int x = x0; x < x1; x += 3)
        {
            int run = 0;
            for (int y = y0; y < y1; y++)
            {
                if (TFill(s, x, y)) run++;
                else { if (run >= 7 && run <= 16) seeds.Add(new[] { x, y - run / 2 }); run = 0; }
            }
        }
        var found = new List<List<Glyph>>();
        foreach (var sd in seeds)
        {
            bool done = false;
            foreach (var f in found)
                if (sd[0] >= f[0].X0 - 4 && sd[0] <= f[7].X1 + 4 && sd[1] >= f[0].Y0 - 4 && sd[1] <= f[0].Y1 + 4) { done = true; break; }
            if (done) continue;
            var gs = Segment(s, sd[0] - 70, sd[1] - 11, 140, 22);
            for (int i = 0; i + 8 <= gs.Count; i++)
            {
                bool ok = true;
                for (int k = 0; k < 8 && ok; k++)
                {
                    bool colon = (k == 2 || k == 5);
                    if (gs[i + k].Colon != colon) ok = false;
                    if (k > 0 && gs[i + k].X0 - gs[i + k - 1].X1 > 6) ok = false;
                }
                if (!ok) continue;
                if (sd[0] < gs[i].X0 - 2 || sd[0] > gs[i + 7].X1 + 2) continue;
                bool dup = false;
                foreach (var f in found) if (Math.Abs(f[0].X0 - gs[i].X0) < 10 && Math.Abs(f[0].Y0 - gs[i].Y0) < 10) { dup = true; break; }
                if (!dup) found.Add(gs.GetRange(i, 8));
                break;
            }
        }
        return found;
    }

    // Doc dong ho tren anh chup: moi dong "X Y hh:mm:ss khoang_cach_lon_nhat" (chu so khong chac -> '?').
    public static List<string> ReadTimers(string screenPath, string modelPath, int rx, int ry, int rw, int rh)
    {
        Img s = Screen(screenPath); var model = Model(modelPath);
        var res = new List<string>();
        foreach (var gs in FindTimerGlyphs(s, rx, ry, rw, rh))
        {
            var sb = new StringBuilder(); double worst = 0;
            foreach (var g in gs)
            {
                if (g.Colon) { sb.Append(':'); continue; }
                double d; char c = Classify(g.F, model, out d);
                if (d > worst) worst = d; sb.Append(c);
            }
            res.Add(string.Format(System.Globalization.CultureInfo.InvariantCulture, "{0} {1} {2} {3:F2}",
                (gs[0].X0 + gs[7].X1) / 2, (gs[0].Y0 + gs[0].Y1) / 2, sb, worst));
        }
        return res;
    }

    // Tao mau chu so (de huan luyen): moi dong "chu_so f1 ... f61" cho dong ho thu i co gia tri 'text' (dang hh:mm:ss)
    public static List<string> TimerSamples(string screenPath, string text, int rx, int ry, int rw, int rh)
    {
        Img s = Screen(screenPath); var res = new List<string>();
        foreach (var gs in FindTimerGlyphs(s, rx, ry, rw, rh))
            for (int k = 0; k < 8; k++)
            {
                if (gs[k].Colon) continue;
                var sb = new StringBuilder(); sb.Append(text[k]);
                foreach (var v in gs[k].F) sb.Append(' ').Append(v.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture));
                res.Add(sb.ToString());
            }
        return res;
    }
}
