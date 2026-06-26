import Foundation
import Testing
import CoreGraphics
@testable import ActunaCopyPasteUI

@Suite("PanelAnchor")
struct PanelAnchorTests {
    private let size = CGSize(width: 320, height: 420)

    @Test("Anchors the top-left at the cursor on a roomy screen")
    func anchorsAtCursor() {
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1400)
        let frame = PanelAnchor.anchoredFrame(panelSize: size, mouse: CGPoint(x: 500, y: 1000), screen: screen)
        #expect(frame.origin.x == CGFloat(500))
        #expect(frame.origin.y == CGFloat(580)) // top edge at the cursor: 1000 - 420
    }

    @Test("Flips to the left of the cursor at the right edge")
    func flipsAtRightEdge() {
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1400)
        let frame = PanelAnchor.anchoredFrame(panelSize: size, mouse: CGPoint(x: 1950, y: 1000), screen: screen)
        #expect(frame.origin.x == CGFloat(1630)) // 1950 - 320
        #expect(frame.maxX <= screen.maxX)
    }

    @Test("Clamps to the bottom edge inset")
    func clampsAtBottomEdge() {
        let screen = CGRect(x: 0, y: 0, width: 2000, height: 1400)
        let frame = PanelAnchor.anchoredFrame(panelSize: size, mouse: CGPoint(x: 500, y: 100), screen: screen, edgeInset: 8)
        #expect(frame.origin.y == CGFloat(8))
    }

    @Test("Clamps to the left edge on a screen with a negative origin")
    func negativeOriginScreen() {
        // Second display to the left of the main one. Cursor near its left edge so
        // the default placement would run off the left → expect a clamp to minX + inset.
        let screen = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let frame = PanelAnchor.anchoredFrame(panelSize: size, mouse: CGPoint(x: -1915, y: 1000), screen: screen, edgeInset: 8)
        #expect(frame.origin.x == CGFloat(-1912)) // screen.minX + inset
        #expect(frame.minX >= screen.minX)
        #expect(frame.maxX <= screen.maxX)
    }
}
