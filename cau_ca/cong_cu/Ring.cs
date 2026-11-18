using System;
using System.Collections.Generic;

// Do ban kinh vong sang dang co vao quanh qua cau cam (anh 640x360, RGB 3 byte/pixel)
public static class Ring
{
    // tam qua cau cam (anh 640x360). Mac dinh do o cho dung cua tai khoan 1; vi tri giao dien cau ca
    // doi theo cho nhan vat dung -> moi vong tron goi FindBall() de lay tam that
    public static int CX = 564, CY = 290;

    static bool IsOrange(int R, int G, int B) { return R > 200 && G > 100 && G < 210 && B < 90; }

    // Tim qua cau cam trong vung goc phai duoi: cum cam dac (ban kinh ~13px) VA co vong xanh duong o ban kinh ~37px
    // (tui Ba lo cung mau cam nhung khong co vong xanh). Nhanh: thu o tam cu truoc.
    public static bool FindBall(byte[] p, int w, int h, out int cx, out int cy)
    {
        cx = 0; cy = 0;
        if (BallAt(p, w, h, CX, CY)) { cx = CX; cy = CY; return true; }
        // luoi o 8x8: dem diem cam, thu cac o nhieu nhat
        int gx0 = 440, gy0 = 180, gw = (w - gx0) / 8, gh = (h - gy0) / 8;
        var cnt = new int[gw * gh];
        for (int y = gy0; y < gy0 + gh * 8; y += 2)
            for (int x = gx0; x < gx0 + gw * 8; x += 2)
            {
                int i = (y * w + x) * 3;
                if (IsOrange(p[i], p[i + 1], p[i + 2])) cnt[((y - gy0) / 8) * gw + (x - gx0) / 8]++;
            }
        for (int tries = 0; tries < 4; tries++)
        {
            int best = -1, bv = 4;
            for (int k = 0; k < cnt.Length; k++) if (cnt[k] > bv) { bv = cnt[k]; best = k; }
            if (best < 0) return false;
            int x0 = gx0 + (best % gw) * 8 + 4, y0 = gy0 + (best / gw) * 8 + 4;
            // tam cum cam quanh o nay
            int n = 0; long sx = 0, sy = 0;
            for (int y = Math.Max(0, y0 - 16); y < Math.Min(h, y0 + 16); y++)
                for (int x = Math.Max(0, x0 - 16); x < Math.Min(w, x0 + 16); x++)
                {
                    int i = (y * w + x) * 3;
                    if (IsOrange(p[i], p[i + 1], p[i + 2])) { n++; sx += x; sy += y; }
                }
            if (n > 0)
            {
                int ax = (int)(sx / n), ay = (int)(sy / n);
                if (BallAt(p, w, h, ax, ay)) { cx = ax; cy = ay; return true; }
            }
            // bo cac o quanh day roi thu cum khac
            for (int dy = -3; dy <= 3; dy++) for (int dx = -3; dx <= 3; dx++)
                {
                    int gxx = best % gw + dx, gyy = best / gw + dy;
                    if (gxx >= 0 && gyy >= 0 && gxx < gw && gyy < gh) cnt[gyy * gw + gxx] = 0;
                }
        }
        return false;
    }

    // (x,y) co phai tam qua cau: >= 20/49 diem cam quanh tam va >= 7/16 tia gap mau xanh duong o ban kinh 30-44
    static bool BallAt(byte[] p, int w, int h, int x0, int y0)
    {
        if (x0 < 8 || y0 < 8 || x0 >= w - 8 || y0 >= h - 8) return false;
        int k = 0;
        for (int y = y0 - 6; y <= y0 + 6; y += 2)
            for (int x = x0 - 6; x <= x0 + 6; x += 2)
            {
                int i = (y * w + x) * 3;
                if (IsOrange(p[i], p[i + 1], p[i + 2])) k++;
            }
        if (k < 20) return false;
        int rays = 0;
        for (int a = 0; a < 16; a++)
            for (int r = 30; r <= 44; r++)
            {
                int x = x0 + DX[a * 100 + r], y = y0 + DY[a * 100 + r];
                if (x < 0 || y < 0 || x >= w || y >= h) continue;
                int i = (y * w + x) * 3; int R = p[i], G = p[i + 1], B = p[i + 2];
                if (B > 170 && B - R > 80 && G > 90) { rays++; break; }
            }
        return rays >= 7;
    }

    // Dem diem do (buoc 3) vung goc phai duoi + tam. Nut Keo can: 876-932; vong tron 600-680; cho bat dau 140-275
    public static int RedCount(byte[] p, int w, int h, out int cx, out int cy)
    {
        int n = 0; long sx = 0, sy = 0;
        for (int y = 180; y < h - 2; y += 3)
            for (int x = 440; x < w - 2; x += 3)
            {
                int i = (y * w + x) * 3; int R = p[i], G = p[i + 1], B = p[i + 2];
                if (R > 140 && R - G > 50 && R - B > 40) { n++; sx += x; sy += y; }
            }
        cx = n > 0 ? (int)(sx / n) : 0; cy = n > 0 ? (int)(sy / n) : 0;
        return n;
    }
    static readonly int[] DX, DY;             // 16 tia
    static Ring()
    {
        DX = new int[16 * 100]; DY = new int[16 * 100];
        for (int a = 0; a < 16; a++)
            for (int r = 0; r < 100; r++)
            {
                double t = a * Math.PI / 8;
                DX[a * 100 + r] = (int)Math.Round(r * Math.Cos(t)); DY[a * 100 + r] = (int)Math.Round(r * Math.Sin(t));
            }
    }

