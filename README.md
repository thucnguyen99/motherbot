# DDTank Farm – tự động thu hoạch & trồng khoai

Script PowerShell điều khiển **MuMu Player** qua **ADB** để vào DDTank Mobile, thu hoạch nông trại, gieo khoai tây vào 10 ô đất, kiểm tra kết quả, tắt app và tắt thiết bị. Chạy xong, script **gửi ảnh kết quả về Telegram**. Có kèm lệnh cài lịch chạy định kỳ bằng Windows Task Scheduler, và **bot Telegram** để chạy / xem trạng thái / dừng script bằng lệnh nhắn tin.

Không cần cài thêm gì: dùng PowerShell 5.1 có sẵn trong Windows, `adb.exe` và `MuMuManager.exe` đi kèm MuMu Player. Nhận diện hình ảnh viết bằng C# (`Vision.cs`), được biên dịch tự động mỗi lần chạy.

---

## 0. Bắt đầu nhanh

Mọi lệnh dưới đây chạy trong thư mục `D:\tools\ddtank-farm`.

1. Kiểm tra phần **Chuẩn bị** (mục 2) đã đủ.
2. Cấu hình Telegram (mục 5), rồi gửi thử:
   ```bat
   run.bat -Account tomcat12345 -TestTelegram
   ```
3. Chạy thử trọn quy trình một lần, có lưu ảnh từng bước:
   ```bat
   run.bat -Account tomcat12345 -StepShots
   ```
4. Lịch tự chạy: lần chạy tay ở bước 3 đã **tự hẹn lần sau** lúc khoai chín (mục 4, cách 1). Không cần cài gì thêm. Mỗi tài khoản chỉ cần chạy tay 1 lần đầu.
   Nếu muốn lịch cố định thay vì tự lập lịch (mục 4, cách 2):
   ```bat
   lap_lich.bat 23:00 8:05 tomcat12345
   ```
5. Xem lịch đã cài:
   ```bat
   lap_lich.bat -Xem
   ```
6. (Tuỳ chọn) Cài bot để điều khiển bằng lệnh Telegram (`/chay`, `/trangthai`, `/dung`…), xem mục 5 phần *Điều khiển bằng lệnh Telegram*:
   ```bat
   cai_bot.bat
   ```

---

## 1. Quy trình script thực hiện

1. **Mở thiết bị MuMu tên `auto`**, chờ Android khởi động xong và ADB kết nối được.
2. **Mở app DDTank** (`com.wan.ddten`).
3. **Đăng nhập**
   - Màn hình **"Đăng nhập"** (chưa đăng nhập): tick ô *Đã đọc và đồng ý Điều khoản*, bấm *Đăng nhập* → *7Road Login*, bấm ▼ để mở danh sách tài khoản đã lưu, **tìm đúng tên tài khoản** (cuộn danh sách nếu tên không nằm ở đầu) → bấm *Login/Register*. Mật khẩu do app tự điền. Script chỉ bấm vào **tên**, không bao giờ bấm nút ✕ (nút này xoá tài khoản đã lưu).
   - Màn hình **"Vào game"** (đã đăng nhập sẵn): tick ô điều khoản nếu đang trống, rồi bấm *Vào game*.
4. **Đóng popup quảng cáo / nạp tiền**: popup này tùy account, có account có, có account không. Script chỉ bấm nút ✕ đỏ khi popup thật sự xuất hiện.
5. **Vào nông trại**: nút *Bạn bè* (góc dưới trái) → nút nông trại (biểu tượng cây cọ, nút giữa).
6. **Đi tới cạnh ruộng**: điểm vào nông trại cố định, ruộng bị khuất ở mép trên màn hình, nên script cho nhân vật đi tới bãi cỏ ngay dưới góc phải ruộng.
7. **Thu hoạch** bằng cách bấm vào biểu tượng **bàn tay** trên từng ô, theo đường rắn để nhân vật đi ít nhất:
   - **Hàng trước** (gần nhân vật): từ **phải → trái**.
   - Xong hàng trước thì **đi ra lối đi phía trên bên trái** ô đầu hàng sau (điểm "xanh").
   - **Hàng sau**: từ **trái → phải**.
   - Sau **mỗi** lần thu hoạch: chờ popup *"Có thưởng"*, bấm **"Nhấn để tiếp tục"** rồi mới tìm ô tiếp theo.
   - Nếu không có ô nào chín, script kiểm tra xem ruộng có **thanh thời gian** (cây đang lớn) hoặc **mầm cây** (vừa gieo) không:
     - Trước tiên đếm **thanh thời gian trên cả màn hình**, không cần biển gỗ, vì cây lớn thường **che mất biển gỗ**.
     - Không thấy thanh nào (ruộng trống, hoặc vừa gieo nên thanh chưa có phần màu xanh) thì mới tìm biển gỗ và kiểm tra từng ô như cũ. Lúc này cây còn nhỏ nên biển gỗ không bị che.
     - **Ruộng trống** (không ô nào có): bỏ qua thu hoạch, **trồng mới luôn**, không chờ.
     - **Cây đang lớn** (có ô có thanh thời gian / mầm cây): **chờ tối đa 12 phút** (`$WaitRipeMinutes`), cứ 30 giây kiểm tra 1 lần. Cây chín thì **thu hoạch + gieo luôn** trong lượt đó (tin Telegram ghi *"đã chờ cây chín N phút"*). Hết 12 phút vẫn chưa chín thì không gieo, tắt máy, báo về Telegram. Lịch tự lập hẹn **trước giờ chín 5 phút** để khoảng chờ này vừa kịp lúc cây chín (mục 4).
   - Xong thì **chụp ảnh 1**: ruộng sau khi thu hoạch (hoặc ruộng trống).
8. **Gieo khoai tây**: bấm *gieo hạt* → tìm **túi hạt khoai tây (màu nâu vàng)** trong danh sách. Danh sách khác nhau tùy account, chưa thấy thì script tự cuộn xuống. Sau đó **nhấn giữ và kéo quét qua 10 ô đất** → *Xác nhận*.
   - Vị trí 10 ô đất thay đổi theo chỗ nhân vật đứng, nên script lấy **biển gỗ cạnh ruộng** làm mốc để tính toạ độ từng ô.
9. **Kiểm tra đã trồng**: đếm số ô có mầm cây. OK khi thấy ≥ 8/10, vì nhân vật có thể che 1–2 ô. Sau đó **chụp ảnh 2**: ruộng sau khi trồng.
10. **Tắt app DDTank** rồi **tắt thiết bị `auto`** để máy không bị treo. Bước này luôn chạy, kể cả khi có lỗi ở giữa.
11. **Gửi ảnh về Telegram** (nếu đã cấu hình, xem mục 5).

---

## 2. Chuẩn bị (làm 1 lần)

| Việc | Ghi chú |
|---|---|
| MuMu Player cài tại `D:\Program Files\Netease\MuMuPlayer` | Nếu khác, sửa `$MuMuDir` đầu file `ddtank_farm.ps1` và `telegram_bot.ps1`. Bot câu cá tự tìm MuMu trên mọi ổ đĩa |
| Có thiết bị MuMu tên **`auto`** | Sửa `$DeviceName` nếu dùng tên khác |
| Màn hình thiết bị **1600 x 900, DPI 240** | **Bắt buộc**, xem mục 7 |
| Đã cài DDTank trên thiết bị `auto` | |
| Tài khoản 7Road **đã đăng nhập tay ít nhất 1 lần** trên thiết bị này để app **lưu tên và mật khẩu** | Script chỉ chọn tài khoản trong danh sách đã lưu, **không gõ mật khẩu** |
| Có hạt khoai tây trong túi hạt giống | Hết hạt thì script báo lỗi `Khong tim thay hat khoai tay` |
| (Tuỳ chọn) Bot Telegram + `telegram.json` | Để nhận ảnh kết quả, xem mục 5 |

---

## 3. Chạy tay

```bat
run.bat -Account <tên tài khoản 7Road> [tuỳ chọn]
```

