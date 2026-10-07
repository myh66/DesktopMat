import AppKit

/// Original vector motifs inspired by textile structure, not copied rug images.
/// Coordinates use the same 1000 × 688 loom as the original Ningxia composition.
@MainActor
enum TextilePatterns {
    private static let bounds = CGRect(x: 0, y: 0, width: 1000, height: 688)

    static func songBrocade(_ c: CGContext) {
        let teal = color(0.13, 0.28, 0.28)
        let deep = color(0.08, 0.20, 0.21)
        let thread = color(0.67, 0.64, 0.48)
        let gold = color(0.47, 0.44, 0.31)
        let cream = color(0.82, 0.79, 0.68)
        fill(c, bounds, deep)
        fill(c, CGRect(x: 9, y: 9, width: 982, height: 670), cream)
        fill(c, CGRect(x: 14, y: 14, width: 972, height: 660), deep)
        stroke(c, CGRect(x: 28, y: 28, width: 944, height: 632), gold, 2)
        stroke(c, CGRect(x: 34, y: 34, width: 932, height: 620), cream, 1.4)
        fill(c, CGRect(x: 78, y: 78, width: 844, height: 532), cream)
        fill(c, CGRect(x: 82, y: 82, width: 836, height: 524), gold)
        fill(c, CGRect(x: 86, y: 86, width: 828, height: 516), teal)
        stroke(c, CGRect(x: 99, y: 99, width: 802, height: 490), thread, 1.2)

        // The border is a woven interlocking fret, distinct from Ningxia's meander.
        c.setLineCap(.square)
        for index in 0..<23 {
            let x = 49 + CGFloat(index) * 41
            diamond(c, center: CGPoint(x: x, y: 55), radius: 12, color: cream, width: 1.7)
            diamond(c, center: CGPoint(x: x, y: 633), radius: 12, color: cream, width: 1.7)
        }
        for index in 0..<15 {
            let y = 55 + CGFloat(index) * 41
            diamond(c, center: CGPoint(x: 55, y: y), radius: 12, color: cream, width: 1.7)
            diamond(c, center: CGPoint(x: 945, y: y), radius: 12, color: cream, width: 1.7)
        }

        c.saveGState()
        c.clip(to: CGRect(x: 105, y: 105, width: 790, height: 478))
        let pitch: CGFloat = 92
        for row in -1..<7 {
            for column in -1..<10 {
                let x = 132 + CGFloat(column) * pitch + (row.isMultiple(of: 2) ? 0 : pitch / 2)
                let y = 120 + CGFloat(row) * 81
                diamond(c, center: CGPoint(x: x, y: y), radius: 47, color: gold, width: 1.5)
                transform(c, x: x, y: y) {
                    flower(c, petals: 4, radius: 18, petalWidth: 8, fill: thread, outline: nil)
                    c.setFillColor(deep.cgColor)
                    c.fillEllipse(in: CGRect(x: -3, y: -3, width: 6, height: 6))
                    c.setStrokeColor(thread.withAlphaComponent(0.70).cgColor)
                    c.setLineWidth(1.2)
                    let vine = CGMutablePath()
                    vine.move(to: CGPoint(x: 0, y: 23))
                    vine.addCurve(to: CGPoint(x: 0, y: 54), control1: CGPoint(x: 24, y: 29), control2: CGPoint(x: -22, y: 48))
                    vine.move(to: CGPoint(x: 23, y: 0))
                    vine.addCurve(to: CGPoint(x: 46, y: 0), control1: CGPoint(x: 30, y: -15), control2: CGPoint(x: 38, y: 15))
                    c.addPath(vine)
                    c.strokePath()
                }
            }
        }
        c.restoreGState()
    }

