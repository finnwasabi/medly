# Dịch vụ đồng bộ và bot Telegram

Một file Node (`server.js`), không thư viện ngoài, Node 22 trở lên. Giữ ảnh chụp trạng thái mới nhất app gửi lên
và chạy một bot Telegram riêng chỉ trả lời một chat. Hợp đồng dữ liệu ở [`docs/spec.md`](../docs/spec.md).

## Biến môi trường

| Biến | Bắt buộc | Ý nghĩa |
|---|---|---|
| `API_TOKEN` | có | Token app dùng để gửi snapshot (`Authorization: Bearer ...`). Tạo bằng `openssl rand -hex 24`. |
| `PUBLIC_URL` | có | Địa chỉ công khai của dịch vụ, ví dụ `https://example.com/ners`. Bot ghép với token thành mã kết nối. |
| `BOT_TOKEN` | không | Token bot từ BotFather. Thiếu thì chỉ chạy API, không có bot. |
| `CHAT_ID` | không | Chat duy nhất bot trả lời và nhắn tới. |
| `PORT` | không | Mặc định `8787`. |
| `DATA_DIR` | không | Mặc định `./data`, chứa `state.json`. |

## Bot

- `/check`: trạng thái mới nhất. `/msg <lời nhắn>`: lời nhắn hiện trên màn Hôm nay của app ở lần đồng bộ tới,
  để trống để xoá. `/link`: mã kết nối dán vào Cài đặt của app.
- Tự nhắn khi có chuyện đáng biết: vừa uống, hoàn tác, thêm lần trễ hay hụt, tạm dừng, sắp hết viên.
- Bản tin 09:00 giờ VN mỗi ngày. Dữ liệu cũ hơn 24 giờ thì ghi rõ "chưa đồng bộ từ ...".

## Chạy

```sh
npm test
API_TOKEN=... PUBLIC_URL=https://example.com/ners node server.js
```

Docker Compose, dùng ảnh Node chính chủ, mount thẳng mã nguồn:

```yaml
ners-daily:
  image: node:24-alpine
  working_dir: /app
  command: node server.js
  env_file: ./ners-daily/.env
  volumes:
    - ./ners-daily/server.js:/app/server.js:ro
    - ./ners-daily/data:/app/data
  restart: unless-stopped
```
