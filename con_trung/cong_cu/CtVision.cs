using System;
using System.Collections.Generic;

// Con trung dai chien: bo sung cho TdVision (anh RGB 960x540)
public static class CtVision
{
    const int W = 960, H = 540;
    // mode 0 = bo rua (do), 1 = buom (canh xanh tim: B cao, R/G thap hon ro -> loai trung xanh G~B, phao tim hong R cao)
    static int Mode = 0;
    static bool Butterfly(byte[] p, int i) { int r = p[i], g = p[i + 1], b = p[i + 2]; return b >= 150 && b - r >= 30 && b - g >= 25; }
    static bool Hit(byte[] p, int i) { return Mode == 1 ? Butterfly(p, i) : Red(p, i); }
    static bool Red(byte[] p, int i) { int r = p[i], g = p[i + 1], b = p[i + 2]; return r >= 160 && g <= 95 && b <= 95 && r - g >= 90; }

    // Bo rua di lang thang o quang truong: cum diem DO (than bo rua) lon nhat trong vung (x0,y0)-(x1,y1).
    // Tra ve {cx, cy, so diem, so cum hop le}; khong thay -> so diem = 0.
    // Liet ke moi cum (debug): {cx, cy, dien tich, rong, cao}
    public static List<int[]> Blobs = new List<int[]>();
    public static int[] FindButterfly(byte[] p, int x0, int y0, int x1, int y1, int minArea, int maxArea)
    { Mode = 1; try { return Find(p, x0, y0, x1, y1, minArea, maxArea); } finally { Mode = 0; } }
    public static int[] FindLadybug(byte[] p, int x0, int y0, int x1, int y1, int minArea, int maxArea)
    { Mode = 0; return Find(p, x0, y0, x1, y1, minArea, maxArea); }
    static int[] Find(byte[] p, int x0, int y0, int x1, int y1, int minArea, int maxArea)
    {
        var seen = new bool[W * H]; int bestA = 0, bx = -1, by = -1, n = 0; Blobs.Clear();
        var q = new Queue<int>();
        for (int y = y0; y < y1; y++)
            for (int x = x0; x < x1; x++)
            {
                int k = y * W + x; if (seen[k] || !Hit(p, k * 3)) continue;
                seen[k] = true; q.Enqueue(k); int a = 0; long sx = 0, sy = 0; int mnx = x, mxx = x, mny = y, mxy = y;
                while (q.Count > 0)
                {
                    int c = q.Dequeue(), cx = c % W, cy = c / W; a++; sx += cx; sy += cy;
                    if (cx < mnx) mnx = cx; if (cx > mxx) mxx = cx; if (cy < mny) mny = cy; if (cy > mxy) mxy = cy;
                    for (int d = 0; d < 4; d++)
                    {
                        int nx = cx + (d == 0 ? 1 : d == 1 ? -1 : 0), ny = cy + (d == 2 ? 1 : d == 3 ? -1 : 0);
                        if (nx < x0 || nx >= x1 || ny < y0 || ny >= y1) continue;
                        int nk = ny * W + nx; if (seen[nk] || !Hit(p, nk * 3)) continue;
                        seen[nk] = true; q.Enqueue(nk);
                    }
                }
                if (a >= 60) Blobs.Add(new[] { (int)(sx / a), (int)(sy / a), a, mxx - mnx + 1, mxy - mny + 1 });
                int bwMax = Mode == 1 ? 100 : 70, bhMax = Mode == 1 ? 65 : 60;   // buom quang truong ~79x40 (24/11), bo rua <= 70x60
                if (a < minArea || a > maxArea || mxx - mnx >= bwMax || mxy - mny >= bhMax) continue;
                n++; if (a > bestA) { bestA = a; bx = (int)(sx / a); by = (int)(sy / a); }
            }
        return new[] { bx, by, bestA, n };
    }
}

// Doc so "Diem bat sau" chi theo NET CHU XANH LA (bo nen: 24/11 08:37 con Bo Hung dung sau bang Ket qua lam nen doi mau
// -> so mau RGB "64" lech -> tuong khong dat -> ban them luoi). Tra ve do trung khop mat na chu (giao / hop, 0-1) tot nhat khi dich +-r.
public static class CtDigits
{
    static readonly Dictionary<string, bool[]> masks = new Dictionary<string, bool[]>();
    static readonly Dictionary<string, int[]> sizes = new Dictionary<string, int[]>();
    static bool Green(int r, int g, int b) { return g >= 120 && g - r >= 45 && g - b >= 45; }
    static void Load(string path)
    {
        if (masks.ContainsKey(path)) return;
        using (var bmp = new System.Drawing.Bitmap(path))
        {
            int w = bmp.Width, h = bmp.Height; var m = new bool[w * h];
            for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) { var c = bmp.GetPixel(x, y); m[y * w + x] = Green(c.R, c.G, c.B); }
            masks[path] = m; sizes[path] = new[] { w, h };
        }
    }
    public static double Match(byte[] p, string tplPath, int x0, int y0, int r)
    {
        Load(tplPath); var m = masks[tplPath]; int tw = sizes[tplPath][0], th = sizes[tplPath][1]; const int W = 960, H = 540;
        double best = 0;
        for (int dy = -r; dy <= r; dy++) for (int dx = -r; dx <= r; dx++)
        {
            int inter = 0, uni = 0;
            for (int y = 0; y < th; y++) for (int x = 0; x < tw; x++)
            {
                int sx = x0 + dx + x, sy = y0 + dy + y; if (sx < 0 || sy < 0 || sx >= W || sy >= H) continue;
                int i = (sy * W + sx) * 3; bool a = Green(p[i], p[i + 1], p[i + 2]), b = m[y * tw + x];
                if (a && b) inter++; if (a || b) uni++;
            }
            if (uni > 0) { double s = inter / (double)uni; if (s > best) best = s; }
        }
        return best;
    }
}