    static func inkLandscape(_ c: CGContext) {
        let paper = color(0.87, 0.86, 0.82)
        let ink = color(0.27, 0.30, 0.31)
        let pale = color(0.71, 0.73, 0.70)
        fill(c, bounds, color(0.35, 0.37, 0.36))
        fill(c, CGRect(x: 7, y: 7, width: 986, height: 674), paper)
        stroke(c, CGRect(x: 22, y: 22, width: 956, height: 644), pale, 1.4)
        stroke(c, CGRect(x: 33, y: 33, width: 934, height: 622), pale.withAlphaComponent(0.60), 0.8)

        c.saveGState()
        c.clip(to: CGRect(x: 50, y: 50, width: 900, height: 588))
        // Long, quiet mountain silhouettes are graphic woven bands, with spacious
        // untouched wool above them; the composition has no central medallion.
        mountain(c, points: [
            CGPoint(x: 40, y: 324), CGPoint(x: 141, y: 396), CGPoint(x: 200, y: 347),
            CGPoint(x: 302, y: 430), CGPoint(x: 389, y: 366), CGPoint(x: 480, y: 419),
            CGPoint(x: 574, y: 370), CGPoint(x: 674, y: 444), CGPoint(x: 762, y: 385),
            CGPoint(x: 860, y: 438), CGPoint(x: 970, y: 348)
        ], floor: 184, color: color(0.72, 0.74, 0.71))
        mountain(c, points: [
            CGPoint(x: 40, y: 240), CGPoint(x: 148, y: 295), CGPoint(x: 213, y: 266),
            CGPoint(x: 322, y: 377), CGPoint(x: 401, y: 325), CGPoint(x: 487, y: 350),
            CGPoint(x: 604, y: 284), CGPoint(x: 688, y: 321), CGPoint(x: 782, y: 273),
            CGPoint(x: 891, y: 329), CGPoint(x: 970, y: 254)
        ], floor: 128, color: color(0.57, 0.60, 0.58))
        // Pale horizontal cloud bands partially obscure the mountains.
        fogBand(c, y: 274, left: 53, right: 947, depth: 22, color: paper.withAlphaComponent(0.80))
        fogBand(c, y: 347, left: 126, right: 907, depth: 12, color: paper.withAlphaComponent(0.76))
        mountain(c, points: [
            CGPoint(x: 40, y: 132), CGPoint(x: 112, y: 180), CGPoint(x: 194, y: 155),
            CGPoint(x: 276, y: 211), CGPoint(x: 355, y: 176), CGPoint(x: 459, y: 221),
            CGPoint(x: 564, y: 174), CGPoint(x: 654, y: 190), CGPoint(x: 738, y: 147),
            CGPoint(x: 839, y: 203), CGPoint(x: 970, y: 145)
        ], floor: 49, color: ink.withAlphaComponent(0.79))

        // A widening river threads through the dark foothills.
        let river = CGMutablePath()
        river.move(to: CGPoint(x: 541, y: 299))
        river.addCurve(to: CGPoint(x: 524, y: 240), control1: CGPoint(x: 507, y: 275), control2: CGPoint(x: 583, y: 255))
        river.addCurve(to: CGPoint(x: 480, y: 148), control1: CGPoint(x: 456, y: 205), control2: CGPoint(x: 575, y: 199))
        river.addCurve(to: CGPoint(x: 620, y: 49), control1: CGPoint(x: 411, y: 103), control2: CGPoint(x: 585, y: 89))
        river.addLine(to: CGPoint(x: 692, y: 49))
        river.addCurve(to: CGPoint(x: 505, y: 151), control1: CGPoint(x: 650, y: 97), control2: CGPoint(x: 449, y: 100))
        river.addCurve(to: CGPoint(x: 542, y: 241), control1: CGPoint(x: 594, y: 203), control2: CGPoint(x: 479, y: 207))
        river.addCurve(to: CGPoint(x: 547, y: 299), control1: CGPoint(x: 598, y: 262), control2: CGPoint(x: 516, y: 278))
        river.closeSubpath()
        c.setFillColor(paper.cgColor)
        c.addPath(river)
        c.fillPath()
        c.setStrokeColor(pale.cgColor)
        c.setLineWidth(0.8)
        for row in 0..<4 {
            let y = 487 + CGFloat(row) * 15
            let cloud = CGMutablePath()
            cloud.move(to: CGPoint(x: 200 + CGFloat(row) * 40, y: y))
            cloud.addCurve(to: CGPoint(x: 731 - CGFloat(row) * 32, y: y + 3), control1: CGPoint(x: 358, y: y + 15), control2: CGPoint(x: 502, y: y - 12))
            c.addPath(cloud)
            c.strokePath()
        }
        c.restoreGState()
    }

