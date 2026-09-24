import SwiftUI
import os

/// The game's only screen.
///
/// On the inner screen the fold splits it into SAFE | MESSAGE, placed around the
/// fold that `reservedRegions(kind: .division)` reports. The outer screen has no
/// fold, so there the safe sits above the message.
struct GameScreen: View {
    @State private var game = GameModel()
    @State private var hinge = HingeInput()
    @State private var showsDeveloperMode = false

    private let log = Logger(subsystem: "dev.foldstate.FoldSafe", category: "game")

    var body: some View {
        GeometryReader { proxy in
            let fold = foldFrame(in: proxy)
            TimelineView(.animation(paused: game.holdStartedAt == nil)) { timeline in
                ZStack {
                    layout(size: proxy.size, fold: fold, now: timeline.date)
                    if showsDeveloperMode {
                        DeveloperOverlay(hinge: hinge, game: game, fold: fold, now: timeline.date,
                                         close: toggleDeveloperMode)
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }
            }
            .onChange(of: layoutDescription(proxy, fold: fold), initial: true) { _, description in
                log.info("Layout \(description, privacy: .public)")
            }
        }
        .background(Backdrop())
        .overlay(alignment: .topTrailing) {
            if hinge.source == .simulated {
                SimulatedBadge().padding(16)
            }
        }
        .overlay(alignment: .topLeading) {
            developerModeCorner
        }
        .hingeUpdates(into: hinge)
        .onChange(of: hinge.angle) { _, angle in
            game.update(angle: angle, at: .now)
        }
        .onChange(of: game.phase) { _, phase in
            logPhase(phase)
        }
        .task(id: game.holdStartedAt) {
            await finishHold()
        }
        .task(id: game.phase) {
            await moveOnFromSuccess()
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
    }

    // MARK: Layout

    /// Where the fold is, in this view's coordinates, or nil on the outer screen.
    private func foldFrame(in proxy: GeometryProxy) -> CGRect? {
        let regions = proxy.reservedRegions(kind: .division, options: .includeInactive)
        guard let frame = regions.first?.frame else { return nil }
        let bounds = CGRect(origin: .zero, size: proxy.size)
        return bounds.contains(CGPoint(x: frame.midX, y: frame.midY)) ? frame : nil
    }

    /// The screen size, safe area and fold, for the log.
    private func layoutDescription(_ proxy: GeometryProxy, fold: CGRect?) -> String {
        let size = proxy.size
        let insets = proxy.safeAreaInsets
        let foldText = fold.map { "fold x \(Int($0.minX))–\(Int($0.maxX)), y \(Int($0.minY))–\(Int($0.maxY))" } ?? "no fold"
        return "\(Int(size.width))×\(Int(size.height)) pt, safe area top \(Int(insets.top)) leading \(Int(insets.leading)) "
            + "bottom \(Int(insets.bottom)) trailing \(Int(insets.trailing)), \(foldText)"
    }

    @ViewBuilder
    private func layout(size: CGSize, fold: CGRect?, now: Date) -> some View {
        if let fold, fold.height >= fold.width {
            // Inner screen, fold running top to bottom: SAFE | MESSAGE.
            HStack(spacing: 0) {
                safe(now: now)
                    .padding(28)
                    .frame(width: fold.minX)
                Color.clear
                    .frame(width: fold.width)
                message(compact: false)
                    .padding(.horizontal, 36)
                    .frame(width: max(size.width - fold.maxX, 0))
            }
        } else if let fold {
            // Inner screen, phone turned so the fold runs side to side: SAFE over MESSAGE.
            VStack(spacing: 0) {
                safe(now: now)
                    .padding(28)
                    .frame(height: fold.minY)
                Color.clear
                    .frame(height: fold.height)
                message(compact: false)
                    .padding(.vertical, 28)
                    .frame(height: max(size.height - fold.maxY, 0))
            }
        } else {
            // Outer screen: no fold, so stack them. The camera side reports a wide
            // safe-area inset, so centre on the physical screen instead of the
            // safe area; nothing here reaches the edges.
            VStack(spacing: 20) {
                safe(now: now)
                    .frame(maxHeight: size.height * 0.56)
                message(compact: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .horizontal)
        }
    }

    private func safe(now: Date) -> some View {
        let proximity = game.proximity(to: hinge.angle)
        return SafeView(ringColor: ringColor(for: proximity),
                        isPulsing: proximity == .almost,
                        holdProgress: game.holdProgress(at: now),
                        hingeAngle: hinge.angle ?? 0,
                        isOpen: game.isSafeOpen) {
            if game.phase == .complete {
                Text("THE PHONE\nWAS THE\nCONTROLLER")
                    .font(.system(size: 40, weight: .black).width(.expanded))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.3)
            }
        }
    }

    private func ringColor(for proximity: Proximity) -> Color {
        switch game.phase {
        case .intro:
            return Palette.idle
        case .unlocked, .complete:
            return Palette.unlocked
        case .playing:
            switch proximity {
            case .noSignal: return Palette.idle
            case .inside: return Palette.unlocked
            case .far, .closer, .almost:
                return Palette.far.mix(with: Palette.near, by: game.closeness(to: hinge.angle))
            }
        }
    }

    private func message(compact: Bool) -> some View {
        VStack(spacing: compact ? 18 : 28) {
            switch game.phase {
            case .intro:
                Headline(text: "CRACK THE\nSAFE", compact: compact)
                Subline(text: "Open and close the phone\nto find the unlock position.", compact: compact)
                Button("START") { game.start(angle: hinge.angle) }
                    .buttonStyle(PillButtonStyle(isProminent: true))
                    .padding(.top, 8)
            case .playing(let index):
                LevelDots(current: index, count: game.levels.count)
                Headline(text: Copy.levelTitles[index], compact: compact)
                StatusLabel(proximity: game.proximity(to: hinge.angle),
                            color: ringColor(for: game.proximity(to: hinge.angle)),
                            compact: compact)
            case .unlocked(let index):
                Headline(text: Copy.successTitles[index], compact: compact)
                Subline(text: Copy.successMessages[index], compact: compact)
            case .complete:
                Subline(text: "No joystick.\nNo slider.\nJust the hinge.", compact: compact)
                HStack(spacing: 12) {
                    Button("PLAY AGAIN") { game.playAgain(angle: hinge.angle) }
                        .buttonStyle(PillButtonStyle(isProminent: true))
                    Button("NEW TARGETS", action: newTargets)
                        .buttonStyle(PillButtonStyle(isProminent: false))
                }
                .padding(.top, 8)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(game.phase)
        .transition(.opacity.combined(with: .offset(y: 14)))
        .animation(.smooth(duration: 0.5), value: game.phase)
    }

    // MARK: Actions

    private func newTargets() {
        var generator = SystemRandomNumberGenerator()
        game.newTargets(angle: hinge.angle, using: &generator)
    }

    /// Finishes a hold on elapsed time alone, without waiting for another hinge event.
    private func finishHold() async {
        guard let start = game.holdStartedAt else { return }
        let remaining = GameConfig.holdDuration - Date.now.timeIntervalSince(start)
        if remaining > 0 {
            do {
                try await Task.sleep(for: .seconds(remaining))
            } catch {
                return  // The hold ended early: the player left the target.
            }
        }
        game.update(angle: hinge.angle, at: .now)
    }

    private func moveOnFromSuccess() async {
        guard case .unlocked = game.phase else { return }
        do {
            try await Task.sleep(for: .seconds(GameConfig.successPause))
        } catch {
            return
        }
        game.advance(angle: hinge.angle)
    }

    private func logPhase(_ phase: Phase) {
        let angle = hinge.angle.map { String(format: "%.1f°", $0) } ?? "no angle"
        let source = hinge.source == .real ? "REAL HINGE" : "SIMULATED"
        switch phase {
        case .intro:
            break
        case .playing(let index):
            log.notice("Level \(index + 1) started")
        case .unlocked(let index):
            log.notice("Level \(index + 1) unlocked at \(angle, privacy: .public) from \(source, privacy: .public)")
        case .complete:
            log.notice("Level 3 unlocked at \(angle, privacy: .public) from \(source, privacy: .public). Game complete")
        }
    }

    // MARK: Developer mode

    /// Triple-tap the top-left corner to open or close developer mode.
    private var developerModeCorner: some View {
        Color.clear
            .frame(width: 80, height: 80)
            .contentShape(Rectangle())
            .onTapGesture(count: 3, perform: toggleDeveloperMode)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }

    private func toggleDeveloperMode() {
        showsDeveloperMode.toggle()
        if !showsDeveloperMode {
            // Leaving developer mode always goes back to the real hinge.
            hinge.useRealHinge()
        }
    }
}

/// The words on screen, kept apart from the logic.
private enum Copy {
    static let levelTitles = ["FIND THE\nSWEET SPOT", "SMALLER\nTARGET", "TINY\nMOVEMENTS\nNOW"]
    static let successTitles = ["UNLOCKED", "NICE."]
    static let successMessages = ["You controlled that\nwith the hinge.", "ONE MORE."]
}

private struct Headline: View {
    var text: String
    var compact: Bool

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 34 : 46, weight: .heavy).width(.expanded))
            .foregroundStyle(.white)
            .lineLimit(3)
            .minimumScaleFactor(0.5)
    }
}

private struct Subline: View {
    var text: String
    var compact: Bool

