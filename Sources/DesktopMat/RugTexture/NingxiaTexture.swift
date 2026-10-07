import AppKit
import Metal

/// Original vector weaving pattern. It is rasterized directly to GPU memory at
/// startup; lighting, yarn breakup, edges and fringe remain shader materials.
@MainActor
enum NingxiaTexture {
    private static let ivory = NSColor(red: 0.86, green: 0.82, blue: 0.71, alpha: 1)
    private static let field = NSColor(red: 0.89, green: 0.86, blue: 0.78, alpha: 1)
    private static let indigo = NSColor(red: 0.12, green: 0.20, blue: 0.28, alpha: 1)
    private static let fadedBlue = NSColor(red: 0.30, green: 0.39, blue: 0.44, alpha: 1)
    private static let paleBlue = NSColor(red: 0.67, green: 0.71, blue: 0.68, alpha: 1)
    private static let cinnabar = NSColor(red: 0.49, green: 0.27, blue: 0.20, alpha: 1)

    static func make(device: any MTLDevice) throws -> any MTLTexture {
        try RugTextureFactory.make(device: device, style: .ningxia)
    }

    /// Draws in a 1000 × 688 point coordinate system for both Metal and gallery.
    static func draw(in context: CGContext) {
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.setFillColor(indigo.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 1000, height: 688))

        // Binding, guard stripes, and a restrained continuous meander border.
        fill(context, rect: CGRect(x: 8, y: 8, width: 984, height: 672), color: ivory)
        fill(context, rect: CGRect(x: 14, y: 14, width: 972, height: 660), color: indigo)
        stroke(context, rect: CGRect(x: 25, y: 25, width: 950, height: 638), color: fadedBlue, width: 2)
        stroke(context, rect: CGRect(x: 33, y: 33, width: 934, height: 622), color: ivory, width: 2.4)
        fill(context, rect: CGRect(x: 88, y: 88, width: 824, height: 512), color: ivory)
        fill(context, rect: CGRect(x: 94, y: 94, width: 812, height: 500), color: indigo)
        fill(context, rect: CGRect(x: 98, y: 98, width: 804, height: 492), color: field)
        stroke(context, rect: CGRect(x: 111, y: 111, width: 778, height: 466), color: fadedBlue, width: 1.2)
        stroke(context, rect: CGRect(x: 118, y: 118, width: 764, height: 452), color: paleBlue, width: 2)

        context.setStrokeColor(ivory.cgColor)
        context.setLineWidth(3.0)
        context.setLineCap(.square)
        context.setLineJoin(.miter)
        for index in 0..<22 {
            let x = 50 + CGFloat(index) * 42
            meander(context, origin: CGPoint(x: x, y: 51), size: 25, quarterTurns: 0)
            meander(context, origin: CGPoint(x: x, y: 637), size: 25, quarterTurns: 2)
        }
        for index in 0..<14 {
            let y = 66 + CGFloat(index) * 42
            meander(context, origin: CGPoint(x: 51, y: y), size: 25, quarterTurns: 1)
            meander(context, origin: CGPoint(x: 949, y: y), size: 25, quarterTurns: 3)
        }
        // Tiny knots of warm pigment interrupt the indigo without dominating it.
        for point in [CGPoint(x: 64, y: 64), CGPoint(x: 936, y: 64), CGPoint(x: 64, y: 624), CGPoint(x: 936, y: 624)] {
            context.setFillColor(cinnabar.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
        }

        // An eight-lobed cloud medallion with a lotus drawn into its center.
        context.saveGState()
        context.translateBy(x: 500, y: 344)
        medallion(context)
        context.restoreGState()

        // Mirrored clouds and trailing stems leave generous unpatterned wool.
        let cloudPositions: [(CGFloat, CGFloat, CGFloat)] = [
            (235, 207, 0), (765, 207, .pi), (235, 481, 0), (765, 481, .pi)
        ]
        for (x, y, angle) in cloudPositions {
            context.saveGState()
            context.translateBy(x: x, y: y)
            context.rotate(by: angle)
            context.scaleBy(x: 0.78, y: 0.78)
            cloud(context, color: fadedBlue)
            context.restoreGState()
        }
        for (x, y, angle) in [(CGFloat(500), CGFloat(168), CGFloat(0)), (500, 520, CGFloat.pi)] {
            context.saveGState()
            context.translateBy(x: x, y: y)
            context.rotate(by: angle)
            context.scaleBy(x: 0.48, y: 0.48)
            cloud(context, color: fadedBlue)
            context.restoreGState()
        }
        for (x, y) in [(CGFloat(148), CGFloat(143)), (852, 143), (148, 545), (852, 545)] {
            context.setFillColor(fadedBlue.cgColor)
            let knot = CGMutablePath()
            knot.move(to: CGPoint(x: x, y: y - 5))
            knot.addLine(to: CGPoint(x: x + 5, y: y))
            knot.addLine(to: CGPoint(x: x, y: y + 5))
            knot.addLine(to: CGPoint(x: x - 5, y: y))
            knot.closeSubpath()
            context.addPath(knot)
            context.fillPath()
        }

    }

