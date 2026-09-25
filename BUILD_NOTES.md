# BUILD_NOTES — FoldSafe

What was built, what was actually proven, and what still needs a physical
iPhone Duo. Everything below was measured on 24 and 25 September 2026. Nothing
here is inferred from code alone.

## At a glance

| Question | Answer |
| --- | --- |
| Is there a public hinge API? | Yes, new in the iOS 27.1 SDK. It is not in iOS 27.0. |
| Is the hinge angle continuous? | Yes. 0° closed to 180° flat, in steps as small as 0.3°. |
| Can the simulator drive it? | Yes, but the public controls only reach three positions. |
| Is the game driven by the real hinge? | Yes. All three levels were unlocked with real hinge input. |
| Tested on a physical device? | **No.** iPhone Duo is not available until 23 October 2026. |

## Toolchain

| | |
| --- | --- |
| Xcode | 27.1 beta, build **27A9269** (`/Applications/Xcode 27.1 beta.app`) |
| SDK | iOS **27.1**, build **24A94403** (`iphoneos27.1`, `iphonesimulator27.1`) |
| Swift | 6.4 (swiftlang-6.4.0.34.1), Swift 6 language mode |
| Deployment target | iOS 27.1, because the hinge API does not exist before it |
| Baseline | Xcode 27.0 (27A266a) is also installed. Its iOS 27.0 SDK has no hinge API at all, which is why the 27.1 beta is required. |

## Simulator

| | |
| --- | --- |
| Device | iPhone Duo (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, model `iPhone19,4`) |
| Runtime | iOS **27.1 (24A94401)** |
| Host app | DeviceHub 27.1 (255.6.6.1), inside Xcode 27.1 beta. Xcode 27 has no Simulator.app. |
| Screens | Cover 466 × 678 pt. Inner 669 × 951 pt, shown landscape as 951 × 669 with the fold down the middle. |

## Public API used

Exact declarations, copied from the iOS 27.1 SDK (`SwiftUICore.swiftinterface`):

```swift
@available(anyAppleOS 27.1, *)
extension View {
  nonisolated public func onHingeChange(
    isEnabled: Bool = true,
    _ action: @escaping (_ oldContext: DeviceHingeContext, _ newContext: DeviceHingeContext) -> Void
  ) -> some View
}

@available(anyAppleOS 27.1, *)
public struct DeviceHingeContext: Equatable, Sendable {
  public var hinge: DeviceHinge?
}

@available(anyAppleOS 27.1, *)
public struct DeviceHinge: Hashable, Sendable {
  public var status: DeviceHinge.Status   // .closed, .partiallyOpen, .fullyOpen
  public var angle: Angle
}
```

For the SAFE | MESSAGE layout, the fold's position comes from:

```swift
@available(anyAppleOS 27.1, *)
public func reservedRegions(kind: ReservedRegion.Kind,               // .division is the fold
                            options: ReservedRegion.QueryOptions = [], // .includeInactive
                            layoutDirectionBehavior: LayoutDirectionBehavior = .mirrors) -> [ReservedRegion]
// on GeometryProxy; ReservedRegion.frame is the fold, margins included
```

Where they are used:

- `FoldSafe/HingeInput.swift` is the only file that touches the hinge API
  (`onHingeChange`, `DeviceHingeContext`, `DeviceHinge`).
- `FoldSafe/GameScreen.swift`, in `foldFrame(in:)`, reads the fold with
  `reservedRegions(kind: .division, options: .includeInactive)`.

UIKit has the same API as `UIHingeInteraction` and `UIHinge` (the angle there is
in radians, and there is an extra `.unknown` status). The app does not use them.

The SDK header is explicit that the hinge is not a fixed-rate sensor:

> The rate and granularity of angle updates are system policy and can change
> based on system state, so don't depend on a particular update frequency or
> precision.

Other public frameworks: AVFAudio for the sounds (`AVAudioEngine`,
`AVAudioPlayerNode`, `AVAudioSession`, including iOS 27's `connectNode`,
`playAudio()` and asynchronous `activate(options:)`), and `os.Logger`.

**No private API.** No private frameworks, no IOKit hinge SPI, nothing from
DeviceKit, and the app never talks to DeviceHub. The internal DeviceHub slider
below is simulator tooling only.

## Is the hinge input real, simulated, or both?

Both, and they never mix silently.

- **Real:** `onHingeChange` delivers a continuous angle. This drives normal play.
- **Simulated:** the developer-mode slider. It is always labelled SIMULATED
  INPUT, and closing developer mode switches back to the real hinge.

## DeviceHub public controls

DeviceHub's normal action bar has three posture buttons:

| Button | Angle reported |
| --- | --- |
| Closed | about 0° |
| Partially open | about 128° (127.8° in the SpringBoard log) |
| Fully open | about 180° ("open flat") |

