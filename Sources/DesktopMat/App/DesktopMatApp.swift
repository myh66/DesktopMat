import AppKit

@main
enum DesktopMatApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) {
            application.finishLaunching()
            delegate.startIfNeeded()
            application.run()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var desktop: DesktopManager?
    private var menuBar: MenuBarController?
    private var hasStarted = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        startIfNeeded()
    }

    func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        if ProcessInfo.processInfo.arguments.contains("--replace") {
            let ownPID = ProcessInfo.processInfo.processIdentifier
            NSRunningApplication.runningApplications(withBundleIdentifier: "com.yixi.desktopmat")
                .filter { $0.processIdentifier != ownPID }.forEach { $0.terminate() }
        }
        do {
            let preferences = RugPreferences(defaults: Self.diagnosticsPath == nil ? .standard : UserDefaults(suiteName: "com.yixi.desktopmat.verification")!)
            if ProcessInfo.processInfo.arguments.contains("--show") { preferences.isVisible = true }
            let desktop = DesktopManager(preferences: preferences)
            self.desktop = desktop
            try desktop.start()
            menuBar = MenuBarController(desktop: desktop)
            if Self.diagnosticsPath == nil && ProcessInfo.processInfo.arguments.contains("--gallery") {
                menuBar?.showGallery()
            }

            if let path = Self.diagnosticsPath {
                Task { @MainActor in
                    // Allow the WindowServer and first Metal frame to finish.
                    try? await Task.sleep(for: .milliseconds(800))
                    let passed = await RuntimeVerification.run(desktop: desktop, outputDirectory: path)
                    desktop.stop()
                    exit(passed ? 0 : 1)
                }
            }
        } catch {
            if Self.diagnosticsPath != nil {
                print("Desktop Mat startup failed: \(error.localizedDescription)")
                desktop?.stop()
                exit(1)
            }
            let alert = NSAlert()
            alert.messageText = "一席暂时无法铺开地毯"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.addButton(withTitle: "退出")
            alert.runModal()
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        desktop?.stop()
    }

    private static var diagnosticsPath: URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "--verify"), arguments.indices.contains(index + 1) else { return nil }
        return URL(fileURLWithPath: arguments[index + 1], isDirectory: true)
    }
}
