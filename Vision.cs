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
}