| Tham số | Ý nghĩa |
|---|---|
| `-Account <tên>` | Tài khoản 7Road đã lưu trong app. **Luôn truyền vào**, bắt buộc khi game đòi đăng nhập |
| `-StepShots` | Lưu ảnh màn hình ở **từng bước** vào `logs\` để kiểm tra |
| `-KeepDevice` | Không tắt thiết bị khi xong (để xem/test). App DDTank vẫn bị tắt |
| `-LoginOnly` | Chỉ đăng nhập tới sảnh chính rồi dừng, không vào nông trại, không gửi Telegram |
| `-SkipLaunch` | Thiết bị đã mở và đang đứng trong nông trại: bỏ qua bước mở app/đăng nhập |
| `-TestTelegram` | Chỉ gửi thử ảnh có sẵn trong `logs\` lên Telegram rồi thoát, không mở máy ảo |
| `-ViewOnly` | Chỉ vào nông trại chụp ảnh ruộng gửi Telegram: không thu hoạch, không gieo, không đổi lịch (lệnh bot `/xemruong`) |
| `-Manual` | Chạy tay: vẫn chạy khi đang `/tamdung`. `run.bat` và lệnh bot `/chay` **tự thêm**, không cần gõ |

Ví dụ:

| Lệnh | Dùng khi |
|---|---|
| `run.bat -Account tomcat12345` | Chạy bình thường (giống lúc chạy theo lịch) |
| `run.bat -Account tomcat12345 -StepShots -KeepDevice` | Test kỹ, xem ảnh từng bước, giữ máy mở |
| `run.bat -Account tomcat12345 -LoginOnly -KeepDevice` | Chỉ thử bước đăng nhập |
| `run.bat -Account tomcat12345 -TestTelegram` | Thử cấu hình Telegram |
| `run.bat -Account tomcat12345 -ViewOnly` | Xem ruộng đang thế nào, không đụng vào cây |

Mã thoát: `0` thành công (kể cả khi cây chưa chín nên bỏ qua), `1` lỗi (xem log), `2` đang có lượt khác chạy, `3` mất mạng, `4` giờ bảo trì game, `5` đang tạm dừng (`/tamdung`).

Trước khi mở MuMu, script **kiểm tra RAM trống và ổ đĩa**. RAM trống dưới 2,5 GB hoặc ổ C / ổ chứa script còn dưới 5 GB thì vẫn chạy, nhưng tin Telegram có thêm dòng cảnh báo, ví dụ `⚠️ Máy sắp hết RAM: còn 0.9 GB trống / 7.9 GB (dùng nhiều: MuMuVMMHeadless 2.2 GB, claude 0.9 GB, chrome 0.9 GB)…`. Ngưỡng chỉnh ở `$MinFreeRamMB`, `$MinFreeDiskGB` (mục 9).

---

## 4. Cài lịch chạy tự động

Có 2 cách. **Nên dùng cách 1**, và đừng dùng cả 2 cho cùng một tài khoản, vì sẽ chạy thừa.

### Cách 1: Tự lập lịch theo giờ khoai chín (mặc định, riêng từng tài khoản)

Mỗi lần chạy xong, script **tự hẹn lần chạy sau** của chính tài khoản đó. Lịch là một task Windows tên `DDTank Farm - <tài khoản>`, chạy 1 lần. Chỉ cần chạy tay 1 lần đầu để bắt đầu chuỗi (`run.bat -Account akaka` hoặc `/chay akaka` trên Telegram). Từ đó chuỗi tự nối tiếp.

| Kết quả lần chạy | Lần sau được hẹn lúc |
|---|---|
| Gieo khoai xong | Khoai chín (giờ gieo + 8 tiếng) **− 5 phút** (hẹn trước giờ chín) |
| Cây đang lớn, đã biết giờ chín từ lần gieo trước | Giờ chín − 5 phút (giờ đó đã qua hoặc còn dưới 2 phút thì hẹn 2 phút nữa) |
| Đã chờ đủ 12 phút, quá giờ chín mà cây vẫn chưa chín | Sau 10 phút. Tối đa 3 lần, sau đó dừng chuỗi và báo về Telegram |
| Không biết giờ chín (vd cây do người trồng tay) | Không hẹn, báo về Telegram để bạn tự `/chay` khi khoai chín |
| Lỗi (đăng nhập, không thấy nút…) | **Làm lại ngay bước bị lỗi, tối đa 3 lần** (vào game: tắt app mở lại; mở nông trại / thu hoạch / gieo hạt: đóng popup đang che). Một bước lỗi đủ 3 lần thì khởi động lại thiết bị, chạy lại cả lượt 1 lần. Vẫn lỗi mới hẹn lại sau 30 phút; lỗi 3 lượt liên tiếp thì dừng chuỗi và báo Telegram. Telegram ghi từng lần làm lại *"🔁 Bước … lỗi lần N: … → làm lại bước"*. Lỗi mà thử lại cũng vô ích (chưa lưu mật khẩu, không thấy tài khoản, hết hạt khoai), mất mạng, giờ bảo trì, hoặc lượt đã chạy quá 35 phút thì không làm lại |
| **Mất mạng Internet** (lúc bắt đầu, hoặc gặp lỗi mà lúc đó không có mạng) | Sau 10 phút, **không tính vào 3 lần lỗi**, thử lại mãi tới khi có mạng |
| **Giờ bảo trì game** (thứ 5, 14:00–15:00 giờ Việt Nam) | Sau giờ bảo trì (15:15), **không tính vào 3 lần lỗi** |
| Đang có lượt khác chạy (vd 2 tài khoản trùng giờ) | Sau 10 phút |
| Đang **tạm dừng** (`/tamdung <giờ>` trên Telegram) | Lúc hết tạm dừng + 1 phút, không gửi Telegram. `/chay` và `/xemruong` vẫn chạy được. `/tiep` bật lại sớm và kéo các lượt bị dời về chạy ngay (2 phút nữa) |

**Hẹn trước giờ chín 5 phút + chờ 12 phút** (`$AutoDelayMinutes = -5`, `$WaitRipeMinutes = 12`). Ví dụ khoai chín 16:22:

| Giờ | Việc |
|---|---|
| 16:17 | Lịch chạy: mở MuMu, vào game, vào nông trại (~2–3 phút) |
| ~16:20 | Thấy cây còn đang lớn → chờ, 30 giây kiểm tra 1 lần |
| 16:22 | Cây chín → thu hoạch 10 ô, gieo khoai ngay (~3 phút) |
| ~16:26 | Xong, tắt máy, gửi Telegram. Lần gieo mới chín ~00:26 → hẹn 00:21 |

Nhờ vậy khoai được thu gần như **đúng lúc chín** và gieo lại ngay, không mất vài phút mỗi vòng như cách hẹn sau giờ chín. Cây chín trễ hơn dự tính tới ~7 phút vẫn kịp thu trong cùng lượt. Mỗi lượt mất tối đa ~20 phút (giới hạn task: 45 phút).

**Giờ bảo trì game** (mặc định **thứ 5, 14:00–15:00, giờ Việt Nam**, đổi trong `$MaintenanceWindows` đầu `ddtank_farm.ps1`):
- Giờ hẹn rơi vào khoảng **13:35 – 15:15 thứ 5** (25 phút trước bảo trì vì 1 lượt chạy mất ~6 phút + chờ cây chín tối đa 12 phút, 15 phút sau phòng bảo trì kéo dài) thì được **dời sang 15:15**. Tin Telegram ghi rõ: `⏰ Đã tự lập lịch lần tới: 15:15 … (khoai chín 14:00; dời qua giờ bảo trì game thứ 5 14:00–15:00)`.
- Lượt chạy bắt đầu trong khoảng đó (vd `/chay` tay, hoặc lịch chạy bù) thì **không mở thiết bị**, hẹn lại 15:15 và nhắn `🛠️ Đang giờ bảo trì game (thứ 5 14:00–15:00) – không chạy lượt này.`
- Lỗi xảy ra trong khoảng đó (game đóng cửa giữa chừng) cũng hẹn lại 15:15 và không tính là lỗi.
- Bảo trì **đột xuất** hoặc kéo dài quá 15:15 thì vẫn tính là lỗi bình thường (thử lại 30 phút/lần, 3 lần thì dừng chuỗi, gửi `/chay <tài khoản>` để chạy lại).
- Giờ bảo trì luôn tính theo **giờ Việt Nam** (`$MaintTimeZone`), dù máy để múi giờ nào.

**Tự kết nối lại Wi-Fi** (thêm 18/11, `ket_noi_mang.ps1`, dùng chung cho script nông trại và bot):
- Lúc còn mạng, script và bot nhớ tên card + Wi-Fi đang dùng vào `state\wifi.txt` (hiện là `Wi-Fi|<tên Wi-Fi>`).
- **Sóng Wi-Fi bị tắt** (nút Wi-Fi trong Quick Settings, chế độ máy bay): bật lại sóng bằng Windows Radio API (không cần quyền admin), Windows tự kết nối lại Wi-Fi *Connect automatically*.
- Mất mạng **60 giây**: **chọn Wi-Fi đã lưu có sóng mạnh nhất** đang bắt được và `netsh wlan connect` (không cần quyền admin), chờ tối đa 20 giây xem có Internet thật không; không có thì thử Wi-Fi đã lưu mạnh kế tiếp (tối đa 3 mạng). Đang nối 1 mạng mà mạng đó không có Internet thì thử các mạng khác trước. **Chỉ chọn trong Wi-Fi đã lưu**, không bao giờ tự nối mạng lạ / mạng mở.
- **Thêm Wi-Fi dự phòng:** bấm vào Wi-Fi đó trên taskbar, tick *Connect automatically*, nhập mật khẩu 1 lần → Windows lưu lại, lần mất mạng sau script/bot sẽ tự chọn giữa các Wi-Fi đã lưu theo sóng. Xem danh sách đã lưu: `netsh wlan show profiles` (18/11 máy chỉ lưu *<tên Wi-Fi>*).
- Mất **120 giây**: thêm bước **khởi động lại card Wi-Fi** (chỉ khi chạy bằng quyền admin, xem dưới; không có quyền thì chỉ làm bước netsh).
- Bot Telegram chạy 24/7 nên vẫn tự kết nối lại cả khi không có lượt nông trại nào, sau đó cứ 10 phút thử lại 1 lần. Có mạng lại bot nhắn *"📶 Bot có mạng lại … Bot đã tự kết nối lại Wi-Fi '<tên Wi-Fi>'"*; tin nông trại có dòng *"🔧 Mất mạng lúc … – đã tự kết nối lại Wi-Fi …"*.
- Không đổi cấu hình mạng nào; chỉ kết nối lại vào Wi-Fi đã lưu sẵn. Tắt: `$AutoReconnect = $false` (đầu `ddtank_farm.ps1` và `telegram_bot.ps1`).
- **Tuỳ chọn – cho phép khởi động lại card Wi-Fi:** mở *Terminal (Admin)* và chạy lệnh dưới để lịch chạy có quyền admin (bot cần khởi động lại máy hoặc chạy lại `cai_bot.bat` để áp dụng):
  ```powershell
  $p = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
  Set-ScheduledTask -TaskName "DDTank Bot" -Principal $p
  Get-ScheduledTask "DDTank Farm*" | ForEach-Object { Set-ScheduledTask -TaskName $_.TaskName -Principal $p }
  ```

**Khi mất mạng** (vd Wi-Fi chưa kết nối lại sau khi máy thức dậy):
- Trước khi mở thiết bị, script kiểm tra Internet và **chờ tối đa 5 phút**. Vẫn không có mạng thì không mở thiết bị, hẹn lại sau 10 phút, không gửi Telegram (log ghi *"Mat mang"*).
- Có mạng lại, tin Telegram của lần chạy đó có thêm dòng `📵 Mất mạng từ 23:58 17/11 đến 08:16 18/11 – đã thử lại 49 lần (không tính là lỗi)`.
- Tin Telegram nào gửi không được (mất mạng giữa chừng) được lưu ở `logs\telegram_cho_gui\` và **gửi bù** ở lần chạy sau có mạng, đầu tin ghi `📨 Tin gửi trễ (lúc đó mất mạng)`.

- Giờ đã hẹn có trong tin Telegram, dòng `⏰ Đã tự lập lịch lần tới: …`. Xem tất cả lịch: `/lich` trên Telegram.
- **Dừng chuỗi** của 1 tài khoản: `/huylich <tài khoản>`. Lệnh này xoá lịch và tạo file `state\<tài khoản>.off`. **Bật lại**: `/chay <tài khoản>`, lệnh này đồng thời xoá đếm lỗi. Nếu không dùng bot: xoá file `.off` rồi chạy tay 1 lần.
- Giờ chín của lần gieo gần nhất lưu ở `state\<tài khoản>.json`.
- Tắt hẳn tính năng này: đặt `$AutoSchedule = $false` đầu file `ddtank_farm.ps1`. Các mốc −5 / 12 / 10 / 30 phút và số lần thử lại (3) cũng chỉnh ở đó.
- Lịch tự lập có thiết lập giống lịch cố định bên dưới: đánh thức máy, chạy bù khi máy bật lại, tối đa 45 phút.

### Cách 2: Lịch cố định (giờ bắt đầu + chu kỳ)

```bat
lap_lich.bat <giờ bắt đầu> <chu kỳ> <tài khoản>
```

| Ví dụ | Ý nghĩa |
|---|---|
| `lap_lich.bat 23:00 8:05 tomcat12345` | Bắt đầu 23:00 hôm nay, lặp lại mỗi 8 tiếng 05 phút |
| `lap_lich.bat 15:00 8 tomcat12345` | Bắt đầu 15:00, lặp lại mỗi 8 tiếng |
| `lap_lich.bat "2026-11-18 07:30" 6 tomcat12345` | Bắt đầu vào ngày giờ cụ thể |
| `lap_lich.bat -Xem` | Xem lịch hiện tại, lần chạy tới, kết quả lần trước |
| `lap_lich.bat -Xoa` | Xoá lịch |

- **Giờ bắt đầu**: `HH:mm` là hôm nay, hoặc `"yyyy-MM-dd HH:mm"`. Theo giờ máy (máy đang ở UTC+7, giờ Việt Nam).
- **Chu kỳ**: `8` (giờ), `8.5` (giờ lẻ) hoặc `8:05` (giờ:phút).
- **Tài khoản**: tên tài khoản 7Road, được truyền vào script mỗi lần chạy theo lịch.
- Chạy lại lệnh thì **ghi đè** lịch cũ. Chỉ có 1 lịch tên `DDTank Farm`.
- **Nên dùng chu kỳ `8:05`** thay vì `8`. Khoai cần đúng 8 tiếng, mà script gieo vào khoảng phút thứ 5 của lần chạy, nên chu kỳ 8:05 bảo đảm khoai đã chín khi tới ruộng. Với chu kỳ 8, lần chạy tới khi khoai còn vài phút nữa mới chín: script chờ tối đa 12 phút nên vẫn thu được, nhưng giờ gieo trễ dần mỗi vòng, vài vòng sau sẽ vượt quá 12 phút và lượt đó bỏ qua. Lịch tự lập (cách 1) không bị trôi như vậy vì luôn hẹn theo giờ chín thật.
- **Chọn giờ bắt đầu sau lúc khoai chín.** Tin Telegram mỗi lần chạy có ghi giờ "thu hoạch tiếp theo", dùng giờ đó để chọn.
- Kiểm tra lệnh mà lịch sẽ chạy bằng `lap_lich.bat -Xem`. Dòng *Lenh* phải có `-Account <tên>`. Nếu không có, chạy lại lệnh cài lịch.

Thiết lập của lịch:
- Chạy **chỉ khi bạn đang đăng nhập Windows**, vì MuMu cần giao diện. Màn hình khoá thì vẫn chạy.
- Tự **đánh thức máy** khi đang sleep. Nếu lỡ giờ (máy tắt) thì **chạy bù** ngay khi máy bật lại.
- Không chạy chồng 2 lần cùng lúc. Mỗi lần tối đa 45 phút.

---

## 5. Gửi ảnh về Telegram

### Nội dung gửi sau mỗi lần chạy

| Trường hợp | Gửi |
|---|---|
| Thu hoạch + trồng xong | Album 2 ảnh: **(1) sau khi thu hoạch**, **(2) sau khi trồng** |
| Ruộng trống + trồng xong | Album 2 ảnh: **(1) ruộng trống**, **(2) sau khi trồng** |
| Cây chưa chín | 1 ảnh "cây đang lớn" |
| Có lỗi | Ảnh màn hình lúc lỗi |

Toàn bộ nội dung được **gộp vào 1 chú thích**, gắn vào ảnh đầu tiên. Ảnh thứ hai không có chú thích. Telegram chỉ hiện chữ ngay dưới album khi chỉ một ảnh có chú thích, nên làm vậy thì chữ luôn hiện ở ngoài, không cần bấm vào ảnh. Thông báo đẩy trên điện thoại cũng có chữ.

Ví dụ tin nhắn khi thu hoạch và trồng xong:

```
🚜 DDTank [tomcat12345] 17/11 23:06
1/2 Sau khi thu hoạch: 10 ô
2/2 Sau khi trồng khoai: OK – thấy mầm cây ở 10/10 ô

