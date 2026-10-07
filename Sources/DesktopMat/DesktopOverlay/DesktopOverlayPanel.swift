import AppKit
import CoreGraphics

/// Uses public system levels rather than hard-coded WindowServer numbers.
enum DesktopLayer {
    static var icons: Int { Int(CGWindowLevelForKey(.desktopIconWindow)) }
    static var rug: Int { icons + 1 }
    static var normal: Int { Int(CGWindowLevelForKey(.normalWindow)) }
}

@MainActor
final class DesktopOverlayPanel: NSPanel {
    private var storedSurface: RugSurfaceView?
    private var storedInput: RugInputView?
    var surface: RugSurfaceView { storedSurface! }
    var input: RugInputView { storedInput! }

    init(frame: NSRect) throws {
        super.init(contentRect: frame,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        storedSurface = try RugSurfaceView(frame: NSRect(origin: .zero, size: frame.size))
        storedInput = RugInputView(surface: surface)
        precondition(DesktopLayer.icons < DesktopLayer.rug && DesktopLayer.rug < DesktopLayer.normal)
        title = "一席 · Desktop Rug"
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // Shadow belongs to the material renderer.
        isFloatingPanel = false
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        canHide = false
        isReleasedWhenClosed = false
        isRestorable = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenNone]
        ignoresMouseEvents = true // Tracking enables only the current cloth silhouette.
        acceptsMouseMovedEvents = true
        isMovable = false
        contentView = input
        // NSPanel floating configuration can reset the WindowServer level.
        // Assign the desktop level after all panel/collection setup.
        level = NSWindow.Level(rawValue: DesktopLayer.rug)
        input.autoresizingMask = [.width, .height]
        setAccessibilityLabel("一席可拖动布料地毯")
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show() {
        orderFrontRegardless()
        surface.resumeRendering()
    }

    override func close() {
        storedSurface?.pauseRendering()
        super.close()
    }
}
