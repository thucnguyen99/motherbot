# Thú cưỡi thám hiểm: ghi chú khám phá (19/11/2026)

Bot khám phá bằng cách bấm từng bước rồi chụp màn hình bằng `adb exec-out screencap -p`, ảnh 1600x900. Ảnh lưu trong `ghi_hinh/` (không đưa lên git).

## Các bước
| Bước | Màn hình | Bấm (1600x900) | Ảnh mẫu |
|---|---|---|---|
| 0 | Sảnh chính | **Dạy dỗ** ở thanh dưới (1185, 840) | `mau/nut_day_do.png` |
| 1 | Menu Dạy dỗ (lưới biểu tượng) | **Thú cưỡi** (972, 385) | `mau/muc_thu_cuoi.png` |
| 2 | Màn Thú cưỡi | **Thú cưỡi Thám hiểm** ở cột trái (285, 400) | `mau/muc_tham_hiem.png` |
| 3 | Màn Thám hiểm: 3 tab **Tổ đội 1/2/3** ở (175,145), (470,145), (768,145) | | |

- `nut_day_do` và `muc_tham_hiem` có **chấm đỏ thông báo**, lúc có lúc không. Khi so khớp phải bỏ góc trên phải của ảnh mẫu.
- Nút **Quay lại** ở góc trên trái (75, 45).

## Trạng thái mỗi tổ đội (chữ trên tab, cạnh tên đội)
| Chữ trên tab | Ý nghĩa | Nút ở (1408, 818) |
|---|---|---|
| **Kết thúc** (xanh lá, thanh tiến độ đầy) | Đã xong, chưa nhận | **Nhận** (xanh lá), `mau/nut_nhan.png` |
| **Chưa có** (xám) | Đã nhận, chưa xuất phát | **Xuất phát** (xanh lá), `mau/nut_xuat_phat.png` |
| **hh:mm:ss** (vd 11:58:28) | Đang thám hiểm, đếm ngược 12 tiếng | **Gọi về** (cam), `mau/nut_goi_ve.png` |

- ⚠️ **Nhận, Xuất phát và Gọi về nằm cùng một chỗ.** Bot phải nhận đúng nút trước khi bấm, và **không bao giờ bấm Gọi về**.
- Bấm Gọi về sẽ hiện hộp **"Nhắc nhở"** (`mau/hop_nhac_nho.png`) với nội dung: "Gọi đội Chinh Chiến của bạn trở về ngay sẽ bị mất hết chiến lợi phẩm!"
  - Hộp có 2 nút: **Hủy bỏ** (602, 607) và **Xác nhận** (998, 607).
  - Nếu lỡ thấy hộp này, bot phải bấm **Hủy bỏ** (hoặc nút ✕ ở (1178, 250)). Không bao giờ bấm Xác nhận.
- Góc trên trái khung cảnh ghi tên khu và trạng thái: "Kết thám hiểm" / "Thời gian cần 12:00:00" / "Đang khám phá map".

## Nhận rồi cho đi tiếp (mỗi tổ đội)
1. Bấm tab tổ đội đó. Nếu tab ghi **Kết thúc** thì bấm **Nhận**.
2. Hiện popup **"Có thưởng"** (`mau/popup_co_thuong.png`) kèm danh sách quà, và dòng "Nhấn để tiếp tục" ở góc dưới phải.
   - Dòng chữ đó nằm đè lên nút Xuất phát. Bot chạm **giữa màn hình (700, 400)** để đóng, không chạm góc dưới phải.
   - Có thể kèm thông báo Bang: "Hoàn thành Thám hiểm thú cưỡi 6 lần".
3. Tab chuyển sang **Chưa có**. Game **tự giữ khu và thú cưỡi cũ** của đội:
   - Tổ đội 1: Vùng Đất Bí Ẩn, 3 thú.
   - Tổ đội 2: Đảo Hoang Tàn, 3 thú.
   - Tổ đội 3: Bình Nguyên Xanh, 5 thú.
4. Bấm **Xuất phát**. Tab đổi sang **12:00:00**, nút đổi thành Gọi về.

- Mỗi khu chỉ có một đội đi cùng lúc: khu đang có đội khác thì hiện "Đang thám hiểm".
- Ở dưới có "Rơi ra" (vật phẩm có thể rơi) và hộp "Cần N điểm tìm kiếm". Hai thứ này không cần bấm.
- 19/11 khoảng 22:50: đã nhận và cho đi tiếp cả 3 đội. Các đội sẽ xong vào khoảng **10:50 sáng 20/11**, lệch nhau vài chục giây.

## Thoát ra sảnh chính (đã thử 19/11)
1. Ở màn Thám hiểm, bấm **Quay lại** (75, 45) → về màn **Thú cưỡi**.
2. Bấm **Quay lại** (75, 45) lần nữa → về **sảnh chính**, nhưng **menu Dạy dỗ vẫn còn mở**.
3. Bấm lại **Dạy dỗ** (1185, 840) → menu đóng, sảnh sạch.

