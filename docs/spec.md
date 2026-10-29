# Đặc tả Ner's Daily

Tài liệu này là nguồn chuẩn cho logic nhắc uống thuốc và hợp đồng dữ liệu giữa app và dịch vụ đồng bộ.

## Giờ Việt Nam cố định

- Mọi mốc giờ tính theo `TimeZone(identifier: "Asia/Ho_Chi_Minh")` (UTC+7, không có giờ mùa hè),
  bất kể múi giờ của máy. Không bao giờ dùng `TimeZone.current` để tính lịch.
- Mọi mốc giờ lưu và truyền dạng thời điểm tuyệt đối (`Date`, UTC ISO 8601 khi ra JSON).
- Hiển thị luôn kèm cả hai giờ: giờ VN và giờ nơi máy đang ở.
- Báo thức dùng `Alarm.Schedule.fixed(Date)` (AlarmKit), noti dùng `UNTimeIntervalNotificationTrigger`
  tính từ thời điểm tuyệt đối. Không dùng `Alarm.Schedule.relative` vì nó chạy theo múi giờ máy.
- App hẹn sẵn H ngày tới (mặc định 14) và nạp thêm khi mở app, khi bấm "Đã uống", khi đổi múi giờ,
  khi Background App Refresh chạy.

## Lịch và khoảng tối đa

- Người dùng đặt **giờ chính** theo giờ VN (ví dụ 21:00).
- **Khoảng tối đa** giữa hai lần uống liên tiếp: mặc định 24 giờ, chỉnh được.
- Hạn chót lần kế = lần uống trước + khoảng tối đa.
- Mốc nhắc lần kế = min(giờ chính ngày kế theo giờ VN, hạn chót).
  Uống sớm thì mốc hôm sau bị kéo sớm theo. Có thao tác "về lại giờ gốc": app báo rõ lần đó sẽ vượt khoảng tối đa.
- Chuỗi nhắc cho mỗi lần uống, tất cả huỷ khi bấm "Đã uống":
  1. Mốc nhắc chính.
  2. Nhắc lại 3 lần, mỗi lần cách 5 phút (chỉnh được).
  3. Sau đó nhắc mỗi 1 giờ.
  4. Trong 2 giờ cuối trước hạn chót: nhắc mỗi 15 phút.
  5. Tại hạn chót: báo thức có tiếng bất kể chế độ, kèm câu trỏ về tờ hướng dẫn thuốc và bác sĩ, dược sĩ.
  6. Quá hạn chót mà chưa uống: vẫn báo có tiếng, nhắc lại 3 lần mỗi 5 phút, rồi mỗi 15 phút tới hết 3 giờ
     đầu, rồi mỗi giờ tới hết cửa sổ trễ (mặc định 12 giờ sau hạn chót, chỉnh được).
  Uống đúng giờ chính mỗi ngày thì hạn chót trùng giờ chính hôm sau, nên phần nhắc sau hạn chót mới là
  phần "nhắc tới khi uống".
- Hoãn: kêu lại sau 10 phút (chỉnh được). Hoãn không dời hạn chót.
- "Đã uống" có hoàn tác trong 10 phút. Thời điểm uống sửa được trong lịch sử.
- "Tạm dừng nhắc N ngày": không nhắc, không tính hụt trong thời gian dừng. Hết dừng thì lần kế tính từ giờ chính.
- Mọi mốc phải đúng khi: đổi múi giờ máy giữa chừng, qua nửa đêm, uống sớm, uống trễ, bỏ một ngày.
- Bất biến: không có khoảng nào giữa hai lần uống liên tiếp vượt khoảng tối đa mà chuỗi nhắc không có
  ít nhất một mốc báo thức có tiếng tại hoặc trước hạn chót.

## Số viên

- Ô "Số viên" tuỳ chọn. Bỏ trống: chỉ nhắc, không đếm.
- Có nhập: mỗi lần "Đã uống" trừ một viên. "Thêm viên" cộng vào số còn lại và tổng.
- "Nhắc mua thêm": bật tắt, kèm số ngày trước khi hết (mặc định 7). Khi số viên còn lại nhỏ hơn hoặc bằng
  số ngày đó, mỗi lần báo uống kèm dòng "còn N viên, nhớ mua thêm".
- **Trễ** = uống sau hạn chót nhưng còn trong cửa sổ trễ. Vẫn tính là đã uống, lần kế tính từ lúc uống.
- **Hụt** = qua hết cửa sổ trễ mà không có xác nhận. Đếm trên máy, không cần mạng.
- `daysTaken` = số lần đã uống kể từ lần nhập hoặc thêm viên gần nhất (khi không đếm viên: kể từ lúc cài).

## Đồng bộ (không phụ thuộc mạng)

- Mọi nhắc nhở và tính toán chạy trên máy. Có mạng thì gửi ảnh chụp trạng thái mới nhất, mất mạng thì để dành.
- Dịch vụ không tự suy luận uống hay chưa, chỉ báo đúng dữ liệu mới nhất kèm giờ cập nhật.

### Hợp đồng dữ liệu

`POST /v1/snapshot`, header `Authorization: Bearer <token>`, body JSON. Server chỉ giữ bản có `updatedAt` mới nhất,
bản cũ hơn bị bỏ qua (trả 200 kèm `"stale": true`).

```json
{
  "schemaVersion": 1,
  "updatedAt": "2026-10-27T14:03:00Z",
  "lastTakenAt": "2026-10-27T14:03:00Z",
  "nextDueAt": "2026-10-28T14:00:00Z",
  "deadlineAt": "2026-10-28T14:03:00Z",
  "daysTaken": 12,
  "missedCount": 1,
  "lateCount": 0,
  "pillsTotal": 28,
  "pillsRemaining": 16,
  "refillReminder": { "enabled": true, "daysBefore": 7 },
  "pausedUntil": null
}
```

- Mọi mốc giờ là UTC ISO 8601 không có phần lẻ giây. `pillsTotal`, `pillsRemaining` là `null` khi không đếm viên.
  `lastTakenAt`, `pausedUntil` có thể `null`.
- `GET /v1/snapshot` (cùng token) trả bản mới nhất, 404 nếu chưa có.

## Bot Telegram

- Bot riêng, chỉ trả lời một chat ID cấu hình sẵn.
- Nhận snapshot mới (không stale) thì nhắn ngay.
- Bảng tin 09:00 giờ VN mỗi ngày: số ngày đã uống, số lần trễ, số hụt, số viên còn trên tổng, giờ đồng bộ gần nhất.
  Snapshot cũ hơn 24 giờ thì ghi rõ "chưa đồng bộ từ ...".
- Lệnh `/check`: trả trạng thái mới nhất.
- Mọi giờ hiển thị theo giờ VN. Token bot, token API, chat ID lấy từ biến môi trường, không nằm trong repo.
