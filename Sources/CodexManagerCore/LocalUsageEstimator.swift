import Foundation

public final class LocalUsageEstimator {
    private let paths: CodexPaths

    public init(paths: CodexPaths = CodexPaths()) {
        self.paths = paths
    }

    public func estimate(profileID: String?, activations: [ProfileActivation]) -> LocalUsageSummary {
        let databaseURL = paths.currentCodexHome.appendingPathComponent("state_5.sqlite")
        guard FileManager.default.fileExists(atPath: databaseURL.path) else {
            return LocalUsageSummary(profileID: profileID, tokensUsed: 0, threadCount: 0)
        }

        let windows = profileID.map { id in activations.filter { $0.profileID == id } } ?? []
        if windows.isEmpty {
            return runAggregateQuery(databaseURL: databaseURL, whereClause: nil, profileID: profileID)
        }

        var tokens: Int64 = 0
        var threads = 0
        for window in windows {
            let start = Int64(window.startedAt.timeIntervalSince1970)
            let end = Int64((window.endedAt ?? Date()).timeIntervalSince1970)
            let clause = "updated_at >= \(start) AND updated_at <= \(end)"
            let summary = runAggregateQuery(databaseURL: databaseURL, whereClause: clause, profileID: profileID)
            tokens += summary.tokensUsed
            threads += summary.threadCount
        }
        return LocalUsageSummary(profileID: profileID, tokensUsed: tokens, threadCount: threads)
    }

    private func runAggregateQuery(databaseURL: URL, whereClause: String?, profileID: String?) -> LocalUsageSummary {
        let condition = whereClause.map { " WHERE \($0)" } ?? ""
        let query = "SELECT COALESCE(SUM(tokens_used), 0), COUNT(*) FROM threads\(condition);"
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databaseURL.path, query]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return LocalUsageSummary(profileID: profileID, tokensUsed: 0, threadCount: 0)
            }
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let string = String(data: data, encoding: .utf8) ?? ""
            let parts = string.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: "|")
            guard parts.count == 2 else {
                return LocalUsageSummary(profileID: profileID, tokensUsed: 0, threadCount: 0)
            }
            return LocalUsageSummary(
                profileID: profileID,
                tokensUsed: Int64(parts[0]) ?? 0,
                threadCount: Int(parts[1]) ?? 0
            )
        } catch {
            return LocalUsageSummary(profileID: profileID, tokensUsed: 0, threadCount: 0)
        }
    }
}
