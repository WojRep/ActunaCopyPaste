import CoreGraphics

/// Pure geometry for the cursor-anchored history panel. All coordinates are in
/// AppKit's bottom-left-origin global space — the space shared by
/// `NSEvent.mouseLocation` and `NSScreen.frame`, so the controller feeds those in
/// directly. Extracted as a free function so the clamping rules are unit-tested
/// without instantiating any AppKit window.
public enum PanelAnchor {

    /// Places the panel with its top-left corner at the cursor, then keeps the
    /// whole panel on `screen` (minus `edgeInset`): flips to the left of the cursor
    /// if it would overflow the right edge, and nudges within the top/bottom edges.
    public static func anchoredFrame(
        panelSize: CGSize,
        mouse: CGPoint,
        screen: CGRect,
        edgeInset: CGFloat = 8
    ) -> CGRect {
        let w = panelSize.width
        let h = panelSize.height

        var x = mouse.x
        if x + w > screen.maxX - edgeInset {
            x = mouse.x - w // flip to the left of the cursor
        }
        x = clamp(x, low: screen.minX + edgeInset, high: screen.maxX - edgeInset - w)

        // Bottom-left origin: the panel's TOP edge sits at the cursor.
        var y = mouse.y - h
        y = clamp(y, low: screen.minY + edgeInset, high: screen.maxY - edgeInset - h)

        return CGRect(x: x, y: y, width: w, height: h)
    }

    private static func clamp(_ value: CGFloat, low: CGFloat, high: CGFloat) -> CGFloat {
        // `high < low` only when the panel is larger than the screen; pin to `low`.
        max(low, min(value, high))
    }
}
