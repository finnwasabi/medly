import Foundation
import NersCore

/// Mã kết nối dạng `https://host/path#token`, bot gửi bằng lệnh /link.
struct SyncConnection: Equatable {
    var endpoint: URL
    var token: String

    init?(code: String) {
        guard let url = URL(string: code.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", let token = url.fragment, !token.isEmpty,
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.fragment = nil
        guard let base = parts.url else { return nil }
        endpoint = base.appending(path: "v1/snapshot")
        self.token = token
    }
}

/// Gửi snapshot mới nhất lên server. Mất mạng thì thôi, lần sau gửi bản mới nhất (server bỏ bản cũ).
nonisolated struct SyncClient: Sendable {
    struct Reply: Decodable {
        var stale: Bool
        var message: String?
    }

    enum Failure: Error, LocalizedError {
        case status(Int)
        var errorDescription: String? {
            switch self {
            case .status(401): L("Mã kết nối sai, xin mã mới bằng lệnh /link.", "Wrong connection code, get a new one with /link.")
            case .status(let code): L("Server trả lỗi \(code).", "Server error \(code).")
            }
        }
    }

    func send(_ snapshot: Snapshot, to connection: SyncConnection) async throws -> Reply {
        var request = URLRequest(url: connection.endpoint, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(connection.token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try snapshot.jsonData()
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Failure.status(status) }
        return try JSONDecoder().decode(Reply.self, from: data)
    }
}

/// Mã kết nối có chứa token nên cất trong Keychain, chỉ đọc được trên máy này.
nonisolated enum ConnectionKeychain {
    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "io.github.finnwasabi.nersdaily.sync"]
    }

    static func load() -> String? {
        var result: AnyObject?
        var lookup = query
        lookup[kSecReturnData as String] = true
        guard SecItemCopyMatching(lookup as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ code: String?) {
        SecItemDelete(query as CFDictionary)
        guard let code else { return }
        var item = query
        item[kSecValueData as String] = Data(code.utf8)
        // Đọc được sau lần mở khoá đầu, để App Intent chạy nền lúc máy khoá vẫn đồng bộ được.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
