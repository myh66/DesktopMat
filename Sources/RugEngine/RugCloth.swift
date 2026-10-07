import Foundation
import simd

/// The same oblique projection is used by rendering and mesh hit testing.
/// Height changes the actual projected silhouette, exposing the desktop below.
public enum RugProjection {
    public static let heightOffset = SIMD2<Float>(0.12, 0.42)

    public static func screenPoint(_ position: SIMD3<Float>) -> SIMD2<Float> {
        SIMD2(position.x, position.y) + heightOffset * position.z
    }
}

/// A wool-weight cloth on a horizontal desktop, measured in screen points.
/// Distance constraints use XPBD; the picked particle is the only kinematic
/// particle. The remaining carpet follows through its connected fabric mesh.
public struct RugCloth: Sendable {
    public private(set) var mesh: RugMesh
    public var isDragging: Bool { grab != nil }
    public private(set) var isSettled = true
    public var maximumHeight: Float { positions.reduce(0) { max($0, $1.z) } }

    private struct DistanceConstraint: Sendable {
        var a: Int
        var b: Int
        var restLength: Float
        var compliance: Float
        var multiplier: Float = 0
    }

    private struct Grab: Sendable {
        var index: Int
        var target: SIMD3<Float>
        var currentTarget: SIMD3<Float>
        var pointerOffset: SIMD2<Float>
    }

    private struct CurvatureConstraint: Sendable {
        var a: Int
        var middle: Int
        var b: Int
        var multiplier = SIMD3<Float>.zero
    }

    private var positions: [SIMD3<Float>]
    private var velocities: [SIMD3<Float>]
    private var previousPositions: [SIMD3<Float>]
    private var constraints: [DistanceConstraint] = []
    private var bendingConstraints: [CurvatureConstraint] = []
    private var grab: Grab?
    private var accumulator: Float = 0
    private var quietSteps = 0
    private var size: SIMD2<Float>
    private static let fixedStep: Float = 1 / 120
    private static let gravity: Float = 1_200

    public init(size: SIMD2<Float> = SIMD2(640, 440), center: SIMD2<Float> = .zero) {
        mesh = RugMesh()
        self.size = size
        positions = Array(repeating: .zero, count: mesh.vertexCount)
        velocities = positions
        previousPositions = positions
        reset(center: center, size: size)
    }

    public mutating func reset(center: SIMD2<Float>, size: SIMD2<Float>) {
        let safeSize = SIMD2(max(120, size.x), max(90, size.y))
        self.size = safeSize
        grab = nil
        accumulator = 0
        quietSteps = 0
        isSettled = true
        for index in mesh.vertices.indices {
            let point = (mesh.vertices[index].textureCoordinate - SIMD2<Float>(repeating: 0.5)) * safeSize + center
            positions[index] = SIMD3(point.x, point.y, 0)
            velocities[index] = .zero
            previousPositions[index] = positions[index]
        }
        makeConstraints()
        publishMesh()
    }

    /// The pointer is in projected window-local points. Corner grabs select an
    /// actual corner; regular grabs pick the nearest cloth particle.
    @discardableResult
    public mutating func beginGrab(at point: SIMD2<Float>, corner: Bool) -> Bool {
        guard point.x.isFinite, point.y.isFinite else { return false }
        let candidates: [Int]
        if corner {
            candidates = [0, mesh.columns, mesh.rows * (mesh.columns + 1), positions.count - 1]
        } else {
            candidates = Array(positions.indices)
        }
        var closest = -1
        var distance = Float.greatestFiniteMagnitude
        for index in candidates {
            let squared = simd_length_squared(RugProjection.screenPoint(positions[index]) - point)
            if squared < distance {
                distance = squared
                closest = index
            }
        }
        let threshold = corner ? min(size.x, size.y) * 0.27 : max(size.x / Float(mesh.columns), size.y / Float(mesh.rows)) * 2.4
        guard closest >= 0, distance <= threshold * threshold else { return false }
        let selected = positions[closest]
        grab = Grab(index: closest, target: selected, currentTarget: selected,
                    pointerOffset: RugProjection.screenPoint(selected) - point)
        isSettled = false
        quietSteps = 0
        return true
    }