Switching between them sweeps the angle through the in-between values in under
a second (closed → partially open took 0.2–0.7 s across runs), so apps see a
real stream of angles. None of these controls can hold any other angle.

## Internal DeviceHub test (external tooling, not part of the app)

| | |
| --- | --- |
| Preference | `com.apple.dt.coredevicepop.useInternalV68ActionBar` |
| Owner | DeviceHub, domain `com.apple.dt.Devices`. The DeviceKit plugin that reads it (`CoreDevicePopDeviceKitExtension`) loads inside DeviceHub, and `defaults` resolves the domain to DeviceHub's container. |
| Original state | **Not set** (the key did not exist). Recorded before any change, with a full export of the domain as a backup. |
| Enable | `defaults write com.apple.dt.Devices com.apple.dt.coredevicepop.useInternalV68ActionBar -bool YES`, then quit (⌘Q) and reopen DeviceHub |
| **Restore** | `defaults delete com.apple.dt.Devices com.apple.dt.coredevicepop.useInternalV68ActionBar`, then quit (⌘Q) and reopen DeviceHub |
| Did it appear? | Yes. The three posture buttons were replaced by a continuous hinge slider, a tabletop control and a poses menu. |
| Arbitrary angles held? | Yes. It held steady at, for example, 25.5°, 46.3° and 115.1°. |
| Usable range | 0° to 180° |
| Stability | No crashes. DeviceHub ignores a quit signal (SIGTERM), so each change needed a manual ⌘Q and relaunch. Quitting DeviceHub also ends any log stream running inside the simulator. |
| Current state | **Restored** to the original "not set" at 11:37 and confirmed by reading it back. |

Nothing in the app depends on this setting.

## Level verification

| Level | Target | Verified with | Result |
| --- | --- | --- | --- |
| 1 | 128° ± 15° | **REAL** hinge: DeviceHub's public "partially open" button | Unlocked at 127.8° |
| 1 | 128° ± 15° | **REAL** hinge: internal DeviceHub slider | Unlocked at 116.5° |
| 2 | 110° ± 7° | **REAL** hinge: internal DeviceHub slider | Unlocked at 115.6° |
| 3 | 82° ± 3° | **REAL** hinge: internal DeviceHub slider | Unlocked at 79.4°, and again at 80.7° |

The app logs every hold and unlock with its angle and input source, for example
`Level 2 unlocked at 115.6° from REAL HINGE`.

### Level 1 with Apple's supported control, end to end

The strongest evidence that the real API controls the game. Level 1 was
waiting with the hinge closed. One click on DeviceHub's public "partially open"
button, then nothing else was touched:

```
11:37:45.087  Level 1 started                          real hinge closed 0.0°
11:42:30.574  SpringBoard: hinge state .closed → .partiallyOpen
11:42:30.575  real hinge 5.0° → 108.3° → 113.4° → 124.3° → 125.6° → 127.8°
11:42:30.706  Hold started at 113.4° from REAL HINGE   entered 113–143° mid-sweep
11:42:31.682  Level 1 unlocked at 127.8° from REAL HINGE
11:42:34.753  Level 2 started                           after the 3 s success pause
```

The chain was DeviceHub posture button → simulated hinge movement →
`onHingeChange` → `HingeInput` → `GameModel` → ring green → one-second hold →
safe unlocked. The hold finished on elapsed time while the hinge sat still at
127.8°.

### The simulated path, kept separate

The developer slider was also used to play all three levels, so the fallback is
proven too. Every unlock was logged as simulated, never as real:

| Level | Unlocked at | Logged source |
| --- | --- | --- |
| 1 | 134.2° and 132.7° (two runs) | SIMULATED |
| 2 | 113.5° and 103.8° | SIMULATED |
| 3 | 81.4° and 84.6° | SIMULATED |

### Hold cancellation

Verified with the real hinge, with the developer slider, and by unit tests.

**Real hinge.** Level 3 (82° ± 3°, so 79–85°) was played by hand on
25 September with DeviceHub's internal slider. Four holds were cancelled as the
hinge drifted out of the window before the fifth held for a full second:

```
11:00:42.481  Hold started at 81.8° from REAL HINGE
11:00:42.529  Hold cancelled at 78.5° after 0.05 s
11:01:12.446  Hold started at 80.1° from REAL HINGE
11:01:12.895  Hold cancelled at 85.8° after 0.45 s
11:01:14.072  Hold started at 83.6° from REAL HINGE
11:01:14.662  Hold cancelled at 85.5° after 0.60 s
11:01:17.787  Hold started at 83.9° from REAL HINGE
11:01:18.095  Hold cancelled at 78.2° after 0.32 s
11:01:19.331  Hold started at 79.8° from REAL HINGE
11:01:20.349  Level 3 unlocked at 80.7° from REAL HINGE. Game complete
```

That run also shows Level 3 doing its job: it takes fine adjustment.

