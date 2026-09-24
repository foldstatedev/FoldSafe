import SwiftUI

/// Colours used across the game.
enum Palette {
    /// Far from the target.
    static let far = Color(red: 1.00, green: 0.26, blue: 0.22)
    /// Getting close.
    static let near = Color(red: 1.00, green: 0.72, blue: 0.16)
    /// Inside the target, and unlocked.
    static let unlocked = Color(red: 0.20, green: 0.88, blue: 0.44)
    /// No game running, or no hinge signal.
    static let idle = Color(white: 0.5)
}

/// The vault, drawn from plain circles so the same design can be rebuilt in motion
/// graphics later. It holds no game logic: it draws the state it is given.
struct SafeView<Interior: View>: View {
    /// Colour of the proximity ring.
    var ringColor: Color
    /// Pulses the ring when the player is very close.
    var isPulsing: Bool
    /// 0 to 1, drawn as the green ring filling while the player holds still.
    var holdProgress: Double
    /// The hinge angle in degrees. The dial turns as the phone folds.
    var hingeAngle: Double
    /// Opens the door, with the unlock animation.
    var isOpen: Bool
    /// What the open door reveals.
    @ViewBuilder var interior: Interior

    @State private var ringCollapsed = false
    @State private var handleTurned = false
    @State private var doorOpen = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            vault(side: side)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .onAppear {
            // Recreated mid-game, for example when moving between screens:
            // show the current state without replaying the animation.
            ringCollapsed = isOpen
            handleTurned = isOpen
            doorOpen = isOpen
        }
        .onChange(of: isOpen) { _, open in
            if open { unlock() } else { lock() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isOpen ? "Safe, open" : "Safe, locked")
    }

    private func vault(side: CGFloat) -> some View {
        let ringDiameter = side * 0.94
        let ringWidth = side * 0.034

        return ZStack {
            // Light behind the safe, in the ring's colour.
            Circle()
                .fill(RadialGradient(colors: [ringColor.opacity(0.3), .clear],
                                     center: .center,
                                     startRadius: side * 0.3,
                                     endRadius: side * 0.62))
                .frame(width: side * 1.24, height: side * 1.24)
                .animation(.easeOut(duration: 0.25), value: ringColor)
                .opacity(ringCollapsed ? 0 : 1)

            // Proximity ring: red far away, amber closer, green inside the target.
            TimelineView(.animation(paused: !isPulsing)) { timeline in
                let beat = sin(timeline.date.timeIntervalSinceReferenceDate * 2 * .pi * 1.6)
                Circle()
                    .stroke(ringColor, lineWidth: ringWidth)
                    .shadow(color: ringColor.opacity(0.85), radius: ringWidth * (isPulsing ? 1.6 : 1))
                    .frame(width: ringDiameter, height: ringDiameter)
                    .scaleEffect(isPulsing ? 1 + 0.03 * beat : 1)
                    .animation(.easeOut(duration: 0.25), value: ringColor)
            }
            .scaleEffect(ringCollapsed ? 0.2 : 1)
            .opacity(ringCollapsed ? 0 : 1)

            // The hold: the green ring filling up.
            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(Palette.unlocked, style: StrokeStyle(lineWidth: ringWidth * 1.6, lineCap: .round))
                .shadow(color: Palette.unlocked, radius: ringWidth * 1.2)
                .rotationEffect(.degrees(-90))
                .frame(width: ringDiameter, height: ringDiameter)
                .opacity(ringCollapsed || holdProgress == 0 ? 0 : 1)

            VaultBody(side: side)

            VaultInterior(side: side) { interior }

            VaultDoor(side: side, turn: hingeAngle * 2 + (handleTurned ? 90 : 0))
                .rotation3DEffect(.degrees(doorOpen ? -78 : 0),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading,
                                  perspective: 0.45)
        }
    }

    /// The ring resolves into the centre, the handle turns, the door swings open.
    private func unlock() {
        withAnimation(.easeIn(duration: 0.3)) { ringCollapsed = true }
        withAnimation(.spring(duration: 0.55, bounce: 0.35).delay(0.25)) { handleTurned = true }
        withAnimation(.spring(duration: 0.95, bounce: 0.18).delay(0.7)) { doorOpen = true }
    }

