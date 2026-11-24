using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

// So anh mau cho Tuong Da. Moi anh dua ve 960x540 RGB (kich thuoc ban ghi lam mau quan_sat_nhanh -W 960 -H 540):
//  - anh chup man hinh "adb exec-out screencap" (RAW 1600x900 RGBA) -> thu nho 0.6
//  - anh JPG/PNG cua ban ghi (960x540) -> giu nguyen
// Diem khop = sai khac trung binh moi kenh (0 = giong het), lay diem nho nhat khi dich trong +-r px.
public static class TdVision
{
    public const int W = 960, H = 540;
    static readonly Dictionary<string, KeyValuePair<byte[], int[]>> cache = new Dictionary<string, KeyValuePair<byte[], int[]>>(StringComparer.OrdinalIgnoreCase);

    static byte[] FromBitmap(Bitmap src, out int w, out int h)
    {
        w = src.Width; h = src.Height;
        var d = src.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
        var raw = new byte[d.Stride * h]; Marshal.Copy(d.Scan0, raw, 0, raw.Length); src.UnlockBits(d);
        var p = new byte[w * h * 3];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        { int s = y * d.Stride + x * 3, t = (y * w + x) * 3; p[t] = raw[s + 2]; p[t + 1] = raw[s + 1]; p[t + 2] = raw[s]; }
        return p;
    }

    static Bitmap Scale(Bitmap b)
    {
        if (b.Width == W && b.Height == H) return b;
        var o = new Bitmap(W, H, PixelFormat.Format24bppRgb);
        using (var g = Graphics.FromImage(o)) { g.InterpolationMode = InterpolationMode.HighQualityBicubic; g.PixelOffsetMode = PixelOffsetMode.HighQuality; g.DrawImage(b, 0, 0, W, H); }
        return o;
    }

    // Luu anh man hinh (raw screencap hoac anh) thanh JPG 960x540 (anh log)
    public static void SaveJpg(string path, string outPath)
    {
        using (var bmp = LoadBitmap(path))
        {
            var sm = Scale(bmp);
            try { sm.Save(outPath, ImageFormat.Jpeg); }
            finally { if (!ReferenceEquals(sm, bmp)) sm.Dispose(); }
        }
    }

    // Anh man hinh (raw screencap hoac jpg/png) -> RGB 960x540
    public static byte[] Screen(string path)
    {
        using (var bmp = LoadBitmap(path))
        {
            var sm = Scale(bmp);
            try { int w, h; return FromBitmap(sm, out w, out h); }
            finally { if (!ReferenceEquals(sm, bmp)) sm.Dispose(); }
        }
    }

