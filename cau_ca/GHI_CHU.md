# Câu cá: ghi chú từ 2 lần người chơi làm mẫu (18/11/2026, thiết bị `auto`, nhân vật tài khoản 1)

## Cấu trúc thư mục (`D:\tools\ddtank-farm\cau_ca\`)
- `cau_ca.bat`: lệnh chạy. `ket_qua/cau_thu_<ngày>_<giờ>/`: ảnh mỗi lần chạy. `ghi_hinh/thu_*`: các lần ghi thử (Mồi chưa đủ, Ba lô đã đầy…).
- `ghi_hinh/ghi_cham_1fps/`: lần 1 (12:55–13:00), khoảng 1 ảnh mỗi giây, ảnh 960x540.
  - Đi từ sảnh tới cầu tàu, câu 3 con, để tuột 1 con vì không bấm Kéo cần.
- `ghi_hinh/ghi_nhanh_17fps/`: lần 2 (13:17:53–13:19:08), khoảng 17 ảnh mỗi giây, ảnh 640x360.
  - Câu 4 con, cố ý bỏ lỡ vòng tròn 1 lần (kết quả *Hụt*).
  - `luc_bam.jpg`: vòng tròn tại thời điểm từng lần bấm.
- Cả hai thư mục đều có:
  - `cham.txt`: kết quả `getevent -lt /dev/input/event4`.
  - `moc_thoi_gian.txt`: mốc để quy uptime của máy ảo ra giờ máy tính.
  - `sheet*.jpg`: ảnh trước và sau mỗi lần chạm.
- `cong_cu/`: các script dùng để ghi và phân tích.
  - `quan_sat_nhanh.ps1`: lấy luồng `screenrecord --output-format=raw-frames` (RGB888, không có header, khoảng 17 ảnh mỗi giây ở 640x360).
  - `doc_cham.ps1`: đọc danh sách lần chạm.
  - `to_sheet.ps1`: ghép ảnh trước và sau mỗi lần chạm.
  - `day_anh.ps1`: ghép dãy ảnh liên tiếp, có thể cắt một vùng.

## Toạ độ chạm
`getevent` trả về toạ độ RAW dọc (X 0–900, Y 0–1600). Đổi sang màn hình ngang 1600x900 như sau:
- **sx = Y**
- **sy = 900 − X**

## Các bước
1. **Sảnh** → *Giao lưu* (thanh dưới, khoảng (1243,672)) → menu → *Thị trấn nhỏ* (khoảng (967,656)).
2. **Thị trấn**: bấm mặt đất 4 lần để đi xuống cầu tàu, mỗi lần đi khoảng 1–2 giây. Tới chỗ câu thì hiện 2 nút:
   - *Câu cá bằng lưới* (khoảng (1111,735)).
   - *Bắt đầu câu cá* (khoảng (1426,767)).
3. *Câu cá bằng lưới* hiện hộp hỏi *"có nên dùng lưới…"*. **Không dùng**, đóng bằng ✕.
4. **Bắt đầu câu cá**: hiện *"Đợi cá cắn câu…"* cùng nút *Rút cần*. Thời gian chờ 4–13 giây.
5. Nút đổi thành **Kéo cần** (màu đỏ, khoảng (1391,767)). Có khoảng **4,5–5 giây** để bấm. Quá giờ thì hiện *"Kéo cần câu hết thời gian, cá tuột đi"*.
6. **Vòng tròn** hiện khoảng 0,4 giây sau khi bấm Kéo cần.
   - Gồm quả cầu cam ở giữa, vòng xanh dương, vòng xanh lá và vòng đỏ ngoài cùng.
   - Một **vòng sáng co dần từ ngoài vào giữa** trong khoảng 2 giây. Khi đè lên vòng xanh lá thì vòng sáng có màu vàng, vào trong vòng xanh dương thì màu trắng hoặc cam.
   - Bấm vào giữa (khoảng (1391,767)). Kết quả theo lúc bấm:
     - **Xuất sắc**: vòng sáng đã vào trong vòng xanh dương nhưng chưa sát quả cầu (bán kính khoảng ½ vòng xanh dương). Lúc bấm cách lúc bấm Kéo cần 1,8–2,0 giây.
     - **Tuyệt vời**: bấm muộn hơn một chút, vòng sáng gần như đã chụm vào quả cầu. Cách lúc bấm Kéo cần 2,05–2,2 giây.
     - **Bình thường**: thấy 1 lần ở lần làm mẫu thứ nhất (Sao biển). Chưa rõ là bấm sớm hay do loại cá.
     - **Không bấm**: vòng sáng chụm hết thì hiện **Hụt**, rồi *"Thao tác chờ đã hết, con cá đã tuột"*. Mất con cá, quay về nút Bắt đầu câu cá.
