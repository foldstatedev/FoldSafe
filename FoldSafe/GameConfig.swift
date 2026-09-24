import Foundation

/// Every number that tunes the game lives here, so the targets can be changed in
/// one place once a physical iPhone Duo is available.
///
/// Angles are hinge angles in degrees, as the system reports them: 0° is closed
/// and 180° is flat.
enum GameConfig {

    /// The three levels, in order.
    static let levels = [
        // 128° is where DeviceHub's public "partially open" posture lands, so
        // Level 1 can be unlocked in the simulator with real hinge input.
        Level(target: 128, tolerance: 15, feedbackRange: 60),
        Level(target: 110, tolerance: 7, feedbackRange: 40),
        Level(target: 82, tolerance: 3, feedbackRange: 24),
    ]

    /// How long the hinge must stay inside the target before the safe opens.
    static let holdDuration: TimeInterval = 1.0

    /// How long a level's success message stays up before the next level starts.
    static let successPause: TimeInterval = 3.0

    /// NEW TARGETS picks every target from this middle range. Below about 60° the
    /// system can treat the phone as closed, and above about 160° it is
    /// effectively flat, so both ends are avoided.
    static let newTargetRange: ClosedRange<Double> = 75...150

    /// The smallest gap between one level's target and the next, so each level
    /// needs a real move.
    static let minimumTargetGap: Double = 30
}