    static Bitmap LoadBitmap(string path)
    {
        Bitmap bmp;
        if (path.EndsWith(".raw", StringComparison.OrdinalIgnoreCase))
        {
            byte[] b = File.ReadAllBytes(path);
            int w = BitConverter.ToInt32(b, 0), h = BitConverter.ToInt32(b, 4), hdr = b.Length - w * h * 4;
            bmp = new Bitmap(w, h, PixelFormat.Format24bppRgb);
            var d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format24bppRgb);
            var row = new byte[d.Stride];
            for (int y = 0; y < h; y++)
            {
                for (int x = 0; x < w; x++) { int s = hdr + (y * w + x) * 4; row[x * 3] = b[s + 2]; row[x * 3 + 1] = b[s + 1]; row[x * 3 + 2] = b[s]; }
                Marshal.Copy(row, 0, d.Scan0 + y * d.Stride, d.Stride);
            }
            bmp.UnlockBits(d);
        }
        else { using (var f = new Bitmap(path)) bmp = new Bitmap(f); }   // khong giu khoa file
        return bmp;
    }

    static KeyValuePair<byte[], int[]> Tpl(string path)
    {
        KeyValuePair<byte[], int[]> t;
        if (!cache.TryGetValue(path, out t))
        {
            using (var b = new Bitmap(path)) { int w, h; var p = FromBitmap(b, out w, out h); t = new KeyValuePair<byte[], int[]>(p, new[] { w, h }); }
            cache[path] = t;
        }
        return t;
    }

    // Diem khop tot nhat cua mau (goc tren trai mau o quanh (x0,y0), dich +-r) va vi tri TAM tren anh 960x540
    public static double Match(byte[] p, string tplPath, int x0, int y0, int r, out int cx, out int cy)
    {
        var t = Tpl(tplPath); byte[] tp = t.Key; int tw = t.Value[0], th = t.Value[1];
        double best = 999; cx = -1; cy = -1;
        for (int dy = -r; dy <= r; dy++)
            for (int dx = -r; dx <= r; dx++)
            {
                int ox = x0 + dx, oy = y0 + dy;
                if (ox < 0 || oy < 0 || ox + tw > W || oy + th > H) continue;
                long s = 0; int n = 0;
                for (int y = 0; y < th; y += 2)
                    for (int x = 0; x < tw; x += 2)
                    {
                        int i = ((oy + y) * W + ox + x) * 3, j = (y * tw + x) * 3;
                        s += Math.Abs(p[i] - tp[j]) + Math.Abs(p[i + 1] - tp[j + 1]) + Math.Abs(p[i + 2] - tp[j + 2]); n += 3;
                    }
                double sc = s / (double)n;
                if (sc < best) { best = sc; cx = ox + tw / 2; cy = oy + th / 2; }
            }
        return best;
    }
    public static double Score(byte[] p, string tplPath, int x0, int y0, int r)
    {
        int cx, cy; return Match(p, tplPath, x0, y0, r, out cx, out cy);
    }

    // ---------- ngam ban: hong tam (diem yeu boss) + cung net dut ----------
    // Tim mau trong ca vung (x0,y0,w,h), buoc 2px. Tra ve diem khop tot nhat + tam.
    public static double FindIn(byte[] p, string tplPath, int x0, int y0, int w, int h, out int cx, out int cy)
    {
        var t = Tpl(tplPath); int tw = t.Value[0], th = t.Value[1];
        double best = 999; cx = -1; cy = -1;
        for (int oy = y0; oy + th <= Math.Min(H, y0 + h); oy += 2)
            for (int ox = x0; ox + tw <= Math.Min(W, x0 + w); ox += 2)
            {
                int bx, by; double s = Match(p, tplPath, ox, oy, 0, out bx, out by);
                if (s < best) { best = s; cx = bx; cy = by; }
            }
        return best;
    }

    // Cham trang cua cung net dut: diem trang (R,G,B > 215) tren anh dang keo ma KHONG trang tren anh nen (truoc khi keo),
    // gom thanh cum nho (3-90 diem, khung <= 14px). Bo vung quanh ngon tay (bong bong "Tra ve de huy" + cham sat tay).
    // Tra ve mang [x0,y0,x1,y1,...] tam cac cum (toa do 960x540).
    public static int[] Dots(byte[] p, byte[] bg, int rx0, int ry0, int rx1, int ry1, int fx, int fy, int fr)
    {
        int w = rx1 - rx0, h = ry1 - ry0; var on = new bool[w * h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            int X = rx0 + x, Y = ry0 + y; int i = (Y * W + X) * 3;
            if ((X - fx) * (X - fx) + (Y - fy) * (Y - fy) < fr * fr) continue;
            bool white = p[i] > 215 && p[i + 1] > 215 && p[i + 2] > 215;
            bool wasWhite = bg[i] > 200 && bg[i + 1] > 200 && bg[i + 2] > 200;
            on[y * w + x] = white && !wasWhite;
        }
        var res = new List<int>(); var seen = new bool[w * h]; var stack = new Stack<int>();
        for (int s = 0; s < on.Length; s++)
        {
            if (!on[s] || seen[s]) continue;
            int n = 0, sx = 0, sy = 0, minx = 9999, maxx = -1, miny = 9999, maxy = -1;
            stack.Push(s); seen[s] = true;
            while (stack.Count > 0)
            {
                int q = stack.Pop(); int qx = q % w, qy = q / w; n++; sx += qx; sy += qy;
                if (qx < minx) minx = qx; if (qx > maxx) maxx = qx; if (qy < miny) miny = qy; if (qy > maxy) maxy = qy;
                int[] nb = { q - 1, q + 1, q - w, q + w };
                foreach (int r in nb)
                {
                    if (r < 0 || r >= on.Length || seen[r] || !on[r]) continue;
                    if ((r == q - 1 && qx == 0) || (r == q + 1 && qx == w - 1)) continue;
                    seen[r] = true; stack.Push(r);
                }
            }
            if (n >= 3 && n <= 90 && maxx - minx <= 14 && maxy - miny <= 14) { res.Add(rx0 + sx / n); res.Add(ry0 + sy / n); }
        }
        return res.ToArray();
    }

    // Khop parabol y = a x^2 + b x + c (binh phuong toi thieu) qua cac cham [x0,y0,...]; tra ve {a,b,c} hoac null
    public static double[] Parabola(int[] pts)
    {
        int n = pts.Length / 2; if (n < 4) return null;
        double s0 = n, s1 = 0, s2 = 0, s3 = 0, s4 = 0, t0 = 0, t1 = 0, t2 = 0;
        for (int i = 0; i < n; i++)
        {
            double x = pts[2 * i], y = pts[2 * i + 1], x2 = x * x;
            s1 += x; s2 += x2; s3 += x2 * x; s4 += x2 * x2; t0 += y; t1 += x * y; t2 += x2 * y;
        }
        // giai he 3x3 (Cramer): [s4 s3 s2; s3 s2 s1; s2 s1 s0] [a b c] = [t2 t1 t0]
        double D = Det(s4, s3, s2, s3, s2, s1, s2, s1, s0);
        if (Math.Abs(D) < 1e-9) return null;
        double a = Det(t2, s3, s2, t1, s2, s1, t0, s1, s0) / D;
        double b = Det(s4, t2, s2, s3, t1, s1, s2, t0, s0) / D;
        double c = Det(s4, s3, t2, s3, s2, t1, s2, s1, t0) / D;
        return new[] { a, b, c };
    }
    // Do lech cua cung so voi hong tam (tx,ty): >0 = cung di THAP hon hong tam tai x = tx (can ban xa/cao hon), <0 = cao hon.
    // Loc cham gia (20/11 ban ghi): quanh nhan vat (x < xMin), bieu tuong tren cung (y < 100), vong sang hong tam (< 28px).
    // Khop 2 lan, lan 2 bo cham lech > 10px. Tra ve {lech, so cham dung}; so cham < 5 -> {NaN, n}
    public static double[] ArcError(byte[] p, byte[] bg, int tx, int ty, int xMin, int fx, int fy)
    {
        // tu y = 45 (cung ban xa vot len sat mep tren, 20/11 22:36); bo o dem nguoc "Vong" (so nhay) va "Dano"
        var d = Dots(p, bg, xMin, 45, Math.Min(W, tx + 40), 440, fx, fy, 60);
        var keep = new List<int>();
        for (int i = 0; i < d.Length; i += 2)
        {
            int dx = d[i] - tx, dy = d[i + 1] - ty;
            if (dx * dx + dy * dy < 28 * 28) continue;
            if (d[i + 1] < 100 && d[i] >= 395 && d[i] <= 720) continue;
            keep.Add(d[i]); keep.Add(d[i + 1]);
        }
        var pts = keep.ToArray();
        for (int pass = 0; pass < 2; pass++)
        {
            var pb = Parabola(pts);
            if (pb == null) return new[] { double.NaN, pts.Length / 2 };
            if (pass == 1) return new[] { pb[0] * tx * tx + pb[1] * tx + pb[2] - ty, pts.Length / 2 };
            var good = new List<int>();
            for (int i = 0; i < pts.Length; i += 2)
            {
                double y = pb[0] * pts[i] * pts[i] + pb[1] * pts[i] + pb[2];
                if (Math.Abs(y - pts[i + 1]) <= 10) { good.Add(pts[i]); good.Add(pts[i + 1]); }
            }
            if (good.Count / 2 < 5) return new[] { double.NaN, good.Count / 2 };
            pts = good.ToArray();
        }
        return new[] { double.NaN, 0 };
    }

    // Duong dan theo cung net dut (net dut NGAN, co khi khong toi hong tam -> tu keo dai theo vat ly):
    // cham cach deu THEO THOI GIAN bay (ban ghi 20/11): khoang ngang 33,32,29,29,27,27,25 (giam nhe), sai phan bac 2 theo doc
    // ~4-5 px (trong luc, ban kinh vong tron ~240). Lan theo chuoi cham tu phia nhan vat: cham ke tiep phai o dung cho du doan
    // (van toc + trong luc, cho hut 1 cham) -> cham gia (vong sang hong tam, nhan vat) bi loai.
    // x(i), y(i) theo bac 2 (y: gia toc = trong luc; it cham thi dung trong luc mac dinh gPx), keo dai toi x = tx.
    // Tra ve {lech = y(tx) - ty (>0: dan di THAP hon hong tam), so cham trong chuoi, so buoc keo dai tu cham cuoi}
    // hoac {NaN, n, 0} khi chuoi < 4 cham. track (neu khac null) nhan toa do du doan moi buoc (de ve / kiem tra chuong ngai).
    public static double[] ArcPredict(byte[] p, byte[] bg, int tx, int ty, int xMin, int fx, int fy, double gPx, List<double> track)
    {
        // chi lay cham TRUOC hong tam (vong sang quanh hong tam ban kinh ~45 tao cham gia, 20/11) -> phan con lai tu keo dai
        var d = Dots(p, bg, xMin, 45, Math.Min(W, tx - 15), 440, fx, fy, 60);
        var pts = new List<int[]>();
        for (int i = 0; i < d.Length; i += 2)
        {
            int dx = d[i] - tx, dy = d[i + 1] - ty;
            if (dx * dx + dy * dy < 45 * 45) continue;
            if (d[i + 1] < 100 && d[i] >= 395 && d[i] <= 720) continue;
            pts.Add(new[] { d[i], d[i + 1] });
        }
        pts.Sort((a, b) => a[0].CompareTo(b[0]));
        List<double[]> best = null;
        for (int s = 0; s < Math.Min(4, pts.Count); s++)
            for (int n2 = s + 1; n2 < pts.Count && pts[n2][0] - pts[s][0] <= 50; n2++)
            {
                double vx = pts[n2][0] - pts[s][0], vy = pts[n2][1] - pts[s][1];
                if (vx < 15) continue;
                var chain = new List<double[]> { new double[] { 0, pts[s][0], pts[s][1] }, new double[] { 1, pts[n2][0], pts[n2][1] } };
                double cx = pts[n2][0], cy = pts[n2][1], t = 1; int last = n2;
                while (true)
                {
                    bool found = false;
                    for (int step = 1; step <= 2 && !found; step++)
                    {
                        double px = cx, py = cy, pvx = vx, pvy = vy;
                        for (int k = 0; k < step; k++) { pvy += gPx; px += pvx; py += pvy; }
                        for (int j = last + 1; j < pts.Count; j++)
                        {
                            if (Math.Abs(pts[j][0] - px) <= 8 + 3 * step && Math.Abs(pts[j][1] - py) <= 8 + 3 * step)
                            {
                                vx = (pts[j][0] - cx) / step; vy = (pts[j][1] - cy) / step - gPx * (step - 1) / 2.0;
                                cx = pts[j][0]; cy = pts[j][1]; t += step; last = j;
                                chain.Add(new double[] { t, cx, cy }); found = true; break;
                            }
                        }
                    }
                    if (!found) break;
                }
                if (best == null || chain.Count > best.Count) best = chain;
            }
        if (best == null || best.Count < 4) return new[] { double.NaN, best == null ? 0 : best.Count, 0 };
        // x(t) = a0 + a1 t + a2 t^2 (giam toc nhe; < 6 cham -> a2 = 0), y(t) = b0 + b1 t + b2 t^2 (< 6 cham -> b2 = gPx/2)
        int n = best.Count; bool full = n >= 6;
        double[] ax = FitT(best, 1, full ? -1 : 0), ay = FitT(best, 2, full ? -1 : gPx / 2);
        double tl = best[n - 1][0], tStar = double.NaN;
        for (double tt = tl; tt <= tl + 80; tt += 0.05)
        {
            double xx = ax[0] + ax[1] * tt + ax[2] * tt * tt;
            if (track != null && Math.Abs(tt - Math.Round(tt)) < 1e-6) { track.Add(xx); track.Add(ay[0] + ay[1] * tt + ay[2] * tt * tt); }
            if (xx >= tx) { tStar = tt; break; }
            if (ax[1] + 2 * ax[2] * tt <= 0.5) break;   // dan khong con bay sang phai
        }
        if (double.IsNaN(tStar)) return new[] { double.NaN, n, 0 };
        double yStar = ay[0] + ay[1] * tStar + ay[2] * tStar * tStar;
        return new[] { yStar - ty, n, tStar - tl };
    }
    // Khop q(t) = c0 + c1 t + c2 t^2 theo cot col cua chain {t,x,y}; c2Fixed >= 0 -> co dinh c2 (chi khop c0, c1); -1 -> khop ca 3
    static double[] FitT(List<double[]> ch, int col, double c2Fixed)
    {
        int n = ch.Count;
        if (c2Fixed >= 0 || n < 3)
        {
            double c2 = c2Fixed >= 0 ? c2Fixed : 0, st = 0, stt = 0, sq = 0, stq = 0;
            foreach (var r in ch) { double q = r[col] - c2 * r[0] * r[0]; st += r[0]; stt += r[0] * r[0]; sq += q; stq += r[0] * q; }
            double den = n * stt - st * st; double c1 = den == 0 ? 0 : (n * stq - st * sq) / den, c0 = (sq - c1 * st) / n;
            return new[] { c0, c1, c2 };
        }
        double s1 = 0, s2 = 0, s3 = 0, s4 = 0, t0 = 0, t1 = 0, t2 = 0;
        foreach (var r in ch) { double t = r[0], t_2 = t * t, q = r[col]; s1 += t; s2 += t_2; s3 += t_2 * t; s4 += t_2 * t_2; t0 += q; t1 += t * q; t2 += t_2 * q; }
        double D = Det(s4, s3, s2, s3, s2, s1, s2, s1, n);
        if (Math.Abs(D) < 1e-9) return FitT(ch, col, 0);
        return new[] { Det(s4, s3, t2, s3, s2, t1, s2, s1, t0) / D, Det(s4, t2, s2, s3, t1, s1, s2, t0, n) / D, Det(t2, s3, s2, t1, s2, s1, t0, s1, n) / D };
    }

    // Vong tron sang quanh nhan vat (hien khi toi luot): tam = nhan vat, ban kinh ~ do zoom (20/11: 220 / 246 man 960).
    // Hough theo huong bien thien do sang, lam o nua kich thuoc (480x270). Ban kinh rMin..rMax, tam trong vung (cx0..cx1, cy0..cy1)
    // (toa do man 960). Tra ve {cx, cy, r, diem} (diem = so phieu / chu vi, cang lon cang chac).
    public static double[] FindCircle(byte[] p, int rMin, int rMax, int cx0, int cx1, int cy0, int cy1)
    {
        int w = W / 2, h = H / 2;
        var g = new float[w * h];
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
        {
            int s = 0; for (int dy = 0; dy < 2; dy++) for (int dx = 0; dx < 2; dx++) { int i = ((2 * y + dy) * W + 2 * x + dx) * 3; s += p[i] + p[i + 1] + p[i + 2]; }
            g[y * w + x] = s / 12f;
        }
        int r0 = rMin / 2, r1 = rMax / 2, ax0 = cx0 / 2, ax1 = cx1 / 2, ay0 = cy0 / 2, ay1 = cy1 / 2;
        int nr = r1 - r0 + 1, aw = ax1 - ax0 + 1, ah = ay1 - ay0 + 1;
        var acc = new int[nr * aw * ah];
        // bien manh: |gradient| >= nguong (Sobel), bo vung thanh item duoi cung (y >= 215 nua kich thuoc = 430 man 960)
        for (int y = 1; y < Math.Min(h - 1, 215); y++)
            for (int x = 1; x < w - 1; x++)
            {
                float gx = (g[(y - 1) * w + x + 1] + 2 * g[y * w + x + 1] + g[(y + 1) * w + x + 1]) - (g[(y - 1) * w + x - 1] + 2 * g[y * w + x - 1] + g[(y + 1) * w + x - 1]);
                float gy = (g[(y + 1) * w + x - 1] + 2 * g[(y + 1) * w + x] + g[(y + 1) * w + x + 1]) - (g[(y - 1) * w + x - 1] + 2 * g[(y - 1) * w + x] + g[(y - 1) * w + x + 1]);
                float m = (float)Math.Sqrt(gx * gx + gy * gy);
                if (m < 40) continue;
                float ux = gx / m, uy = gy / m;
                for (int r = r0; r <= r1; r++)
                    for (int sgn = -1; sgn <= 1; sgn += 2)
                    {
                        int cx = (int)Math.Round(x + sgn * r * ux), cy = (int)Math.Round(y + sgn * r * uy);
                        if (cx < ax0 || cx > ax1 || cy < ay0 || cy > ay1) continue;
                        acc[((r - r0) * ah + (cy - ay0)) * aw + (cx - ax0)]++;
                    }
            }
        // lam tron 3x3 + chuan hoa theo chu vi, lay cuc dai
        double best = -1; int br = 0, bx = 0, by = 0;
        for (int r = 0; r < nr; r++)
            for (int y = 1; y < ah - 1; y++)
                for (int x = 1; x < aw - 1; x++)
                {
                    int s = 0; for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) s += acc[(r * ah + y + dy) * aw + x + dx];
                    double sc = s / (2 * Math.PI * (r + r0));
                    if (sc > best) { best = sc; br = r + r0; bx = x + ax0; by = y + ay0; }
                }
        return new[] { bx * 2.0, by * 2.0, br * 2.0, best };
    }

    static double Det(double a, double b, double c, double d, double e, double f, double g, double h, double i)
    { return a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g); }
}
