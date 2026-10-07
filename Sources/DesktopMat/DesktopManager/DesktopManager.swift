import AppKit

@MainActor
final class DesktopManager: NSObject {
    private let preferences: RugPreferences
    private(set) var panels: [CGDirectDisplayID: DesktopOverlayPanel] = [:]
    var onStateChange: (() -> Void)?
    private var verificationWindow: NSWindow?
    private(set) var lastError: String?
    let mouseTracking = MouseTrackingManager()

    init(preferences: RugPreferences) {
        self.preferences = preferences
        super.init()
    }

    var isVisible: Bool { preferences.isVisible }
    var selectedStyle: RugStyle { preferences.style }

    func setStyle(_ style: RugStyle) throws {
        // Prepare every display before committing the change. A failed texture
        // allocation leaves all live rugs and persisted preference unchanged.
        let prepared = try panels.values.map { panel in
            (panel, try panel.surface.prepareStyle(style))
        }
        for (panel, texture) in prepared { panel.surface.applyStyle(style, texture: texture) }
        preferences.style = style
        onStateChange?()
    }

    func start() throws {
        try synchronizeDisplays()
        mouseTracking.start()
        NotificationCenter.default.addObserver(self, selector: #selector(displayConfigurationChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func stop() {
        NotificationCenter.default.removeObserver(self)
        mouseTracking.stop()
        panels.values.forEach { $0.close() }
        panels.removeAll()
        verificationWindow?.close()
    }

    func toggleVisibility() {
        preferences.isVisible.toggle()
        applyVisibility()
        onStateChange?()
    }

    func resetPosition() {
        mouseTracking.cancelActiveGrab()
        for screen in NSScreen.screens {
            guard let id = Self.displayID(screen), let panel = panels[id] else { continue }
            Self.resetRug(in: panel, on: screen)
        }
    }

    @objc private func displayConfigurationChanged(_ notification: Notification) {
        do {
            try synchronizeDisplays()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            NSLog("Desktop Mat display reconfiguration: %@", error.localizedDescription)
        }
        onStateChange?()
    }

    private func synchronizeDisplays() throws {
        mouseTracking.cancelActiveGrab()
        let screens = NSScreen.screens
        let activeIDs = Set(screens.compactMap(Self.displayID))
        for id in Array(panels.keys) where !activeIDs.contains(id) {
            panels.removeValue(forKey: id)?.close()
        }
        for screen in screens {
            guard let id = Self.displayID(screen) else { continue }
            let frame = Self.defaultFrame(on: screen)
            if let panel = panels[id] {
                panel.setFrame(frame, display: true)
            } else {
                panels[id] = try DesktopOverlayPanel(frame: frame)
            }
            if let panel = panels[id] {
                Self.resetRug(in: panel, on: screen)
                let texture = try panel.surface.prepareStyle(selectedStyle)
                panel.surface.applyStyle(selectedStyle, texture: texture)
            }
        }
        mouseTracking.updatePanels(panels)
        applyVisibility()
    }

    private func applyVisibility() {
        mouseTracking.setSuspended(!isVisible)
        for panel in panels.values {
            if isVisible {
                panel.show()
            } else {
                panel.surface.pauseRendering()
                panel.orderOut(nil)
            }
        }
    }

    static func displayID(_ screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }

    static func defaultFrame(on screen: NSScreen) -> CGRect {
        screen.frame
    }

    private static func resetRug(in panel: DesktopOverlayPanel, on screen: NSScreen) {
        let available = screen.visibleFrame.insetBy(dx: 24, dy: 24)
        let nominal = CGSize(width: 760, height: 560)
        let factor = min(1, available.width / nominal.width, available.height / nominal.height)
        let size = CGSize(width: nominal.width * factor, height: nominal.height * factor)
        let center = CGPoint(x: available.maxX - size.width / 2 - screen.frame.minX,
                             y: available.midY - screen.frame.minY)
        panel.surface.resetRug(center: center, size: CGSize(width: 640 * factor, height: 440 * factor))
        panel.surface.preferredFramesPerSecond = min(120, max(60, screen.maximumFramesPerSecond))
    }

    /// A real, normal-level native window for repeatable foreground-occlusion verification.
    @discardableResult
    func showVerificationWindow(activate: Bool = true) -> NSWindow? {
        guard let panel = panels.values.first else { return nil }
        if let existing = verificationWindow {
            if activate { NSApp.activate(ignoringOtherApps: true) }
            existing.makeKeyAndOrderFront(nil)
            return existing
        }
        let size = CGSize(width: 420, height: 260)
        let mesh = panel.surface.snapshotMesh
        let count = CGFloat(max(1, mesh.vertices.count))
        let rugCenter = mesh.vertices.reduce(CGPoint.zero) { CGPoint(x: $0.x + CGFloat($1.position.x) / count,
                                                                   y: $0.y + CGFloat($1.position.y) / count) }
        let frame = CGRect(x: panel.frame.minX + rugCenter.x - size.width / 2,
                           y: panel.frame.minY + rugCenter.y - size.height / 2, width: size.width, height: size.height)
        let window = NSWindow(contentRect: frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "一席 · 窗口层级检查"
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.contentView = LayerVerificationView(frame: NSRect(origin: .zero, size: size))
        verificationWindow = window
        if activate { NSApp.activate(ignoringOtherApps: true) }
        window.makeKeyAndOrderFront(nil)
        return window
    }
}
