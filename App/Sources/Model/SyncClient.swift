import Foundation
import NersCore

/// A connection code shaped `https://host/path#token`, sent by the bot's /link command.
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

/// Sends the latest snapshot to the server. Offline is fine: the next sync sends the newest one (the server drops older ones).
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

/// The connection code contains a token, so it lives in the Keychain, readable on this device only.
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
        // Readable after first unlock, so background App Intents can still sync while the phone is locked.
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(item as CFDictionary, nil)
    }
}
