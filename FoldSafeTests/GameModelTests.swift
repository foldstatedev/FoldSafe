import Foundation
import Testing
@testable import FoldSafe

struct GameModelTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    /// A game on Level 1 with the hinge closed.
    private func gameOnLevelOne() -> GameModel {
        var game = GameModel()
        game.start(angle: 0)
        return game
    }

    /// Holds the current level's target for the full hold time.
    private func unlockCurrentLevel(_ game: inout GameModel, from seconds: TimeInterval) {
        guard let target = game.currentLevel?.target else { return }
        game.update(angle: target, at: at(seconds))
        game.update(angle: target, at: at(seconds + GameConfig.holdDuration))
    }

    // MARK: Distance and tolerance

    @Test func distanceIsAbsolute() {
        let level = Level(target: 110, tolerance: 7, feedbackRange: 40)
        #expect(level.distance(to: 100) == 10)
        #expect(level.distance(to: 120) == 10)
        #expect(level.distance(to: 110) == 0)
    }

    @Test func outsideTolerance() {
        let level = Level(target: 82, tolerance: 3, feedbackRange: 24)
        #expect(!level.contains(78.9))
        #expect(!level.contains(85.1))
    }

    @Test func insideToleranceIncludesTheEdges() {
        let level = Level(target: 82, tolerance: 3, feedbackRange: 24)
        #expect(level.contains(79))
        #expect(level.contains(82))
        #expect(level.contains(85))
    }

    // MARK: Holding

    @Test func holdBeginsInsideTheTarget() {
        var game = gameOnLevelOne()
        game.update(angle: 128, at: at(1))
        #expect(game.holdStartedAt == at(1))
        #expect(game.holdProgress(at: at(1.5)) == 0.5)
        #expect(game.phase == .playing(level: 0))
    }

    @Test func leavingTheTargetCancelsTheHold() {
        var game = gameOnLevelOne()
        game.update(angle: 128, at: at(1))
        game.update(angle: 90, at: at(1.9))
        #expect(game.holdStartedAt == nil)
        #expect(game.holdProgress(at: at(2)) == 0)

        // Coming back starts again from zero.
        game.update(angle: 128, at: at(2))
        #expect(game.holdStartedAt == at(2))
        game.update(angle: 128, at: at(2.9))
        #expect(game.phase == .playing(level: 0))
    }

    @Test func oneSecondHoldUnlocksWithoutFurtherHingeMovement() {
        var game = gameOnLevelOne()
        game.update(angle: 128, at: at(1))
        // Same angle: only time has passed.
        game.update(angle: 128, at: at(2))
        #expect(game.phase == .unlocked(level: 0))
    }

    @Test func levelThatStartsInsideItsTargetWaitsForTheHingeToMove() {
        var game = GameModel()
        game.start(angle: 128)
        game.update(angle: 128, at: at(0))
        game.update(angle: 128, at: at(5))
        #expect(game.phase == .playing(level: 0))
        #expect(game.proximity(to: 128) == .noSignal)

        // Out and back in: now it counts.
        game.update(angle: 60, at: at(6))
        unlockCurrentLevel(&game, from: 7)
        #expect(game.phase == .unlocked(level: 0))
    }

    // MARK: Progression

    @Test func levelOneLeadsToLevelTwo() {
        var game = gameOnLevelOne()
        unlockCurrentLevel(&game, from: 1)
        #expect(game.phase == .unlocked(level: 0))
        game.advance(angle: 128)
        #expect(game.phase == .playing(level: 1))
    }

    @Test func levelTwoLeadsToLevelThree() {
        var game = gameOnLevelOne()
        unlockCurrentLevel(&game, from: 1)
        game.advance(angle: 128)
        unlockCurrentLevel(&game, from: 10)
        #expect(game.phase == .unlocked(level: 1))
        game.advance(angle: 110)
        #expect(game.phase == .playing(level: 2))
    }

    @Test func levelThreeCompletesTheGame() {
        var game = gameOnLevelOne()
        unlockCurrentLevel(&game, from: 1)
        game.advance(angle: 128)
        unlockCurrentLevel(&game, from: 10)
        game.advance(angle: 110)
        unlockCurrentLevel(&game, from: 20)
        #expect(game.phase == .complete)
        #expect(game.isSafeOpen)
    }

    @Test func playAgainResetsToLevelOne() {
        var game = gameOnLevelOne()
        unlockCurrentLevel(&game, from: 1)
        game.advance(angle: 128)
        unlockCurrentLevel(&game, from: 10)
        game.advance(angle: 110)
        unlockCurrentLevel(&game, from: 20)

        game.playAgain(angle: 82)
        #expect(game.phase == .playing(level: 0))
        #expect(game.holdStartedAt == nil)
        #expect(game.levels == GameConfig.levels)
    }

    @Test func newTargetsStayInTheMiddleOfTheHingeRange() {
        for seed in 0..<500 {
            var generator = SeededGenerator(seed: UInt64(seed))
            var game = gameOnLevelOne()
            game.newTargets(angle: 0, using: &generator)

            #expect(game.phase == .playing(level: 0))
            for (index, level) in game.levels.enumerated() {
                #expect(GameConfig.newTargetRange.contains(level.target))
                #expect(level.tolerance == GameConfig.levels[index].tolerance)
                if index > 0 {
                    #expect(abs(level.target - game.levels[index - 1].target) >= GameConfig.minimumTargetGap)
                }
            }
        }
    }
}

/// SplitMix64, so the New Targets test is repeatable.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
