import Foundation
import EarningsCore

/// App 与扩展各自读取同一 App Group；所有写操作仅由 App 执行。
enum SharedStore {
    static let groupID = "group.com.callum.TodayEarnings"
    static var fileURL: URL {
        get throws {
            guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) else {
                throw NSError(domain: "SharedStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法访问共享容器，请检查 App Group 签名配置。"])
            }
            return directory.appendingPathComponent("earnings.json")
        }
    }
    static func load() throws -> EarningsData {
        let url = try fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return EarningsData() }
        return try JSONDecoder().decode(EarningsData.self, from: Data(contentsOf: url, options: .mappedIfSafe))
    }
    static func save(_ data: EarningsData) throws {
        let url = try fileURL
        try JSONEncoder().encode(data).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