    var body: some View {
        Text(text)
            .font(.system(size: compact ? 20 : 24, weight: .medium))
            .foregroundStyle(.white.opacity(0.72))
            .lineSpacing(4)
            .minimumScaleFactor(0.6)
    }
}

/// One colour-coded word or two, so the state reads with the sound off.
private struct StatusLabel: View {
    var proximity: Proximity
    var color: Color
    var compact: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(color: color, radius: 6)
            Text(word)
                .font(.system(size: compact ? 18 : 22, weight: .bold).width(.expanded))
                .tracking(2)
        }
        .foregroundStyle(color)
        .animation(.easeOut(duration: 0.2), value: proximity)
    }

    private var word: String {
        switch proximity {
        case .noSignal: "MOVE THE HINGE"
        case .far: "FAR AWAY"
        case .closer: "GETTING CLOSER"
        case .almost: "ALMOST THERE"
        case .inside: "HOLD IT"
        }
    }
}

private struct LevelDots: View {
    var current: Int
    var count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? Color.white : Color.white.opacity(0.22))
                    .frame(width: index == current ? 28 : 10, height: 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(current + 1) of \(count)")
    }
}

private struct PillButtonStyle: ButtonStyle {
    var isProminent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold).width(.expanded))
            .tracking(1.5)
            .foregroundStyle(isProminent ? Color.black : Color.white)
            .padding(.horizontal, 28)
            .frame(height: 54)
            .background(Capsule().fill(isProminent ? Color.white : Color.white.opacity(0.14)))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

private struct Backdrop: View {
    var body: some View {
        RadialGradient(colors: [Color(white: 0.11), Color(white: 0.02)],
                       center: .center, startRadius: 0, endRadius: 700)
            .ignoresSafeArea()
    }
}
