import SwiftUI

/// Hidden developer mode: the live numbers, which input is driving the game, and
/// a simulated hinge for testing without hardware. Players never see it.
///
/// Simulated input only exists while this panel is open (closing it switches back
/// to the real hinge), so the SIMULATED INPUT banner here is always on screen
/// whenever simulated data is driving the game.
struct DeveloperOverlay: View {
    var hinge: HingeInput
    var game: GameModel
    /// The fold's frame, if the current screen has one.
    var fold: CGRect?
    var now: Date
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if isSimulated {
                SimulatedBanner()
            }
            readouts
            Divider().overlay(Color.white.opacity(0.2))
            simulator
        }
        .padding(14)
        .frame(width: 320)
        .background(Color.black.opacity(0.88), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(Color.white.opacity(0.14)))
        .foregroundStyle(.white)
    }

    private var isSimulated: Bool { hinge.source == .simulated }

    private var header: some View {
        HStack {
            SectionTitle(text: "DEVELOPER MODE")
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            .accessibilityLabel("Close developer mode")
        }
    }

    private var readouts: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 4) {
            GridRow {
                Label(text: "INPUT SOURCE")
                Text(isSimulated ? "SIMULATED" : "REAL HINGE")
                    .fontWeight(.heavy)
                    .foregroundStyle(isSimulated ? Palette.near : Palette.unlocked)
            }
            row("REAL HINGE", "\(hinge.realStatus), \(degrees(hinge.realAngle))")
            row("REAL UPDATES", "\(hinge.realUpdateCount)")
            row("CURRENT ANGLE", degrees(hinge.angle))
            row("TARGET", degrees(game.currentLevel?.target))
            row("DIFFERENCE", degrees(difference))
            row("TOLERANCE", game.currentLevel.map { "±" + degrees($0.tolerance) } ?? "–")
            row("STATE", state)
            row("HOLD PROGRESS", String(format: "%.2f s of %.2f s",
                                        game.holdProgress(at: now) * GameConfig.holdDuration,
                                        GameConfig.holdDuration))
            row("FOLD", fold.map { "x \(Int($0.minX))–\(Int($0.maxX)), y \(Int($0.minY))–\(Int($0.maxY))" } ?? "none")
        }
        .font(.system(size: 12, weight: .medium, design: .monospaced))
    }

    private var simulator: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(text: "SIMULATE HINGE")
                Spacer()
                Text(degrees(hinge.simulatedAngle))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
            }
            Slider(value: Binding(get: { hinge.simulatedAngle }, set: { hinge.simulate($0) }),
                   in: 0...180)
                .tint(Palette.near)
            Button {
                hinge.useRealHinge()
            } label: {
                Text("USE REAL HINGE")
                    .font(.system(size: 14, weight: .bold).width(.expanded))
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
            }
            .buttonStyle(.borderedProminent)
            .tint(Palette.unlocked)
            .disabled(!isSimulated)
        }
    }

    private var difference: Double? {
        guard let level = game.currentLevel, let angle = hinge.angle else { return nil }
        return level.distance(to: angle)
    }

    private var state: String {
        switch game.phase {
        case .intro: "intro"
        case .playing(let index): "level \(index + 1), playing"
        case .unlocked(let index): "level \(index + 1), unlocked"
        case .complete: "complete"
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Label(text: label)
            Text(value)
        }
    }

    private func degrees(_ value: Double?) -> String {
        value.map { String(format: "%.1f°", $0) } ?? "–"
    }
}

/// Shown whenever simulated input is driving the game.
private struct SimulatedBanner: View {
    var body: some View {
        Text("SIMULATED INPUT")
            .font(.system(size: 15, weight: .heavy).width(.expanded))
            .tracking(1.5)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Palette.near, in: .rect(cornerRadius: 12))
    }
}

private struct SectionTitle: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .heavy).width(.expanded))
            .tracking(1.5)
            .foregroundStyle(Color.white.opacity(0.5))
    }
}

private struct Label: View {
    var text: String

    var body: some View {
        Text(text)
            .foregroundStyle(Color.white.opacity(0.5))
    }
}