    static func seaCliff(_ c: CGContext) {
        let blue = color(0.11, 0.22, 0.32)
        let navy = color(0.07, 0.15, 0.23)
        let foam = color(0.72, 0.75, 0.70)
        let slate = color(0.39, 0.49, 0.54)
        fill(c, bounds, navy)
        fill(c, CGRect(x: 8, y: 8, width: 984, height: 672), foam)
        fill(c, CGRect(x: 13, y: 13, width: 974, height: 662), navy)
        stroke(c, CGRect(x: 27, y: 27, width: 946, height: 634), slate, 2)
        stroke(c, CGRect(x: 33, y: 33, width: 934, height: 622), foam, 1.4)
        fill(c, CGRect(x: 76, y: 76, width: 848, height: 536), foam)
        fill(c, CGRect(x: 81, y: 81, width: 838, height: 526), blue)
        stroke(c, CGRect(x: 93, y: 93, width: 814, height: 502), slate, 1.4)

        for row in 0..<2 {
            wave(c, x: 42, y: 48 + CGFloat(row) * 12, length: 916, amplitude: 4, pitch: 48, color: foam, width: 1.2)
            wave(c, x: 42, y: 628 + CGFloat(row) * 12, length: 916, amplitude: 4, pitch: 48, color: foam, width: 1.2)
        }
        transform(c, x: 52, y: 74, angle: .pi / 2) {
            wave(c, x: 0, y: 0, length: 540, amplitude: 4, pitch: 48, color: foam, width: 1.2)
        }
        transform(c, x: 948, y: 74, angle: .pi / 2) {
            wave(c, x: 0, y: 0, length: 540, amplitude: 4, pitch: 48, color: foam, width: 1.2)
        }

        c.saveGState()
        c.clip(to: CGRect(x: 103, y: 103, width: 794, height: 482))
        // Broad striated rocks, without any imperial robe or dragon composition.
        let rock = CGMutablePath()
        rock.addLines(between: [
            CGPoint(x: 327, y: 218), CGPoint(x: 373, y: 334), CGPoint(x: 428, y: 359),
            CGPoint(x: 476, y: 457), CGPoint(x: 524, y: 457), CGPoint(x: 574, y: 357),
            CGPoint(x: 627, y: 334), CGPoint(x: 673, y: 218)
        ])
        rock.closeSubpath()
        c.setFillColor(slate.cgColor)
        c.addPath(rock)
        c.fillPath()
        c.setStrokeColor(foam.withAlphaComponent(0.76).cgColor)
        c.setLineWidth(1.7)
        let strata = CGMutablePath()
        strata.addLines(between: [CGPoint(x: 355, y: 251), CGPoint(x: 402, y: 322), CGPoint(x: 449, y: 335), CGPoint(x: 493, y: 421)])
        strata.move(to: CGPoint(x: 424, y: 241))
        strata.addLines(between: [CGPoint(x: 461, y: 297), CGPoint(x: 493, y: 299), CGPoint(x: 511, y: 379)])
        strata.move(to: CGPoint(x: 564, y: 241))
        strata.addLines(between: [CGPoint(x: 548, y: 291), CGPoint(x: 573, y: 326), CGPoint(x: 538, y: 402)])
        strata.move(to: CGPoint(x: 635, y: 241))
        strata.addLines(between: [CGPoint(x: 602, y: 310), CGPoint(x: 568, y: 339)])
        c.addPath(strata)
        c.strokePath()
        for row in 0..<9 {
            let y = 112 + CGFloat(row) * 16
            wave(c, x: 100 - CGFloat(row % 2) * 22, y: y, length: 820, amplitude: 6 + CGFloat(row) * 0.8, pitch: 100, color: row.isMultiple(of: 3) ? foam : slate, width: row.isMultiple(of: 3) ? 2.0 : 1.1)
        }
        for (x, y, scale) in [(CGFloat(248), CGFloat(452), CGFloat(0.46)), (752, 452, 0.46), (500, 535, 0.34)] {
            transform(c, x: x, y: y, scale: scale) { cloud(c, color: foam, width: 3.0) }
        }
        c.restoreGState()
    }

