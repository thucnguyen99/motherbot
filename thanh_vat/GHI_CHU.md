# Thánh vật: nhận rương "Đạt được" (19/11/2026)

Thưởng treo máy: tích luỹ theo giờ, tối đa **9 giờ**, cứ 6 phút ra một lần thưởng. Mức hiện tại là "Chương 3 Tổ Côn Trùng", 10/giờ.

Bot nhận rương trong **mỗi lượt nông trại** (`ddtank_farm.ps1`, công tắc `$ThanhVat = $true`). Thứ tự trong lượt: vào sảnh → nhận rương → về sảnh → mở nông trại, thu hoạch như cũ. Khoai chín khoảng 8 tiếng, nên mỗi lần nhận rương gần đầy, không phí.

## Các bước (đã thử tay 19/11 lúc 12:16 giờ game)
| Bước | Màn hình | Bấm (1600x900) | Ảnh mẫu `mau/` |
|---|---|---|---|
| 1 | Sảnh | **Dạy dỗ** (1185, 840) | `nut_day_do` (chép từ thám hiểm) |
| 2 | Menu Dạy dỗ | **Thánh vật** (1255, 540) | `muc_thanh_vat` |
| 3 | Màn Thánh vật | **Đạt được** ở góc trên trái (105, 205) | `nut_dat_duoc` |
| 4 | Màn Đạt được ("Chương …", "10/giờ") | **rương** ở góc dưới phải (1410, 760) | `man_dat_duoc` (biểu tượng Cửa hàng) |
| 5 | Popup **"Thời gian bố trí"** | **Nhận** (798, 745) nếu nút xanh | `popup_bo_tri`, `nut_nhan` |
| 6 | Popup **"Có thưởng"** | chạm giữa màn hình (700, 420) | `popup_co_thuong` |
| 7 | Màn Đạt được | **Quay lại** (75, 45) **một lần** → về thẳng sảnh, menu Dạy dỗ vẫn mở | |
| 8 | Sảnh | **Dạy dỗ** để đóng menu | |

- **Rương chưa có thưởng:** popup ghi "00:00:18", danh sách trống, **nút Nhận màu xám** (`nut_nhan_xam`). Bot đóng popup bằng ✕ ở (1487, 77) (`nut_dong`).
- ⚠️ Ở sảnh, góc trên trái là **ảnh đại diện**. Bấm "Quay lại" khi đã ở sảnh sẽ mở màn thông tin nhân vật (19/11 lỡ bấm 1 lần). Bot chỉ bấm Quay lại khi **chưa** thấy sảnh (`btn_friends`, không có popup).

## Ngưỡng khớp (đo trên 14 ảnh)
- Đúng chỗ: 0–6,3. Chỗ khác: ≥ 38.
- Nhận xanh và Nhận xám lệch nhau 56.
- Popup "Có thưởng": 8,2–12,7.
- Ngưỡng dùng trong code: 12, riêng `popup_bo_tri` 18, `nut_nhan` / `nut_nhan_xam` 15, `popup_co_thuong` 25.

## Lỗi thì sao
- Lỗi giữa chừng → làm lại bước Thánh vật (tối đa 3 lần), trước mỗi lần thử thì đóng popup và về sảnh.
- Hết lần thử → **bỏ qua**, Telegram ghi "⚠️ Thánh vật lỗi…". Bot về sảnh (không được thì mở lại game), rồi **vẫn thu hoạch bình thường**.
- Telegram: ảnh "🎁 Thánh vật: đã nhận rương Đạt được" kèm dòng tóm tắt. Lịch sử `lich_su.jsonl` có trường `tv` (đã nhận hay chưa).
- Chạy cả khi `/xemruong` (`-ViewOnly`, từ 20/11 theo yêu cầu). Không chạy khi `-SkipLaunch`, `-LoginOnly` hoặc thám hiểm (`-Job tham_hiem`).

## Trạng thái
Code đã viết và qua kiểm tra cú pháp. **Chưa chạy thử trong một lượt nông trại thật.**
