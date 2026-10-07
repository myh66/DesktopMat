import AppKit
import Metal

/// Creates the same original composition for a GPU albedo and its gallery tile.
/// Fibre lighting, pile direction and moving fringe stay in the cloth shader.
@MainActor
enum RugTextureFactory {
    static func make(device: any MTLDevice, style: RugStyle) throws -> any MTLTexture {
        let width = 2048, height = 1408
        guard let context = makeContext(width: width, height: height),
              let data = context.data else { throw RugRenderingError.textureAllocation }
        draw(style: style, in: context, width: width, height: height)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false
        )
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw RugRenderingError.textureAllocation
        }
        texture.label = "\(style.displayName) · original woven pattern"
        texture.replace(
            region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
            withBytes: data, bytesPerRow: width * 4
        )
        return texture
    }

    static func preview(style: RugStyle) -> NSImage {
        let width = 600, height = 412
        guard let context = makeContext(width: width, height: height) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        draw(style: style, in: context, width: width, height: height)
        guard let image = context.makeImage() else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        return NSImage(cgImage: image, size: NSSize(width: width, height: height))
    }

    private static func makeContext(width: Int, height: Int) -> CGContext? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue
        )
    }

    private static func draw(style: RugStyle, in context: CGContext, width: Int, height: Int) {
        context.saveGState()
        context.scaleBy(x: CGFloat(width) / 1000, y: CGFloat(height) / 688)
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        switch style {
        case .ningxia: NingxiaTexture.draw(in: context)
        case .songBrocade: TextilePatterns.songBrocade(context)
        case .inkLandscape: TextilePatterns.inkLandscape(context)
        case .seaCliff: TextilePatterns.seaCliff(context)
        case .cinnabar: TextilePatterns.cinnabar(context)
        case .hiddenPanda: TextilePatterns.hiddenPanda(context)
        }
        // Deterministic, tiny irregularities in the yarn, rather than a flat fill.
        // The low contrast lets the changing Metal light reveal the thicker pile.
        TextilePatterns.woolGrain(context)
        context.restoreGState()
    }
}