    static func cinnabar(_ c: CGContext) {
        let red = color(0.52, 0.28, 0.25)
        let dark = color(0.33, 0.17, 0.18)
        let cream = color(0.86, 0.79, 0.66)
        let rose = color(0.67, 0.46, 0.39)
        fill(c, bounds, dark)
        fill(c, CGRect(x: 9, y: 9, width: 982, height: 670), cream)
        fill(c, CGRect(x: 14, y: 14, width: 972, height: 660), dark)
        stroke(c, CGRect(x: 29, y: 29, width: 942, height: 630), rose, 2)
        stroke(c, CGRect(x: 37, y: 37, width: 926, height: 614), cream, 1.6)
        fill(c, CGRect(x: 90, y: 90, width: 820, height: 508), cream)
        fill(c, CGRect(x: 95, y: 95, width: 810, height: 498), dark)
        fill(c, CGRect(x: 102, y: 102, width: 796, height: 484), red)
        stroke(c, CGRect(x: 113, y: 113, width: 774, height: 462), rose, 1.5)

        for index in 0..<22 {
            let x = 56 + CGFloat(index) * 42
            transform(c, x: x, y: 63) { flower(c, petals: 4, radius: 10, petalWidth: 3.5, fill: cream, outline: nil) }
            transform(c, x: x, y: 625) { flower(c, petals: 4, radius: 10, petalWidth: 3.5, fill: cream, outline: nil) }
        }
        for index in 0..<14 {
            let y = 72 + CGFloat(index) * 42
            transform(c, x: 63, y: y) { flower(c, petals: 4, radius: 10, petalWidth: 3.5, fill: cream, outline: nil) }
            transform(c, x: 937, y: y) { flower(c, petals: 4, radius: 10, petalWidth: 3.5, fill: cream, outline: nil) }
        }
        transform(c, x: 500, y: 344) {
            let star = CGMutablePath()
            for point in 0..<32 {
                let angle = CGFloat(point) * .pi / 16
                let radius: CGFloat = point.isMultiple(of: 2) ? 151 : 130
                let p = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                if point == 0 { star.move(to: p) } else { star.addLine(to: p) }
            }
            star.closeSubpath()
            c.setFillColor(dark.cgColor)
            c.setStrokeColor(cream.cgColor)
            c.setLineWidth(2.1)
            c.addPath(star)
            c.drawPath(using: .fillStroke)
            c.setStrokeColor(rose.cgColor)
            c.strokeEllipse(in: CGRect(x: -121, y: -121, width: 242, height: 242))
            flower(c, petals: 8, radius: 108, petalWidth: 31, fill: cream, outline: rose)
            flower(c, petals: 8, radius: 55, petalWidth: 13, fill: red, outline: nil)
            c.setFillColor(cream.cgColor)
            c.fillEllipse(in: CGRect(x: -12, y: -12, width: 24, height: 24))
        }
        for (x, y, angle) in [(CGFloat(228), CGFloat(216), CGFloat(0)), (772, 216, .pi), (228, 472, 0), (772, 472, .pi)] {
            transform(c, x: x, y: y, angle: angle) {
                flower(c, petals: 6, radius: 26, petalWidth: 8.5, fill: cream, outline: dark)
                c.setStrokeColor(cream.cgColor)
                c.setLineWidth(1.8)
                c.setLineCap(.round)
                let stem = CGMutablePath()
                stem.move(to: CGPoint(x: -14, y: -25))
                stem.addCurve(to: CGPoint(x: -66, y: -37), control1: CGPoint(x: -37, y: -42), control2: CGPoint(x: -71, y: -12))
                stem.addCurve(to: CGPoint(x: -48, y: -62), control1: CGPoint(x: -84, y: -66), control2: CGPoint(x: -54, y: -83))
                stem.move(to: CGPoint(x: 16, y: 25))
                stem.addCurve(to: CGPoint(x: 58, y: 45), control1: CGPoint(x: 26, y: 56), control2: CGPoint(x: 66, y: 25))
                stem.addCurve(to: CGPoint(x: 80, y: 63), control1: CGPoint(x: 38, y: 68), control2: CGPoint(x: 69, y: 85))
                c.addPath(stem)
                c.strokePath()
                leaf(c, x: -47, y: -28, angle: -.pi / 3, size: 11, color: rose)
                leaf(c, x: 42, y: 41, angle: .pi / 4, size: 11, color: rose)
            }
        }
    }