    public mutating func updateGrab(target: SIMD2<Float>, lift: Float) {
        guard var active = grab, target.x.isFinite, target.y.isFinite, lift.isFinite else { return }
        let height = min(max(0, lift), min(size.x, size.y) * 0.85)
        let planePoint = target + active.pointerOffset - RugProjection.heightOffset * height
        active.target = SIMD3(planePoint.x, planePoint.y, height)
        grab = active
    }

    public mutating func endGrab() {
        grab = nil
        quietSteps = 0
        isSettled = false
    }

    /// Fixed substeps prevent frame-rate-dependent stretching and limit catch-up
    /// after a suspended app. Idle cloth sleeps without spending CPU cycles.
    public mutating func step(deltaTime: Float) {
        guard !isSettled, deltaTime.isFinite, deltaTime > 0 else { return }
        accumulator += min(deltaTime, 1 / 15)
        var steps = 0
        while accumulator >= Self.fixedStep && steps < 8 {
            simulateSubstep()
            accumulator -= Self.fixedStep
            steps += 1
            if isSettled { accumulator = 0; break }
        }
        if steps > 0 { publishMesh() }
    }

    private mutating func makeConstraints() {
        constraints.removeAll(keepingCapacity: true)
        bendingConstraints.removeAll(keepingCapacity: true)
        constraints.reserveCapacity(mesh.vertexCount * 6)
        let stride = mesh.columns + 1
        func index(_ column: Int, _ row: Int) -> Int { row * stride + column }
        for row in 0...mesh.rows {
            for column in 0...mesh.columns {
                let a = index(column, row)
                if column < mesh.columns { appendConstraint(a, index(column + 1, row), compliance: 0.000_000_08) }
                if row < mesh.rows { appendConstraint(a, index(column, row + 1), compliance: 0.000_000_08) }
                if column < mesh.columns && row < mesh.rows {
                    appendConstraint(a, index(column + 1, row + 1), compliance: 0.000_000_3)
                    appendConstraint(index(column + 1, row), index(column, row + 1), compliance: 0.000_000_3)
                }
                // Discrete material curvature: each three-particle woven line
                // resists changes of tangent, including tight folds which a
                // two-point distance spring alone cannot distinguish.
                if column + 2 <= mesh.columns {
                    bendingConstraints.append(CurvatureConstraint(a: a, middle: index(column + 1, row), b: index(column + 2, row)))
                }
                if row + 2 <= mesh.rows {
                    bendingConstraints.append(CurvatureConstraint(a: a, middle: index(column, row + 1), b: index(column, row + 2)))
                }
            }
        }
    }

    private mutating func appendConstraint(_ a: Int, _ b: Int, compliance: Float) {
        constraints.append(DistanceConstraint(a: a, b: b, restLength: simd_distance(positions[a], positions[b]), compliance: compliance))
    }

