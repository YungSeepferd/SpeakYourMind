import AppKit
import SwiftUI

/// Tiny non-activating panel that shows a pulsing red dot while instant-recording.
/// Never steals focus. Click-through. Visible on all Spaces.
final class RecordingIndicatorPanel: NSPanel {

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 140, height: 44),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .statusBar
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isReleasedWhenClosed = false

        contentView = NSHostingView(rootView: RecordingIndicatorView())

        positionTopRight()
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show() {
        positionTopRight()
        orderFrontRegardless()
    }

    func hide() {
        orderOut(nil)
    }

    private func positionTopRight() {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.maxX - frame.width - 16
        let y = screenFrame.maxY - frame.height - 8
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Indicator SwiftUI View

private struct RecordingIndicatorView: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .scaleEffect(pulse ? 1.3 : 1.0)
                .opacity(pulse ? 0.7 : 1.0)
                .animation(
                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: pulse
                )

            Text("Recording…")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .onAppear { pulse = true }
    }
}