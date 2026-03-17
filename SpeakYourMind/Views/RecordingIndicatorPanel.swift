import AppKit
import SwiftUI

/// Subtle non-activating panel showing a small pulsing red dot while instant-recording.
/// Positioned near the menu bar icon. Never steals focus. Click-through. Visible on all Spaces.
final class RecordingIndicatorPanel: NSPanel {

    /// Reference to the status item button for positioning
    weak var statusItemButton: NSStatusBarButton?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 16, height: 16),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isReleasedWhenClosed = false

        contentView = NSHostingView(rootView: RecordingIndicatorView())
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show() {
        positionNearStatusItem()
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    /// Positions the panel near the menu bar status item
    private func positionNearStatusItem() {
        guard let button = statusItemButton,
              let buttonWindow = button.window,
              let screen = NSScreen.main else {
            // Fallback to top-right of screen
            positionTopRight()
            return
        }

        // Get the button's frame in screen coordinates
        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = buttonWindow.convertToScreen(buttonFrame)

        // Position the dot just above and to the right of the status item
        let panelX = screenFrame.maxX - frame.width - 2
        let panelY = screenFrame.maxY + 2

        setFrameOrigin(NSPoint(x: panelX, y: panelY))
    }

    /// Fallback positioning: top-right of screen
    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - 8
        let y = screenFrame.maxY - frame.height - 4
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Indicator SwiftUI View

private struct RecordingIndicatorView: View {
    @State private var isPulsing = false

    var body: some View {
        Circle()
            .fill(Color.red)
            .frame(width: 10, height: 10)
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}