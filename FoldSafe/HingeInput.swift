import SwiftUI
import os

/// The one place the app touches Apple's hinge API.
///
///     Apple's public hinge API (onHingeChange)  →  HingeInput  →  GameModel  →  UI
///
/// The developer slider feeds the same `angle`, but always marked as
/// `.simulated`. Real hinge data is never silently replaced by simulated data.
@Observable
final class HingeInput {
    enum Source {
        case real
        case simulated
    }

    /// Where `angle` currently comes from.
    private(set) var source = Source.real

    /// The latest hinge angle from the system, in degrees (0° closed, 180° flat).
    /// Nil until the first update, or while this view hierarchy gets no hinge updates.
    private(set) var realAngle: Double?

    /// The latest hinge status from the system, for developer mode.
    private(set) var realStatus = "no update yet"

    /// How many hinge updates the system has delivered.
    private(set) var realUpdateCount = 0

    /// The developer slider's value, in degrees.
    private(set) var simulatedAngle = 90.0

    /// The angle the game uses.
    var angle: Double? {
        switch source {
        case .real: realAngle
        case .simulated: simulatedAngle
        }
    }

    private let log = Logger(subsystem: "dev.foldstate.FoldSafe", category: "hinge")

    /// Receives an update from Apple's hinge API.
    func receive(_ context: DeviceHingeContext) {
        realUpdateCount += 1
        guard let hinge = context.hinge else {
            realAngle = nil
            realStatus = "unavailable"
            log.notice("Real hinge unavailable in this view hierarchy")
            return
        }
        realAngle = hinge.angle.degrees
        realStatus = Self.describe(hinge.status)
        log.debug("Real hinge \(self.realStatus, privacy: .public) \(hinge.angle.degrees, format: .fixed(precision: 1), privacy: .public)°")
    }

    /// Switches to simulated input at the given angle. Developer mode only.
    func simulate(_ degrees: Double) {
        simulatedAngle = degrees
        source = .simulated
    }

    /// Switches back to the real hinge.
    func useRealHinge() {
        source = .real
    }

    private static func describe(_ status: DeviceHinge.Status) -> String {
        switch status {
        case .closed: "closed"
        case .partiallyOpen: "partially open"
        case .fullyOpen: "fully open"
        default: "unknown"
        }
    }
}

extension View {
    /// Feeds Apple's public hinge updates into `input`.
    func hingeUpdates(into input: HingeInput) -> some View {
        onHingeChange { _, newContext in
            input.receive(newContext)
        }
    }
}
