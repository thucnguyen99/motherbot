using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

// Doc dong ho dem nguoc tren tab "To doi" (vd "11:58:28") o man Thu cuoi tham hiem, anh 1600x900.
// Chu: ruot vang nhat (R>=225, G 185-238, B 90-165), vien nau dam; nen tab cam (khong chon) / kem (dang chon, B>=190).
// Tach cot theo mat na ruot -> 8 ky tu dd:dd:dd; chu so phan loai bang lang gieng gan nhat (luoi 6x10 + ti le rong/cao)
// voi mau trong tham_hiem\mau\so_tab.txt (giong cach doc dong ho o dat cua nong trai trong Vision.cs).
public static class TabTimer
{
    const int GW = 6, GH = 10;
    class Img { public int W, H; public byte[] P; }   // P: R,G,B
    class Glyph { public int X0, X1, Y0, Y1; public bool Colon; public double[] F; }

    static Img Load(string path)
    {
        if (path.EndsWith(".raw", StringComparison.OrdinalIgnoreCase))
        {
            byte[] b = File.ReadAllBytes(path);
            int w = BitConverter.ToInt32(b, 0), h = BitConverter.ToInt32(b, 4);
            int hdr = b.Length - w * h * 4;   // screencap RAW: header 12 hoac 16 byte + RGBA
            var im = new Img { W = w, H = h, P = new byte[w * h * 3] };
            for (int i = 0, s = hdr; i < w * h; i++, s += 4) { im.P[i * 3] = b[s]; im.P[i * 3 + 1] = b[s + 1]; im.P[i * 3 + 2] = b[s + 2]; }
            return im;
        }
        using (var bmp = new Bitmap(path))
        {
            var im = new Img { W = bmp.Width, H = bmp.Height, P = new byte[bmp.Width * bmp.Height * 3] };
            var d = bmp.LockBits(new Rectangle(0, 0, im.W, im.H), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
            var raw = new byte[d.Stride * im.H]; Marshal.Copy(d.Scan0, raw, 0, raw.Length); bmp.UnlockBits(d);
            for (int y = 0; y < im.H; y++) for (int x = 0; x < im.W; x++)
            { int s = y * d.Stride + x * 3, t = (y * im.W + x) * 3; im.P[t] = raw[s + 2]; im.P[t + 1] = raw[s + 1]; im.P[t + 2] = raw[s]; }
            return im;
        }
    }

    static bool Fill(Img s, int x, int y)
    {
        if (x < 0 || y < 0 || x >= s.W || y >= s.H) return false;
        int i = (y * s.W + x) * 3; int R = s.P[i], G = s.P[i + 1], B = s.P[i + 2];
        return R >= 225 && G >= 185 && G <= 238 && B >= 90 && B <= 165;
    }

    // Tach cac ky tu trong vung: dai hang co nhieu diem ruot nhat (cao >= 10px), roi tach theo cot
    static List<Glyph> Segment(Img s, int rx, int ry, int rw, int rh)
    {
        var res = new List<Glyph>();
        int[] rowCnt = new int[rh];
        for (int y = 0; y < rh; y++) for (int x = 0; x < rw; x++) if (Fill(s, rx + x, ry + y)) rowCnt[y]++;
        int bestA = -1, bestB = -1, a = -1, gap = 0;
        for (int y = 0; y <= rh; y++)
        {
            bool on = y < rh && rowCnt[y] >= 2;
            if (on) { if (a < 0) a = y; gap = 0; }
            else if (a >= 0)
            {
                gap++;
                if (gap > 1 || y == rh) { int b = y - gap; if (b - a > bestB - bestA) { bestA = a; bestB = b; } a = -1; gap = 0; }
            }
        }
        if (bestA < 0 || bestB - bestA < 10) return res;
        int y0 = ry + bestA, y1 = ry + bestB, th = y1 - y0 + 1, c0 = -1;
        for (int x = 0; x <= rw; x++)
        {
            bool on = false;
            if (x < rw) for (int y = y0; y <= y1; y++) if (Fill(s, rx + x, y)) { on = true; break; }
            if (on) { if (c0 < 0) c0 = x; }
            else if (c0 >= 0) { AddGlyph(s, res, rx + c0, rx + x - 1, y0, y1, th); c0 = -1; }
        }
        return res;
    }

    static void AddGlyph(Img s, List<Glyph> res, int x0, int x1, int y0, int y1, int th)
    {
        int w = x1 - x0 + 1, gy0 = y1, gy1 = y0, cnt = 0;
        for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) if (Fill(s, x, y)) { cnt++; if (y < gy0) gy0 = y; if (y > gy1) gy1 = y; }
        if (cnt < 3) return;
        var g = new Glyph { X0 = x0, X1 = x1, Y0 = gy0, Y1 = gy1 };
        // dau ":" = 2 cham nho tach roi (cao it hon nua chieu cao chu, it diem)
        if (w <= 5 && cnt <= 25) g.Colon = true;
        else if ((gy1 - gy0 + 1) < th * 0.6) return;   // vun nho (khong phai chu so)
        if (!g.Colon)
        {
            g.F = new double[GW * GH + 1];
            int hh = gy1 - gy0 + 1;
            for (int gy = 0; gy < GH; gy++) for (int gx = 0; gx < GW; gx++)
            {
                int ax = x0 + gx * w / GW, bx = x0 + (gx + 1) * w / GW; if (bx <= ax) bx = ax + 1;
                int ay = gy0 + gy * hh / GH, by = gy0 + (gy + 1) * hh / GH; if (by <= ay) by = ay + 1;
                int on = 0, tot = 0;
                for (int y = ay; y < by; y++) for (int x = ax; x < bx; x++) { tot++; if (Fill(s, x, y)) on++; }
                g.F[gy * GW + gx] = tot > 0 ? on / (double)tot : 0;
            }
            g.F[GW * GH] = w / (double)hh * 2;
        }
        res.Add(g);
    }

