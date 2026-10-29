# Ner's Daily

App iOS nhắc uống thuốc hằng ngày, luôn tính theo giờ Việt Nam dù máy đang ở múi giờ nào.

- Báo thức kêu cả khi máy gạt im lặng hoặc bật Focus (AlarmKit), hoặc chế độ chỉ rung.
- Hoãn, nhắc lại tới khi xác nhận đã uống, cảnh báo trước khi hai lần uống cách nhau quá 24 giờ.
- Đếm số viên còn lại và nhắc mua thêm (tuỳ chọn). Đánh dấu uống bù cho viên hụt.
- Tiếng Việt và tiếng Anh, chọn ở lần mở đầu và đổi trong Cài đặt.
- Chạy hoàn toàn không cần mạng. Có mạng thì đồng bộ trạng thái lên một dịch vụ tự host để người thân theo dõi qua Telegram.

## Yêu cầu

- iOS 26 trở lên.
- Cài qua [SideStore](https://sidestore.io) với Apple ID miễn phí.

## Cài đặt

Trong SideStore: Sources, nút `+`, dán địa chỉ source rồi cài Ner's Daily. Có bản mới thì SideStore tự báo.

```
https://github.com/finnwasabi/ners-daily/releases/latest/download/source.json
```

## Phát triển

- Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate` rồi mở `NersDaily.xcodeproj`.
- `scripts/build-ipa.sh` build file `.ipa` không ký để cài qua SideStore.
- Đặc tả logic và hợp đồng dữ liệu: [docs/spec.md](docs/spec.md).
- Dịch vụ đồng bộ và bot Telegram: [server/](server/README.md).
- Phát hành: gắn tag `vX.Y.Z`, GitHub Actions build `.ipa` và `source.json` rồi đăng lên Releases.

## Giấy phép

MIT
