import Testing
import simd
@testable import RugEngine

private func centerOfMass(_ cloth: RugCloth) -> SIMD3<Float> {
    cloth.mesh.vertices.reduce(SIMD3<Float>.zero) { $0 + $1.position } / Float(cloth.mesh.vertexCount)
}

private func maximumStructuralStretch(_ cloth: RugCloth, size: SIMD2<Float>) -> Float {
    let mesh = cloth.mesh
    var maximum: Float = 0
    for row in 0...mesh.rows {
        for column in 0...mesh.columns {
            let index = row * (mesh.columns + 1) + column
            if column < mesh.columns {
                maximum = max(maximum, simd_distance(mesh.vertices[index].position, mesh.vertices[index + 1].position) / (size.x / Float(mesh.columns)))
            }
            if row < mesh.rows {
                maximum = max(maximum, simd_distance(mesh.vertices[index].position, mesh.vertices[index + mesh.columns + 1].position) / (size.y / Float(mesh.rows)))
            }
        }
    }
    return maximum
}

private func projectedShape(_ cloth: RugCloth) -> (area: Float, flippedFraction: Float) {
    let mesh = cloth.mesh
    var area: Float = 0
    var flipped = 0
    for triangle in stride(from: 0, to: mesh.triangleIndices.count, by: 3) {
        let a = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[triangle])].position)
        let b = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[triangle + 1])].position)
        let c = RugProjection.screenPoint(mesh.vertices[Int(mesh.triangleIndices[triangle + 2])].position)
        let signedArea = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
        area += signedArea * 0.5
        if signedArea < 0 { flipped += 1 }
    }
    return (area, Float(flipped) / Float(mesh.triangleCount))
}

@Test func restingRugSleepsWithoutChangingShape() {
    var cloth = RugCloth(size: SIMD2(640, 440), center: SIMD2(600, 400))
    let positions = cloth.mesh.vertices.map(\.position)
    for _ in 0..<120 { cloth.step(deltaTime: 1 / 60) }
    #expect(cloth.isSettled)
    #expect(!cloth.isDragging)
    #expect(cloth.mesh.vertices.map(\.position) == positions)
    #expect(cloth.maximumHeight == 0)
}

@Test func grabMovesNearbyClothFirstAndEventuallyPullsWholeRug() {
    var cloth = RugCloth()
    let initial = cloth.mesh.vertices.map(\.position)
    let picked = cloth.mesh.vertexIndex(column: 20, row: 15)!
    let didGrab = cloth.beginGrab(at: .zero, corner: false)
    #expect(didGrab)
    cloth.updateGrab(target: SIMD2(120, 0), lift: 0)
    cloth.step(deltaTime: 1 / 120)
    let nearbyDistance = simd_distance(cloth.mesh.vertices[picked].position, initial[picked])
    let edgeDistance = simd_distance(cloth.mesh.vertices[0].position, initial[0])
    #expect(nearbyDistance > 5)
    #expect(nearbyDistance > edgeDistance * 3)
    // Sustained slow dragging transfers motion through the mesh, with friction.
    for frame in 1...120 {
        cloth.updateGrab(target: SIMD2(120 + Float(frame) * 1.25, 0), lift: 0)
        cloth.step(deltaTime: 1 / 60)
    }
    #expect(centerOfMass(cloth).x > 180)
    #expect(maximumStructuralStretch(cloth, size: SIMD2(640, 440)) < 1.6)
}

@Test func raisedCornerDeformsMeshAndFallsBackOntoDesktop() {
    var cloth = RugCloth()
    let corner = RugProjection.screenPoint(cloth.mesh.vertices[0].position)
    let didGrab = cloth.beginGrab(at: corner, corner: true)
    #expect(didGrab)
    for frame in 1...90 {
        let fraction = min(1, Float(frame) / 40)
        cloth.updateGrab(target: corner + SIMD2(115, 70) * fraction, lift: 190 * fraction)
        cloth.step(deltaTime: 1 / 60)
    }
    #expect(cloth.maximumHeight > 180)
    #expect(cloth.mesh.vertices[0].position.z > 180)
    // A corner lift is local: the opposite corner remains near the desktop.
    #expect(cloth.mesh.vertices.last!.position.z < 35)
    #expect(cloth.mesh.vertices.contains { $0.normal.z < 0.8 })
    cloth.endGrab()
    for _ in 0..<900 { cloth.step(deltaTime: 1 / 60) }
    #expect(cloth.maximumHeight < 1)
    #expect(cloth.isSettled)
    #expect(cloth.mesh.vertices.allSatisfy { $0.position.z >= 0 })
}

