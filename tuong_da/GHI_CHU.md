# Tượng Đá (phó bản tượng khổng lồ): ghi chú

Mỗi ngày có **5 lượt thử thách**. Trận mặc định là **thua**, nhưng vẫn nhận **Xu Cổ** (20/11: 560 xu, "Số lần nhận Xu Cổ hôm nay 1/5"). Script chạy riêng như câu cá: `tuong_da.bat [số trận]`.

## Bản ghi làm mẫu
`hoc_mau\ghi_20261120_215019\`: 3.293 khung 960x540, 30 lần chạm, 3 tờ ghép `sheet*.jpg`. Bản ghi không đưa lên git.

## Vào trận (toạ độ màn 1600x900)
1. Sảnh → thẻ chế độ ở góc dưới phải (1281, 537) → bảng chế độ → **"Phó tượng khổng lồ"** (748, 628).
2. Hộp **"Khám phá"** ("Mục tiêu: Khiêu chiến Tượng Đá") → nút **Khám phá** (1300, 730).
3. **Phòng chờ**: thanh đỏ trên cùng "Số thử thách còn lại: N lần". Chạm (808, 487) rồi chạm **cổng sáng** (~1100–1125, 420–470) → nhân vật đi vào → tải → trận.

## Trong trận
- **Tới lượt mình = nút PASS góc trên phải sáng** (mẫu `nut_pass`: sáng 0–5, mờ 20–30).
  - Trùng đúng 3 lượt trong bản ghi.
  - Lượt boss / chuyển cảnh thì PASS và chữ "Dano:" có lúc mất.
- Mỗi trận trong bản ghi có **3 lượt** rồi ra "Thất bại".
- **Item** (thanh dưới, y ≈ 474 trên khung 960x540; số nhỏ là năng lượng tốn):

  | Ký hiệu | Hình | Năng lượng |
  |---|---|---|
  | A | người đỏ mũi tên lên | 10 |
  | B | vòng lửa | 30 |
  | C | mũi tên đỏ 63% | 30 |
  | D | rồng xanh | 10 |
  | **POW** | nút tròn lớn góc dưới phải; **sáng cam** = sẵn sàng (mẫu `pow_toi` lệch ≥ 85) | |

  - Item dùng xong **biến khỏi thanh**. Bot bấm **ô khớp bên trái nhất**, trùng 8/8 lần người chơi bấm (lệch ≤ 8 px).
- **Kịch bản người chơi** (bot làm theo, `$Turns` trong `cong_cu\tuong_da.ps1`):

  | Lượt | Item | Kéo |
  |---|---|---|
  | 1 | A → B → C → POW → D → A | kéo ngắn #12 → kéo bắn #13 (3,9 s) |
  | 2 | C → POW | kéo ngắn #18 → kéo bắn #19 (2,9 s) |
  | 3 | C → A → POW | kéo bắn #23 (2,1 s) |

  - **Kéo bắn**: giữ và kéo từ quanh nhân vật về phía dưới trái. Hiện cung nét đứt (đường đạn), kèm "Trả về để hủy". Thả tay là bắn.
  - Người chơi canh cung né chướng ngại vật, vào điểm yếu của boss; có thể di chuyển nhân vật để dễ bắn trúng.
  - Bản đầu **phát lại đúng đường kéo** (`mau\duong_keo.txt`: giây:x,y màn 1600x900), lệch ±3 px, tốc độ 90–110%.
  - Lượt thứ 4 trở đi (nếu có) lặp lại kịch bản lượt 3.
- **Kết quả**: màn "Thất bại", "Chiến đấu nhận Xu Cổ" → "Nhấn để tiếp tục" → về phòng chờ (số lượt giảm 1).
- **Thoát giữa trận**: nút nguồn góc trên phải → "Xác nhận thoát chiến đấu? Thoát trận sẽ không trừ vào lượt thử thách" → Xác nhận. Khi chạy thử, người chơi thoát hộ gần cuối để không mất lượt; script thấy phòng chờ hoặc sảnh thì dừng, ghi `thoat`.

## Nhận diện
- So ảnh mẫu trên ảnh chụp 1600x900 thu về 960x540 (`TdVision.cs`), mẫu cắt từ bản ghi. Ngưỡng đo trên bản ghi:
  - Đúng chỗ: 0–3,2. Chỗ khác: ≥ 40.
  - Chữ "Dano:" trong trận ≤ 21, ngoài trận ≥ 62.
- ⚠️ Không đặt tên hàm PowerShell trùng bí danh có sẵn: `Sc` = Set-Content (19/11 đã dính, đổi thành `TplScore` / `TplMatch`).

## Trạng thái (20/11)
- Kiểm tra offline trên bản ghi: mọi màn hình nhận đúng, item chọn đúng 8/8.
- **Chưa chạy thật.** Chưa biết:
  - màn thắng (nếu có);
  - màn khi hết lượt;
  - cách về sảnh từ phòng chờ;
  - phát lại đường kéo có trúng không khi vị trí boss hoặc điểm yếu khác lần ghi.

## 20/11 22:14–22:44: thử ngắm theo điểm yếu — TẠM DỪNG (bắn trượt)
- **Chạy 22:14** (phát lại đường kéo mẫu): lượt 1–2 trúng (4,16 triệu → 6,46 triệu). Lượt 3 trượt vì hồng tâm khác chỗ lúc làm mẫu.
- **Mỗi trận khác nhau**:
  - "Khoảng cách": 11,5 / 10,0 / 14,5.
  - Chỗ nhân vật: tâm vòng tròn x = 76–298. Zoom: bán kính vòng tròn 232–248.
  - Hồng tâm đổi chỗ giữa các lượt: (790,232) (680,258) (680,328) (680,136) (680,190) (920,120) (920,232).
- **Đã làm được (`TdVision.cs`)**:
  - Tìm vòng tròn quanh nhân vật (`FindCircle`, Hough): đúng trên mọi ảnh đã thử.
  - Tìm hồng tâm (`hong_tam_1/2`).
  - Lần chuỗi chấm của đường nét đứt rồi kéo dài theo vật lý (`ArcPredict`). Chấm cách đều theo thời gian: ngang ~33→25 px, trọng lực ~4,5 px/bước² ở r = 240. Trên bản ghi, lượt 3 lúc người chơi thả (trúng) tính ra lệch −4,2 px.
- **Chưa làm được**:
  - **Chạy 22:28**: không tìm được tên nhân vật (zoom khác), cả 3 phát kéo theo đường mẫu.
  - **Chạy 22:35**: lỗi tên biến `$R`/`$r` (PowerShell không phân biệt hoa thường), đã sửa.
  - **Chạy 22:43**:
    - Lượt 1: hồng tâm (920,232) bị loại vì ngưỡng mép phải x ≤ 900 quá chặt (nên ≤ 935).
    - Lượt 2: ngắm 5 lần (lệch +161 → +26 → +24 → −109 nhiễu → −25) rồi thả, **vẫn trượt**.
  - Chưa né khối đá lơ lửng. Chỉ chỉnh lực theo hướng của lần bắn mẫu, chưa đổi góc.
- **Cần thêm từ người chơi khi làm tiếp**:
  - Quay vài trận mẫu ở nhiều "Khoảng cách" (nhất là xa ~14) và nhiều vị trí hồng tâm.
  - Xác nhận cách điều khiển: điểm bắt đầu và điểm thả đều phải trong vòng tròn? Lực theo độ dài kéo?