    static func hiddenPanda(_ c: CGContext) {
        let charcoal = color(0.18, 0.20, 0.20)
        let wool = color(0.87, 0.86, 0.81)
        let gray = color(0.57, 0.59, 0.56)
        fill(c, bounds, charcoal)
        fill(c, CGRect(x: 10, y: 10, width: 980, height: 668), wool)
        fill(c, CGRect(x: 16, y: 16, width: 968, height: 656), charcoal)
        stroke(c, CGRect(x: 31, y: 31, width: 938, height: 626), wool, 1.5)
        fill(c, CGRect(x: 70, y: 70, width: 860, height: 548), wool)
        stroke(c, CGRect(x: 83, y: 83, width: 834, height: 522), gray, 1.4)
        stroke(c, CGRect(x: 92, y: 92, width: 816, height: 504), charcoal, 0.8)
        for index in 0..<24 {
            let x = 45 + CGFloat(index) * 39.6
            smallCloudKnot(c, x: x, y: 51, color: wool)
            smallCloudKnot(c, x: x, y: 637, color: wool)
        }
        for index in 0..<15 {
            let y = 68 + CGFloat(index) * 39.6
            transform(c, x: 51, y: y, angle: .pi / 2) { smallCloudKnot(c, x: 0, y: 0, color: wool) }
            transform(c, x: 949, y: y, angle: .pi / 2) { smallCloudKnot(c, x: 0, y: 0, color: wool) }
        }

        // A cloud-ring knot uses abundant blank wool and no face or mascot.
        transform(c, x: 500, y: 344) {
            for turn in 0..<4 {
                transform(c, x: 0, y: 0, angle: CGFloat(turn) * .pi / 2) {
                    let knot = CGMutablePath()
                    knot.move(to: CGPoint(x: 25, y: 32))
                    knot.addCurve(to: CGPoint(x: 64, y: 119), control1: CGPoint(x: 116, y: 47), control2: CGPoint(x: 154, y: 127))
                    knot.addCurve(to: CGPoint(x: 42, y: 76), control1: CGPoint(x: -13, y: 113), control2: CGPoint(x: -5, y: 40))
                    knot.addCurve(to: CGPoint(x: 78, y: 86), control1: CGPoint(x: 72, y: 104), control2: CGPoint(x: 99, y: 60))
                    c.setStrokeColor(charcoal.cgColor)
                    c.setLineWidth(3.5)
                    c.setLineCap(.round)
                    c.addPath(knot)
                    c.strokePath()
                }
            }
            diamond(c, center: .zero, radius: 30, color: gray, width: 2.1)
        }
        for (x, y, angle) in [(CGFloat(234), CGFloat(224), CGFloat(0)), (766, 224, .pi), (234, 464, 0), (766, 464, .pi)] {
            transform(c, x: x, y: y, angle: angle, scale: 0.62) {
                cloud(c, color: charcoal, width: 3.0)
                // The tiny black-and-white animal occupies the curled cloud tail.
                // No eyes, smiling face or oversized head: it reads as a weave.
                panda(c, x: 47, y: -21, black: charcoal, white: wool)
            }
        }
        for (x, y) in [(CGFloat(500), CGFloat(159)), (500, 529)] {
            transform(c, x: x, y: y, scale: 0.34) { cloud(c, color: gray, width: 3.5) }
        }
    }

    static func woolGrain(_ c: CGContext) {
        // An LCG makes the exact original composition repeat across all launches.
        var state: UInt32 = 0x59_49_58_49
        func sample() -> CGFloat {
            state = state &* 1_664_525 &+ 1_013_904_223
            return CGFloat(state & 0xFFFF) / 65535
        }
        c.setLineCap(.round)
        for index in 0..<12_000 {
            let x = sample() * 1000, y = sample() * 688
            let length = 0.6 + sample() * 2.3
            let warm = index.isMultiple(of: 3)
            c.setStrokeColor(NSColor(white: warm ? 1 : 0, alpha: warm ? 0.055 : 0.035).cgColor)
            c.setLineWidth(0.25 + sample() * 0.35)
            c.move(to: CGPoint(x: x, y: y))
            c.addLine(to: CGPoint(x: x + (sample() - 0.5) * 0.9, y: y + length))
            c.strokePath()
        }
    }