    // Lay 8 ky tu dung mau dd:dd:dd (null neu khong co)
    static List<Glyph> Clock(Img s, int rx, int ry, int rw, int rh)
    {
        var gs = Segment(s, rx, ry, rw, rh);
        for (int i = 0; i + 8 <= gs.Count; i++)
        {
            bool ok = true;
            for (int k = 0; k < 8 && ok; k++) if (gs[i + k].Colon != (k == 2 || k == 5)) ok = false;
            if (ok) return gs.GetRange(i, 8);
        }
        return null;
    }

    static List<KeyValuePair<char, double[]>> Model(string path)
    {
        var m = new List<KeyValuePair<char, double[]>>();
        if (!File.Exists(path)) return m;
        foreach (var line in File.ReadAllLines(path))
        {
            var p = line.Trim().Split(' ');
            if (p.Length != GW * GH + 2 || p[0].Length != 1) continue;
            var f = new double[GW * GH + 1];
            for (int i = 0; i < f.Length; i++) f[i] = double.Parse(p[i + 1], System.Globalization.CultureInfo.InvariantCulture);
            m.Add(new KeyValuePair<char, double[]>(p[0][0], f));
        }
        return m;
    }

    // Doc dong ho trong vung. Tra ve "hh:mm:ss khoang_cach_lon_nhat" (chu so khong chac -> '?'), "" neu khong thay dong ho
    public static string Read(string screenPath, string modelPath, int rx, int ry, int rw, int rh)
    {
        var s = Load(screenPath); var model = Model(modelPath);
        var gs = Clock(s, rx, ry, rw, rh);
        if (gs == null) return "";
        var sb = new StringBuilder(); double worst = 0;
        foreach (var g in gs)
        {
            if (g.Colon) { sb.Append(':'); continue; }
            char best = '?'; double dist = double.MaxValue;
            foreach (var kv in model)
            {
                double d = 0; for (int i = 0; i < g.F.Length; i++) { double e = g.F[i] - kv.Value[i]; d += e * e; }
                if (d < dist) { dist = d; best = kv.Key; }
            }
            if (dist > worst) worst = dist; sb.Append(best);
        }
        return sb.ToString() + " " + worst.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture);
    }

    // Tao mau hoc: moi chu so 1 dong "chu_so f1 ... f61" cho dong ho co gia tri 'text' (hh:mm:ss)
    public static List<string> Samples(string screenPath, string text, int rx, int ry, int rw, int rh)
    {
        var s = Load(screenPath); var res = new List<string>();
        var gs = Clock(s, rx, ry, rw, rh);
        if (gs == null) return res;
        for (int k = 0; k < 8; k++)
        {
            if (gs[k].Colon) continue;
            var sb = new StringBuilder(); sb.Append(text[k]);
            foreach (var v in gs[k].F) sb.Append(' ').Append(v.ToString("0.###", System.Globalization.CultureInfo.InvariantCulture));
            res.Add(sb.ToString());
        }
        return res;
    }

    // So ky tu tach duoc (de kiem tra)
    public static string Debug(string screenPath, int rx, int ry, int rw, int rh)
    {
        var s = Load(screenPath); var gs = Segment(s, rx, ry, rw, rh); var sb = new StringBuilder();
        foreach (var g in gs) sb.Append(g.Colon ? ":" : "#").Append("[").Append(g.X0).Append("-").Append(g.X1).Append(",").Append(g.Y0).Append("-").Append(g.Y1).Append("] ");
        return sb.ToString();
    }
}