// Dinh cung net dut (tu ngam khi doi trang phuc: 24/11 08:55 trang phuc moi -> cung khac, keo y het chi 30 diem).
// Cham cung = diem trang moi xuat hien so voi anh nen (TdVision.Dots). Ghep parabol y = A x^2 + B x + C bang RANSAC
// (sau bo bay lam nhieu), A > 0 (dinh la diem cao nhat). Tra ve {dinh x - thanh mau x, dinh y - thanh mau y, A, so cham khop}
// hoac null. Mau dat 64 (trang phuc cu, 08:36): dinh (+64, -218), cac cham cach ~7px.
public static class CtArc
{
    // tx,ty = dinh mong muon (so voi thanh mau): chi nhan dinh trong +-45 ngang, +-60 doc (09:06: bo bay lam ghep nham cung (99,-249) (28,-311))
    public static double[] Apex(byte[] p, byte[] bg, int barX, int barY, int fx, int fy, int fr, int tx, int ty)
    {
        int x0 = Math.Max(0, barX - 80), y0 = Math.Max(0, barY - 340), x1 = Math.Min(959, barX + 280), y1 = Math.Max(y0 + 10, barY - 40);
        int[] d = TdVision.Dots(p, bg, x0, y0, x1, y1, fx, fy, fr);
        int n = d.Length / 2; if (n < 6) return null;
        double bestScore = 0; double[] best = null;
        for (int i = 0; i < n; i++) for (int j = i + 1; j < n; j++) for (int k = j + 1; k < n; k++)
        {
            double xa = d[2 * i], ya = d[2 * i + 1], xb = d[2 * j], yb = d[2 * j + 1], xc = d[2 * k], yc = d[2 * k + 1];
            if (Math.Abs(xa - xb) < 6 || Math.Abs(xa - xc) < 6 || Math.Abs(xb - xc) < 6) continue;
            double den = (xa - xb) * (xa - xc) * (xb - xc);
            double A = (xc * (yb - ya) + xb * (ya - yc) + xa * (yc - yb)) / den;
            if (A < 0.025 || A > 0.065) continue;   // cung that A 0.034-0.053; keo dang do / nhieu: A < 0.01
            double B = (xc * xc * (ya - yb) + xb * xb * (yc - ya) + xa * xa * (yb - yc)) / den;
            double C = (xb * xc * (xb - xc) * ya + xc * xa * (xc - xa) * yb + xa * xb * (xa - xb) * yc) / den;
            double h = -B / (2 * A), kk = C - B * B / (4 * A);
            if (Math.Abs(h - barX - tx) > 45 || Math.Abs(kk - barY - ty) > 60) continue;
            int inl = 0; double minX = 9999, maxX = -9999;
            for (int q = 0; q < n; q++)
            {
                double x = d[2 * q], y = d[2 * q + 1];
                if (Math.Abs(A * x * x + B * x + C - y) <= 3) { inl++; if (x < minX) minX = x; if (x > maxX) maxX = x; }
            }
            // can it nhat 7 cham va cham trai dai 2 ben dinh (cung that, khong phai 1 dong chu)
            if (inl < 8 || minX > h - 10 || maxX < h + 10) continue;   // 09:33-09:37 chup truc tiep nhieu lan < 10 cham -> khong thay cung
            double score = inl + (maxX - minX) / 100.0;
            if (score > bestScore) { bestScore = score; best = new[] { h - barX, kk - barY, A, inl }; }
        }
        return best;
    }
}

// Dong ho luot (so cam lon giua tren, 15 -> 1): so diem cam trong vung (430-530, 40-105) man 960.
// Ban ghi 24/11: dang dem 93-846 (ca khi chi con "1"), khong co dong ho <= 26.
// 09:02: mo man tran PASS da sang ~8 giay ma CHUA cho di (chua co dong ho) -> bot tuong toi luot, giu nut vo ich roi PASS mat luot that.
public static class CtTimer
{
    public static int Orange(byte[] p)
    {
        int n = 0;
        for (int y = 40; y < 105; y++) for (int x = 430; x < 530; x++)
        { int i = (y * 960 + x) * 3; if (p[i] >= 220 && p[i + 1] >= 120 && p[i + 1] <= 215 && p[i + 2] <= 90) n++; }
        return n;
    }
}