    private static func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    private static func fill(_ c: CGContext, _ rect: CGRect, _ color: NSColor) {
        c.setFillColor(color.cgColor)
        c.fill(rect)
    }

    private static func stroke(_ c: CGContext, _ rect: CGRect, _ color: NSColor, _ width: CGFloat) {
        c.setStrokeColor(color.cgColor)
        c.setLineWidth(width)
        c.stroke(rect)
    }

    private static func transform(_ c: CGContext, x: CGFloat, y: CGFloat, angle: CGFloat = 0, scale: CGFloat = 1, draw: () -> Void) {
        c.saveGState()
        c.translateBy(x: x, y: y)
        c.rotate(by: angle)
        c.scaleBy(x: scale, y: scale)
        draw()
        c.restoreGState()
    }

    private static func diamond(_ c: CGContext, center: CGPoint, radius: CGFloat, color: NSColor, width: CGFloat) {
        let path = CGMutablePath()
        path.addLines(between: [
            CGPoint(x: center.x, y: center.y + radius), CGPoint(x: center.x + radius, y: center.y),
            CGPoint(x: center.x, y: center.y - radius), CGPoint(x: center.x - radius, y: center.y)
        ])
        path.closeSubpath()
        c.setStrokeColor(color.cgColor)
        c.setLineWidth(width)
        c.addPath(path)
        c.strokePath()
    }