✅ Xong việc lúc: 23:06 17/11/2026
🥔 Thu hoạch tiếp theo (khoai chín): 07:05 18/11/2026
⏰ Đã tự lập lịch lần tới: 07:00 18/11/2026 (khoai chín 07:05)
```

Các dạng tin khác:

| Trường hợp | Dòng nội dung |
|---|---|
| Ruộng trống | `1/2 Ruộng trống – không có cây để thu hoạch, trồng mới luôn` |
| Trồng thiếu ô | `2/2 Sau khi trồng khoai: ⚠️ CẢNH BÁO – chỉ thấy mầm cây ở 6/10 ô` |
| Chờ cây chín rồi thu | `1/2 Sau khi thu hoạch: 10 ô (đã chờ cây chín 4 phút)` |
| Chờ đủ 12 phút cây vẫn chưa chín | `🌱 Chưa có ô chín (cây đang lớn) (đã chờ 12 phút) – không thu hoạch, không gieo` và `🥔 Khoai chín lúc: …` hoặc `🥔 Thu hoạch tiếp theo: chưa xác định (lần này không gieo)` |
| Có lỗi | `❌ LỖI: Không tìm thấy hạt khoai tây` (lỗi hiếm gặp từ Windows/ADB có thể là tiếng Anh) |
| Có mạng lại sau khi mất mạng | `📵 Mất mạng từ … đến … – đã thử lại N lần (không tính là lỗi)` |
| Chạy đúng giờ bảo trì game (tin chữ, không có ảnh) | `🛠️ Đang giờ bảo trì game (thứ 5 14:00–15:00) – không chạy lượt này.` |
| Tin gửi bù | `📨 Tin gửi trễ (lúc đó mất mạng):` + nội dung tin cũ |

Ý nghĩa các dòng tổng kết:
- **Xong việc lúc**: thời điểm script chạy xong.
- **Thu hoạch tiếp theo**: lúc bấm *Xác nhận* gieo + `$GrowHours` (mặc định 8 tiếng).
- **Đã tự lập lịch lần tới**: giờ script vừa hẹn cho lần chạy sau của tài khoản này, kèm lý do (mục 4, cách 1). Có thể thay bằng `⚠️ Không biết giờ khoai chín…`, `⛔ Lỗi 3 lần liên tiếp…` hoặc `⏸️ Tự lập lịch đang tắt…`.
- **Lần chạy tự động tới**: chỉ hiện khi tắt tự lập lịch (`$AutoSchedule = $false`), lấy từ lịch cố định `DDTank Farm`.

**Lưu ý mã hoá:** tin nhắn viết tiếng Việt có dấu và emoji, nên `ddtank_farm.ps1` phải được lưu dạng **UTF-8 có BOM** (PowerShell 5.1 cần BOM mới đọc đúng). Nếu tự sửa file bằng Notepad, chọn *Save As → Encoding: UTF-8 with BOM*. Lưu sai thì tin nhắn bị lỗi font.

### Bước 1: Tạo bot, lấy bot token

1. Mở Telegram, tìm **@BotFather** (có dấu tick xanh) và bấm **Start**.
2. Gõ `/newbot`.
3. BotFather hỏi **tên hiển thị** của bot, bạn đặt tuỳ ý, ví dụ `DDTank Farm`.
4. BotFather hỏi **username** của bot. Username phải kết thúc bằng `bot`, ví dụ `ddtank_farm_cua_toi_bot`.
5. BotFather trả về **token**, dạng `7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxx`. Copy chuỗi này.

### Bước 2: Lấy chat_id

1. Bấm vào link bot mà BotFather gửi (`t.me/<username>`), bấm **Start**, rồi nhắn cho bot một tin bất kỳ, ví dụ `hi`.
2. Mở trình duyệt, vào địa chỉ dưới đây (thay `<TOKEN>` bằng token ở bước 1):
   ```
   https://api.telegram.org/bot<TOKEN>/getUpdates
   ```
3. Tìm đoạn `"chat":{"id":123456789,...` và lấy **con số** sau `"id":`. Đó là **chat_id**.
   - Nếu trang chỉ hiện `{"ok":true,"result":[]}`: nhắn thêm 1 tin cho bot rồi tải lại trang.
   - **Muốn gửi vào nhóm**: thêm bot vào nhóm, nhắn 1 tin trong nhóm, rồi xem lại `getUpdates`. Id của nhóm là **số âm**, ví dụ `-1001234567890`. Lấy cả dấu `-`.

### Bước 3: Điền vào `telegram.json`

Mở file **`telegram.json`** trong thư mục script bằng Notepad. Nếu chưa có file, copy `telegram.example.json` thành `telegram.json`. Thay 2 giá trị, giữ nguyên dấu ngoặc kép:

```json
{
  "bot_token": "7123456789:AAHxxxxxxxxxxxxxxxxxxxxxxx",
  "chat_id": "123456789"
}
```

Lưu file lại.

### Bước 4: Gửi thử

```bat
run.bat -Account tomcat12345 -TestTelegram
```

Bot sẽ gửi album 2 ảnh lấy tạm từ `logs\`, chữ hiện ngay dưới album, các dòng nội dung có đánh dấu `[GỬI THỬ]`. Ở bản gửi thử, giờ "thu hoạch tiếp theo" tính theo thời điểm của file ảnh cũ nên có thể lệch. Khi chạy thật thì giờ này đúng.

Nếu không nhận được tin: mở file log mới nhất trong `logs\` và tìm dòng `Gui Telegram loi ...`.

| Lỗi trong log | Cách sửa |
|---|---|
| `Chua co telegram.json` | Tạo file theo bước 3 |
| `telegram.json chua dien bot_token/chat_id` | Còn chữ `DIEN_...`, điền giá trị thật |
| `(401) ... Unauthorized` | Sai token, copy lại từ BotFather |
| `(400) ... chat not found` | Sai chat_id, hoặc chưa bấm Start / chưa nhắn tin cho bot |
| `(403) ... bot was blocked by the user` | Bạn đã chặn bot, mở chat với bot và bấm Start lại |
| Lỗi kết nối / timeout | Mất mạng, hoặc mạng chặn `api.telegram.org` |

### Ghi chú

- Không có `telegram.json`, hoặc chưa điền token: script vẫn chạy bình thường, chỉ bỏ qua bước gửi. Nội dung lẽ ra được gửi vẫn ghi vào log.
- Gửi Telegram lỗi **không** làm script báo lỗi. Lỗi chỉ được ghi vào log.
- `telegram.json` chứa token **dạng chữ thường**. Ai có token đều điều khiển được bot. Đừng chia sẻ file hay thư mục này. Lộ token thì vào @BotFather → `/revoke` để đổi token mới, rồi sửa lại `telegram.json`.
- Trồng loại cây khác thời gian chín khác: sửa `$GrowHours` đầu file `ddtank_farm.ps1`.

### Điều khiển bằng lệnh Telegram (bot)

`telegram_bot.ps1` chạy nền trên máy tính, liên tục hỏi Telegram xem có lệnh mới không. Nhận được lệnh thì nó chạy script tương ứng rồi trả lời. Bot dùng chung `bot_token` + `chat_id` trong `telegram.json`, chỉ chủ động kết nối ra ngoài nên không cần mở cổng mạng (cách hoạt động: xem *Bot giao tiếp với Telegram thế nào* bên dưới).

**Cài bot** (làm 1 lần, sau khi đã cấu hình `telegram.json`):

```bat
cai_bot.bat
```

Bot tự bật mỗi lần đăng nhập Windows, bị lỗi thì tự khởi động lại. Khi bật, bot nhắn *"🤖 Bot DDTank đã sẵn sàng"*. Gõ `/` trong chat với bot sẽ hiện menu lệnh.

**Bàn phím nút bấm** (đang **TẮT** vì chiếm chỗ hiển thị chat): bot có sẵn bàn phím nút bấm dưới ô chat. Đang tắt (`$ShowKeyboard = $false` đầu `telegram_bot.ps1`), mỗi lần khởi động bot gửi lệnh gỡ bàn phím cũ nếu còn hiện. Muốn bật lại: đặt `$ShowKeyboard = $true` rồi chạy `cai_bot.bat`; bàn phím hiện khi bot khởi động hoặc khi gõ `/help`:

```
[ /trangthai ]  [ /lich ]          [ /anh ]
[ /maytinh ]    [ /thongke ]       [ /log ]
[ /chay akaka ] [ /xemruong akaka ]          ← 1 hàng cho mỗi tài khoản (tối đa 3), lấy từ state\
[ /tamdung 2 ]  [ /tiep ]          [ /help ]
```

`/dung` cố ý **không** có nút (tránh bấm nhầm), gõ tay khi cần.

| Lệnh cài | Tác dụng |
|---|---|
| `cai_bot.bat` | Cài + bật bot ngay. Chạy lại = khởi động lại bot (vd sau khi sửa `telegram_bot.ps1`) |
| `cai_bot.bat -Xem` | Bot có đang chạy không, 5 dòng log cuối |
| `cai_bot.bat -Xoa` | Tắt bot + gỡ cài đặt |

**Lệnh gõ trong Telegram:**

| Lệnh | Tác dụng |
|---|---|
| `/chay <tài khoản>` | Chạy ngay thu hoạch + trồng, vd `/chay akaka`. Xong có ảnh gửi về như bình thường. Chạy được cả khi đang `/tamdung` |
| `/xemruong <tài khoản>` | Vào game chụp ruộng gửi về (~3–4 phút): có ô chín chưa (🖐️ bàn tay), cây đang lớn mấy ô, ruộng trống, **bao nhiêu ô cần tưới 💧 / có sâu 🐛**. Có giọt nước / con sâu thì **bấm 1 cái để tưới cây + bắt sâu cả ruộng** (game xử lý cả ruộng chỉ với 1 lần bấm) và gửi thêm ảnh sau khi chăm sóc. **Không thu hoạch, không gieo, không đổi lịch** |
| `/trangthai` | Script có đang chạy không (tài khoản, từ lúc nào), thiết bị bật/tắt, lần chạy tự động tới, 6 dòng log cuối |
| `/maytinh` | Sức khoẻ máy: RAM trống + 3 chương trình tốn RAM nhất, CPU, ổ đĩa, thời gian máy đã chạy, số lần tắt bất thường / màn hình xanh 7 ngày qua (kèm mã lỗi), Wi-Fi + số lần rớt 24 giờ, VPN, MuMu, bot, tự đăng nhập bật/tắt |
| `/thongke [số ngày]` | Thống kê theo tài khoản (mặc định 7 ngày, tối đa 60): số lượt, lượt thu hoạch + tổng ô, lượt gieo, chờ cây chín, cây chưa chín, lỗi / mất mạng / bảo trì / tạm dừng, lỗi gần nhất. Lấy từ `state\lich_su.jsonl` |
| `/tamdung <số giờ>` | Tạm dừng **mọi lịch tự động** (0.1 – 168 giờ), vd `/tamdung 2`, `/tamdung 0.5`. Lượt tới hạn trong lúc đó dời tới lúc hết tạm dừng. Lượt đang chạy vẫn chạy tiếp (dừng ngay: `/dung`). Hết giờ bot tự nhắn *"▶️ Hết tạm dừng"* |
| `/tiep` | Bật lại lịch tự động ngay. Lượt nào đã quá giờ chín (bị dời trong lúc tạm dừng) được kéo về chạy sau 2 phút |
| `/anh` | Chụp màn hình thiết bị `auto` gửi về (chỉ khi thiết bị đang bật) |
| `/log` | 40 dòng cuối log lần chạy gần nhất |
| `/lich` | Xem tất cả lịch: lịch cố định + lịch tự lập của từng tài khoản, tài khoản nào đang tắt tự lập lịch |
| `/huylich <tài khoản>` | Dừng tự lập lịch của tài khoản đó (xoá lịch đã hẹn). Bật lại bằng `/chay <tài khoản>` |
| `/datlich <giờ> <chu kỳ> <tài khoản>` | Cài lịch cố định, giống `lap_lich.bat` (mục 4, cách 2). vd `/datlich 23:00 8:05 akaka` |
| `/xoalich` | Xoá lịch cố định |
| `/dung` | Dừng lượt đang chạy, tắt app DDTank và thiết bị `auto`. Lượt bị dừng không gửi ảnh |
| `/help` | Danh sách lệnh (kèm bàn phím nút bấm nếu `$ShowKeyboard = $true`) |

**An toàn & giới hạn:**
- Bot **chỉ nhận lệnh từ đúng `chat_id`** trong `telegram.json`. Người khác nhắn bot đều bị bỏ qua, có ghi vào log.
- Bot **chỉ có các lệnh trong bảng trên**, không có lệnh chạy câu lệnh tuỳ ý trên máy. Tên tài khoản, giờ, chu kỳ đều được kiểm tra hợp lệ trước khi dùng.
- **Không chạy chồng:** đang có lượt chạy (theo lịch, `/chay` hoặc `/xemruong`) thì `/chay` / `/xemruong` báo *"đang chạy rồi"*. Script nông trại cũng tự thoát nếu phát hiện có lượt khác đang chạy.
- **Lệnh cũ hơn 10 phút bị bỏ qua** (vd gửi lúc máy tắt), bot báo *"Bỏ qua lệnh cũ"* để bạn gửi lại nếu vẫn cần.
- Máy tính phải **bật và đã đăng nhập Windows**. Máy tắt hoặc sleep thì bot không nhận được lệnh. Khởi động lại máy: xem mục *Khi khởi động lại máy tính* ngay dưới.
- Log bot ở `logs\bot.log`, ghi mỗi lệnh nhận được và nội dung trả lời. Lớn hơn 1 MB thì bot tự rút gọn còn 3000 dòng cuối (lúc khởi động và mỗi 24 giờ).

Thử 1 lệnh không cần mở Telegram (câu trả lời vẫn gửi về Telegram):

```bat
powershell -ExecutionPolicy Bypass -File telegram_bot.ps1 -Thu "/trangthai"
```

### Bot giao tiếp với Telegram thế nào (long polling, không dùng webhook)

```
Máy tính (telegram_bot.ps1)                    Máy chủ Telegram
        │ getUpdates(offset, timeout=50) ───────────►│
        │                                            │ có tin mới? → trả về ngay
        │                                            │ chưa có  → giữ kết nối tối đa 50 giây
        │◄─────────────────────── danh sách tin ─────│
        │ xử lý lệnh (/chay, /trangthai…)            │
        │ sendMessage / sendPhoto ──────────────────►│ → hiện trên điện thoại
        │ getUpdates(offset mới) ───────────────────►│ … lặp lại mãi
```

1. Bot gửi yêu cầu `getUpdates` tới `api.telegram.org` và cho phép Telegram **giữ yêu cầu chờ tới 50 giây**.
2. Bạn gửi lệnh trong lúc bot đang chờ thì Telegram **trả về ngay**, nên bot phản hồi gần như tức thì (~1 giây).
3. Không có lệnh: sau 50 giây Telegram trả về danh sách rỗng, bot hỏi lại ngay.
4. **`offset`** đánh dấu tin đã xử lý để Telegram không gửi lại tin cũ. Lưu ở `logs\bot_offset.txt`, nên bot khởi động lại cũng không chạy lại lệnh cũ.
5. Bot trả lời bằng `sendMessage` / `sendPhoto`. Script nông trại **gửi ảnh trực tiếp** (`sendPhoto` / `sendMediaGroup`), không đi qua bot. Hai bên chỉ dùng chung token trong `telegram.json`.

**Vì sao không dùng webhook:** webhook bắt Telegram phải **gọi vào máy bạn** qua một địa chỉ HTTPS công khai. Muốn vậy cần IP tĩnh hoặc tên miền, chứng chỉ SSL và mở cổng trên router, hoặc dùng dịch vụ đường hầm như ngrok / Cloudflare Tunnel. Máy để ở nhà nằm sau router (NAT) nên mặc định không nhận được kết nối từ ngoài vào. Polling **chỉ kết nối từ máy ra ngoài** (giống trình duyệt mở web): không cần mở cổng, không lộ máy ra Internet, đơn giản và an toàn hơn.

**Đặc điểm:**
- **Rất nhẹ:** khi không có lệnh chỉ ~1 yêu cầu mỗi 50 giây, vài KB dữ liệu. Bot dùng ~20 MB RAM.
- **Mất mạng:** yêu cầu đang chờ bị lỗi hoặc hết thời gian chờ (90 giây). Bot thử lại mỗi 10 giây, có mạng lại thì chạy tiếp. Log chỉ ghi 1 dòng lúc mất mạng (rồi 30 phút/lần), mất từ 2 phút trở lên thì có mạng lại bot nhắn *"📶 Bot có mạng lại…"*. Mạng rớt ngắn (dưới ~1 phút) thường không gây lỗi gì.
- **Tin gửi lúc máy tắt / mất mạng:** Telegram giữ tin trên máy chủ tối đa 24 giờ, bot hỏi lại là nhận được. Lệnh cũ hơn 10 phút bị bỏ qua (báo *"Bỏ qua lệnh cũ"*) để tránh chạy bất ngờ.
- **Chỉ 1 bot được hỏi 1 lúc:** 2 tiến trình cùng gọi `getUpdates` thì Telegram báo xung đột, nên bot có khoá (mutex) để chỉ chạy 1 bản. **Không bật webhook** cho bot này: đã có webhook thì `getUpdates` ngừng hoạt động.

### Khi khởi động lại máy tính

**Không cần tự chạy lại `telegram_bot.ps1`.** Task `DDTank Bot` (do `cai_bot.bat` cài) tự bật bot mỗi khi bạn **đăng nhập Windows**. Bot bật xong sẽ nhắn *"🤖 Bot DDTank đã sẵn sàng"*. Lịch thu hoạch (lịch tự lập và lịch cố định) cũng là task Windows nên vẫn còn sau khi khởi động lại.

| Tình huống | Chuyện gì xảy ra |
|---|---|
| Khởi động lại rồi đăng nhập Windows | Bot tự bật, lịch vẫn giữ nguyên. Không cần làm gì |
| Máy dừng ở **màn hình đăng nhập** (vd Windows Update tự khởi động lại lúc vắng nhà) | Bot **chưa chạy**, lịch thu hoạch cũng **chưa chạy** (MuMu cần giao diện Windows). Đăng nhập vào là bot bật, lượt bị lỡ sẽ chạy bù ngay |
| Máy đang tắt / sleep đúng giờ hẹn | Sleep: Windows tự đánh thức máy để chạy. Tắt hẳn: lượt bị lỡ chạy bù khi bật máy và đăng nhập |
| Mạng chưa sẵn sàng lúc vừa đăng nhập / mất mạng giữa chừng | Bot tự thử lại mỗi 10 giây. Mất mạng từ 2 phút trở lên thì khi có lại, bot nhắn *"📶 Bot có mạng lại. Mất kết nối từ … đến …"*. Lịch thu hoạch chờ có mạng (mục 4, cách 1) |
| Bot bị lỗi và dừng | Windows tự bật lại sau 1 phút |
| Lệnh gửi trong lúc máy tắt / chưa đăng nhập | Bot bật lên sẽ bỏ qua lệnh cũ hơn 10 phút và báo *"Bỏ qua lệnh cũ"*. Gửi lại nếu vẫn cần |

**Đã kiểm chứng thực tế (18/11/2026, chưa bật tự đăng nhập, đăng nhập tay):**

| Giờ | Sự kiện |
|---|---|
| 09:50:54 | Máy khởi động xong |
| 09:51:03 | Đăng nhập Desktop |
| 09:51:09 | Wi-Fi tự kết nối |
| 09:51:10 | Task `DDTank Bot` tự bật bot (~7 giây sau khi đăng nhập) |
| 09:51:36 | Bot nhắn *"🤖 Bot DDTank đã sẵn sàng"* |

Lịch tự lập `DDTank Farm - akaka` vẫn giữ nguyên giờ hẹn. Cài đặt nguồn (không sleep, không tắt Wi-Fi USB) vẫn còn sau khi khởi động lại. Ping 30 giây sau khi khởi động: không mất gói nào.

**Muốn máy tự chạy được cả khi khởi động lại lúc vắng nhà:** cài Windows tự đăng nhập và không sleep, xem mục *Cài Windows 11 cho máy chạy 24/7* ngay dưới. Script không tự đổi các cài đặt này, bạn tự làm.

**Kiểm tra sau khi khởi động lại:** gửi `/trangthai` (bot trả lời là đang chạy, kèm lịch lần tới), hoặc chạy `cai_bot.bat -Xem` trên máy. Nếu bot không chạy: chạy lại `cai_bot.bat`.

### Cài Windows 11 cho máy chạy 24/7 (máy tính để bàn)

Mục tiêu: máy **luôn ở màn hình Desktop**, không sleep, mất điện hay khởi động lại xong cũng tự vào Windows. Như vậy bot luôn nhận lệnh và lịch thu hoạch luôn chạy đúng giờ. Tất cả làm bằng lệnh, không cần mò giao diện Cài đặt.

**Mở PowerShell quyền Admin:** bấm chuột phải nút Start → **Terminal (Admin)** (hoặc *Windows PowerShell (Admin)*) → bấm *Yes*. Dán từng khối lệnh dưới đây vào rồi Enter.

> ⚠️ **Bảo mật:** tự đăng nhập nghĩa là **ai bật máy cũng vào thẳng Windows** của bạn. Chỉ nên làm với máy để ở nhà. Công cụ Autologon lưu mật khẩu dạng mã hoá (LSA secret), tốt hơn cách ghi thẳng mật khẩu vào Registry (`DefaultPassword`) hay gặp trên mạng.

#### A. Tự đăng nhập Windows (không cần gõ mật khẩu / PIN)

**Bước 1: Tắt "chỉ cho đăng nhập bằng Windows Hello"** (chế độ này chặn đăng nhập bằng mật khẩu, trong đó có tự đăng nhập):

```powershell
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PasswordLess\Device" /v DevicePasswordLessBuildVersion /t REG_DWORD /d 0 /f
```

**Bước 2: Cài công cụ Autologon** (của Microsoft Sysinternals, qua winget):

```powershell
winget install --id Microsoft.Sysinternals.Autologon -e
```

Cài xong, **đóng cửa sổ PowerShell và mở lại một cửa sổ Admin mới** (để nhận lệnh `autologon`).

**Bước 3: Bật tự đăng nhập.** Lệnh sẽ hỏi mật khẩu Windows của bạn (mật khẩu thật, **không phải mã PIN**; gõ không hiện chữ là bình thường). Mật khẩu không bị lưu vào lịch sử lệnh của PowerShell:

```powershell
$p = Read-Host "Mat khau Windows" -AsSecureString
autologon $env:USERNAME $env:COMPUTERNAME ([Net.NetworkCredential]::new('', $p).Password) /accepteula
Remove-Variable p
```

Nếu hiện hộp thoại báo thành công thì bấm OK. Tài khoản Microsoft (đăng nhập bằng email) thì nhập mật khẩu tài khoản Microsoft.

**Bước 4: Không bắt đăng nhập lại khi máy tỉnh, bật lại màn hình, hay chạy trình bảo vệ màn hình:**

```powershell
powercfg /setacvalueindex SCHEME_CURRENT SUB_NONE CONSOLELOCK 0
powercfg /setactive SCHEME_CURRENT
reg add "HKCU\Control Panel\Desktop" /v ScreenSaverIsSecure /t REG_SZ /d 0 /f
reg add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" /v EnableGoodbye /t REG_DWORD /d 0 /f
```

(Dòng 1–2: không hỏi mật khẩu khi máy tỉnh. Dòng 3: trình bảo vệ màn hình không khoá máy. Dòng 4: tắt *Dynamic lock* – tự khoá khi điện thoại Bluetooth đi xa.)

**Kiểm tra:**

```powershell
(Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon').AutoAdminLogon
```

Ra `1` là đã bật. Sau đó khởi động lại máy, không chạm vào bàn phím: máy phải tự vào thẳng Desktop, khoảng 1 phút sau có tin *"🤖 Bot DDTank đã sẵn sàng"*.

**Muốn bỏ tự đăng nhập:**

```powershell
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon" /v AutoAdminLogon /t REG_SZ /d 0 /f
```

(Hoặc chạy `autologon` không kèm gì, bấm *Disable*. Giữ phím `Shift` lúc máy khởi động cũng bỏ qua tự đăng nhập cho lần đó.)

#### B. Tắt sleep / ngủ đông

```powershell
powercfg /change standby-timeout-ac 0
powercfg /change hibernate-timeout-ac 0
```

(Chỉ áp dụng khi cắm điện – máy bàn luôn cắm điện.) Màn hình vẫn được phép tự tắt, không ảnh hưởng bot hay MuMu. Muốn đổi thời gian tắt màn hình, vd 10 phút: `powercfg /change monitor-timeout-ac 10`.

**Kiểm tra:**

```powershell
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE | findstr "AC"
```

Dòng *Current AC Power Setting Index* phải là `0x00000000`.

> Nếu vẫn muốn để máy sleep cho tiết kiệm điện: lịch thu hoạch vẫn tự đánh thức máy dậy để chạy (cần *wake timers* đang bật – mặc định là bật). Nhưng lúc máy ngủ thì **bot không nhận được lệnh**.

#### C. Giữ Wi-Fi không bị rớt (card Wi-Fi USB)

Máy đang dùng card Wi-Fi USB (802.11n). Nhật ký Windows 11–18/11/2026 ghi **11 lần rớt do driver**: 8 lần ngay lúc máy thức dậy từ sleep (đã hết khi tắt sleep ở mục B), 3 lần lúc máy đang chạy bình thường (nghi do Windows tắt card USB để tiết kiệm điện). Chặn bằng 3 lệnh, chạy trong **Terminal (Admin)** – lệnh `reg add` báo *Access is denied* nếu không có quyền Admin:

```powershell
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setactive SCHEME_CURRENT
reg add "HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\0011" /v PnPCapabilities /t REG_DWORD /d 24 /f
```

(Dòng 1–2: tắt *USB selective suspend* – Windows tạm ngắt cổng USB không dùng. Dòng 3: bỏ tick *"Allow the computer to turn off this device to save power"* của card Wi-Fi; `0011` là số thứ tự của card trên máy này, máy khác có thể khác.)

Lệnh `reg add` **chỉ có hiệu lực sau khi khởi động lại máy**. Kiểm tra (sau khi khởi động lại):

```powershell
(Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable | ? InstanceName -like '*VID_148F*PID_7601*').Enable
```

Ra `False` là Windows không còn được tắt card Wi-Fi (máy này đã đạt từ 18/11/2026). Nếu vẫn hay rớt: **cắm dây LAN** vào cổng Ethernet có sẵn trên mainboard (Intel I219-V) là cách triệt để nhất.

#### D. Tự bật máy lại sau khi mất điện (cài trong BIOS)

Máy bàn mất điện xong có điện lại sẽ **nằm im**, không tự bật. Muốn tự bật:
1. Khởi động lại máy, lúc vừa bật bấm liên tục `Del` (hoặc `F2`, tuỳ mainboard) để vào BIOS.
2. Tìm mục có tên kiểu **Restore on AC Power Loss** / **AC Power Recovery** / **After Power Failure** / **AC Back** (thường nằm trong *Power*, *Advanced* hoặc *Chipset*).
3. Chọn **Power On** (luôn bật lại) hoặc **Last State** (bật lại nếu lúc mất điện máy đang bật).
4. Lưu và thoát (thường là `F10`).

Kết hợp với tự đăng nhập ở mục A: có điện lại → máy tự bật → tự vào Windows → bot và lịch tự chạy.

> Nếu ổ đĩa có **BitLocker hỏi PIN lúc khởi động**, máy sẽ dừng ở màn hình nhập PIN và mọi thứ ở trên không có tác dụng. BitLocker chỉ dùng TPM (không hỏi gì lúc khởi động) thì không ảnh hưởng.

#### E. Windows Update

Không cần tắt Windows Update. Đã bật tự đăng nhập (mục A) thì Windows tự khởi động lại sau cập nhật xong sẽ tự vào Desktop, bot tự bật, lượt thu hoạch bị lỡ trong lúc cập nhật sẽ chạy bù.

**Chưa bật tự đăng nhập mà sắp đi vắng nhiều ngày:** *Cài đặt → Windows Update →* **Tạm dừng 1 tuần**, để Windows không tự khởi động lại rồi dừng ở màn hình đăng nhập.

#### Tóm tắt kiểm tra

| Việc | Đúng khi |
|---|---|
| Tự đăng nhập | Khởi động lại máy, tự vào Desktop không cần gõ gì |
| Không sleep | Để máy 30 phút không dùng, gửi `/trangthai` vẫn được trả lời ngay |
| Wi-Fi không bị tắt | Lệnh kiểm tra ở mục C ra `False`. Bot không nhắn *"📶 Bot có mạng lại"* trong nhiều ngày |
| Tự bật sau mất điện | Rút điện / tắt ổ cắm khi máy đang bật, cắm lại, máy tự lên |
| Bot | Sau mỗi lần khởi động có tin *"🤖 Bot DDTank đã sẵn sàng"* |

---

## 6. Log & xử lý lỗi

Mỗi lần chạy tạo `logs\run_<ngày>_<giờ>.log`, kèm ảnh:
- `..._sau_thu_hoach.png`: ruộng sau khi thu hoạch (ảnh 1 gửi Telegram).
- `..._ket_qua.png`: ruộng sau khi gieo (ảnh 2 gửi Telegram).
- `..._ruong_trong.png`: ruộng trống, không có gì để thu hoạch (ảnh 1 gửi Telegram).
- `..._dang_trong.png`: không có ô chín (cây đang lớn), bỏ qua gieo.
- `..._loi*.png`: màn hình lúc gặp lỗi.
- `..._stepNN_*.png`: ảnh từng bước, chỉ có khi chạy với `-StepShots`.
- `..._xem_ruong.png`: ảnh chụp bằng `/xemruong` (`-ViewOnly`).

**Tự dọn log:** mỗi lần chạy, script xoá `run_*.log` và ảnh `yyyyMMdd_HHmmss_*.png` **cũ hơn 14 ngày** (`$KeepLogDays`, đặt `0` = không xoá). Không xoá `bot.log`, `bot_offset.txt`, tin chờ gửi bù và file khác. Ước tính ~10–15 MB/ngày với 3 lượt/ngày, nên `logs\` giữ ở khoảng 200 MB.

**Lịch sử chạy:** mỗi lượt (trừ `-LoginOnly`, `-SkipLaunch`, tài khoản `zz_*`) ghi 1 dòng vào `state\lich_su.jsonl` (giờ bắt đầu/kết thúc, tài khoản, kết quả, số ô thu hoạch, gieo hay không, số mầm, phút chờ chín, lỗi). File này **không bị dọn**, dùng cho `/thongke`. Lịch sử trước 18/11/2026 được tạo lại từ log cũ; 4 lượt "Không vào được sảnh chính" đêm 17–18/11 được ghi là *mất mạng* (đã xác định do Wi-Fi rớt sau khi máy thức dậy).

| Thông báo lỗi (log + Telegram) | Nguyên nhân thường gặp |
|---|---|
| `Mất mạng: không kết nối được Internet sau 5 phút` (chỉ trong log) | Wi-Fi / mạng rớt. Script tự thử lại mỗi 10 phút, không tính là lỗi. Nên cắm dây LAN nếu hay gặp |
| `Không tìm thấy thiết bị MuMu tên 'auto'` | Thiết bị bị đổi tên / xoá |
| `Thiết bị không khởi động được trong 3 phút` | MuMu lỗi, máy quá chậm |
| `Game đang đợi đăng nhập nhưng chưa truyền -Account` | Thiếu tham số tài khoản (lịch cũ chưa có `-Account`) |
| `Không thấy tài khoản '...' trong danh sách đã lưu` | Sai tên, hoặc tài khoản chưa từng đăng nhập trên máy này |
| `... chưa được app lưu mật khẩu` | Đăng nhập tay 1 lần để app lưu mật khẩu |
| `Không vào được sảnh chính sau 4 phút` | Popup lạ chưa có nút ✕ đỏ, mạng chậm, game bảo trì, hoặc sai kích thước màn hình |
| `Không tìm thấy ruộng (biển gỗ)` | Nhân vật đứng sai chỗ / bị che, xem ảnh `loi_tim_ruong` |
| `Không mở được bảng hạt giống` | Bảng hạt hiện quá chậm, xem ảnh `loi_bang_hat` |
| `Không tìm thấy hạt khoai tây` | Hết hạt khoai |
| `CANH BAO: chi thay mam cay o x/10 o` (chỉ trong log) | Có ô chưa được gieo, xem ảnh `ket_qua` |

Khi gặp lỗi lạ: chạy lại với `-StepShots -KeepDevice` và xem ảnh từng bước trong `logs\`.

### Tốc độ nhận diện & bản backup

Từ 17/11/2026, script được tối ưu tốc độ chuyển bước:

| Thay đổi | Trước | Sau |
|---|---|---|
| Tìm 1 ảnh mẫu trên màn hình | 0,5 – 7 giây | ~0,1 – 0,4 giây (kết quả giống hệt, đã so trên ảnh chụp thật) |
| Chụp màn hình (RAW thay vì PNG) | ~1,3 giây | ~0,7 giây |
| Khoảng nghỉ giữa các lần kiểm tra (`WaitFor`) | 0,8 giây | 0,3 giây |
| Xác nhận đã hết ô để thu hoạch | ~22 giây (4 lần, nghỉ 2 giây) | ~6 giây (3 lần, nghỉ 1 giây) |
| Một số lần chờ cố định (vào game, vào nông trại, đóng popup) | 1,5 – 5 giây | 1 – 2 giây |

Ảnh lưu trong `logs\` và gửi Telegram vẫn là PNG như cũ.

Bản trước khi tối ưu được giữ ở `backup\20261117_1655_truoc_toi_uu\` (script, `Vision.cs`, README, `templates\`). Muốn quay lại bản cũ: chép `ddtank_farm.ps1` và `Vision.cs` trong thư mục đó đè lên 2 file cùng tên ở thư mục chính.

---

## 7. Kích thước màn hình (quan trọng)

Thiết bị `auto` phải để **1600 x 900, DPI 240**. Trong MuMu: *Cài đặt → Hiển thị → Tuỳ chỉnh*.

Script nhận diện bằng **ảnh mẫu** (`templates\`), so khớp từng pixel và **không tự co giãn**. Ngoài ra còn có nhiều **toạ độ / độ lệch** đo ở kích thước này. Nếu đổi độ phân giải hoặc DPI:
- Không nhận ra nút, bàn tay, biển gỗ, hạt giống, dẫn tới lỗi *"Khong vao duoc sanh chinh"*, thu hoạch 0 ô, *"Khong tim thay ruong"*.
- Toạ độ cố định bấm lệch: nhân vật đi sai chỗ, kéo hạt trượt khỏi ô đất.
- Riêng phần đăng nhập 7Road (đọc giao diện Android bằng uiautomator) vẫn chạy đúng.

Nếu buộc phải đổi kích thước: chụp lại toàn bộ ảnh mẫu và đo lại các toạ độ. Chi tiết ở phần chú thích *KICH THUOC MAN HINH* đầu file `ddtank_farm.ps1`.

---

## 8. Lưu ý khác

- **Nguy cơ bị phát hiện:** game có thể nhận ra giả lập, ADB đang bật, và kiểu thao tác lặp lại đều đặn mỗi 8 tiếng. Dùng công cụ tự động thường **vi phạm điều khoản** của game, có thể bị cảnh cáo hoặc khoá tài khoản. Script không sửa dữ liệu game hay gói tin mạng, nhưng rủi ro vẫn không bằng 0. Nên thử trên account phụ trước.
- **Thao tác giống người** (thêm 18/11, bật mặc định, áp dụng cho cả nông trại và câu cá):
  - **Bấm bằng ghi thẳng sự kiện chạm.** Sự kiện được ghi vào thiết bị cảm ứng của MuMu (*Xiaomi Input*, bot tự dò `/dev/input/eventN`) thay vì dùng `input tap`.
    - Game thấy cú chạm đi đúng đường của **click chuột thật** trong MuMu. Còn `input tap` tạo cú chạm không gắn với thiết bị nào, phần mềm có thể kiểm tra được.
    - Bấm cũng đều hơn: 25–30 ms so với 33–65 ms của `input tap`.
    - Ghi sự kiện lỗi thì tự quay về `input tap`.
  - **Ngẫu nhiên hoá:**
    - Toạ độ bấm lệch ±5 px (ô tick điều khoản ±2 px).
    - Thời gian giữ ngón 50–120 ms.
    - Thời gian chờ giữa các bước dao động 90–140%.
    - Vuốt danh sách lệch ±4 px, nhanh chậm 85–125%.
    - Kéo hạt: lệch ±3 px mỗi điểm, giữ 0,5–0,8 giây, bước kéo 34–46 px.
    - Lượt chạy theo lịch bắt đầu lệch ngẫu nhiên 0–60 giây.
  - **Vuốt và kéo hạt vẫn dùng `input swipe` / `input motionevent`**: chưa chuyển sang ghi sự kiện vì chưa test được thao tác kéo.
  - Tắt: `$HumanLike = $false` / `$DirectTouch = $false` đầu `ddtank_farm.ps1`.
  - Rủi ro lớn nhất vẫn là **nhịp chơi** (chạy đều đặn, chạy lâu, tỉ lệ chuẩn quá cao) và **điều khoản của game**. Giả lập người chỉ giảm rủi ro, không loại bỏ được.
- Script **không bắt sâu / tưới nước**. Các biểu tượng sâu, giọt nước trên cây đang lớn được bỏ qua.
- Đang chạy theo lịch thì **đừng dùng thiết bị `auto`**, vì script sẽ tắt nó khi xong.
- Script **tự tick ô đồng ý điều khoản** mỗi lần cần đăng nhập.

---

## 9. Cấu trúc thư mục

```
ddtank-farm\
├─ ddtank_farm.ps1        script chính (cấu hình ở đầu file)
├─ Vision.cs              nhận diện ảnh (template matching)
├─ run.bat                chạy tay:  run.bat -Account <tên>
├─ cau_ca\                câu cá chạy riêng (mục 12): cau_ca.bat, GHI_CHU.md, hieu_chinh.csv, bu_vong_<tên máy>.txt,
│                         cong_cu\ (script), mau\ (ảnh mẫu), ket_qua\ (ảnh mỗi lần chạy), ghi_hinh\ (bản ghi làm mẫu)
├─ lap_lich.ps1 / .bat    cài / xem / xoá lịch
├─ telegram_bot.ps1       bot nhận lệnh Telegram (/chay, /trangthai, /dung…)
├─ ket_noi_mang.ps1       tự kết nối lại Wi-Fi khi mất mạng (dùng chung cho script nông trại + bot)
├─ cai_bot.ps1 / .bat     cài / xem / gỡ bot (tự chạy khi đăng nhập Windows)
├─ telegram.json          bot_token + chat_id của bạn (KHÔNG chia sẻ)
├─ telegram.example.json  file mẫu
├─ README.md              tài liệu này
├─ templates\             ảnh mẫu (chụp ở 1600x900)
├─ logs\                  log + ảnh mỗi lần chạy
├─ state\                 giờ khoai chín từng tài khoản (tự lập lịch), file .off = đã /huylich, .offline = đang mất mạng,
│                         lich_su.jsonl = lịch sử mọi lượt chạy (/thongke), _tamdung.txt = đang /tamdung tới giờ nào
│                         (logs\telegram_cho_gui\ = tin Telegram chờ gửi bù khi có mạng)
├─ backup\                bản sao các phiên bản cũ (xem mục 6)
└─ debug\                 ảnh/giao diện dùng khi phát triển (có thể xoá)
```

Cấu hình đầu `ddtank_farm.ps1`:

| Biến | Mặc định | Ý nghĩa |
|---|---|---|
| `$MuMuDir` | `D:\Program Files\Netease\MuMuPlayer\nx_main` | Thư mục MuMu |
| `$DeviceName` | `auto` | Tên thiết bị MuMu |
| `$Package` | `com.wan.ddten` | Gói app DDTank |
| `$PlotCount` | `10` | Số ô đất |
| `$FarmWalkPoint` | `600, 190` | Điểm bấm để nhân vật đi tới cạnh ruộng |
| `$BackRowWalkOffset` | `-133, -42` | Điểm "xanh" (lệch so với bàn tay ô đầu hàng sau) |
| `$WaitRipeMinutes` | `12` | Cây đang lớn thì chờ tối đa bao nhiêu phút cho cây chín (0 = không chờ, kết thúc luôn) |
| `$GrowHours` | `8` | Số giờ khoai chín (báo giờ thu hoạch tiếp theo + tự lập lịch) |
| `$AutoSchedule` | `$true` | Tự hẹn lần chạy sau theo giờ khoai chín (mục 4, cách 1) |
| `$AutoDelayMinutes` | `-5` | Hẹn lệch so với giờ khoai chín bao nhiêu phút (âm = trước giờ chín; nên nhỏ hơn `$WaitRipeMinutes`) |
| `$RetryMinutes` | `10` | Thử lại sau bao nhiêu phút nếu tới sớm / đang có lượt khác chạy |
| `$ErrorRetryMinutes` | `30` | Thử lại sau bao nhiêu phút nếu bị lỗi (sau khi đã thử lại trong lượt mà vẫn lỗi) |
| `$StepRetries` | `3` | Mỗi bước (vào game, mở nông trại, thu hoạch, gieo hạt) lỗi thì làm lại bước đó tối đa bao nhiêu lần |
| `$InRunRetries` | `1` | Một bước hết số lần làm lại thì khởi động lại thiết bị và chạy lại cả lượt bao nhiêu lần. `0` = không |
| `$RetryBudgetMin` | `35` | Lượt đã chạy quá bao nhiêu phút thì thôi làm lại (Task Scheduler tự diệt lượt sau 45 phút) |
| `$SafetyRunMin` | `50` | Đầu mỗi lượt (theo lịch hoặc `/chay`) hẹn sẵn 1 lượt dự phòng sau bao nhiêu phút; lượt bị treo / bị diệt giữa chừng vẫn còn lượt sau. Xong bình thường thì hẹn lại đúng giờ. `0` = tắt |
| `$NoRetryErrors` | chưa lưu mật khẩu, không thấy tài khoản, hết hạt… | Lỗi khớp mẫu này thì không thử lại trong lượt |
| `$MaxRetries` | `3` | Số lần thử lại liên tiếp tối đa trước khi dừng chuỗi (không tính lần mất mạng) |
| `$NetWaitMinutes` | `5` | Trước khi chạy, chờ có Internet tối đa bao nhiêu phút |
| `$OfflineRetryMinutes` | `10` | Mất mạng thì thử lại sau bao nhiêu phút |
| `$AutoReconnect` | `$true` | Mất mạng thì tự kết nối lại Wi-Fi đã lưu (mục 4) |
| `$NetRepairAfterSec` | `60` | Mất mạng bao nhiêu giây thì kết nối lại Wi-Fi; gấp đôi thì khởi động lại card (cần quyền admin) |
| `$NetTestHosts` | `api.telegram.org, www.google.com, 1.1.1.1` | Máy chủ dùng để kiểm tra có Internet (cổng 443, chỉ cần 1 máy trả lời) |
| `$MaintenanceWindows` | `Thursday 14:00–15:00` | Giờ bảo trì game hằng tuần (giờ Việt Nam). Thêm dòng `@{ Day = '...'; Start = '...'; End = '...' }` nếu có nhiều khung giờ |
| `$MaintBeforeMin` | `25` | Không bắt đầu chạy trong bao nhiêu phút trước giờ bảo trì (1 lượt ~6 phút + chờ chín tối đa 12 phút) |
| `$MaintAfterMin` | `15` | Chạy lại sau giờ bảo trì bao nhiêu phút (đặt `0` = chạy ngay lúc hết bảo trì) |
| `$MaintTimeZone` | `SE Asia Standard Time` | Múi giờ của giờ bảo trì (UTC+7, Việt Nam) |
| `$MinFreeRamMB` | `2500` | RAM trống tối thiểu trước khi mở MuMu; thấp hơn thì cảnh báo trên Telegram (vẫn chạy) |
| `$MinFreeDiskGB` | `5` | Dung lượng trống tối thiểu ổ C: và ổ chứa script; thấp hơn thì cảnh báo |
| `$KeepLogDays` | `14` | Xoá log + ảnh các lần chạy cũ hơn bao nhiêu ngày (0 = không xoá) |
| `$PlotOffsets` | 10 cặp toạ độ | Vị trí 10 ô đất so với biển gỗ |
| `$CareOnView` | `$true` | `/xemruong` thấy giọt nước / con sâu thì bấm 1 cái để tưới cây + bắt sâu cả ruộng. `$false` = chỉ xem |
| `$WaterMaxScore` / `$BugMaxScore` | `20` / `28` | Ngưỡng nhận diện ảnh mẫu `templates\water.png` (giọt nước) / `templates\bug.png` (con sâu) |
| `$DirectTouch` | `$true` | Bấm bằng ghi thẳng sự kiện chạm vào thiết bị cảm ứng của MuMu (mục 8). `$false` = dùng `input tap` |
| `$HumanLike` | `$true` | Ngẫu nhiên hoá toạ độ, thời gian giữ ngón, thời gian chờ, giờ bắt đầu (mục 8) |
| `$TapJitterPx` | `5` | Toạ độ bấm lệch tối đa ±bao nhiêu px |
| `$StartJitterSec` | `60` | Lượt tự động chờ ngẫu nhiên 0–bao nhiêu giây trước khi bắt đầu (chạy tay `-Manual` thì không chờ) |

---

## 10. Việc cần làm (TODO)

### Test trường hợp máy chủ game bảo trì → cập nhật script

- **Khi nào:** giờ bảo trì thật gần nhất, **thứ 5 19/11/2026, 14:00–15:00** (giờ Việt Nam). Lỡ thì làm vào thứ 5 tuần sau.
- **Ai làm:** bạn báo Claude lúc game đang bảo trì, Claude chạy test trên máy.
- **Mục tiêu:** script **tự nhận ra màn hình bảo trì** của game, kể cả bảo trì **đột xuất** hoặc **kéo dài quá 15:15**. Khi đó:
  - Không tính là lỗi, không dừng chuỗi tự lập lịch sau 3 lần.
  - Hẹn lại sau một khoảng (vd 30 phút) cho tới khi hết bảo trì.
  - Telegram báo rõ *"🛠️ Game đang bảo trì"* thay vì *"❌ LỖI: Không vào được sảnh chính sau 4 phút"*.
- **Các bước test dự kiến:**
  1. Trong giờ bảo trì, chạy `run.bat -Account akaka -LoginOnly -KeepDevice -StepShots`. Chế độ `-LoginOnly` không bị chặn bởi giờ bảo trì, nên script vẫn mở game để chụp màn hình.
  2. Lưu ảnh từng bước + giao diện Android (uiautomator) lúc game báo bảo trì: popup / thông báo / nút bấm hiện ra ở đâu, chữ gì.
  3. Cắt ảnh mẫu mới (vd `templates\maintenance.png`) hoặc đọc chữ qua uiautomator để nhận diện.
  4. Sửa `Enter-Game` trong `ddtank_farm.ps1`: thấy màn hình bảo trì thì dừng lượt, kết quả `maintenance` (đã có sẵn cách hẹn lại, không tính lỗi).
  5. Chạy lại test, cập nhật README (mục 4, 5, 6).
- **Trong lúc chờ:** giờ bảo trì cố định (thứ 5 14:00–15:00) đã được xử lý bằng cách dời lịch (mục 4, cách 1). Chỉ bảo trì đột xuất hoặc kéo dài mới còn bị tính là lỗi.

---

## 11. Danh sách nâng cấp (đã làm / chưa làm)

Danh sách đề xuất ngày 18/11/2026. Cập nhật trạng thái mỗi khi làm xong một mục.

**Chú thích:** ✅ đã làm và test · 🟡 đã làm, chưa test với game thật · 🔄 đang làm · ⬜ chưa làm · 🧑 bạn tự làm (không phải code)

### A. Chạy ổn định khi treo máy lâu ngày

| # | Nâng cấp | Trạng thái | Ghi chú |
|---|---|---|---|
| 1 | Nhận diện màn hình bảo trì của game (kể cả bảo trì đột xuất / kéo dài) | 🔄 | Giờ bảo trì cố định thứ 5 14:00–15:00 đã xử lý (dời lịch, không tính lỗi). Còn nhận diện màn hình bảo trì: chờ test lúc game bảo trì thật (mục 10) |
| 2 | Không dừng hẳn sau 3 lần lỗi: chuyển sang thử lại mỗi 2 giờ | ⬜ | |
| 29 | Làm lại từng bước khi lỗi (tối đa 3 lần/bước), hết lần thì khởi động lại thiết bị chạy lại cả lượt, thay vì tắt máy hẹn 30 phút | 🟡 | Logic kiểm tra đúng 12/12 tình huống bằng hàm giả; lượt thật 18/11 16:37 chạy thông suốt với code mới. Chưa gặp lỗi thật để thấy làm lại (mục 4, `$StepRetries`) |
| 30 | Đóng popup hiện muộn ở sảnh (vd *Báo danh mỗi ngày*); xử lý game tự đăng nhập bằng phiên cũ | ✅ | Gặp và sửa trong lượt 18/11 16:20–16:27. Test lại 18/11 16:51 sau giờ reset ngày (16:00) trên tài khoản server S574 chưa báo danh: đóng popup *Nạp lần đầu* (bấm ✕, không bấm *Nạp ngay*), rồi popup *Báo danh mỗi ngày* hiện 2 lần (lần đầu ✕ thì game đóng dấu *Đã báo danh*, *Còn 12 → 11 lần*; lần sau ✕ mới đóng), vào sảnh, vào nông trại bình thường |
| 3 | Tự đóng popup lạ (sự kiện mới) + gửi ảnh để bổ sung ảnh mẫu | ⬜ | Cần test với game thật |
| 4 | Kiểm tra RAM + ổ đĩa trước khi mở MuMu, cảnh báo trên Telegram | ✅ | `$MinFreeRamMB` 2500, `$MinFreeDiskGB` 5 (mục 3, 9) |
| 5 | Tự dọn log + ảnh cũ hơn 14 ngày; bot.log tự rút gọn | ✅ | `$KeepLogDays` (mục 6) |
| 6 | Bot báo khi máy vừa khởi động lại + nguyên nhân (màn hình xanh / mất điện / Update) | ⬜ | `/maytinh` đã hiện số lần tắt bất thường 7 ngày, nhưng chưa tự nhắn |
| 7 | Cảnh báo "lượt hẹn đã quá giờ mà chưa chạy" | ⬜ | Một phần: lịch dự phòng (dòng 33) |
| 33 | Giới hạn thời gian cho mọi lệnh adb / MuMuManager; lịch dự phòng sau 50 phút; file ảnh riêng mỗi lượt; dọn adb treo | 🟡 | Sau sự cố 19/11 00:31 (mục 13). Đã kiểm tra lệnh treo bị cắt sau đúng giới hạn; lượt thật 19/11 08:28 chạy thông suốt. Chưa gặp lại thiết bị treo thật |
| 34 | Kiểm tra đúng tài khoản trước khi thu hoạch; không chiếm thiết bị khi bạn đang chơi | ⬜ | Gặp 19/11 08:28 (mục 13). Đã làm thử "hoãn 15 phút khi game đang mở" rồi **bỏ theo yêu cầu** (19/11) |
| 32 | Kết nối lại: chọn Wi-Fi đã lưu có sóng mạnh nhất, kiểm tra Internet thật, không được thì chuyển mạng kế tiếp | 🟡 | Đọc danh sách / sắp xếp đã test (18/11, giả lập 3 Wi-Fi đã lưu). Máy mới lưu 1 Wi-Fi (*<tên Wi-Fi>*) nên chưa test chuyển mạng thật (mục 4) |
| 31 | Tự kết nối lại Wi-Fi khi mất mạng (bật lại sóng Wi-Fi; netsh; khởi động lại card nếu có quyền admin) | ✅ | Test 18/11 (bot, không quyền admin): **Disconnect <tên Wi-Fi>** 17:13:30 → bot phát hiện 17:14:50, `netsh` kết nối lại, có Internet 17:14:53. **Tắt sóng Wi-Fi** 17:15:59 → bot bật lại sóng 17:16:54, `netsh` kết nối, có Internet 17:17:07. Bot nhắn *"📶 Bot có mạng lại"* chậm hơn ~1 phút sau khi có mạng (yêu cầu Telegram đang treo phải hết thời gian chờ) (mục 4) |

### B. Nông trại

| # | Nâng cấp | Trạng thái | Ghi chú |
|---|---|---|---|
| 8 | Đọc số hạt khoai còn lại, báo khi sắp hết | ⬜ | Cần test với game thật |
| 9 | Tự mua hạt khi sắp hết | ⬜ | Tiêu tiền trong game – cần cẩn thận |
| 10 | Chọn loại cây trong cấu hình (thời gian chín riêng) | ⬜ | Cần ảnh mẫu hạt từng loại |
| 11 | Bắt sâu / tưới nước ruộng của mình | 🟡 | Trong `/xemruong` (19/11): nhận diện 💧/🐛 đúng 7/7 + 3/3 trên ảnh thật; bấm 1 biểu tượng là cả ruộng được tưới + bắt sâu (thử tay trên game thật). Mỗi vụ (gieo → thu hoạch) chỉ có **2 lần** cần tưới / bắt sâu. Chưa gặp lượt `/xemruong` thật lúc ruộng đang có biểu tượng. Lượt thu hoạch tự động chưa tưới |
| 12 | Nhiều tài khoản: hàng đợi chạy lần lượt, `/chay tatca` | ⬜ | Hiện mỗi tài khoản đã có lịch riêng, trùng giờ thì chờ 10 phút |
| 23 | Thao tác giống người: bấm bằng ghi thẳng sự kiện chạm + ngẫu nhiên hoá | ✅ | Lượt thật 18/11 16:27: đăng nhập, thu hoạch 10 ô, gieo 10/10 với cách bấm mới (mục 8) |
| 24 | Chuyển vuốt / kéo hạt sang ghi thẳng sự kiện chạm | ⬜ | Cần test thao tác kéo khi thiết bị rảnh |

### C. Bot Telegram

| # | Nâng cấp | Trạng thái | Ghi chú |
|---|---|---|---|
| 13 | Bàn phím nút bấm thay vì gõ lệnh | ✅ (đang tắt) | Đã làm và test, sau đó **tắt theo yêu cầu** vì chiếm chỗ chat. Bật lại: `$ShowKeyboard = $true` (mục 5) |
| 14 | `/tamdung <giờ>` và `/tiep` | ✅ | Đã test: lượt tự động bị dời tới lúc hết tạm dừng, `/tiep` kéo lượt quá hạn về chạy sau 2 phút (mục 4, 5) |
| 15 | `/xemruong <tài khoản>`: chụp ruộng, không thu hoạch | ✅ | Lượt thật 18/11 16:37: *"cây đang lớn ở 9/10 ô"* (cây vừa gieo, nhân vật che 1 ô). Trước đó: đã chạy với game thật lúc 12:35 ngày 18/11: ảnh đúng nhưng báo *"không xác định được"* vì cây lớn che biển gỗ. **Đã sửa:** đếm thanh thời gian trên cả màn hình, ảnh đó giờ ra đúng 10/10 |
| 16 | `/thongke [ngày]` | ✅ | Lịch sử ở `state\lich_su.jsonl`, đã tạo lại từ log cũ (mục 6) |
| 17 | Tóm tắt mỗi ngày lúc 22:00 | ⬜ | |
| 18 | `/maytinh`: RAM, CPU, ổ đĩa, uptime, màn hình xanh, Wi-Fi, VPN, MuMu, tự đăng nhập | ✅ | |

### D. Hạ tầng (bạn tự làm)

| # | Việc | Trạng thái | Ghi chú |
|---|---|---|---|
| 19 | Tự đăng nhập Windows + BIOS tự bật máy sau mất điện | 🧑 ⬜ | Lệnh/hướng dẫn ở mục 5 → *Cài Windows 11 cho máy chạy 24/7* (A, D) |
| 20 | Cắm dây LAN thay Wi-Fi USB | 🧑 ⬜ | Đã giảm rớt Wi-Fi bằng cách tắt sleep + tiết kiệm điện USB (mục C, xong 18/11) |
| 21 | Thêm 1 thanh RAM 8 GB | 🧑 ⬜ | RAM trống thường chỉ ~1 GB khi Chrome + MuMu cùng chạy |
| 22 | Kiểm tra RAM (`mdsched.exe`) sau màn hình xanh 0x12B ngày 18/11 | 🧑 ⬜ | Làm sau lượt thu hoạch, máy sẽ khởi động lại ~15–30 phút |

### E. Câu cá (chạy riêng, mục 12)

| # | Nâng cấp | Trạng thái | Ghi chú |
|---|---|---|---|
| 25 | Bot câu cá tự động, nhắm "Tuyệt vời" | ✅ | Máy DELL (`-LeadSec 0.03`): 92% vòng Tuyệt vời trên 259 vòng |
| 29 | Chạy được khi clone sang máy khác (tự tìm MuMu, `-NghiSau 20,30` qua `-File`, `-LeadSec` theo máy) | ✅ | 18/11 |
| 30 | Bù riêng từng loại vòng (chậm / vừa / nhanh / thưa khung), tự học theo kết quả, lưu theo máy | ✅ ⏳ | Chưa chạy thử với game |
| 26 | Tự đi từ sảnh tới chỗ câu (Giao lưu → Thị trấn nhỏ → cầu tàu) | ⬜ | Hiện phải đứng sẵn ở cầu tàu |
| 27 | Tự bán / dọn cá khi Ba lô đầy (khoảng 60 con) | ⬜ | Cần bạn làm mẫu thao tác bán cá |
| 28 | Lệnh Telegram `/cauca` | ⬜ | Bạn chọn chạy tay bằng `cau_ca.bat` |

---

## 12. Câu cá tự động (chạy riêng)

Bot câu cá **chạy riêng bằng tay**, không theo lịch và không gắn vào bot Telegram. Nó dùng chung thiết bị MuMu `auto` với script nông trại.

### Chuẩn bị
1. Bật MuMu thiết bị `auto`, vào game bằng tài khoản muốn câu.
2. Đi tới **chỗ câu trên cầu tàu** (Giao lưu → Thị trấn nhỏ → đi xuống cầu tàu) cho tới khi thấy 2 nút **Câu cá bằng lưới** và **Bắt đầu câu cá**.
3. Ba lô còn chỗ trống (chứa khoảng 60 con) và còn mồi.

### Chạy
Tất cả file câu cá nằm trong thư mục `cau_ca\` của repo. Mở PowerShell hoặc cmd tại thư mục repo:
```
cau_ca\cau_ca.bat 30
```
- `30` là số lần câu. Bỏ trống thì câu 30 lần.
- Thêm `-KhongNguoi` để tắt giả lập người: không nghỉ giữa chừng, không lệch toạ độ.
- Thêm `-LeadSec 0.03` (hoặc giá trị đã hiệu chỉnh cho máy đang dùng), xem mục **Hiệu chỉnh theo máy** bên dưới.
- Dừng giữa chừng: bấm `Ctrl+C` trong cửa sổ đang chạy.

Lệnh đầy đủ, có thêm tuỳ chọn (sửa đường dẫn cho đúng chỗ clone repo):
```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\DELL\Documents\tools\motherbot\cau_ca\cong_cu\cau_thu.ps1" -N 50 -NghiSau 15,20 -NghiGiay 25,35 -LeadSec 0.03
```
| Tham số | Mặc định | Ý nghĩa |
|---|---|---|
| `-N` | 3 (`cau_ca.bat`: 30) | Số lần câu |
| `-ThietBi` | `auto` | Tên thiết bị MuMu. Bot tự tìm thư mục MuMu (ổ C:, D:…) và cổng ADB |
| `-NghiSau a,b` | `12,20` | Cứ câu ngẫu nhiên a–b con thì nghỉ 1 lần. Viết `20,30`, `20-30` hay `"20 30"` đều được |
| `-NghiGiay a,b` | `20,90` | Mỗi lần nghỉ ngẫu nhiên a–b giây |
| `-KhongNguoi` | tắt | Tắt ngẫu nhiên hoá và nghỉ |
| `-LeadSec` | `0.12` | Độ trễ bù của máy (giây). **Mỗi máy một giá trị**: máy cũ `0.12`, máy mới (DELL) `0.03` |
| `-TargetR` | `11` | Bán kính (px) muốn vòng sáng chạm tới lúc lệnh bấm tới game |

### Hiệu chỉnh theo máy
Cùng cài đặt MuMu (1600x900, 240 dpi) nhưng **máy nhanh hay chậm thì độ trễ khác nhau**.
- Ví dụ máy DELL: luồng hình khoảng 30 khung/giây, còn máy cũ khoảng 20.
- Dùng `-LeadSec 0.12` của máy cũ trên máy DELL thì bot bấm sớm khoảng 0,08 giây, nên ra toàn **Xuất sắc**.

Khi chạy trên máy mới:
1. Chạy khoảng 10–20 lần rồi xem tổng kết.
2. Nhiều **Xuất sắc** (bấm sớm) thì giảm `-LeadSec`. Nhiều **Hụt** (bấm muộn, mất cá) thì tăng. Mỗi lần chỉnh khoảng `0.02`.
3. Phần lệch còn lại theo từng loại vòng, bot **tự học** (xem bên dưới).

**Bù riêng từng loại vòng (tự học, lưu theo máy):**
- Bot chia vòng theo tốc độ co: `cham` (< 130 px/s), `vua` (130–190), `nhanh` (≥ 190).
- Bot cũng chia theo độ thưa của khung hình: tiền tố `thua_` khi chỉ đo được khoảng 14 lần/giây thay vì 30. Đây là một loại cá có hình vòng tròn hiện trễ.
- Mỗi loại có một mức bù (px) cộng vào ngưỡng bấm. Sau mỗi vòng: **Xuất sắc → bấm muộn hơn 0,5 px**, **Hụt → bấm sớm hơn 1,5 px**.
- Mức bù lưu ở `cau_ca\bu_vong_<tên máy>.txt`, mỗi máy một file.
  - Tên máy là `%COMPUTERNAME%` của Windows. Ví dụ máy DELL là `bu_vong_DESKTOP-UHCRB1I.txt`.
  - File được tạo với giá trị khởi đầu ở lần chạy đầu tiên, rồi cập nhật sau mỗi vòng ra Xuất sắc hoặc Hụt.
  - Đầu và cuối mỗi lượt chạy, bot in bảng mức bù.
  - Muốn học lại từ đầu thì xoá file đó.

> ⚠️ **Mức bù và `-LeadSec` khác nhau tuỳ theo máy.**
> - Các file `bu_vong_*.txt` được commit lên repo để giữ lại mức bù đã học. Mỗi file chỉ đúng với **đúng máy có tên đó**.
> - **Không** đổi tên hay chép file của máy này sang máy khác.
> - Máy mới sẽ tự tạo file riêng và học lại, kể cả khi cùng cài đặt MuMu (1600x900, 240 dpi).
> - Sau khi câu một đợt dài, nhớ commit file `bu_vong_<tên máy>.txt` của máy đó để lưu mức bù mới.
>
> | Máy | Tên máy | `-LeadSec` |
> |---|---|---|
> | Máy cũ | (chưa ghi) | `0.12` |
> | Máy DELL | `DESKTOP-UHCRB1I` | `0.03` |

### Bot làm gì mỗi lần câu
1. Chờ thấy nút *Câu cá bằng lưới* (đang ở chỗ câu), rồi bấm **Bắt đầu câu cá**. **Không bao giờ bấm Câu cá bằng lưới.**
2. Đợi cá cắn câu (4–13 giây). Nút đổi thành **Kéo cần** màu đỏ thì bấm.
3. **Vòng tròn:** vòng sáng co dần vào quả cầu cam. Bot đo bán kính 20–30 lần mỗi giây (tuỳ máy) và bấm đúng lúc để được **Tuyệt vời**.
   - Mỗi vòng co với tốc độ khác nhau (60–290 px/s).
   - Cá khó có 2–3 vòng liên tiếp, vòng sau nhanh hơn. Bot bấm từng vòng, mỗi loại vòng dùng mức bù riêng.
4. Màn **Chúc mừng!** (tên cá, cân nặng) → bấm *Nhấn để tiếp tục*, rồi câu con tiếp theo.
5. Log ghi **điểm bấm thật** (đã lệch ngẫu nhiên) của mọi lần bấm. Ví dụ: `bam Keo can tai (1391,704) (tam nut (1385,710))`.

### Bot tự dừng khi
| Tình huống | Bot báo |
|---|---|
| Game báo **"Mồi chưa đủ"** | `HET MOI`: đổi tài khoản hoặc mua mồi |
| Game báo **"Ba lô đã đầy"** | `BALO DAY`: bán hoặc dọn cá trong Ba lô |
| Không thấy nút Bắt đầu câu cá sau 30 giây | `LOI`: nhân vật không đứng ở chỗ câu |
| Đủ số lần câu đã đặt | Tổng kết số lần Tuyệt vời / Xuất sắc / Hụt |

### Kết quả thử nghiệm (18/11/2026)
| Đợt | Câu được | Vòng Tuyệt vời |
|---|---|---|
| 40 lần (`input tap`) | 37/40 | 72% |
| 20 lần (`input tap`) | 17/20 | 65% |
| 20 lần (ghi thẳng sự kiện chạm) | 19/20 | 79% |
| **Máy DELL, `-LeadSec 0.03`, 6 lượt (21:16–22:30)** | **197/204** | **92% (237/259 vòng)** |

Trên máy DELL, các vòng chưa được Tuyệt vời đều là vòng 2–3 co nhanh, và vòng 2 của loại cá "thưa khung". Bot đã thêm bù riêng cho các vòng này nhưng **chưa chạy thử** (xem `GHI_CHU.md`).

Mỗi lần câu mất khoảng 11–13 giây, chưa tính các lần nghỉ.

### Đầu ra
- `cau_ca\ket_qua\cau_thu_<ngày>_<giờ>\`: mỗi lần chạy một thư mục.
  - `log.txt`: toàn bộ nhật ký, gồm thông số lúc chạy, từng bước bấm, **dãy bán kính đo được của từng vòng**, các lần nghỉ, lỗi và tổng kết.
  - `N_0_truoc.jpg`: trước khi câu. `N_vK_sau_bam.jpg`: sau khi bấm vòng K (thấy chữ Tuyệt vời / Xuất sắc / Hụt).
  - `N_3_chuc_mung.jpg` / `N_3_khong_chuc_mung.jpg`: câu được / trượt. `het_moi`, `balo_day`, `loi_…`: lúc bot dừng.
- `cau_ca\hieu_chinh.csv`: mỗi vòng bấm một dòng, ghi thêm vào sau qua mọi lần chạy. Gồm giờ, lần, vòng, bán kính dự đoán, tốc độ co, kết quả, có giả lập người hay không, **dãy bán kính** (`vet_ban_kinh`) tên thư mục lần chạy (`lan_chay`) để mở ảnh tương ứng, và **loại vòng** (`loai_vong` = `loại:bù_px:khoảng_cách_đo_s`). Dùng để tìm nguyên nhân các lần Hụt / Xuất sắc và chỉnh script.
- `cau_ca\bu_vong_<tên máy>.txt`: mức bù từng loại vòng mà bot đã tự học trên máy đó. Có commit lên repo, **mỗi máy một file, khác nhau tuỳ máy**.
- `cau_ca\GHI_CHU.md`: ghi chú kỹ thuật (luật vòng tròn, cách nhận trạng thái, lịch sử hiệu chỉnh).

### Lưu ý
- **Đừng để trùng giờ với lượt nông trại** (xem giờ bằng `/trangthai` trên Telegram). Lượt nông trại sẽ đăng nhập lại tài khoản nông trại và **tắt thiết bị `auto`** khi xong.
- Đang câu thì không bấm vào cửa sổ MuMu.
- Vị trí nút Kéo cần và vòng tròn **thay đổi theo chỗ nhân vật đứng**. Bot tự tìm nên không cần đứng đúng một chỗ, miễn là thấy 2 nút ở góc phải dưới.
- Nếu luồng hình bị ngắt (ví dụ thu nhỏ MuMu), bot tự kết nối lại tối đa 3 lần, kể cả lúc mới khởi động.
- Luồng hình khựng trong lúc vòng tròn đang co thì bot chờ, không bỏ vòng. Vòng nào bot không bấm được ghi là `Khong bam`.

---

## 13. Các lỗi gặp khi chạy thật

Nhật ký các lỗi xảy ra khi script chạy thật trên máy (không tính lỗi lúc phát triển). Mỗi lần gặp lỗi mới thì thêm 1 dòng.

**Chú thích:** ✅ đã sửa (đã kiểm tra) · 🟡 đã sửa, chưa gặp lại để kiểm chứng · ❌ chưa sửa · 🧑 bạn tự xử lý

| Thời gian | Hiện tượng | Nguyên nhân | Cách xử lý | Trạng thái |
|---|---|---|---|---|
| 17/11 23:58 → 18/11 01:43 | 4 lượt liên tiếp *"Không vào được sảnh chính"* | Máy sleep, khi thức dậy Wi-Fi USB không tự kết nối lại | Tắt sleep, tắt tiết kiệm điện USB Wi-Fi (mục 5 → *Cài Windows 11 cho máy chạy 24/7*); script chờ mạng 5 phút, mất mạng không tính là lỗi | ✅ |
| 18/11 10:55 | Màn hình xanh, máy tự khởi động lại | Lỗi `0x12B` (hỏng trang bộ nhớ) – nghi RAM / pagefile khi máy thiếu RAM | Kiểm tra RAM bằng `mdsched.exe`, thêm RAM (mục 11, dòng 21–22) | 🧑 ❌ |
| 18/11 12:35 | `/xemruong` báo *"không xác định được"* | Cây lớn che mất biển gỗ cạnh ruộng | Đếm thanh thời gian trên cả màn hình, không cần biển gỗ | ✅ |
| 18/11 16:17 | Lượt tự động dừng ngay: *"could not get driver version for /dev/input/mouse1"* | Lệnh dò thiết bị cảm ứng (`getevent`) in cảnh báo ra stderr; script chạy chế độ `Stop` nên PowerShell coi là lỗi | Đọc lệnh adb không qua stderr của PowerShell | ✅ |
| 18/11 16:20 | *"Không thấy nút nông trại trong bảng Bạn bè"* | Popup *Báo danh mỗi ngày* hiện **sau** khi đã vào sảnh, che nút Bạn bè | Đóng popup trước khi bấm Bạn bè; test lại sau giờ reset 16:00 (popup cần bấm ✕ 2 lần) | ✅ |
| 18/11 16:25 | *"Không mở được form đăng nhập 7Road"* | Game tự đăng nhập bằng phiên cũ (vừa đăng nhập vài phút trước), nhảy thẳng tới *Vào game* | Thấy nút *Vào game* thì đi tiếp | ✅ |
| 18/11 17:06 | Mất mạng, bot thử `netsh` nhưng không kết nối lại được; bot còn báo nhầm *"đã tự kết nối lại"* | Sóng Wi-Fi bị **tắt** (không phải ngắt kết nối) → `netsh` không làm gì được; bot ghi nhận khi chưa kiểm tra kết quả | Bật lại sóng Wi-Fi bằng Radio API; chỉ báo việc thật sự thành công; test lại 2 trường hợp tắt sóng / ngắt kết nối đều tự nối lại | ✅ |
| **19/11 00:31** | Lượt 00:26 **đứng im giữa lúc thu hoạch** (đã thu 3/10 ô), không báo lỗi, không hẹn lịch mới; **thiết bị và game treo** tới khi bạn phát hiện lúc 04:18 và `/chay` lại | Lệnh chụp màn hình `adb exec-out screencap` treo vô hạn (thiết bị/game treo), script không có giới hạn thời gian → chờ mãi; nhiều khả năng Task Scheduler diệt lượt sau 45 phút → không chạy phần tắt máy + hẹn lịch | (1) **Mọi lệnh adb và MuMuManager có giới hạn thời gian** (chụp màn hình 15 giây) → quá giờ thì báo lỗi, bước được làm lại, cuối cùng khởi động lại thiết bị. (2) **Lịch dự phòng**: đầu mỗi lượt hẹn sẵn 1 lượt sau 50 phút (`$SafetyRunMin`), lượt bị diệt vẫn còn lượt sau | 🟡 |
| 19/11 04:21 | Lượt `/chay` lỗi *"The process cannot access the file …ddtank_farm_screen.raw"* (2 lần làm lại không được, phải khởi động lại thiết bị) | Lệnh adb treo của lượt 00:26 vẫn còn sống, giữ file ảnh chụp chung | Mỗi lượt dùng file ảnh riêng; đầu lượt diệt lệnh chụp màn hình bị treo còn sót (> 3 phút) | 🟡 |
| 19/11 04:24 | Lượt chạy thành công nhưng **không có tin Telegram** (*"message caption is too long"*) | 3 dòng báo làm lại chép nguyên câu lỗi dài → chú thích ảnh vượt 1024 ký tự | Rút gọn câu lỗi (≤ 140 ký tự); chú thích quá dài thì gửi phần còn lại thành tin nhắn riêng | 🟡 |
| 19/11 08:28 | Lượt xem ruộng (test) báo *"akaka: có ô đã chín"* nhưng thật ra là **ruộng của tài khoản khác**; xong còn **tắt thiết bị đang có người dùng** | Thiết bị đang bật sẵn, game đang ở sảnh của tài khoản khác → script không kiểm tra đang đăng nhập tài khoản nào, vào thẳng nông trại; cuối lượt luôn tắt thiết bị | **Bạn chọn giữ nguyên** (19/11): lượt tự động vẫn chạy khi game đang mở. Tránh mở game trên thiết bị `auto` gần giờ thu hoạch (xem `/lich`) | 🧑 |
