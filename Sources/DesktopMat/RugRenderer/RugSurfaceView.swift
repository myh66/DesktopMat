import AppKit
import ImageIO
import Metal
import MetalKit
import QuartzCore
import RugEngine
import UniformTypeIdentifiers
import simd

enum RugRenderingError: LocalizedError {
    case unavailableMetal
    case missingShader
    case missingShaderFunction
    case commandQueueAllocation
    case meshAllocation
    case textureAllocation
    case renderEncoderAllocation
    case snapshotAllocation
    case snapshotWrite

    var errorDescription: String? {
        switch self {
        case .unavailableMetal: "This Mac does not expose a Metal device."
        case .missingShader: "The application bundle is missing Rug.metal."
        case .missingShaderFunction: "The rug shader functions are unavailable."
        case .commandQueueAllocation: "Metal could not create a rendering queue."
        case .meshAllocation: "Metal could not allocate the rug mesh."
        case .textureAllocation: "Metal could not allocate the wool material."
        case .renderEncoderAllocation: "Metal could not begin rendering the rug."
        case .snapshotAllocation: "Metal could not allocate the snapshot."
        case .snapshotWrite: "The rendered snapshot could not be saved."
        }
    }
}

struct RugRendererDiagnostics: Codable {
    let style: String
    let device: String
    let renderBackend: String
    let vertexCount: Int
    let triangleCount: Int
    let gridColumns: Int
    let gridRows: Int
    let albedoWidth: Int
    let albedoHeight: Int
    let shaderBundlePath: String
    let livePhysics: Bool
    let transparentBackground: Bool
}

struct RugSnapshotDiagnostics: Codable {
    let transparentPixelCount: Int
    let opaquePixelCount: Int
    let invalidPremultipliedPixelCount: Int
    let centerIsOpaque: Bool
    let cornerIsTransparent: Bool
}

// SIMD3 occupies 16 bytes in both Swift and Metal. The last fields occupy its
// existing trailing alignment, yielding a 48-byte dynamic vertex.
private struct RugGPUVertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
    var uv: SIMD2<Float>
    var occlusion: Float
    var pileDirection: Float
}

private struct RugUniforms {
    var viewport: SIMD2<Float>
    var rugSize: SIMD2<Float>
    var backingScale: Float
    var material: UInt32
    var shadowOffset: SIMD2<Float> = .zero
}

/// A native, transparent full-display Metal surface. The cloth positions live
/// in view-local points; renderer, grabbing and mouse passthrough share exactly
/// the same height projection and current triangles.
@MainActor
final class RugSurfaceView: MTKView {
    static let recommendedSize = CGSize(width: 760, height: 560)
    private var renderer: RugMetalRenderer!
    var onSimulationSettled: (() -> Void)?

    var rendererDiagnostics: RugRendererDiagnostics { renderer.diagnostics }
    var snapshotMesh: RugMesh { renderer.cloth.mesh }
    var rugSize: CGSize { renderer.rugSize }
    var isDragging: Bool { renderer.cloth.isDragging }
    var maximumHeight: Float { renderer.cloth.maximumHeight }
    var style: RugStyle { renderer.style }

    func prepareStyle(_ style: RugStyle) throws -> any MTLTexture {
        try renderer.prepareStyle(style)
    }

    func applyStyle(_ style: RugStyle, texture: any MTLTexture) {
        renderer.applyStyle(style, texture: texture)
        setNeedsDisplay(bounds)
    }

    init(frame: CGRect, metalDevice: (any MTLDevice)? = MTLCreateSystemDefaultDevice()) throws {
        // NSView must finish its designated initialization before a throwing
        // Metal setup; otherwise AppKit deallocation masks the actual error.
        super.init(frame: frame, device: metalDevice)
        guard let device = metalDevice else { throw RugRenderingError.unavailableMetal }
        renderer = try RugMetalRenderer(device: device, center: CGPoint(x: frame.width / 2, y: frame.height / 2))
        colorPixelFormat = .bgra8Unorm
        depthStencilPixelFormat = .depth32Float
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        clearDepth = 1
        framebufferOnly = true
        preferredFramesPerSecond = 120
        isPaused = true
        enableSetNeedsDisplay = true
        autoResizeDrawable = true
        sampleCount = 1
        delegate = renderer
        wantsLayer = true
        layer?.isOpaque = false
        if let metalLayer = layer as? CAMetalLayer {
            metalLayer.isOpaque = false
            metalLayer.backgroundColor = NSColor.clear.cgColor
            metalLayer.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        }
    }