@Test func ordinaryCenterDragKeepsWoolCarpetSpreadAcrossDesktop() {
    // Match the live app acceptance trajectory, including its small hand lift.
    let size = SIMD2<Float>(640, 440)
    var cloth = RugCloth(size: size)
    let didGrab = cloth.beginGrab(at: .zero, corner: false)
    #expect(didGrab)
    cloth.updateGrab(target: SIMD2(-180, 65), lift: 24)
    for _ in 0..<66 {
        cloth.step(deltaTime: 1 / 60)
        let shape = projectedShape(cloth)
        #expect(shape.area > size.x * size.y * 0.85)
        #expect(shape.flippedFraction < 0.015)
        #expect(cloth.maximumHeight < 75)
    }
    let center = centerOfMass(cloth)
    #expect(center.x < -100)
    #expect(center.x > -235)
    cloth.endGrab()
    for _ in 0..<144 { cloth.step(deltaTime: 1 / 60) }
    #expect(cloth.maximumHeight < 10)
    #expect(projectedShape(cloth).area > size.x * size.y * 0.95)
}

@Test func fastGrabsStayFiniteAndDoNotTearFabric() {
    let size = SIMD2<Float>(640, 440)
    var cloth = RugCloth(size: size)
    let didGrab = cloth.beginGrab(at: .zero, corner: false)
    #expect(didGrab)
    for frame in 0..<420 {
        let time = Float(frame) / 60
        cloth.updateGrab(target: SIMD2(260 * sin(time * 3.8), 180 * cos(time * 2.7)), lift: max(0, 130 * sin(time * 2.1)))
        cloth.step(deltaTime: frame.isMultiple(of: 31) ? 1 / 20 : 1 / 60)
        #expect(cloth.mesh.vertices.allSatisfy { vertex in
            let point = RugProjection.screenPoint(vertex.position)
            return point.x.isFinite && point.y.isFinite && vertex.position.z.isFinite
                && vertex.normal.x.isFinite && vertex.normal.y.isFinite && vertex.normal.z.isFinite
                && vertex.position.z >= 0
        })
        #expect(maximumStructuralStretch(cloth, size: size) < 1.6)
    }
    cloth.endGrab()
    for _ in 0..<600 { cloth.step(deltaTime: 1 / 60) }
    // Aggressive dragging can leave a small physical fold; it must fall down,
    // stop consuming simulation time, and remain unchanged while asleep.
    #expect(cloth.maximumHeight < 50)
    #expect(cloth.isSettled)
    let restingShape = cloth.mesh.vertices.map(\.position)
    cloth.step(deltaTime: 1 / 60)
    #expect(cloth.mesh.vertices.map(\.position) == restingShape)
}

@Test func projectionAgreesWithHeightOffsetAndInvalidInputIsIgnored() {
    #expect(RugProjection.screenPoint(SIMD3(20, 30, 100)) == SIMD2<Float>(32, 72))
    var cloth = RugCloth()
    let invalidGrab = cloth.beginGrab(at: SIMD2(.nan, 0), corner: false)
    #expect(!invalidGrab)
    let distantGrab = cloth.beginGrab(at: SIMD2(2_000, 2_000), corner: false)
    #expect(!distantGrab)
    let didGrab = cloth.beginGrab(at: .zero, corner: false)
    #expect(didGrab)
    cloth.updateGrab(target: SIMD2(.infinity, 0), lift: 0)
    cloth.step(deltaTime: .nan)
    #expect(cloth.mesh.vertices.allSatisfy { $0.position.x.isFinite })
}