    private static func flower(_ c: CGContext, petals: Int, radius: CGFloat, petalWidth: CGFloat, fill: NSColor, outline: NSColor?) {
        for petal in 0..<petals {
            transform(c, x: 0, y: 0, angle: CGFloat(petal) * 2 * .pi / CGFloat(petals)) {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 0, y: radius * 0.16))
                path.addCurve(to: CGPoint(x: 0, y: radius), control1: CGPoint(x: -petalWidth, y: radius * 0.46), control2: CGPoint(x: -petalWidth * 0.68, y: radius * 0.82))
                path.addCurve(to: CGPoint(x: 0, y: radius * 0.16), control1: CGPoint(x: petalWidth * 0.68, y: radius * 0.82), control2: CGPoint(x: petalWidth, y: radius * 0.46))
                path.closeSubpath()
                c.setFillColor(fill.cgColor)
                c.addPath(path)
                if let outline {
                    c.setStrokeColor(outline.cgColor)
                    c.setLineWidth(1.2)
                    c.drawPath(using: .fillStroke)
                } else {
                    c.fillPath()
                }
            }
        }
    }

    private static func mountain(_ c: CGContext, points: [CGPoint], floor: CGFloat, color: NSColor) {
        guard let first = points.first, let last = points.last else { return }
        let path = CGMutablePath()
        path.addLines(between: points)
        path.addLine(to: CGPoint(x: last.x, y: floor))
        path.addLine(to: CGPoint(x: first.x, y: floor))
        path.closeSubpath()
        c.setFillColor(color.cgColor)
        c.addPath(path)
        c.fillPath()
    }

    private static func fogBand(_ c: CGContext, y: CGFloat, left: CGFloat, right: CGFloat, depth: CGFloat, color: NSColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: left, y: y))
        path.addCurve(to: CGPoint(x: right, y: y + 4), control1: CGPoint(x: 390, y: y + depth), control2: CGPoint(x: 611, y: y - depth * 0.4))
        path.addCurve(to: CGPoint(x: left, y: y - depth), control1: CGPoint(x: 649, y: y - depth * 1.4), control2: CGPoint(x: 341, y: y - depth * 0.8))
        path.closeSubpath()
        c.setFillColor(color.cgColor)
        c.addPath(path)
        c.fillPath()
    }

    private static func wave(_ c: CGContext, x: CGFloat, y: CGFloat, length: CGFloat, amplitude: CGFloat, pitch: CGFloat, color: NSColor, width: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        let samples = max(2, Int(length / 4))
        for index in 1...samples {
            let along = CGFloat(index) / CGFloat(samples) * length
            let height = sin(along / pitch * 2 * .pi) * amplitude
            path.addLine(to: CGPoint(x: x + along, y: y + height))
        }
        c.setStrokeColor(color.cgColor)
        c.setLineWidth(width)
        c.setLineCap(.round)
        c.addPath(path)
        c.strokePath()
    }

    private static func leaf(_ c: CGContext, x: CGFloat, y: CGFloat, angle: CGFloat, size: CGFloat, color: NSColor) {
        transform(c, x: x, y: y, angle: angle) {
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addQuadCurve(to: CGPoint(x: 0, y: size), control: CGPoint(x: -size * 0.8, y: size * 0.6))
            path.addQuadCurve(to: .zero, control: CGPoint(x: size * 0.8, y: size * 0.6))
            path.closeSubpath()
            c.setFillColor(color.cgColor)
            c.addPath(path)
            c.fillPath()
        }
    }

    private static func cloud(_ c: CGContext, color: NSColor, width: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -73, y: -13))
        path.addCurve(to: CGPoint(x: -49, y: 14), control1: CGPoint(x: -86, y: 12), control2: CGPoint(x: -63, y: 28))
        path.addCurve(to: CGPoint(x: -17, y: 37), control1: CGPoint(x: -52, y: 45), control2: CGPoint(x: -25, y: 56))
        path.addCurve(to: CGPoint(x: 24, y: 34), control1: CGPoint(x: -7, y: 64), control2: CGPoint(x: 32, y: 61))
        path.addCurve(to: CGPoint(x: 58, y: 14), control1: CGPoint(x: 55, y: 49), control2: CGPoint(x: 74, y: 37))
        path.addCurve(to: CGPoint(x: 73, y: -10), control1: CGPoint(x: 88, y: 19), control2: CGPoint(x: 92, y: -6))
        path.addCurve(to: CGPoint(x: 32, y: -16), control1: CGPoint(x: 64, y: -31), control2: CGPoint(x: 43, y: -27))
        path.addCurve(to: CGPoint(x: -9, y: -37), control1: CGPoint(x: 14, y: -2), control2: CGPoint(x: 7, y: -47))
        path.addCurve(to: CGPoint(x: -46, y: -19), control1: CGPoint(x: -31, y: -48), control2: CGPoint(x: -45, y: -34))
        path.addCurve(to: CGPoint(x: -73, y: -13), control1: CGPoint(x: -59, y: -37), control2: CGPoint(x: -82, y: -34))
        path.move(to: CGPoint(x: -48, y: -1))
        path.addCurve(to: CGPoint(x: -18, y: 13), control1: CGPoint(x: -49, y: 30), control2: CGPoint(x: -10, y: 35))
        path.addCurve(to: CGPoint(x: 21, y: 15), control1: CGPoint(x: -33, y: -9), control2: CGPoint(x: 25, y: -10))
        path.addCurve(to: CGPoint(x: 51, y: -2), control1: CGPoint(x: 15, y: 40), control2: CGPoint(x: 59, y: 29))
        c.setStrokeColor(color.cgColor)
        c.setLineWidth(width)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.addPath(path)
        c.strokePath()
    }

    private static func smallCloudKnot(_ c: CGContext, x: CGFloat, y: CGFloat, color: NSColor) {
        transform(c, x: x, y: y) {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -12, y: -3))
            path.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: -16, y: 10), control2: CGPoint(x: 1, y: 16))
            path.addCurve(to: CGPoint(x: 12, y: -3), control1: CGPoint(x: -1, y: -9), control2: CGPoint(x: 16, y: -14))
            c.setStrokeColor(color.cgColor)
            c.setLineWidth(1.5)
            c.setLineCap(.round)
            c.addPath(path)
            c.strokePath()
        }
    }

    private static func panda(_ c: CGContext, x: CGFloat, y: CGFloat, black: NSColor, white: NSColor) {
        transform(c, x: x, y: y, angle: -.pi / 8) {
            c.setFillColor(black.cgColor)
            c.fillEllipse(in: CGRect(x: -6.5, y: -9, width: 13, height: 15))
            c.fillEllipse(in: CGRect(x: -5, y: 1, width: 10, height: 9))
            c.fillEllipse(in: CGRect(x: -6.5, y: 7, width: 4, height: 4))
            c.fillEllipse(in: CGRect(x: 2.5, y: 7, width: 4, height: 4))
            c.setFillColor(white.cgColor)
            c.fillEllipse(in: CGRect(x: -3.5, y: -6, width: 7, height: 7))
            c.fillEllipse(in: CGRect(x: -3.3, y: 2, width: 6.6, height: 5.5))
        }
    }
}