    required init(coder: NSCoder) { fatalError("RugSurfaceView is created programmatically.") }
    override var isOpaque: Bool { false }

    func pauseRendering() {
        isPaused = true
        enableSetNeedsDisplay = true
    }

    func resumeRendering() {
        if renderer.cloth.isSettled {
            setNeedsDisplay(bounds)
        } else {
            wakeSimulation()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        preferredFramesPerSecond = min(120, max(60, window?.screen?.maximumFramesPerSecond ?? 60))
    }

    func resetRug(center: CGPoint, size: CGSize = CGSize(width: 640, height: 440)) {
        renderer.reset(center: center, size: size)
        wakeSimulation()
    }

    func containsRug(at point: CGPoint) -> Bool {
        let p = SIMD2<Float>(Float(point.x), Float(point.y))
        let mesh = renderer.cloth.mesh
        // Bounds are only an early reject; folded/lifted openings are decided
        // by actual projected triangles, never by the original rectangle.
        guard renderer.projectedBounds.insetBy(dx: -1, dy: -1).contains(point) else { return false }
        for index in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
            let a = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[index])].position)
            let b = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[index + 1])].position)
            let c = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[index + 2])].position)
            if Self.contains(p, triangle: (a, b, c)) { return true }
        }
        return false
    }

    func nearestCorner(at point: CGPoint, radius: CGFloat = 55) -> Bool {
        let p = SIMD2<Float>(Float(point.x), Float(point.y))
        let mesh = renderer.cloth.mesh
        let corners = [0, mesh.columns, mesh.rows * (mesh.columns + 1), mesh.vertexCount - 1]
        return corners.contains { simd_distance(RugProjection.screenPoint(mesh.vertices[$0].position), p) <= Float(radius) }
    }

    @discardableResult
    func beginGrab(at point: CGPoint, corner: Bool) -> Bool {
        let started = renderer.cloth.beginGrab(at: SIMD2(Float(point.x), Float(point.y)), corner: corner)
        if started { wakeSimulation() }
        return started
    }

    func updateGrab(target: CGPoint, lift: Float) {
        renderer.cloth.updateGrab(target: SIMD2(Float(target.x), Float(target.y)), lift: lift)
        wakeSimulation()
    }

    func endGrab() {
        renderer.cloth.endGrab()
        wakeSimulation()
    }

    private func wakeSimulation() {
        if isPaused { renderer.resumeClock() }
        enableSetNeedsDisplay = false
        isPaused = false
    }

    fileprivate func simulationDidSettle() {
        isPaused = true
        enableSetNeedsDisplay = true
        onSimulationSettled?()
    }

    private static func contains(_ p: SIMD2<Float>, triangle: (SIMD2<Float>, SIMD2<Float>, SIMD2<Float>)) -> Bool {
        let (a, b, c) = triangle
        func cross(_ u: SIMD2<Float>, _ v: SIMD2<Float>) -> Float { u.x * v.y - u.y * v.x }
        let area = cross(b - a, c - a)
        guard abs(area) > 0.0001 else { return false }
        let u = cross(b - p, c - p) / area
        let v = cross(c - p, a - p) / area
        return u >= -0.0001 && v >= -0.0001 && u + v <= 1.0001
    }

    /// Synchronous offscreen diagnostics do not require Screen Recording access.
    @discardableResult
    func captureSnapshot(to url: URL, scale: CGFloat = 2) throws -> RugSnapshotDiagnostics {
        try renderer.captureSnapshot(to: url, size: bounds.size, scale: scale)
    }
}

@MainActor
private final class RugMetalRenderer: NSObject, MTKViewDelegate {
    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private let shadowDepth: any MTLDepthStencilState
    private let fabricDepth: any MTLDepthStencilState
    private let indexBuffer: any MTLBuffer
    private var albedo: any MTLTexture
    private(set) var style: RugStyle = .ningxia
    private let shaderBundlePath: String
    var cloth: RugCloth
    private(set) var rugSize = CGSize(width: 640, height: 440)
    private var lastFrameTime: CFTimeInterval?
    private var accumulator: Float = 0
    private var settledFrames = 0