    static int Px(byte[] p, int w, int h, int x, int y, int ch)
    {
        if (x < 0 || y < 0 || x >= w || y >= h) return -1;
        return p[(y * w + x) * 3 + ch];
    }

    // Co qua cau cam o tam khong (dau hieu dang o vong tron)
    public static bool HasBall(byte[] p, int w, int h)
    {
        int k = 0;
        for (int y = CY - 6; y <= CY + 6; y += 2)
            for (int x = CX - 6; x <= CX + 6; x += 2)
            {
                int i = (y * w + x) * 3; int R = p[i], G = p[i + 1], B = p[i + 2];
                if (R > 200 && G > 100 && G < 210 && B < 90) k++;
            }
        return k >= 20;   // 49 diem
    }

    // Ti le diem do trong nut tron goc phai duoi (tam nut ~ (556,300)), 0..100
    public static int RedPct(byte[] p, int w, int h)
    {
        int k = 0, n = 0;
        for (int y = 275; y <= 325; y += 3)
            for (int x = 530; x <= 582; x += 3)
            {
                int i = (y * w + x) * 3; int R = p[i], G = p[i + 1], B = p[i + 2]; n++;
                if (R > 140 && R - G > 50 && R - B > 40) k++;
            }
        return k * 100 / n;
    }
    public static bool IsPullButton(byte[] p, int w, int h) { return RedPct(p, w, h) >= 35 && !HasBall(p, w, h); }

    // Do sang trung binh goc tren trai (man Chuc mung bi lam toi)
    public static int Bright(byte[] p, int w, int h)
    {
        long s = 0; int n = 0;
        for (int y = 60; y < 200; y += 4) for (int x = 100; x < 400; x += 4) { int i = (y * w + x) * 3; s += p[i] + p[i + 1] + p[i + 2]; n++; }
        return (int)(s / n / 3);
    }

    // Do lech trung binh nho nhat khi dat mau tpl (tw x th) quanh (x0,y0) +- r pixel (moi kenh, 0..255)
    public static double MatchAt(byte[] p, int w, int h, byte[] tpl, int tw, int th, int x0, int y0, int r)
    {
        double best = 999;
        for (int dy = -r; dy <= r; dy++)
            for (int dx = -r; dx <= r; dx++)
            {
                int ox = x0 + dx, oy = y0 + dy;
                if (ox < 0 || oy < 0 || ox + tw > w || oy + th > h) continue;
                long s = 0; int n = 0;
                for (int y = 0; y < th; y += 2)
                    for (int x = 0; x < tw; x += 2)
                    {
                        int i = ((oy + y) * w + ox + x) * 3, j = (y * tw + x) * 3;
                        s += Math.Abs(p[i] - tpl[j]) + Math.Abs(p[i + 1] - tpl[j + 1]) + Math.Abs(p[i + 2] - tpl[j + 2]); n += 3;
                    }
                double m = (double)s / n; if (m < best) best = m;
            }
        return best;
    }

    // Doc JPG/PNG -> RGB 3 byte/pixel
    public static byte[] LoadRgb(string path, out int w, out int h)
    {
        using (var b = new System.Drawing.Bitmap(path))
        {
            w = b.Width; h = b.Height;
            var d = b.LockBits(new System.Drawing.Rectangle(0, 0, w, h), System.Drawing.Imaging.ImageLockMode.ReadOnly, System.Drawing.Imaging.PixelFormat.Format24bppRgb);
            var raw = new byte[d.Stride * h]; System.Runtime.InteropServices.Marshal.Copy(d.Scan0, raw, 0, raw.Length); b.UnlockBits(d);
            var p = new byte[w * h * 3];
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) { int s = y * d.Stride + x * 3, t = (y * w + x) * 3; p[t] = raw[s + 2]; p[t + 1] = raw[s + 1]; p[t + 2] = raw[s]; }
            return p;
        }
    }

    // Ban kinh co thay doi lon nhat so voi anh nen (luc vong tron vua hien), r trong [16, 95]
    // Tra ve -1 neu khong ro
    public static int Radius(byte[] p, byte[] bg, int w, int h, out int score)
    {
        int best = -1; score = 0;
        for (int r = 16; r <= 95; r++)
        {
            int s = 0;
            for (int a = 0; a < 16; a++)
            {
                int x = CX + DX[a * 100 + r], y = CY + DY[a * 100 + r];
                if (x < 0 || y < 0 || x >= w || y >= h) continue;
                int i = (y * w + x) * 3;
                int d = Math.Abs(p[i] - bg[i]) + Math.Abs(p[i + 1] - bg[i + 1]) + Math.Abs(p[i + 2] - bg[i + 2]);
                if (d > 90) s += d;
            }
            if (s > score) { score = s; best = r; }
        }
        return score >= 1500 ? best : -1;
    }
}
