import Foundation

/// Hạn chữ ký của app. SideStore với Apple ID miễn phí ký 7 ngày; quá hạn là app không mở được
/// và có thể không còn nhắc, nên phải báo trước.
nonisolated enum SigningInfo {
    /// Đọc `ExpirationDate` trong hồ sơ ký nhúng trong app. `nil` trên Simulator hoặc khi không đọc được.
    static let expiration: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8)),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil),
              let dict = plist as? [String: Any] else { return nil }
        return dict["ExpirationDate"] as? Date
    }()
}