**Developer slider.**

```
11:47:42.095  Hold started at 115.7° from SIMULATED     Level 2 window is 103–117°
11:47:42.293  Hold cancelled at 100.3° after 0.20 s     no unlock
11:49:35.282  Hold started at 84.6° from SIMULATED      Level 3 window is 79–85°
11:49:35.560  Hold cancelled at 85.1° after 0.28 s      0.1° outside, no unlock
```

DeviceHub's public posture buttons cannot show a cancellation: during Level 2
the "closed" sweep jumped from 120.1° straight to 98.3°, over the whole
103–117° window, so no hold started.

### Developer mode and restarting

- Opens with a triple-tap in the top-left corner, or with the launch argument
  `-FoldSafeDeveloperMode YES`.
- Shows INPUT SOURCE (REAL HINGE in green, SIMULATED in amber), the real hinge's
  status and angle, the update count, current angle, target, difference,
  tolerance, state, hold progress and the fold's frame.
- Moving its slider switches to simulated input and shows a SIMULATED INPUT
  banner. Closing it returns to the real hinge. After closing it on the final
  screen and tapping PLAY AGAIN, Level 1 showed FAR AWAY for the real hinge at
  0°, not the last simulated 84.6°.
- PLAY AGAIN restarts at Level 1 (checked on screen). NEW TARGETS is covered by
  a unit test that runs 500 seeded draws; it was not tapped on screen this
  session.

## Hinge behaviour measured in the simulator

From 565 real updates while the internal slider was dragged:

- Angles from 0.0° to 180.0°, with 468 distinct values.
- Steps as small as 0.3°, median 1.1°. That is fine enough for Level 3's ±3°.
- Updates arrived about every 50 ms while moving (about 20 a second; the fastest
  gap was 16 ms, the slowest 235 ms).
- Near the ends the angle snaps: below about 5° it reads 0°, and above about 175°
  it reads 180°.
- After the slider was released the angle stayed steady; it did not drift.
- The status is not the angle. While closing, the status became `closed` at
  60.4°, the same point where the game moved to the cover screen. While opening,
  it read `closed` at 5.0° and then `partially open` from 108.3°.
- For comparison, Apple ships a hardware capture in the runtime
  (`SpringBoardFoundation.framework/hinge-samples.csv`, recorded on an
  iPhone19,4): 0–180°, sampled about 100 times a second. What reaches apps on
  real hardware is still system policy and unverified.

## Physical device

**NOT TESTED.** A physical iPhone Duo is not available until 23 October 2026.
Everything above comes from the iOS 27.1 simulator.

## Known limitations

- **Hardware feel is unknown.** Update rate, precision, and how steady a hand
  can hold ±3° all need the real device.
- **Levels 1 and 2 overlap** between 113° and 117°. If Level 1 unlocks in that
  band, Level 2 starts with the hinge already on target. By design it then shows
  MOVE THE HINGE and waits for the hinge to leave and come back, so a level never
  opens without movement. This happened in testing: Level 1 unlocked at 116.5°.
- **The outer screen takes over as the phone closes.** SpringBoard, and the
  public hinge status, switched to closed at about 60° while closing (60.4°
  logged), and back to open just above 30° while opening. A target below about
  60° may flip the game to the cover screen, which is why New Targets stays
  between 75° and 150°. The game reads the angle, not the status, so it keeps
  working either way.
- **Fold region during screen changes.** While the game moves between screens,
  the fold is briefly reported in the other screen's coordinates (for about
  10 ms). The layout corrects itself on the next frame.
- **Public simulator controls reach only 0°, about 128° and 180°.** Levels 2 and 3
  need the internal DeviceHub slider, the developer slider, or hardware.
- **Sound plays even on silent.** The session uses the playback category, mixed
  with other audio, so sounds are heard on camera even if the phone is on silent.

## Build and test

- `xcodebuild` with Xcode 27.1 beta for the iPhone Duo simulator:
  **0 errors, 0 warnings.** Two iOS 27 deprecations (`AVAudioPlayerNode.play()`
  and `AVAudioEngine.connect(_:to:format:)`) were replaced with the SDK's named
  successors, `playAudio()` and `connectNode(_:to:format:)`.
- 12 unit tests (Swift Testing): **all passing.** They cover distance, the
  tolerance edges, hold start, hold cancellation, the one-second hold completing
  without further hinge events, a level that starts on target waiting for
  movement, Level 1 → 2 → 3 → complete, Play Again, and New Targets staying in
  range.
- Runtime log check: no SwiftUI runtime issues. One AVAudioSession "hang risk"
  fault, caused by activating the audio session synchronously on the main thread,
  was fixed by switching to the asynchronous `activate(options:)`. The remaining
  logged errors come from the simulator and system frameworks (CoreAudio tuning,
  keyboard tracking during screen switches), not from app code.
