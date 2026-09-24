import Foundation

/// One level: where the hidden position is and how precise the player must be.
struct Level: Equatable {
    /// The hidden hinge angle, in degrees.
    var target: Double
    /// How far either side of the target still counts as correct, in degrees.
    var tolerance: Double
    /// Degrees beyond the tolerance over which the ring warms from red to amber.
    /// A smaller range makes the feedback more sensitive.
    var feedbackRange: Double

    func distance(to angle: Double) -> Double {
        abs(angle - target)
    }

    func contains(_ angle: Double) -> Bool {
        distance(to: angle) <= tolerance
    }

    /// 0 when far away, rising to 1 at the edge of the target zone.
    func closeness(to angle: Double) -> Double {
        let beyondTolerance = distance(to: angle) - tolerance
        return min(max(1 - beyondTolerance / feedbackRange, 0), 1)
    }
}

/// How close the hinge is, in the terms the player sees.
enum Proximity: Equatable {
    /// No usable angle: no hinge data yet, or the level is waiting for the hinge to move.
    case noSignal
    case far
    case closer
    case almost
    case inside
}

enum Phase: Hashable {
    case intro
    case playing(level: Int)
    case unlocked(level: Int)
    case complete
}

/// The whole game as plain logic: no UI and no hinge API, just angles and times.
struct GameModel {
    private(set) var levels = GameConfig.levels
    private(set) var phase = Phase.intro
    /// When the hinge entered the target zone, or nil when no hold is in progress.
    private(set) var holdStartedAt: Date?

    /// Set when a level starts with the hinge already inside its target. The hold
    /// waits until the hinge has left the zone once, so a level never opens
    /// without the hinge moving.
    private var waitingForHingeToLeave = false

    var currentLevel: Level? {
        guard case .playing(let index) = phase else { return nil }
        return levels[index]
    }

    var isSafeOpen: Bool {
        switch phase {
        case .unlocked, .complete: true
        case .intro, .playing: false
        }
    }

    func proximity(to angle: Double?) -> Proximity {
        guard let level = currentLevel, let angle, !waitingForHingeToLeave else { return .noSignal }
        if level.contains(angle) { return .inside }
        let closeness = level.closeness(to: angle)
        if closeness >= 0.75 { return .almost }
        if closeness >= 0.35 { return .closer }
        return .far
    }

    /// 0 when far away, rising to 1 at the edge of the current level's target zone.
    func closeness(to angle: Double?) -> Double {
        guard let level = currentLevel, let angle else { return 0 }
        return level.closeness(to: angle)
    }

    /// How much of the hold is done, from 0 to 1.
    func holdProgress(at now: Date) -> Double {
        guard let holdStartedAt else { return 0 }
        return min(max(now.timeIntervalSince(holdStartedAt) / GameConfig.holdDuration, 0), 1)
    }

    mutating func start(angle: Double?) {
        begin(level: 0, angle: angle)
    }

    /// Call on every hinge change, and again when a hold is due to finish. The
    /// hold completes on elapsed time, so it never needs another hinge event.
    mutating func update(angle: Double?, at now: Date) {
        guard case .playing(let index) = phase else { return }
        guard let angle, levels[index].contains(angle) else {
            holdStartedAt = nil
            waitingForHingeToLeave = false
            return
        }
        guard !waitingForHingeToLeave else { return }

        let start = holdStartedAt ?? now
        holdStartedAt = start
        if now.timeIntervalSince(start) >= GameConfig.holdDuration {
            holdStartedAt = nil
            phase = index == levels.count - 1 ? .complete : .unlocked(level: index)
        }
    }

    /// Moves on from a level's success message to the next level.
    mutating func advance(angle: Double?) {
        guard case .unlocked(let index) = phase else { return }
        begin(level: index + 1, angle: angle)
    }

    mutating func playAgain(angle: Double?) {
        begin(level: 0, angle: angle)
    }

    /// Picks three new targets from the middle of the hinge range and starts again
    /// from Level 1. Tolerances stay the same.
    mutating func newTargets<Generator: RandomNumberGenerator>(angle: Double?, using generator: inout Generator) {
        var previous: Double?
        for index in levels.indices {
            var target = Double.random(in: GameConfig.newTargetRange, using: &generator).rounded()
            while let previous, abs(target - previous) < GameConfig.minimumTargetGap {
                target = Double.random(in: GameConfig.newTargetRange, using: &generator).rounded()
            }
            levels[index].target = target
            previous = target
        }
        begin(level: 0, angle: angle)
    }

    private mutating func begin(level index: Int, angle: Double?) {
        phase = .playing(level: index)
        holdStartedAt = nil
        if let angle {
            waitingForHingeToLeave = levels[index].contains(angle)
        } else {
            waitingForHingeToLeave = false
        }
    }
}
