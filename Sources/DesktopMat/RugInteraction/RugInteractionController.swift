import AppKit

@MainActor
final class RugInteractionController {
    weak var panel: DesktopOverlayPanel?
    weak var tracking: MouseTrackingManager?
    private var initialPoint = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var lastTimestamp: TimeInterval = 0
    private var cornerGrab = false
    private(set) var lastDragEventTime: TimeInterval = 0

    init(panel: DesktopOverlayPanel, tracking: MouseTrackingManager) {
        self.panel = panel
        self.tracking = tracking
        panel.input.onMouseDown = { [weak self] in self?.mouseDown($0) }
        panel.input.onMouseDragged = { [weak self] in self?.mouseDragged($0) }
        panel.input.onMouseUp = { [weak self] in self?.mouseUp($0) }
    }

    var isDragging: Bool { panel?.surface.isDragging ?? false }

    func localPoint(fromScreen point: CGPoint) -> CGPoint? {
        guard let panel else { return nil }
        return panel.input.convert(panel.convertPoint(fromScreen: point), from: nil)
    }

    private func mouseDown(_ event: NSEvent) {
        guard let panel, let tracking, tracking.activeGrab == nil else { return }
        let point = panel.input.convert(event.locationInWindow, from: nil)
        guard panel.surface.containsRug(at: point) else { return }
        let corner = panel.surface.nearestCorner(at: point, radius: 60)
        guard panel.surface.beginGrab(at: point, corner: corner) else { return }
        initialPoint = point
        lastPoint = point
        lastTimestamp = event.timestamp
        cornerGrab = corner
        lastDragEventTime = ProcessInfo.processInfo.systemUptime
        tracking.claimGrab(self)
        NSCursor.closedHand.set()
        panel.invalidateCursorRects(for: panel.input)
    }

    private func mouseDragged(_ event: NSEvent) {
        guard let panel, tracking?.activeGrab === self, isDragging else { return }
        let point = panel.input.convert(event.locationInWindow, from: nil)
        let delta = hypot(point.x - lastPoint.x, point.y - lastPoint.y)
        let dt = max(1.0 / 240.0, event.timestamp - lastTimestamp)
        let speed = delta / dt
        let travel = hypot(point.x - initialPoint.x, point.y - initialPoint.y)
        let lift: Float = cornerGrab
            ? Float(min(240, 12 + travel * 0.62))
            : Float(min(44, 9 + speed * 0.010))
        panel.surface.updateGrab(target: point, lift: lift)
        lastPoint = point
        lastTimestamp = event.timestamp
        lastDragEventTime = ProcessInfo.processInfo.systemUptime
        NSCursor.closedHand.set()
    }

    private func mouseUp(_ event: NSEvent) { finishGrab() }

    func finishGrab() {
        // Always release ownership, including reset/disconnect paths where the
        // weak panel vanished or resetRug already cleared the engine grab.
        if let panel, panel.surface.isDragging { panel.surface.endGrab() }
        tracking?.releaseGrab(self)
        if let panel {
            panel.invalidateCursorRects(for: panel.input)
            if NSWindow.windowNumber(at: NSEvent.mouseLocation, belowWindowWithWindowNumber: 0) == panel.windowNumber {
                NSCursor.openHand.set()
            }
        }
    }
}
