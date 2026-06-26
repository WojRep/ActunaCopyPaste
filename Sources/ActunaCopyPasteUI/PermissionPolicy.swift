import ActunaCopyPasteCore

/// Whether a given TCC permission has been granted.
public enum PermissionState: Equatable, Sendable {
    case granted
    case missing
}

/// Which permissions the running build actually needs, derived from its capabilities.
///
/// - `needsPostEvent`: auto-paste synthesizes ⌘V (`CGRequestPostEventAccess`) — now
///   REQUIRED in every build so a picked item lands at the cursor.
/// - `needsAccessibility`: an *active* `CGEventTap` (the ⌃+right-click gesture) needs
///   Accessibility trust. Only the full build installs the tap, so this mirrors
///   `CapabilitySet.gestureTrigger`.
public struct PermissionRequirements: Equatable, Sendable {
    public let needsPostEvent: Bool
    public let needsAccessibility: Bool

    public init(needsPostEvent: Bool, needsAccessibility: Bool) {
        self.needsPostEvent = needsPostEvent
        self.needsAccessibility = needsAccessibility
    }

    /// Requirements for a build with the given capabilities: PostEvent is always
    /// required; Accessibility only when the gesture tap is enabled (full build).
    public static func forCapabilities(_ capabilities: CapabilitySet) -> PermissionRequirements {
        PermissionRequirements(needsPostEvent: true,
                               needsAccessibility: capabilities.gestureTrigger)
    }
}

/// Pure decision logic for the launch-time permission prompt — no platform calls, so
/// it is fully unit-testable (the `AppController` feeds it the live TCC probes).
public enum PermissionPolicy {
    /// Should we prompt the user at launch? Prompt when any REQUIRED permission is not
    /// yet granted; never nag for a permission this build does not need.
    public static func shouldPrompt(
        postEventGranted: Bool,
        axTrusted: Bool,
        requirements: PermissionRequirements
    ) -> Bool {
        if requirements.needsPostEvent && !postEventGranted { return true }
        if requirements.needsAccessibility && !axTrusted { return true }
        return false
    }
}