7. **Chúc mừng!**: tên cá và cân nặng. Bấm *Nhấn để tiếp tục* (khoảng (1435,830)), rồi quay lại bước 4.

## Cá đã câu được
Ghẹ 181g, Ghẹ 185g, Tôm 54g, Cá mòi 112g, Cá hố 203g, Cá hố 286g, Cá diếc 160g, Sao biển 105g.

## Câu thử bằng bot (18/11, 13:50–14:14, tài khoản tài khoản 1)
- Script `cong_cu/cau_thu.ps1`, phần lõi ở `Fisher.cs` và `Ring.cs`. Ảnh mẫu trạng thái nằm trong `mau/`. Mỗi vòng được ghi một dòng vào `hieu_chinh.csv`.
- Nhận trạng thái trên luồng 640x360:
  - Chờ bắt đầu: thấy nút *Câu cá bằng lưới* (`nut_luoi.png`).
  - Đang đợi: thấy chữ *Đợi cá cắn câu* (`doi_ca.png`).
  - Kéo cần: nút tròn đỏ.
  - Vòng tròn: quả cầu cam ở tâm (564,290).
  - Chúc mừng: màn hình tối.
  - Hết mồi: thông báo **"Mồi chưa đủ"** (`het_moi.png`).
- Một con cá có thể có **1–3 vòng liên tiếp**. Mỗi vòng có **tốc độ co riêng, 62–253 px/s**, và vòng sau nhanh hơn vòng trước.
  - Bot kẻ đường thẳng khớp mọi điểm đo của vòng (chỉ dùng r ≥ 33, hoặc r ≥ 25 khi vòng co nhanh).
  - Bot bấm khi r dự đoán ≤ TargetR + v × 0,12 giây.
- Độ trễ của cả hệ thống khoảng 0,12 giây. Bấm quá sớm ra Xuất sắc, quá muộn thì ra Hụt và mất cá.
- Kết quả với TargetR = 9 (14:11): 10 Tuyệt vời, 2 Xuất sắc, 2 Hụt; 7/9 con câu được. Sau đó hết mồi.
- Tài khoản thứ 2 (có khoảng 5000 cần câu). Sau khi sửa (14:15–14:26), lượt 40 lần lúc 14:26–14:35 cho **37/40 con**; trong 53 vòng có **38 Tuyệt vời (72%)**, 12 Xuất sắc, 3 Hụt.
  - Vòng chậm (<100 px/s): Tuyệt vời ở r dự đoán 19–23, Xuất sắc ở 22–23 → bấm muộn hơn 1 px (TargetR 12 → 11).
  - 3 lần Hụt đều do lỗi đo: r > 78 đo sai, và ở vòng nhanh bot bỏ điểm r = 32 nên phải đoán từ điểm cũ → đã sửa, **chưa chạy thử lại**.
- Các sửa trong lúc thử:
  - **Vị trí giao diện câu cá đổi theo chỗ nhân vật đứng** → bot tự tìm quả cầu (cụm cam có vòng xanh dương ở r khoảng 37) và nút Kéo cần (cụm đỏ).
  - Chỉ bấm vòng tròn khi còn thấy quả cầu hoặc vòng sáng. Trước đó có lần bấm nhầm xuống đất làm nhân vật đi chỗ khác.
  - Vòng 2–3: chữ "Tuyệt vời" của vòng trước che quả cầu một lúc → đo được vòng sáng cũng tính là vòng tròn còn hiện.
  - Đã bắt đầu câu = nút *Câu cá bằng lưới* biến mất 0,5 giây (chữ *Đợi cá cắn câu* đổi vị trí và nền).
  - Luồng hình screenrecord có lúc ngắt → tự khởi động lại tối đa 3 lần.
