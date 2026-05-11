import Foundation

final class BatteryHistoryStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
        let appDirectory = supportDirectory.appendingPathComponent("mac-battery-ledger", isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        fileURL = appDirectory.appendingPathComponent("history.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func load() -> BatteryHistory {
        guard
            let data = try? Data(contentsOf: fileURL),
            let history = try? decoder.decode(BatteryHistory.self, from: data)
        else {
            return .empty
        }

        return history
    }

    func save(_ history: BatteryHistory) {
        guard let data = try? encoder.encode(history) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}