- Kiểm tra đã ở sảnh: dùng cách của nông trại, tức thấy nút Giao lưu (`btn_friends`) và không có popup.
- Kiểm tra menu đã đóng: không còn thấy ô Thú cưỡi (`mau/muc_thu_cuoi.png`).
- Chấm đỏ ở mục Thú cưỡi Thám hiểm **vẫn còn sau khi đã nhận hết**, nên không dùng chấm đỏ để biết có thưởng hay không.

## Đã làm (19/11 23:15)
- **Chạy:** `ddtank_farm.ps1 -Account akaka -Job tham_hiem`, hoặc lệnh bot `/thamhiem akaka`. Thám hiểm dùng chung toàn bộ phần của nông trại:
  - bật máy ảo, đăng nhập đúng tài khoản;
  - khoá thiết bị và xếp hàng khi trùng lượt nông trại;
  - né giờ bảo trì, mất mạng, `/tamdung`;
  - Telegram có hàng đợi gửi bù;
  - ghi `lich_su.jsonl` (`job = tham_hiem`, `nhan`, `di`).
- **Lịch:** task riêng `DDTank Farm - <tk> - tham hiem`, hẹn **trước 5 phút** lúc tổ đội xong sớm nhất rồi **ngồi chờ** đội còn ≤ 12 phút là xong, xong là nhận + cho đi tiếp luôn (giống nông trại chờ cây chín; sửa 20/11 sau lượt thử 08:34: trước đây hẹn sau 3 phút, không chờ). Trạng thái nằm ở `state\<tk>.tham_hiem.json` / `.off` / `.offline`, không đè lên trạng thái nông trại.
- **Phần riêng của thám hiểm:**
  - `cong_cu/tham_hiem.ps1`: vào màn, xử lý 3 tổ đội, đọc giờ, về sảnh.
  - `cong_cu/TabTimer.cs`: đọc đồng hồ trên tab.
  - `mau/so_tab.txt`: mẫu chữ số.
- **Nhận nút:** lấy nút giống nhất trong 3 nút Nhận / Xuất phát / Gọi về, ngưỡng < 12 (đo trên 28 ảnh).
  - Đúng nút: 3,7–6,2. Nhận ↔ Xuất phát lệch 19,2. Màn khác ≥ 48.
  - Mỗi lần bấm đều chụp lại và kiểm tra ngay trước khi bấm. Thấy hộp "Nhắc nhở" thì bấm Hủy bỏ.
- **Đọc đồng hồ:** chỉ đọc ở tab **không chọn**, vì nền kem của tab đang chọn gây nhiễu. Chọn tab 1 để đọc tab 2, 3; chọn tab 2 để đọc tab 1.
  - Kiểm tra chéo trên 9 đồng hồ: đọc đúng 8/9. Ca sai là chữ 7 khi chỉ có 1 mẫu, khoảng cách 12,2, vượt ngưỡng 6 nên bị bỏ.
  - **Còn thiếu mẫu chữ số 6.** Đồng hồ đọc không chắc được lưu ảnh `logs\*_dong_ho_doi<k>_khong_doc_duoc.png` để bổ sung mẫu.
  - Không đọc được thì ước tính: đội vừa xuất phát trong lượt này lấy lúc xuất phát + 12 tiếng. Không có giờ nào thì xem lại sau 60 phút.
- **Chạy thử 23:09** (`-SkipLaunch`): game đang ở màn nông trại (người chơi đang dùng), bot báo "Không thấy nút Dạy dỗ" và không bấm gì. **Chưa chạy thử trọn một lượt.**

## Kế hoạch script (`cong_cu/`)
1. **Vào màn Thám hiểm** từ sảnh: Dạy dỗ → Thú cưỡi → Thú cưỡi Thám hiểm, chờ và kiểm tra bằng ảnh mẫu ở mỗi bước.
2. **Duyệt 3 tab:**
   - Kết thúc → Nhận → đóng popup → Xuất phát → kiểm tra thấy giờ đếm ngược.
   - Chưa có → Xuất phát.
   - Đang chạy → đọc giờ còn lại.
3. **Hẹn giờ lần sau** = lúc đội xong sớm nhất (giờ hiện tại + thời gian còn lại nhỏ nhất) + vài phút. Cách làm giống nông trại hẹn theo giờ khoai chín.
4. **Giả lập người** như nông trại và câu cá: chạm lệch ngẫu nhiên, giữ ngón 45–120 ms, chờ ngẫu nhiên giữa các bước. Nhận cả 3 đội liền một lượt nhưng có nghỉ ngắn ngẫu nhiên.
5. **Tích hợp** như nông trại:
   - Dùng chung khoá thiết bị, để không chạy chồng lên nông trại hoặc câu cá.
   - Tự bật máy ảo và đăng nhập đúng tài khoản.
   - Gửi Telegram ảnh 3 tổ đội kèm tóm tắt quà nhận được và giờ lần sau. Ghi vào `lich_su.jsonl`.
