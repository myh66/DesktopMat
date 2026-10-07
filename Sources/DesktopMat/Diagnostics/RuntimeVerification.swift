import AppKit
import RugEngine
import simd

@MainActor
enum RuntimeVerification {
    struct Check: Codable {
        let name: String
        let passed: Bool
        let detail: String
    }
    struct WindowRecord: Codable {
        let id: Int
        let owner: String
        let ownerPID: Int
        let layer: Int
        let onScreen: Bool
    }
    struct Report: Codable {
        let version: String
        let operatingSystem: String
        let desktopIconLevel: Int
        let rugLevel: Int
        let normalLevel: Int
        let displayCount: Int
        let renderers: [RugRendererDiagnostics]
        let checks: [Check]
        let relevantWindows: [WindowRecord]
        let scope: String
    }

    static func run(desktop: DesktopManager, outputDirectory: URL) async -> Bool {
        var checks: [Check] = []
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let normalWindow = desktop.showVerificationWindow(activate: false)
            normalWindow?.displayIfNeeded()
            try await Task.sleep(for: .milliseconds(350))
            let windows = windowRecords()
            let ownIDs = Set(desktop.panels.values.map(\.windowNumber))
            let finderPID = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first?.processIdentifier
            let finder = windows.filter { $0.ownerPID == Int(finderPID ?? -1) && $0.layer == DesktopLayer.icons }
            let overlays = windows.filter { ownIDs.contains($0.id) }
            checks.append(Check(name: "WindowServer desktop ordering",
                passed: !overlays.isEmpty && overlays.count == desktop.panels.count && overlays.allSatisfy { $0.layer == DesktopLayer.rug }
                    && !finder.isEmpty && windows.contains { $0.id == normalWindow?.windowNumber && $0.layer == DesktopLayer.normal },
                detail: "Finder \(DesktopLayer.icons) < \(overlays.map(\.layer)) < normal \(DesktopLayer.normal)"))
            checks.append(Check(name: "Nonactivating full-display panels",
                passed: desktop.panels.count == NSScreen.screens.count && desktop.panels.values.allSatisfy {
                    !$0.canBecomeKey && !$0.canBecomeMain && !$0.isOpaque && !$0.hasShadow
                }, detail: "\(desktop.panels.count) transparent panels; input uses the current cloth silhouette"))

            guard let panel = desktop.panels.values.first else { return false }
            let surface = panel.surface
            let initialMesh = surface.snapshotMesh
            let initialStyle = desktop.selectedStyle
            for style in RugStyle.allCases {
                try desktop.setStyle(style)
                checks.append(pixelCheck("Preset GPU frame: \(style.rawValue)",
                    try surface.captureSnapshot(to: outputDirectory.appendingPathComponent("preset-\(style.rawValue).png"), scale: 1)))
            }
            let shapePreserved = zip(initialMesh.vertices, surface.snapshotMesh.vertices).allSatisfy { $0.position == $1.position }
            checks.append(Check(name: "Style selection preserves cloth on all displays",
                passed: shapePreserved && desktop.selectedStyle == RugStyle.allCases.last
                    && desktop.panels.values.allSatisfy { $0.surface.style == desktop.selectedStyle },
                detail: "All six original materials loaded; changing texture preserves particle positions and updates every display"))
            try desktop.setStyle(initialStyle)
            let initialCenter = centroid(initialMesh)
            let center = CGPoint(x: CGFloat(initialCenter.x), y: CGFloat(initialCenter.y))
            checks.append(Check(name: "Mesh input coverage",
                passed: surface.containsRug(at: center) && !surface.containsRug(at: CGPoint(x: 8, y: 8)),
                detail: "Cloth interior is hit; transparent display corner is not"))

            // In-process native responder fixtures verify dispatch ownership;
            // they do not synthesize OS events or substitute for real UI drag tests.
            let down = NSEvent.mouseEvent(with: .leftMouseDown, location: panel.input.convert(center, to: nil),
                modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 1, clickCount: 1, pressure: 1)!
            panel.input.mouseDown(with: down)
            let owned = surface.isDragging && desktop.mouseTracking.activeGrab != nil
                && !panel.ignoresMouseEvents && desktop.panels.values.filter { $0 !== panel }.allSatisfy(\.ignoresMouseEvents)
            let up = NSEvent.mouseEvent(with: .leftMouseUp, location: down.locationInWindow,
                modifierFlags: [], timestamp: down.timestamp + 0.01, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 2, clickCount: 1, pressure: 0)!
            panel.input.mouseUp(with: up)
            checks.append(Check(name: "Native responder drag ownership",
                passed: owned && !surface.isDragging && desktop.mouseTracking.activeGrab == nil,
                detail: "One native view owns the gesture; mouse-up clears engine grab and cross-display ownership"))

            let started = surface.beginGrab(at: center, corner: false)
            surface.updateGrab(target: CGPoint(x: center.x - 180, y: center.y + 65), lift: 24)
            try await Task.sleep(for: .milliseconds(1100))
            let moved = simd_distance(centroid(surface.snapshotMesh), initialCenter)
            checks.append(Check(name: "Live local cloth drag", passed: started && moved > 45 && finite(surface.snapshotMesh),
                detail: "Mesh centroid followed by \(Int(moved)) pt through XPBD constraints"))
            let areaRatio = projectedArea(surface.snapshotMesh) / projectedArea(initialMesh)
            let reversed = surface.snapshotMesh.vertices.filter { $0.normal.z < -0.1 }.count
            checks.append(Check(name: "Ordinary drag retains rug body",
                passed: areaRatio > 0.70 && reversed < initialMesh.vertexCount / 5,
                detail: "Projected triangle area \(Int(areaRatio * 100))% of rest; \(reversed) downward-facing vertices"))
            checks.append(pixelCheck("Dragged GPU frame",
                try surface.captureSnapshot(to: outputDirectory.appendingPathComponent("cloth-drag.png"), scale: 1)))
            surface.endGrab()
            try await Task.sleep(for: .milliseconds(650))

            let flatMesh = surface.snapshotMesh
            let cornerPosition = RugProjection.screenPoint(flatMesh.vertices.last!.position)
            let corner = CGPoint(x: CGFloat(cornerPosition.x), y: CGFloat(cornerPosition.y))
            let lifted = surface.beginGrab(at: corner, corner: true)
            surface.updateGrab(target: CGPoint(x: corner.x - 145, y: corner.y - 100), lift: 180)
            try await Task.sleep(for: .milliseconds(1100))
            let peak = surface.maximumHeight
            let normalTilt = surface.snapshotMesh.vertices.map { simd_length(SIMD2($0.normal.x, $0.normal.y)) }.max() ?? 0
            checks.append(Check(name: "Three-dimensional corner lift",
                passed: lifted && peak > 100 && normalTilt > 0.25 && finite(surface.snapshotMesh),
                detail: "Height \(Int(peak)) pt; maximum normal tilt \(normalTilt)"))
            checks.append(pixelCheck("Folded GPU frame",
                try surface.captureSnapshot(to: outputDirectory.appendingPathComponent("cloth-lift.png"), scale: 1)))
            let exposed = flatMesh.vertices.filter { vertex in
                let point = RugProjection.screenPoint(vertex.position)
                return !surface.containsRug(at: CGPoint(x: CGFloat(point.x), y: CGFloat(point.y)))
            }.count
            checks.append(Check(name: "Fold changes projected hit region", passed: exposed > 10,
                detail: "\(exposed) previously covered mesh sample points are now outside cloth triangles"))
            surface.endGrab()
            try await Task.sleep(for: .milliseconds(2400))
            let landed = surface.maximumHeight
            checks.append(Check(name: "Gravity release", passed: !surface.isDragging && landed < peak * 0.65 && finite(surface.snapshotMesh),
                detail: "Peak \(Int(peak)) pt decreased to \(Int(landed)) pt after release"))
            checks.append(pixelCheck("Released GPU frame",
                try surface.captureSnapshot(to: outputDirectory.appendingPathComponent("cloth-rest.png"), scale: 1)))
            desktop.resetPosition()

            let report = Report(version: "0.3.0-presets-cloth", operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
                desktopIconLevel: DesktopLayer.icons, rugLevel: DesktopLayer.rug, normalLevel: DesktopLayer.normal,
                displayCount: desktop.panels.count, renderers: desktop.panels.values.map { $0.surface.rendererDiagnostics }, checks: checks,
                relevantWindows: windows.filter { ownIDs.contains($0.id) || $0.id == normalWindow?.windowNumber || $0.ownerPID == Int(finderPID ?? -1) },
                scope: "Native responder fixtures, live XPBD simulation, projected mesh hit testing and real Metal output. OS mouse dispatch and desktop composite require separate UI inspection. No Finder files or wallpaper are read or changed.")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(report)
            try data.write(to: outputDirectory.appendingPathComponent("cloth-verification.json"), options: .atomic)
            print(String(decoding: data, as: UTF8.self))
            return checks.allSatisfy(\.passed)
        } catch {
            print("Cloth verification failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func centroid(_ mesh: RugMesh) -> SIMD2<Float> {
        mesh.vertices.reduce(SIMD2<Float>.zero) { $0 + RugProjection.screenPoint($1.position) } / Float(mesh.vertexCount)
    }
    private static func finite(_ mesh: RugMesh) -> Bool {
        mesh.vertices.allSatisfy { $0.position.x.isFinite && $0.position.y.isFinite && $0.position.z.isFinite }
    }
    private static func projectedArea(_ mesh: RugMesh) -> Float {
        var area: Float = 0
        for index in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
            let a = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[index])].position)
            let b = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[index + 1])].position)
            let c = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[index + 2])].position)
            let u = b - a, v = c - a
            area += abs(u.x * v.y - u.y * v.x) * 0.5
        }
        return area
    }
    private static func pixelCheck(_ name: String, _ coverage: RugSnapshotDiagnostics) -> Check {
        Check(name: name, passed: coverage.opaquePixelCount > 20_000 && coverage.cornerIsTransparent && coverage.invalidPremultipliedPixelCount == 0,
            detail: "\(coverage.opaquePixelCount) opaque, \(coverage.transparentPixelCount) transparent, \(coverage.invalidPremultipliedPixelCount) invalid premultiplied pixels")
    }
    private static func windowRecords() -> [WindowRecord] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return [] }
        return list.compactMap { entry in
            guard let id = entry[kCGWindowNumber as String] as? Int,
                  let owner = entry[kCGWindowOwnerName as String] as? String,
                  let layer = entry[kCGWindowLayer as String] as? Int else { return nil }
            return WindowRecord(id: id, owner: owner,
                ownerPID: entry[kCGWindowOwnerPID as String] as? Int ?? -1, layer: layer,
                onScreen: entry[kCGWindowIsOnscreen as String] as? Bool ?? false)
        }
    }
}