- 14:39: chạy kiểm tra bản sửa cuối được 2 lần (1 Tuyệt vời, 1 Xuất sắc) thì game báo **"Ba lô đã đầy"** (`balo_day.png`). Bot giờ dừng và báo **BALO DAY**. Phải bán hoặc dọn cá trong Ba lô mới câu tiếp được.
- 14:42, sau khi người chơi dọn Ba lô: chạy nốt 8 lần → **8/8 con**, 8/9 vòng Tuyệt vời. Gộp cả 10 lần kiểm tra bản sửa cuối (TargetR = 11): **10/10 con, 9/11 vòng Tuyệt vời (82%), 0 Hụt**.
- 14:47, chạy 20 lần với `input tap`: 17/20 con, 17/26 vòng Tuyệt vời (65%), 6 Xuất sắc, 3 Hụt.
- **Rút kinh nghiệm từ các vòng Xuất sắc và Hụt:**
  - Giả thuyết "vòng sáng co nhanh dần về cuối" **không đúng**. Tỉ lệ tốc độ cuối/đầu ở vòng Tuyệt vời là 1,02, ở vòng Xuất sắc là 0,94, đều dao động 0,5–1,75 do nhiễu đo.
  - Nguyên nhân chính là **nhiễu thời gian của lệnh bấm**. `input tap` khởi động Java mỗi lần, mất 33–65 ms. Khoảng thời gian để được Tuyệt vời chỉ rộng khoảng 100 ms.
  - Cách sửa: bấm vòng tròn bằng cách ghi thẳng sự kiện vào `/dev/input/event4`. Chạy `cat` một file nhị phân `input_event` 24 byte (tạo khi biết tâm vòng tròn) qua shell mở sẵn, mất 25–30 ms và đều.
  - Toạ độ RAW dọc: X = 900 − y, Y = x. Mã sự kiện: 3/57 tracking, 1/330 BTN_TOUCH, 3/53 X, 3/54 Y, 0/0 SYN. Thả: tracking = −1.
- 14:55, chạy 20 lần với cách bấm trực tiếp (TargetR 11, độ trễ 0,12): **19/20 con, 22/28 vòng Tuyệt vời (79%), 5 Xuất sắc, 1 Hụt**.
  - Các vòng Xuất sắc còn lại chủ yếu là vòng vừa và nhanh (v > 100). Có thể thử độ trễ 0,11 (bấm muộn hơn v × 0,01 px), **chưa thử**.
- Ba lô chứa khoảng 60 con. Từ lúc dọn tới 15:00 đã câu khoảng 49 con.

## Gợi ý khi viết bot
- Bước 1–5 và 7: nhận nút bằng ảnh mẫu như phần nông trại, chụp màn hình 1 ảnh mỗi giây là đủ.
- Bước 6 cần chụp nhanh, nên dùng luồng raw-frames, chỉ đọc vùng vòng tròn.
  - Cách 1: đo bán kính vòng sáng so với vòng xanh dương rồi bấm.
  - Cách 2: lấy mốc khi vòng sáng đè vòng xanh lá (màu vàng) rồi bấm sau một khoảng cố định.
  - Khoảng thời gian để được *Xuất sắc* rộng khoảng 150–250 mili-giây.
  - Lệnh bấm nên gửi qua một kết nối adb shell mở sẵn để giảm độ trễ.

## Nhật ký để phân tích (thêm 18/11 15:45)
- Mỗi lần chạy có `ket_qua\cau_thu_<ngày>_<giờ>\log.txt` (toàn bộ nhật ký, kể cả dãy bán kính).
- `hieu_chinh.csv` có thêm 3 cột: `nguoi` (1 = giả lập người), `vet_ban_kinh` ("giây:bán_kính …" của vòng vừa bấm), `lan_chay` (thư mục ảnh). Các dòng trước 15:45 không có 3 cột này.
- Phân tích: lọc `ket_qua` = Hut / Xuat sac, xem `vet_ban_kinh` có bị khựng (khoảng trống giữa 2 điểm > 0,1 s), đo sai ở r > 78, hay phải đoán xa (`ngoai_suy_s` lớn), rồi mở ảnh `N_vK_sau_bam.jpg` trong `lan_chay`.