    private func lock() {
        withAnimation(.spring(duration: 0.6, bounce: 0.1)) { doorOpen = false }
        withAnimation(.spring(duration: 0.45).delay(0.35)) { handleTurned = false }
        withAnimation(.easeOut(duration: 0.45).delay(0.5)) { ringCollapsed = false }
    }
}

/// The fixed part of the vault: the heavy frame, its bolts, and the mark the dial turns against.
private struct VaultBody: View {
    var side: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(AngularGradient(colors: [Color(white: 0.26), Color(white: 0.11), Color(white: 0.30),
                                               Color(white: 0.09), Color(white: 0.26)],
                                      center: .center))
            Circle()
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.03)],
                                             startPoint: .top, endPoint: .bottom),
                              lineWidth: side * 0.004)
            ForEach(0..<12, id: \.self) { index in
                Circle()
                    .fill(RadialGradient(colors: [Color(white: 0.62), Color(white: 0.14)],
                                         center: UnitPoint(x: 0.35, y: 0.3),
                                         startRadius: 0, endRadius: side * 0.02))
                    .frame(width: side * 0.034, height: side * 0.034)
                    .offset(y: -side * 0.362)
                    .rotationEffect(.degrees(Double(index) * 30 + 15))
            }
            IndexMark()
                .fill(.white.opacity(0.9))
                .frame(width: side * 0.036, height: side * 0.026)
                .offset(y: -side * 0.338)
        }
        .frame(width: side * 0.8, height: side * 0.8)
        .shadow(color: .black.opacity(0.7), radius: side * 0.05, y: side * 0.025)
    }
}

/// What sits behind the door: a lit cavity, and whatever the game puts inside.
private struct VaultInterior<Content: View>: View {
    var side: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color(red: 0.42, green: 0.36, blue: 0.22), Color(white: 0.02)],
                                     center: .center, startRadius: 0, endRadius: side * 0.34))
            Circle()
                .strokeBorder(.black.opacity(0.85), lineWidth: side * 0.03)
                .blur(radius: side * 0.012)
            content
                .foregroundStyle(.white)
                .padding(side * 0.07)
        }
        .frame(width: side * 0.64, height: side * 0.64)
        .clipShape(Circle())
    }
}

/// The round door. Its dial and handle turn with the hinge.
private struct VaultDoor: View {
    var side: CGFloat
    /// How far the dial and handle are turned, in degrees.
    var turn: Double

    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.36), Color(white: 0.13)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle()
                .strokeBorder(.white.opacity(0.2), lineWidth: side * 0.003)
            Circle()
                .stroke(.black.opacity(0.45), lineWidth: side * 0.006)
                .padding(side * 0.075)
            DialTicks(count: 60)
                .stroke(.white.opacity(0.6), lineWidth: side * 0.0045)
                .padding(side * 0.012)
                .rotationEffect(.degrees(turn))
            Handle(side: side)
                .rotationEffect(.degrees(turn))
        }
        .frame(width: side * 0.64, height: side * 0.64)
        .shadow(color: .black.opacity(0.55), radius: side * 0.02, y: side * 0.012)
    }
}

/// Three spokes and a hub.
private struct Handle: View {
    var side: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                ZStack {
                    Capsule()
                        .fill(LinearGradient(colors: [Color(white: 0.8), Color(white: 0.4)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: side * 0.03, height: side * 0.19)
                        .offset(y: -side * 0.095)
                    Circle()
                        .fill(Color(white: 0.82))
                        .frame(width: side * 0.05, height: side * 0.05)
                        .offset(y: -side * 0.19)
                }
                .rotationEffect(.degrees(Double(index) * 120))
            }
            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.9), Color(white: 0.32)],
                                     center: UnitPoint(x: 0.35, y: 0.3),
                                     startRadius: 0, endRadius: side * 0.07))
                .frame(width: side * 0.12, height: side * 0.12)
        }
    }
}

/// Tick marks around the edge of the dial, longer every fifth tick.
nonisolated private struct DialTicks: Shape {
    var count: Int

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * .pi
            let inner = radius * (index.isMultiple(of: 5) ? 0.82 : 0.89)
            let outer = radius * 0.96
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
        }
        return path
    }
}

/// A small triangle pointing down at the dial.
nonisolated private struct IndexMark: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}