    var diagnostics: RugRendererDiagnostics {
        RugRendererDiagnostics(
            style: style.rawValue,
            device: device.name, renderBackend: "Metal / PBD cloth mesh / normal lighting / projected contact shadows",
            vertexCount: cloth.mesh.vertexCount, triangleCount: cloth.mesh.triangleCount,
            gridColumns: cloth.mesh.columns, gridRows: cloth.mesh.rows,
            albedoWidth: albedo.width, albedoHeight: albedo.height,
            shaderBundlePath: shaderBundlePath,
            livePhysics: true, transparentBackground: true
        )
    }

    var projectedBounds: CGRect {
        var lower = SIMD2<Float>(repeating: .greatestFiniteMagnitude)
        var upper = SIMD2<Float>(repeating: -.greatestFiniteMagnitude)
        for vertex in cloth.mesh.vertices {
            let p = RugProjection.screenPoint(vertex.position)
            lower = simd_min(lower, p)
            upper = simd_max(upper, p)
        }
        return CGRect(x: CGFloat(lower.x), y: CGFloat(lower.y), width: CGFloat(upper.x - lower.x), height: CGFloat(upper.y - lower.y))
    }

    init(device: any MTLDevice, center: CGPoint) throws {
        self.device = device
        guard let queue = device.makeCommandQueue() else { throw RugRenderingError.commandQueueAllocation }
        commandQueue = queue
        cloth = RugCloth(size: SIMD2(640, 440), center: SIMD2(Float(center.x), Float(center.y)))
        let mesh = cloth.mesh
        guard let indices = device.makeBuffer(bytes: mesh.triangleIndices, length: mesh.triangleIndices.count * MemoryLayout<UInt32>.stride, options: .storageModeShared) else {
            throw RugRenderingError.meshAllocation
        }
        indexBuffer = indices
        indexBuffer.label = "Cloth triangle topology"
        albedo = try RugTextureFactory.make(device: device, style: .ningxia)

        let packagedBundle = Bundle.main.resourceURL
            .map { $0.appendingPathComponent("DesktopMat_DesktopMat.bundle", isDirectory: true) }
            .flatMap { Bundle(url: $0) }
        let shaderBundle = packagedBundle ?? Bundle.module
        shaderBundlePath = shaderBundle.bundleURL.path
        guard let shaderURL = shaderBundle.url(forResource: "Rug", withExtension: "metal", subdirectory: "Shaders") else {
            throw RugRenderingError.missingShader
        }
        let source = try String(contentsOf: shaderURL, encoding: .utf8)
        let options = MTLCompileOptions()
        options.mathMode = .fast
        let library = try device.makeLibrary(source: source, options: options)
        guard let vertex = library.makeFunction(name: "rug_vertex"),
              let fragment = library.makeFunction(name: "rug_fragment") else { throw RugRenderingError.missingShaderFunction }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Premultiplied transparent dynamic wool material"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let shadowDescriptor = MTLDepthStencilDescriptor()
        shadowDescriptor.depthCompareFunction = .always
        shadowDescriptor.isDepthWriteEnabled = false
        let fabricDescriptor = MTLDepthStencilDescriptor()
        fabricDescriptor.depthCompareFunction = .lessEqual
        fabricDescriptor.isDepthWriteEnabled = true
        guard let shadowDepth = device.makeDepthStencilState(descriptor: shadowDescriptor),
              let fabricDepth = device.makeDepthStencilState(descriptor: fabricDescriptor) else { throw RugRenderingError.meshAllocation }
        self.shadowDepth = shadowDepth
        self.fabricDepth = fabricDepth
        super.init()
    }

    func reset(center: CGPoint, size: CGSize) {
        rugSize = size
        cloth.reset(center: SIMD2(Float(center.x), Float(center.y)), size: SIMD2(Float(size.width), Float(size.height)))
        resumeClock()
    }

    func prepareStyle(_ style: RugStyle) throws -> any MTLTexture {
        if style == self.style { return albedo }
        return try RugTextureFactory.make(device: device, style: style)
    }

    func applyStyle(_ style: RugStyle, texture: any MTLTexture) {
        albedo = texture
        self.style = style
    }

    func resumeClock() {
        lastFrameTime = nil
        accumulator = 0
        settledFrames = 0
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let time = CACurrentMediaTime()
        let elapsed = min(Float(lastFrameTime.map { time - $0 } ?? (1.0 / 120.0)), 1.0 / 30.0)
        lastFrameTime = time
        accumulator += max(0, elapsed)
        let fixedStep: Float = 1.0 / 120.0
        while accumulator >= fixedStep {
            cloth.step(deltaTime: fixedStep)
            accumulator -= fixedStep
        }
        settledFrames = cloth.isSettled && !cloth.isDragging ? settledFrames + 1 : 0
        if settledFrames >= 3 { (view as? RugSurfaceView)?.simulationDidSettle() }
        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let command = commandQueue.makeCommandBuffer() else { return }
        do {
            try encode(into: command, pass: pass, pixelSize: view.drawableSize, logicalSize: view.bounds.size)
        } catch {
            NSLog("Desktop Mat render failed: %@", error.localizedDescription)
            return
        }
        command.present(drawable)
        command.commit()
    }