    private mutating func simulateSubstep() {
        let dt = Self.fixedStep
        let dtSquared = dt * dt
        let airDamping = exp(-6.0 * dt)
        let verticalDamping = exp(-20.0 * dt)
        let floorDamping = exp(-2.4 * dt)
        let grabbedIndex = grab?.index ?? -1

        if var active = grab {
            // A bounded hand speed keeps a single skipped mouse event from
            // injecting unbounded energy into a small patch of fabric.
            let movement = active.target - active.currentTarget
            let distance = simd_length(movement)
            if distance > 0.0001 {
                active.currentTarget += movement * min(1, 800 * dt / distance)
            }
            grab = active
        }

        for index in positions.indices {
            previousPositions[index] = positions[index]
            var velocity = velocities[index] * airDamping
            // Thick wool dissipates out-of-plane flutter more than horizontal
            // sliding. This damps velocity, without clamping vertex heights.
            velocity.z = velocities[index].z * verticalDamping
            if positions[index].z < 0.2 {
                velocity.x *= floorDamping
                velocity.y *= floorDamping
            }
            positions[index] += velocity * dt + SIMD3(0, 0, -Self.gravity * dtSquared)
            positions[index].z = max(0, positions[index].z)
        }
        if let active = grab { positions[active.index] = active.currentTarget }
        for index in constraints.indices { constraints[index].multiplier = 0 }
        for index in bendingConstraints.indices { bendingConstraints[index].multiplier = .zero }

        // Alternating sweep order avoids a preferred direction in the fabric.
        for iteration in 0..<10 {
            if iteration.isMultiple(of: 2) {
                for index in constraints.indices { solveConstraint(index, grabbedIndex: grabbedIndex, dtSquared: dtSquared) }
                for index in bendingConstraints.indices { solveCurvature(index, grabbedIndex: grabbedIndex, dtSquared: dtSquared) }
            } else {
                for index in constraints.indices.reversed() { solveConstraint(index, grabbedIndex: grabbedIndex, dtSquared: dtSquared) }
                for index in bendingConstraints.indices.reversed() { solveCurvature(index, grabbedIndex: grabbedIndex, dtSquared: dtSquared) }
            }
            for index in positions.indices { positions[index].z = max(0, positions[index].z) }
            if let active = grab { positions[active.index] = active.currentTarget }
        }

        // Large pointer jumps are a soft hand constraint rather than permission
        // to tear wool. This strain limit may let the picked point lag the hand
        // briefly; it still moves the connected particles instead of translating
        // the carpet as a rigid rectangle.
        for iteration in 0..<4 {
            if iteration.isMultiple(of: 2) {
                for index in constraints.indices { limitStrain(index) }
            } else {
                for index in constraints.indices.reversed() { limitStrain(index) }
            }
            for index in positions.indices { positions[index].z = max(0, positions[index].z) }
        }

        var maximumSpeedSquared: Float = 0
        var height: Float = 0
        for index in positions.indices {
            var velocity = (positions[index] - previousPositions[index]) / dt
            if positions[index].z < 0.001, velocity.z < 0 {
                // Low restitution gives a thick rug one restrained landing wave.
                velocity.z = min(24, -velocity.z * 0.09)
            }
            let speed = simd_length(velocity)
            if speed > 3_600 { velocity *= 3_600 / speed }
            velocities[index] = velocity
            maximumSpeedSquared = max(maximumSpeedSquared, simd_length_squared(velocity))
            height = max(height, positions[index].z)
        }
        if grab == nil, maximumSpeedSquared < 9 {
            quietSteps += 1
            if quietSteps >= 30 {
                for index in positions.indices {
                    if height < 0.35 { positions[index].z = 0 }
                    velocities[index] = .zero
                }
                isSettled = true
            }
        } else {
            quietSteps = 0
        }
    }

    private mutating func solveConstraint(_ index: Int, grabbedIndex: Int, dtSquared: Float) {
        var constraint = constraints[index]
        let difference = positions[constraint.a] - positions[constraint.b]
        let length = simd_length(difference)
        guard length > 0.00001 else { return }
        let weightA: Float = constraint.a == grabbedIndex ? 0 : 1
        let weightB: Float = constraint.b == grabbedIndex ? 0 : 1
        let alpha = constraint.compliance / dtSquared
        let delta = (-(length - constraint.restLength) - alpha * constraint.multiplier) / (weightA + weightB + alpha)
        constraint.multiplier += delta
        let correction = difference * (delta / length)
        positions[constraint.a] += correction * weightA
        positions[constraint.b] -= correction * weightB
        constraints[index] = constraint
    }

    private mutating func limitStrain(_ index: Int) {
        let constraint = constraints[index]
        guard constraint.compliance < 0.000_001 else { return }
        let difference = positions[constraint.a] - positions[constraint.b]
        let length = simd_length(difference)
        let limit = constraint.restLength * 1.28
        guard length > limit else { return }
        let correction = difference * ((length - limit) / (2 * length))
        positions[constraint.a] -= correction
        positions[constraint.b] += correction
    }

    private mutating func solveCurvature(_ index: Int, grabbedIndex: Int, dtSquared: Float) {
        var constraint = bendingConstraints[index]
        let curvature = positions[constraint.a] - 2 * positions[constraint.middle] + positions[constraint.b]
        let weightA: Float = constraint.a == grabbedIndex ? 0 : 1
        let weightMiddle: Float = constraint.middle == grabbedIndex ? 0 : 1
        let weightB: Float = constraint.b == grabbedIndex ? 0 : 1
        let alpha: Float = 0.000_002 / dtSquared
        let delta = (-curvature - alpha * constraint.multiplier) / (weightA + 4 * weightMiddle + weightB + alpha)
        constraint.multiplier += delta
        positions[constraint.a] += delta * weightA
        positions[constraint.middle] -= delta * (2 * weightMiddle)
        positions[constraint.b] += delta * weightB
        bendingConstraints[index] = constraint
    }

    private mutating func publishMesh() {
        for index in mesh.vertices.indices { mesh.vertices[index].position = positions[index] }
        mesh.updateNormals()
    }
}