## Máy thứ 2 (18/11 21:00): `LeadSec` phải chỉnh theo từng máy
- Cùng MuMu 1600x900 240dpi, cùng code, nhưng chạy mặc định (`LeadSec` 0,12) thì **7/7 vòng ra Xuất sắc** (bấm quá sớm).
- Bot bấm ở cùng thời điểm trên cả 2 máy (trung bình 0,234 s trước khi vòng chụm), nên lệch là do **độ trễ của máy**, không phải do code.
- Máy mới nhanh hơn: luồng hình khoảng 30 khung/s (máy cũ khoảng 20), vòng tròn hiện 0,25 s sau Kéo cần (máy cũ khoảng 0,4 s).
  - Bot thấy hình sớm hơn, cộng thêm phần bù trễ 0,12 s (đo ở máy cũ) nên bấm sớm khoảng 0,08 s.
- `-LeadSec 0.03` trên máy mới: **8/10 con, 11/12 vòng Tuyệt vời**, 1 Hụt (vòng 2, 154 px/s).
- Đổi máy thì chạy thử khoảng 10 lần: nhiều Xuất sắc → giảm `LeadSec`; nhiều Hụt → tăng `LeadSec`. Mỗi bước khoảng 0,02.

## Phân tích 259 vòng trên máy 2 (18/11 21:16–22:30, `LeadSec` 0,03) và các sửa đổi
- Tổng: 237 Tuyệt vời (92%), 17 Xuất sắc, 5 Hụt; câu được 197/204 con (6 lượt). Lượt nào cũng dừng vì **Ba lô đầy** (khoảng 40 con).
- Chia theo loại vòng:

| Loại | Đặc điểm | Kết quả | Kết luận |
|---|---|---|---|
| `cham` | < 130 px/s, hầu hết là vòng 1 | 199/200 Tuyệt vời | Giữ nguyên |
| `vua` | 130–190 px/s, vòng 2 | 28 Tuyệt vời, 10 Xuất sắc | Bấm hơi sớm |
| `nhanh` | ≥ 190 px/s, vòng 3 | 6/6 Xuất sắc | Bấm sớm |
| `thua_vua` | Vòng 2 (~157 px/s) của một loại cá, chỉ đo được khoảng 14 điểm/giây (thường là 30) | 4/4 Hụt, mất cá | Hình hiện trễ nên bot bấm muộn |
| `thua_cham` | Vòng 1 của loại cá đó | 10/10 Tuyệt vời | Giữ nguyên |

- Khoảng cách giữa 2 lần đo: khung thường 0,030–0,041 s, khung thưa 0,065–0,069 s. Ngưỡng phân loại là 0,05 s.
- **Sửa: bù riêng từng loại vòng, tự học và lưu theo máy** (`bu_vong_<tên máy>.txt`, có commit; **khác nhau tuỳ máy**, không chép sang máy khác).
  - Mức bù (px, dương = bấm sớm hơn) được cộng vào ngưỡng bấm.
  - Sau mỗi vòng: Xuất sắc → −0,5; Hụt → +1,5.
  - Giá trị khởi đầu: `vua` −1,5; `nhanh` −3; `thua_vua` +4; các loại khác 0.
  - Không học khi bấm dự phòng hoặc khi khung hình cuối đã cũ hơn 0,2 s.
- **Sửa: không bỏ vòng khi luồng hình khựng.** Lần 10 lượt 21:16 mất cá vì luồng hình dừng 0,8 s. Giờ chỉ tính thời gian có khung hình mới.
- **Sửa: vòng không bấm ghi là "Khong bam".** Trước đây vòng xanh dương bị đọc nhầm thành "Xuat sac".
- CSV có thêm cột `loai_vong` = `loại:bù_px:khoảng_cách_đo_s`.