    private func surfaceVertices() -> [RugGPUVertex] {
        let mesh = cloth.mesh
        let width = mesh.columns + 1
        return mesh.vertices.indices.map { index in
            let vertex = mesh.vertices[index]
            let row = index / width, column = index % width
            var neighborHeight: Float = 0
            var neighborCount: Float = 0
            for (x, y) in [(column - 1, row), (column + 1, row), (column, row - 1), (column, row + 1)] {
                if let adjacent = mesh.vertexIndex(column: x, row: y) {
                    neighborHeight += mesh.vertices[adjacent].position.z
                    neighborCount += 1
                }
            }
            let hollow = max(0, neighborHeight / max(1, neighborCount) - vertex.position.z)
            let crease = 1 - abs(vertex.normal.z)
            let occlusion = max(0.47, 1 - hollow * 0.034 - crease * 0.16)
            return RugGPUVertex(position: vertex.position, normal: vertex.normal,
                                uv: vertex.textureCoordinate, occlusion: occlusion,
                                pileDirection: vertex.normal.x * 0.7 + vertex.normal.y * 0.3)
        }
    }

    /// Individual fringe strands attach to each deformed short edge. Positions
    /// and edge tangents follow the current solver, including lifted corners.
    private func fringeVertices() -> [RugGPUVertex] {
        let mesh = cloth.mesh
        var result: [RugGPUVertex] = []
        let strandCount = max(2, Int(rugSize.height / 2.2))
        result.reserveCapacity(strandCount * 12)
        for side in [0, mesh.columns] {
            for strand in 0..<strandCount {
                let t = (Float(strand) + 0.5) / Float(strandCount)
                let rowPosition = t * Float(mesh.rows)
                let row = min(mesh.rows - 1, Int(rowPosition))
                let fraction = rowPosition - Float(row)
                let a = mesh.vertices[row * (mesh.columns + 1) + side]
                let b = mesh.vertices[(row + 1) * (mesh.columns + 1) + side]
                let adjacentColumn = side == 0 ? 1 : mesh.columns - 1
                let inwardA = mesh.vertices[row * (mesh.columns + 1) + adjacentColumn]
                let inwardB = mesh.vertices[(row + 1) * (mesh.columns + 1) + adjacentColumn]
                var base = simd_mix(a.position, b.position, SIMD3(repeating: fraction))
                let inward = simd_mix(inwardA.position, inwardB.position, SIMD3(repeating: fraction))
                let normal = simd_normalize(simd_mix(a.normal, b.normal, SIMD3(repeating: fraction)))
                let tangent = simd_normalize(b.position - a.position)
                let outwardDelta = base - inward
                let outward = simd_length_squared(outwardDelta) > 0.0001 ? simd_normalize(outwardDelta) : SIMD3<Float>(side == 0 ? -1 : 1, 0, 0)
                let random = sin(Float(strand) * 17.31 + Float(side) * 2.47) * 0.5 + 0.5
                let length: Float = 10.5 + random * 5.5
                base += normal * 0.26
                // Short wool fibers droop as an edge rises off the desktop.
                var end = base + outward * length + tangent * sin(Float(strand) * 4.71) * 0.48
                end.z = max(0.12, end.z - min(base.z * 0.18, 4.5))
                let halfWidth: Float = 0.46
                let uv = SIMD2<Float>(Float(side) / Float(mesh.columns), t)
                let p0 = RugGPUVertex(position: base - tangent * halfWidth, normal: normal, uv: uv, occlusion: 0.92, pileDirection: random)
                let p1 = RugGPUVertex(position: base + tangent * halfWidth, normal: normal, uv: uv, occlusion: 0.92, pileDirection: random)
                let p2 = RugGPUVertex(position: end - tangent * halfWidth * 0.35, normal: normal, uv: uv, occlusion: 0.92, pileDirection: random)
                let p3 = RugGPUVertex(position: end + tangent * halfWidth * 0.35, normal: normal, uv: uv, occlusion: 0.92, pileDirection: random)
                result.append(contentsOf: [p0, p1, p2, p1, p3, p2])
            }
        }
        return result
    }

