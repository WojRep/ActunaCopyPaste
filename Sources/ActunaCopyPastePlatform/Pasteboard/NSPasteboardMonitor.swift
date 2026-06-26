import Foundation
import AppKit
import ActunaCopyPasteCore

/// Observes an `NSPasteboard` for new content by polling `changeCount` (the only
/// native change-detection mechanism on macOS — there is no notification).
///
/// Production hardening: before a full read, gate via the `detect*` API
/// (`detectPatterns`/`detectMetadata`) and `accessBehavior` to avoid the macOS
/// read-privacy alert; only read raw contents when actually capturing. The
/// content extraction below is isolated into `capture(from:)` so it is unit-tested.
@MainActor
public final class NSPasteboardMonitor: PasteboardMonitorPort {
    private let pasteboard: NSPasteboard
    private let interval: TimeInterval
    private var lastChangeCount: Int
    private var timer: Timer?

    public init(pasteboard: NSPasteboard = .general, interval: TimeInterval = 0.3) {
        self.pasteboard = pasteboard
        self.interval = interval
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start(onCapture: @escaping @Sendable (CapturedContent) -> Void) async {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let pb = self.pasteboard
                guard pb.changeCount != self.lastChangeCount else { return }
                self.lastChangeCount = pb.changeCount
                if let content = Self.capture(from: pb) {
                    onCapture(content)
                }
            }
        }
    }

    public func stop() async {
        timer?.invalidate()
        timer = nil
    }

    /// Builds `CapturedContent` from a pasteboard's current contents. Honors the
    /// nspasteboard.org markers and the source-app attribution type.
    public static func capture(from pasteboard: NSPasteboard) -> CapturedContent? {
        let types = pasteboard.types ?? []
        let typeStrings = Set(types.map(\.rawValue))

        let markers = Set(PasteboardMarker.allCases.filter { typeStrings.contains($0.rawValue) })
        let sourceApp = pasteboard
            .data(forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))
            .flatMap { String(data: $0, encoding: .utf8) }

        // File URLs first (Finder copies), then images, then text.
        if let url = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL], let first = url.first, first.isFileURL {
            return CapturedContent(kind: .file, text: nil, resourceReference: first.path,
                                   label: first.lastPathComponent, sourceApp: sourceApp, markers: markers)
        }
        if typeStrings.contains(NSPasteboard.PasteboardType.tiff.rawValue) ||
            typeStrings.contains(NSPasteboard.PasteboardType.png.rawValue) {
            return CapturedContent(kind: .image, text: nil, resourceReference: nil,
                                   label: "Image", sourceApp: sourceApp, markers: markers)
        }
        if let string = pasteboard.string(forType: .string), !string.isEmpty {
            return CapturedContent(kind: .text, text: string, resourceReference: nil,
                                   label: nil, sourceApp: sourceApp, markers: markers)
        }
        return nil
    }
}