## 19/11: lỗi "khong thay nut Bat dau cau ca" và mất cá ở vòng 3
- **Lỗi giả "không ở chỗ câu"** (4 lượt, mỗi lượt chờ đủ 30 giây trong khi nút vẫn hiện):
  - Ảnh mẫu `nut_luoi.png` có kèm số lưới ở góc nút (mẫu là "1", hôm nay game hiện "0").
  - Nút trong suốt, nên nền phía sau đổi theo chỗ nhân vật đứng.
  - Đo trên ảnh đã lưu: 345 ảnh có nút cho điểm ≤ 20,1; 740 ảnh đang câu hoặc chúc mừng cho điểm ≥ 50. Lúc đang đợi cá (đo trực tiếp) là khoảng 54.
  - Ngưỡng cũ 20 nằm sát mép → **nâng lên 35**. Log ghi điểm khớp khi bắt đầu câu và khi báo lỗi.
- **Vòng 3 co rất nhanh, bot không bấm** (3 lần mất cá):
  - Vòng bắt đầu đo được từ r = 66–75 và chụm trong khoảng 0,25 giây. Bot không kịp có 4 điểm đo trong 0,1 giây.
  - Sửa: từ vòng 2 trở đi, cho bấm khi có 3 điểm giảm đều trong ≥ 0,05 giây và r ≤ 40. Log ghi "vong rat nhanh: bam voi N diem".
- **Chưa sửa** — vòng 3 bấm rồi mà game không nhận (2 lần):
  - Ảnh 350 ms sau khi bấm không có chữ kết quả. Bot đọc nhầm vòng xanh dương thành "Xuat sac".
  - Sau đó game báo "Thao tác chờ đã hết, con cá đã tuột".
- **Đọc nhầm "Xuất sắc" — đã sửa:**
  - Trong 41 vòng ghi "Xuat sac" (18–19/11), chỉ khoảng 10 vòng có chữ Xuất sắc thật. Các vòng còn lại không có chữ hoặc chỉ còn chữ cũ của vòng trước đang mờ dần. Nhầm nhiều nhất ở vòng 3: 25/25 vòng là đọc nhầm.
  - Nguyên nhân 1: vùng đọc chữ chứa cả vòng xanh dương nên luôn có điểm xanh.
  - Nguyên nhân 2: ở vòng 2–3, chữ kết quả mới thường hiện muộn hơn 350 ms.
  - Hậu quả: bot học theo kết quả nhầm, bù `nhanh` trôi tới −10 và `vua` tới −5.
  - Sửa vùng đọc: chỉ đọc dải ngang |dy| ≤ 25 quanh tâm, bỏ quả cầu (r < 16) và vòng xanh dương (r 28–46).
  - Đo trên ảnh: Tuyệt vời 95–600+ điểm vàng; Xuất sắc 16–32 điểm xanh (không có chữ là 0–1); Hụt 83–97 điểm đỏ.
  - Sửa cách đọc: đọc mọi khung hình tới khi thấy chữ mới, tối đa 1,5 s sau khi bấm. Log ghi "chu hien sau X s". Không thấy chữ thì ghi "Khong ro" và không học.
  - Đặt lại bù trên máy DELL: `vua` −2, `nhanh` −3.
  - Các dòng `Xuat sac` ở vòng 2–3 trong `hieu_chinh.csv` trước 19/11 22:30 **không đáng tin**.
- **Chạy thử 19/11 22:30, 25 lần (bộ đọc chữ mới):**
  - Kết quả: 24/25 con, 31 Tuyệt vời, 0 Xuất sắc, 1 Hụt. Chữ kết quả đọc được ngay khung đầu (0,25 s) ở mọi vòng, không có "Khong ro".
  - Lần Hụt duy nhất (lần 22, vòng 3): luồng hình khựng 0,11 s ngay sau điểm đầu (75 @ −0,01 s, rồi 68 @ 0,10 s, 61, 54…).
    - Đường thẳng kẻ qua cả điểm cũ cho tốc độ 189 px/s, trong khi tốc độ thật khoảng 300 px/s → bấm muộn.
    - Sửa: khi tính tốc độ, bỏ các điểm đứng trước khoảng khựng > 0,085 s nếu sau đó còn ≥ 3 điểm. **Chưa chạy thử**: game thoát ra màn đăng nhập lúc 22:36.