    private static func fill(_ context: CGContext, rect: CGRect, color: NSColor) {
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    private static func stroke(_ context: CGContext, rect: CGRect, color: NSColor, width: CGFloat) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.stroke(rect)
    }

    private static func meander(_ context: CGContext, origin: CGPoint, size: CGFloat, quarterTurns: Int) {
        context.saveGState()
        context.translateBy(x: origin.x, y: origin.y)
        context.rotate(by: CGFloat(quarterTurns) * .pi / 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size / 2, y: -size / 2))
        path.addLines(between: [
            CGPoint(x: size / 2, y: -size / 2), CGPoint(x: size / 2, y: size / 2),
            CGPoint(x: -size / 2, y: size / 2), CGPoint(x: -size / 2, y: -size / 8),
            CGPoint(x: size / 8, y: -size / 8), CGPoint(x: size / 8, y: size / 8)
        ])
        context.addPath(path)
        context.strokePath()
        context.restoreGState()
    }

    private static func cloud(_ context: CGContext, color: NSColor) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(3.6)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        let outline = CGMutablePath()
        outline.move(to: CGPoint(x: -70, y: -11))
        outline.addCurve(to: CGPoint(x: -50, y: 21), control1: CGPoint(x: -91, y: 5), control2: CGPoint(x: -73, y: 29))
        outline.addCurve(to: CGPoint(x: -21, y: 36), control1: CGPoint(x: -56, y: 47), control2: CGPoint(x: -27, y: 54))
        outline.addCurve(to: CGPoint(x: 24, y: 37), control1: CGPoint(x: -21, y: 68), control2: CGPoint(x: 25, y: 67))
        outline.addCurve(to: CGPoint(x: 58, y: 20), control1: CGPoint(x: 52, y: 53), control2: CGPoint(x: 75, y: 32))
        outline.addCurve(to: CGPoint(x: 77, y: -9), control1: CGPoint(x: 82, y: 26), control2: CGPoint(x: 92, y: 0))
        outline.addCurve(to: CGPoint(x: 40, y: -12), control1: CGPoint(x: 62, y: -23), control2: CGPoint(x: 48, y: -17))
        outline.addCurve(to: CGPoint(x: 5, y: -39), control1: CGPoint(x: 28, y: -6), control2: CGPoint(x: 25, y: -34))
        outline.addCurve(to: CGPoint(x: -48, y: -27), control1: CGPoint(x: -29, y: -46), control2: CGPoint(x: -32, y: -14))
        outline.addCurve(to: CGPoint(x: -70, y: -11), control1: CGPoint(x: -52, y: -42), control2: CGPoint(x: -80, y: -37))
        context.addPath(outline)
        context.strokePath()

        let inner = CGMutablePath()
        inner.move(to: CGPoint(x: -64, y: 0))
        inner.addCurve(to: CGPoint(x: -35, y: 11), control1: CGPoint(x: -57, y: 19), control2: CGPoint(x: -42, y: 17))
        inner.addCurve(to: CGPoint(x: -7, y: 20), control1: CGPoint(x: -40, y: 34), control2: CGPoint(x: -14, y: 39))
        inner.addCurve(to: CGPoint(x: 9, y: 22), control1: CGPoint(x: -13, y: 4), control2: CGPoint(x: 18, y: 6))
        inner.addCurve(to: CGPoint(x: 39, y: 8), control1: CGPoint(x: 10, y: 42), control2: CGPoint(x: 40, y: 28))
        inner.addCurve(to: CGPoint(x: 66, y: 1), control1: CGPoint(x: 43, y: -8), control2: CGPoint(x: 61, y: -10))
        inner.move(to: CGPoint(x: -32, y: -17))
        inner.addCurve(to: CGPoint(x: 30, y: -19), control1: CGPoint(x: -5, y: -4), control2: CGPoint(x: 3, y: -35))
        inner.move(to: CGPoint(x: -23, y: -48))
        inner.addCurve(to: CGPoint(x: 52, y: -58), control1: CGPoint(x: 11, y: -55), control2: CGPoint(x: 22, y: -70))
        inner.addCurve(to: CGPoint(x: 66, y: -46), control1: CGPoint(x: 76, y: -50), control2: CGPoint(x: 82, y: -61))
        context.setLineWidth(2.4)
        context.addPath(inner)
        context.strokePath()
    }

    private static func medallion(_ context: CGContext) {
        let outline = CGMutablePath()
        let radius: CGFloat = 125
        for segment in 0..<64 {
            let angle = CGFloat(segment) / 64 * 2 * .pi
            let r = radius + 11 * cos(angle * 8)
            let point = CGPoint(x: r * cos(angle), y: r * sin(angle))
            if segment == 0 { outline.move(to: point) } else { outline.addLine(to: point) }
        }
        outline.closeSubpath()
        context.setFillColor(paleBlue.cgColor)
        context.addPath(outline)
        context.fillPath()
        context.setStrokeColor(indigo.cgColor)
        context.setLineWidth(4)
        context.addPath(outline)
        context.strokePath()
        context.saveGState()
        context.scaleBy(x: 0.91, y: 0.91)
        context.setStrokeColor(ivory.cgColor)
        context.setLineWidth(2.8)
        context.addPath(outline)
        context.strokePath()
        context.restoreGState()

        for petal in 0..<8 {
            context.saveGState()
            context.rotate(by: CGFloat(petal) * .pi / 4)
            let shape = CGMutablePath()
            shape.move(to: CGPoint(x: 0, y: 14))
            shape.addCurve(to: CGPoint(x: 0, y: 93), control1: CGPoint(x: -38, y: 39), control2: CGPoint(x: -18, y: 72))
            shape.addCurve(to: CGPoint(x: 0, y: 14), control1: CGPoint(x: 19, y: 72), control2: CGPoint(x: 35, y: 36))
            shape.closeSubpath()
            context.setFillColor(field.cgColor)
            context.setStrokeColor(fadedBlue.cgColor)
            context.setLineWidth(2.0)
            context.addPath(shape)
            context.drawPath(using: .fillStroke)
            let vein = CGMutablePath()
            vein.move(to: CGPoint(x: 0, y: 30))
            vein.addCurve(to: CGPoint(x: 0, y: 73), control1: CGPoint(x: -7, y: 48), control2: CGPoint(x: 7, y: 58))
            context.setLineWidth(1.3)
            context.addPath(vein)
            context.strokePath()
            context.restoreGState()
        }
        context.setFillColor(indigo.cgColor)
        context.fillEllipse(in: CGRect(x: -20, y: -20, width: 40, height: 40))
        context.setFillColor(ivory.cgColor)
        context.fillEllipse(in: CGRect(x: -13, y: -13, width: 26, height: 26))
        context.setFillColor(cinnabar.cgColor)
        context.fillEllipse(in: CGRect(x: -4, y: -4, width: 8, height: 8))
    }
}
