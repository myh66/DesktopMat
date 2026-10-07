import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let desktop: DesktopManager
    private let statusItem: NSStatusItem
    private let visibilityItem = NSMenuItem()
    private let stateItem = NSMenuItem()
    private var styleItems: [RugStyle: NSMenuItem] = [:]
    private lazy var gallery = RugGalleryController(desktop: desktop)

    init(desktop: DesktopManager) {
        self.desktop = desktop
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.image = Self.rugSymbol()
        statusItem.button?.toolTip = "一席 · Desktop Mat"
        statusItem.button?.setAccessibilityLabel("一席桌面地毯菜单")

        let menu = NSMenu(title: "一席")
        let title = NSMenuItem(title: "一席 · Desktop Mat", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        stateItem.isEnabled = false
        menu.addItem(stateItem)
        menu.addItem(.separator())
        visibilityItem.action = #selector(toggleVisibility)
        visibilityItem.target = self
        menu.addItem(visibilityItem)
        let stylesItem = NSMenuItem(title: "地毯纹样", action: nil, keyEquivalent: "")
        let stylesMenu = NSMenu(title: "地毯纹样")
        for style in RugStyle.allCases {
            let choice = item(style.displayName, action: #selector(selectStyle(_:)))
            choice.representedObject = style.rawValue
            stylesMenu.addItem(choice)
            styleItems[style] = choice
        }
        stylesItem.submenu = stylesMenu
        menu.addItem(stylesItem)
        menu.addItem(item("地毯画廊…", action: #selector(showGallery)))
        menu.addItem(item("重置地毯位置", action: #selector(resetPosition)))
        menu.addItem(item("检查窗口层级…", action: #selector(checkLayers)))
        menu.addItem(.separator())
        menu.addItem(item("关于一席…", action: #selector(showAbout)))
        menu.addItem(item("退出一席", action: #selector(quit), key: "q"))
        statusItem.menu = menu
        desktop.onStateChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func refresh() {
        visibilityItem.title = desktop.isVisible ? "隐藏地毯" : "显示地毯"
        stateItem.title = desktop.lastError.map { "显示器错误：\($0)" }
            ?? "\(desktop.selectedStyle.displayName) · \(desktop.panels.count) 个显示器"
        for (style, item) in styleItems { item.state = style == desktop.selectedStyle ? .on : .off }
        gallery.syncSelection()
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleVisibility() { desktop.toggleVisibility() }
    @objc func showGallery() { gallery.show() }
    @objc private func selectStyle(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let style = RugStyle(rawValue: id) else { return }
        gallery.apply(style)
    }
    @objc private func resetPosition() { desktop.resetPosition() }
    @objc private func checkLayers() { desktop.showVerificationWindow() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "一席 · Desktop Mat"
        alert.informativeText = "0.3.0 · MIT 开源\n\n一张铺在桌面上的地毯，六种原创纹样。\n\n抓住中部自由拖动，抓住四角附近向内拖动可掀起。松手后布料自然回落。\n\n地毯外与露出的区域穿透鼠标。地毯只遮挡画面，不读取、移动或修改桌面文件。"
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private static func rugSymbol() -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { _ in
            NSColor.black.setStroke()
            let body = NSBezierPath(roundedRect: NSRect(x: 3.5, y: 4.5, width: 13, height: 11), xRadius: 1, yRadius: 1)
            body.lineWidth = 1.2
            body.stroke()
            let roll = NSBezierPath(ovalIn: NSRect(x: 3.5, y: 12.5, width: 13, height: 3))
            roll.lineWidth = 1
            roll.stroke()
            let fringe = NSBezierPath()
            for x in stride(from: 5.0, through: 15.0, by: 2.5) {
                fringe.move(to: NSPoint(x: x, y: 4.5))
                fringe.line(to: NSPoint(x: x, y: 2.5))
            }
            fringe.lineWidth = 1
            fringe.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }
}