    private func encode(into command: any MTLCommandBuffer, pass: MTLRenderPassDescriptor, pixelSize: CGSize, logicalSize: CGSize) throws {
        let vertices = surfaceVertices()
        let fringe = fringeVertices()
        // Each command owns fresh immutable vertex data. No CPU writes can race
        // a preceding frame still reading its Metal buffer.
        guard let vertexBuffer = device.makeBuffer(bytes: vertices, length: vertices.count * MemoryLayout<RugGPUVertex>.stride, options: .storageModeShared),
              let fringeBuffer = device.makeBuffer(bytes: fringe, length: fringe.count * MemoryLayout<RugGPUVertex>.stride, options: .storageModeShared),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else {
            throw RugRenderingError.renderEncoderAllocation
        }
        vertexBuffer.label = "Immutable cloth vertices for this frame"
        fringeBuffer.label = "Deformed wool fringe for this frame"
        var uniforms = RugUniforms(
            viewport: SIMD2(Float(pixelSize.width), Float(pixelSize.height)),
            rugSize: SIMD2(Float(rugSize.width), Float(rugSize.height)),
            backingScale: Float(pixelSize.width / max(logicalSize.width, 1)), material: 0
        )
        encoder.setRenderPipelineState(pipeline)
        encoder.setCullMode(.none)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setFragmentTexture(albedo, index: 0)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setDepthStencilState(shadowDepth)
        // Nine small area-light samples make a soft shadow of the *deformed*
        // footprint. Elevated sections spread and weaken; floor contact darkens.
        for offset in [SIMD2<Float>(0, 0), SIMD2(1, 0), SIMD2(-1, 0), SIMD2(0, 1), SIMD2(0, -1), SIMD2(0.707, 0.707), SIMD2(-0.707, 0.707), SIMD2(0.707, -0.707), SIMD2(-0.707, -0.707)] {
            uniforms.material = 0
            uniforms.shadowOffset = offset
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<RugUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<RugUniforms>.stride, index: 1)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: cloth.mesh.triangleIndices.count, indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }
        encoder.setDepthStencilState(fabricDepth)
        uniforms.material = 2
        uniforms.shadowOffset = .zero
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<RugUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<RugUniforms>.stride, index: 1)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: cloth.mesh.triangleIndices.count, indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
        uniforms.material = 1
        encoder.setVertexBuffer(fringeBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&uniforms, length: MemoryLayout<RugUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<RugUniforms>.stride, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: fringe.count)
        encoder.endEncoding()
    }

    func captureSnapshot(to url: URL, size: CGSize, scale: CGFloat) throws -> RugSnapshotDiagnostics {
        let width = max(1, Int(size.width * scale)), height = max(1, Int(size.height * scale))
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = [.renderTarget, .shaderRead]
        let depthDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: width, height: height, mipmapped: false)
        depthDescriptor.storageMode = .private
        depthDescriptor.usage = .renderTarget
        guard let texture = device.makeTexture(descriptor: descriptor),
              let depth = device.makeTexture(descriptor: depthDescriptor),
              let command = commandQueue.makeCommandBuffer() else { throw RugRenderingError.snapshotAllocation }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        pass.depthAttachment.texture = depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.storeAction = .dontCare
        pass.depthAttachment.clearDepth = 1
        try encode(into: command, pass: pass, pixelSize: CGSize(width: width, height: height), logicalSize: size)
        command.commit()
        command.waitUntilCompleted()
        if let error = command.error { throw error }
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        texture.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        var transparent = 0, opaque = 0, invalid = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = pixels[offset + 3]
            if alpha == 0 { transparent += 1 }
            if alpha == 255 { opaque += 1 }
            if pixels[offset] > alpha || pixels[offset + 1] > alpha || pixels[offset + 2] > alpha { invalid += 1 }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let image = CGImage(
                width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
              ), let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw RugRenderingError.snapshotWrite
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RugRenderingError.snapshotWrite }
        return RugSnapshotDiagnostics(transparentPixelCount: transparent, opaquePixelCount: opaque,
            invalidPremultipliedPixelCount: invalid,
            centerIsOpaque: pixels[((height / 2) * width + width / 2) * 4 + 3] == 255,
            cornerIsTransparent: pixels[3] == 0)
    }
}
