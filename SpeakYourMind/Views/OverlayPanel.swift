import AppKit

/// Floating panel for the overlay mode — user interacts with buttons/text editor.
/// Appears centered like Spotlight. Steals focus intentionally.
final class OverlayPanel: NSPanel {

    init(contentRect: NSRect = NSRect(x: 0, y: 0, width: 400, height: 300)) {
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isMovableByWindowBackground = true
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.97)
        isReleasedWhenClosed = false

        // Constrain minimum window size so controls never clip
        minSize = NSSize(width: 320, height: 140)
        maxSize = NSSize(width: 800, height: 900)

        center()

        // Allow Esc to close
        let esc = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.orderOut(nil)
                return nil
            }
            return event
        }
        _ = esc // keep monitor alive as long as panel lives
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}