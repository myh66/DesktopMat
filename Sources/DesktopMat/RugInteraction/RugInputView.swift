import AppKit

/// The Metal view renders only. This native responder owns a complete drag
/// sequence, including events outside the current projected cloth silhouette.
@MainActor
final class RugInputView: NSView {
    let surface: RugSurfaceView
    var onMouseDown: ((NSEvent) -> Void)?
    var onMouseDragged: ((NSEvent) -> Void)?
    var onMouseUp: ((NSEvent) -> Void)?

    init(surface: RugSurfaceView) {
        self.surface = surface
        super.init(frame: surface.frame)
        surface.autoresizingMask = [.width, .height]
        addSubview(surface)
    }

    required init?(coder: NSCoder) { fatalError("RugInputView is created programmatically.") }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? {
        // Cross-application passthrough is decided on NSPanel before dispatch,
        // rather than trying to forward a received event to Finder.
        bounds.contains(point) ? self : nil
    }
    override func mouseDown(with event: NSEvent) { onMouseDown?(event) }
    override func mouseDragged(with event: NSEvent) { onMouseDragged?(event) }
    override func mouseUp(with event: NSEvent) { onMouseUp?(event) }
    override func mouseMoved(with event: NSEvent) {
        if surface.containsRug(at: convert(event.locationInWindow, from: nil)) {
            (surface.isDragging ? NSCursor.closedHand : NSCursor.openHand).set()
        }
    }
    override func resetCursorRects() {
        // Cursor feedback is installed on real delivered mouseMoved / drag
        // events. A full-screen cursor rect would include transparent holes.
    }
}
