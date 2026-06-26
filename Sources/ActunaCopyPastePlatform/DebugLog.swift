import Foundation

/// Dead-simple file logger for diagnosing the running app (OSLog `debug`/`info`
/// levels don't reliably land in `log show` for an ad-hoc-signed agent). Appends
/// timestamped lines to `~/Library/Logs/ActunaCopyPaste/debug.log`, which can be
/// `tail -f`'d while interacting with the app.
public enum DebugLog {
    /// `~/Library/Logs/ActunaCopyPaste/debug.log` (inside the container for a sandboxed build).
    public static let fileURL: URL? = {
        guard let logs = try? FileManager.default.url(
            for: .libraryDirectory, in: .userDomainMask, appropriateFor: nil, create: false
        ) else { return nil }
        let dir = logs.appendingPathComponent("Logs/ActunaCopyPaste", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("debug.log")
    }()

    private static let lock = NSLock()

    public static func log(_ message: String, category: String = "app") {
        guard let fileURL else { return }
        let line = "\(Date()) [\(category)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        lock.lock()
        defer { lock.unlock() }
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: fileURL)
        }
    }

    /// Wipes the log (called once at launch so each run starts fresh).
    public static func reset() {
        guard let fileURL else { return }
        lock.lock()
        defer { lock.unlock() }
        try? Data().write(to: fileURL)
    }
}
