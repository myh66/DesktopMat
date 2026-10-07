import AppKit

/// One input owner across all displays. Mouse monitors observe only: they do
/// not synthesize, swallow or replay clicks delivered to another application.
@MainActor
final class MouseTrackingManager: NSObject {
    private var controllers: [CGDirectDisplayID: RugInteractionController] = [:]
    private(set) var activeGrab: RugInteractionController?
    private var timer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var suspended = false
    private weak var hoverCandidate: RugInteractionController?

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 120.0, target: self, selector: #selector(poll), userInfo: nil, repeats: true)
        timer.tolerance = 0.001
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            MainActor.assumeIsolated {
                if event.type == .leftMouseUp { self?.activeGrab?.finishGrab() }
                self?.refreshPassthrough()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated { self?.refreshPassthrough() }
            return event
        }
    }

    func updatePanels(_ panels: [CGDirectDisplayID: DesktopOverlayPanel]) {
        for id in Array(controllers.keys) where panels[id] !== controllers[id]?.panel {
            controllers.removeValue(forKey: id)?.finishGrab()
        }
        for (id, panel) in panels where controllers[id] == nil {
            controllers[id] = RugInteractionController(panel: panel, tracking: self)
        }
        refreshPassthrough()
    }

    func setSuspended(_ value: Bool) {
        suspended = value
        if value { cancelActiveGrab() }
        refreshPassthrough()
    }

    func cancelActiveGrab() { activeGrab?.finishGrab() }

    func claimGrab(_ controller: RugInteractionController) {
        guard activeGrab == nil else { return }
        activeGrab = controller
        refreshPassthrough()
    }

    func releaseGrab(_ controller: RugInteractionController) {
        guard activeGrab === controller else { return }
        activeGrab = nil
        refreshPassthrough()
    }

    func stop() {
        cancelActiveGrab()
        timer?.invalidate()
        timer = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        controllers.values.forEach { $0.panel?.ignoresMouseEvents = true }
        controllers.removeAll()
        hoverCandidate = nil
    }

    @objc private func poll() {
        // A delayed fallback only. Device state must not race queued drag/up
        // events, which remain the authoritative source for grab ownership.
        if let activeGrab, NSEvent.pressedMouseButtons & 1 == 0,
           ProcessInfo.processInfo.systemUptime - activeGrab.lastDragEventTime > 0.15 {
            activeGrab.finishGrab()
        }
        refreshPassthrough()
    }

    private func refreshPassthrough() {
        let point = NSEvent.mouseLocation
        let buttonDown = NSEvent.pressedMouseButtons & 1 != 0
        if !buttonDown && activeGrab == nil {
            hoverCandidate = controllers.values.first { controller in
                guard let panel = controller.panel, panel.isVisible, panel.frame.contains(point),
                      let local = controller.localPoint(fromScreen: point) else { return false }
                return panel.surface.containsRug(at: local)
            }
        }
        for controller in controllers.values {
            guard let panel = controller.panel else { continue }
            if suspended || !panel.isVisible {
                panel.ignoresMouseEvents = true
            } else if let activeGrab {
                panel.ignoresMouseEvents = controller !== activeGrab
            } else if buttonDown {
                // Do not acquire someone else's Finder drag when it crosses
                // over the rug or enters a different display.
                panel.ignoresMouseEvents = controller !== hoverCandidate
            } else if let local = controller.localPoint(fromScreen: point), panel.frame.contains(point) {
                panel.ignoresMouseEvents = !panel.surface.containsRug(at: local)
            } else {
                panel.ignoresMouseEvents = true
            }
        }
    }
}
