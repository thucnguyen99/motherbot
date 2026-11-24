# Côn trùng Đại chiến (bắt sâu bọ): ghi chú

Mỗi trận bắn **Lưới** một lần. **Điểm bắt sâu 64 = đạt**, thấp hơn là không đạt (người chơi xác nhận 24/11).
Script chạy riêng như câu cá: `con_trung.bat [số trận]`.

## Bản ghi làm mẫu
- `hoc_mau\bat_bo_20261124_075614\`: 2.660 khung 960x540 (18 khung/giây), 36 lần chạm, 2 trận. Cả 2 trận đều 64 điểm (Bọ Rùa x4, Bướm x8). Bản ghi không đưa lên git.
- Video điện thoại `1JBOJJOIB_6Q6TBR.mp4` (1,7 s): người chơi khoanh đỏ chỗ đứng và đích.
  - Chỗ đứng: miệng khủng long sát chữ "Khoảng cách 1,6 / cao 1,4".
  - Đích: con Bọ Rùa "Khoảng cách 1,6 / cao 7,4".
  - Góc bắn 78°.

## Vào trận (toạ độ màn 1600x900)
1. Sảnh → thẻ chế độ (1253, 542). Dùng chung mẫu `sanh_the_mo` với Tượng Đá.
2. Bảng chế độ → **"Côn trùng Đại chiến"** (1218, 610).
3. **Quảng trường**: bọ rùa và bướm đi lang thang, có chữ "Đếm ngược" 13 → 1.
   - Hết đếm ngược thì **chạm vào con bọ rùa**: nhân vật chạy tới → màn VS → tải → trận.
   - Bot tìm bọ rùa bằng cụm điểm đỏ lớn nhất (`CtVision.FindLadybug`). Thân bọ rùa có 540–930 điểm đỏ ở màn 960.

## Trong trận
- **3 lượt**, mỗi lượt 15 giây. **PASS sáng** = tới lượt mình (mẫu `pass_sang`: sáng 0–7, mờ 24–26).
- Bảng "Kết quả" bên phải luôn hiện trong trận (`ket_qua`).
- **Camera cố định theo chiều ngang**: bãi sâu bọ đứng yên, chỉ nhân vật di chuyển.
  - Nhãn "Khoảng cách" tính theo nhân vật nên đổi khi đi.
  - Chỗ đứng lúc vào trận khác nhau mỗi trận: x = 212 và 100 ở màn 960.
- **Di chuyển**: giữ nút ▶ góc dưới trái (299, 783), khoảng 20 px/giây ở màn 960. Chạm ngắn 0,06–0,19 s để chỉnh.
  - Cả 2 trận đều dừng khi **tâm thanh máu nhân vật x = 272** (màn 960). Bot so mẫu `thanh_mau_1/2`: đúng 0,2–39, nhầm chỗ khác ≥ 44.
  - Trận 2 đi từ x = 100 mất ~9 giây, hết lượt 1 nên PASS, bắn ở lượt 2.
- **Bắn**:
  - Bấm **Lưới** (695, 774). Số lưới giảm 1 (226 → 225).
  - Chạm vào nhân vật rồi **kéo xuống dưới trái**, thả tay là bắn:

    | Trận | Điểm chạm | Điểm thả | Vector |
    |---|---|---|---|
    | 1 | (455, 418) | (405, 634) | (−50, +216) |
    | 2 | (446, 511) | (395, 726) | (−51, +215) |

  - Hai lần gần như trùng nhau, góc ≈ 77°.
  - Điểm chạm ≈ tâm thanh máu + (−5, −138) ở màn 1600. Thanh máu lên xuống theo camera dọc: y = 329 / 395 ở màn 960.
  - Người chơi giữ 5–7 giây để nhìn cung nét đứt rồi mới thả. Trận 1 thả khi đồng hồ còn 1.
- Sau khi thả ~2,6 giây, lưới nhện bung ra, điểm cập nhật "Điểm bắt sâu: 64".
  - Mẫu `diem_64`: khớp 0–3,6, khác ≥ 14. Mẫu `diem_0`: khớp 0–2,7.
- Các lượt sau người chơi bấm **PASS** (1218, 30).
- Màn **"Chiến thắng"** ("Chiến đấu nhận Xu Bắt Sâu"): chạm (1061, 840) → tải → về quảng trường.

## Thông số chỉnh được
`con_trung\thong_so.txt`:
- `DichX`, `SaiSoX`: chỗ đứng.
- `KeoX`, `KeoY`: vector kéo.
- `ChamX`, `ChamY`: điểm chạm so với thanh máu.

Mỗi phát bắn ghi 1 dòng vào `con_trung\lich_su_ban.csv`, kèm ảnh `*_ngam.jpg` (cung lúc sắp thả) và `*_sau_ban_<điểm>.jpg`. Phát nào trượt thì xem ảnh rồi chỉnh thông số.

## Trạng thái (24/11)
- Kiểm tra offline trên bản ghi: mọi màn hình nhận đúng, vị trí nhân vật đúng (x = 272 khi dừng), điểm 64/0 đọc đúng.
- Đã chạy thử (mục dưới). Ngắm đã đúng như mẫu, **chưa thử lại có Lưới**. Chưa biết:
  - màn thua (nếu có);
  - giới hạn số trận mỗi ngày;
  - đi lệch bao nhiêu px thì trượt.

## 24/11 08:11–08:28: chạy thật, các lỗi đã sửa
- **08:11 (có Lưới, 16 điểm)**: nhân vật **quay mặt sang trái** nên kéo bắn sai (người chơi chỉ ra).
  - Nguyên nhân: đi lố rồi chạm ◀ để lùi.
  - Sửa: bước cuối luôn đi sang PHẢI. Đi lố thì lùi qua đích 5 px rồi tiến lại. Đầu trận chưa biết hướng mặt thì lùi 1 chút rồi tiến.
- **08:11 lượt 2**: chạm lúc camera còn trượt dọc nên trúng thanh máu, bật bảng "Trạng thái tạm thời".
  - Sửa: chờ 2 lần chụp liên tiếp thanh máu đứng yên rồi mới kéo.
- **08:17**: đứng xa (x = 48), lượt 2 không thấy thanh máu vì y = 451 nằm ngoài vùng tìm. Nới vùng tìm thành y 250–500.
- **08:19**: lắc qua lắc lại quanh chỗ đứng, mỗi lần lố ~30 px vì ảnh chụp trễ ~0,5 s.
  - Sửa: đoạn ≤ 40 px thì giữ nút theo thời gian tính trước (px / tốc độ, tốc độ tự đo, ~20 px/giây). Đoạn dài thì nhả khi còn 15 px.
- **08:21**: mỗi lệnh `sendevent` trên máy ảo ~40 ms, nên 1 lần di chuyển mất ~170 ms. Lệnh xếp hàng: kéo "2 giây" thực tế 5 giây, ảnh ngắm chụp lúc mới kéo nửa đường.
  - Sửa: còn ~10 điểm kéo, sau đó `ShSync` (echo rồi chờ) để thiết bị chạy hết lệnh rồi mới giữ và thả.
- **08:22**: chờ đọc điểm 9 s, lượt 3 bắt đầu lúc đang chờ, vòng "chờ hết lượt" nuốt mất lượt 3.
  - Sửa: chờ điểm tối đa 6 s, thấy lượt mới thì dừng. Chờ hết lượt chỉ tới hết 15 s của lượt đó.
- **Lực và góc chỉ theo điểm thả** (người chơi xác nhận). Giữ lâu chỉ để ngắm.
- **08:27 (`-KhongLuoi`, chỉ kéo thả bắn thử)**: đứng x = 272 (±1). Nhãn 2,4 / 0,4 / 1,6 / 3,6 trùng mẫu, đỉnh cung trùng con Bọ Rùa "1,6 / cao 7,4" như video.
  - x = 274 thì nhãn 2,5 / 3,5 nên đã siết `SaiSoX` 3 → 1.
- Bắt đầu lúc game đang màn tải: chờ tối đa 25 s.
- **08:30 (người chơi chạy, có Lưới)**: cả 3 lượt "không thấy thanh máu nhân vật".
  - Nguyên nhân: vào trận nhân vật đứng sát mép trái (x ≈ 100, y ≈ 455), thanh máu nằm dưới nút di chuyển bán trong suốt nên tối màu (mẫu 1/2 lệch 41–44).
  - Sửa: thêm mẫu `thanh_mau_3` (chỗ bị che). Mẫu này khớp 0–17 ở đó nhưng nhầm chỗ khác ~33, nên chỉ nhận khi < 25.
  - Dự phòng: chưa thấy lần nào trong lượt thì đi phải 1,5 s rồi tìm lại.
- **08:36 (bot, có Lưới)**: **phát lưới đầu tiên đạt 64** (Bọ Rùa x4, Bướm x8), giống hệt người chơi.
  - Bot đọc sai vì Bọ Hung đứng sau bảng Kết quả làm nền đổi màu, mẫu RGB "64" lệch, nên tưởng trượt và bắn thêm lưới thứ 2.
  - Sửa: đọc điểm theo nét chữ xanh lá (`CtDigits`): khớp 0,90–1,00, số khác 0,26–0,37, ngưỡng 0,7.
  - **1 ván chỉ dùng 1 lưới** (người chơi): đã bắn lưới thì các lượt sau PASS.
- Di chuyển (08:34–08:36): bỏ hẳn kiểu "giữ + nhìn" (mỗi lần chụp và tìm mất ~0,7 s nên luôn lố). Mọi đoạn đều giữ nút theo thời gian (tốc độ tự đo 15–28 px/giây). Đoạn dài cố ý thiếu 6 px.
  - Giữ ≥ 0,5 s mà nhân vật không nhúc nhích thì lưu ảnh và thôi đi (nghi hết thể lực).
- **08:42–08:48 (người chơi chạy 5 ván)**: **4/4 ván vào trận đều đạt 64**, mỗi ván 1 lưới.
  - Ván 5 không vào được: quảng trường rộng hơn màn hình, bọ rùa đi ra ngoài khung nhìn.
  - Sửa: tìm cả sát mép dưới. Không thấy thì chạm cho nhân vật đi chỗ khác (camera lia theo) rồi tìm lại, tối đa 12 lần.
  - "Giữ nút mà không nhúc nhích" xảy ra sau một đoạn đi dài (ván 3, 4): đúng là hết thể lực của lượt. Lượt sau đi tiếp được.
- **Người chơi xác nhận 24/11**:
  - **Chạm bướm cũng vào trận.** Bot ưu tiên bọ rùa, không có thì chạm bướm.
    - Bướm ở quảng trường: màu xanh tím (B ≥ 150, B−R ≥ 30, B−G ≥ 25), ~1.265 điểm, khung 79x40.
    - Trứng xanh tím dưới chân tượng cũng cùng màu nhưng chỉ ~460 điểm, khung 28x31, nên bướm phải ≥ 700 điểm.
  - **Hết lưới thì bắn không có điểm.** Bắn lưới mà "Điểm bắt sâu" vẫn 0 thì bot coi là hết lưới và dừng cả lượt chạy.
- **08:55–09:09: trang phục mới** (người chơi đổi). Đứng đúng chỗ, kéo y hệt thì đường cung khác, nên điểm thấp:

  | Giờ | Cách ngắm | Đỉnh cung | Kết quả |
  |---|---|---|---|
  | 08:55 | kéo y hệt (−50, 216) | – | 30 (Bọ Rùa x3, Bướm x3) |
  | 09:01 | tự ngắm | (63, −222) | 60 (x3, x8): sót bọ rùa thấp nhất cột 1,6 |
  | 09:04 | tự ngắm | (64, −218) | 52 (x4, x6): sót 2 bướm thấp |
  | 09:06 | tự ngắm, nhiễu | – | ? |
  | 09:08 | tự ngắm | (53, −202) | 44 (x5, x4) |

  - Bot tự ngắm được (đỉnh cung trong ±5 px), nhưng **trang phục mới lưới / nổ khác** (hiện chữ "Siêu Bùng Nổ", "Bậc Thầy cao cấp"). Cùng đỉnh cung mà kết quả dao động, nên đỉnh (60, −219) của trang phục cũ không áp được.
  - **Đề xuất**: người chơi bắn mẫu 1 phát 64 với trang phục mới (ghi hình), rồi lấy đỉnh cung đó làm `DinhX` / `DinhY`. Hoặc dùng lại trang phục cũ (5/5 ván đạt 64).
  - Đã sửa trong lúc thử:
    - Lượt chỉ tính khi đồng hồ cam đang chạy (`CtTimer`, ≥ 60 điểm cam).
    - Bộ tìm đỉnh cung chỉ nhận A 0,025–0,065, đỉnh gần đích, ≥ 10 chấm.
    - Không thấy cung thì đo lại, không thả bừa.
    - Đuổi theo bọ ở quảng trường.
- **09:31–09:38 (người chơi chạy 5 ván, trang phục cũ)**: **5/5 đạt 64**, mỗi ván 1 lưới.
  - Ván 2–5 tự ngắm không thấy cung (ngưỡng ≥ 10 chấm quá chặt với ảnh chụp trực tiếp). Bot vẫn thả với đường kéo chuẩn nên vẫn đạt. Hạ ngưỡng xuống 8 chấm.
  - Đoạn đi dài thiếu 6 px vẫn lố (100 → 284), lùi lại thì hết thể lực nên mất lượt 1. Đổi thành thiếu 15 px.
