# FoldSafe

A prototype iPhone Duo game you play by folding the phone. Open and close it to
find a hidden hinge angle, hold it there, and the safe cracks open. There are no
on-screen controls during play: the hinge is the controller.

It is a proof of concept, not a product. It answers one question: can the
physical hinge of iPhone Duo be the primary controller for a game?

## The answer

Yes. The iOS 27.1 SDK adds a public hinge API. In SwiftUI it is
`onHingeChange`, which reports a continuous angle from 0° (closed) to 180°
(flat) and a status. In the iPhone Duo simulator, all three levels were unlocked
by real hinge input through that API, not by a slider.

[BUILD_NOTES.md](BUILD_NOTES.md) has the evidence: exact API signatures, logs,
measurements, and what still needs a physical device.

## How it works

```
PHONE MOVES  →  ANGLE  →  CHECK  →  UNLOCK
```

| Step | File | What it does |
| --- | --- | --- |
| Angle | `HingeInput.swift` | The only file that touches Apple's hinge API. It turns `onHingeChange` into an angle in degrees. |
| Check | `GameModel.swift` | Plain logic. How far is the angle from the target, is it inside the tolerance, has it stayed there for a second? |
| Targets | `GameConfig.swift` | Every tunable number in one place: 128° ± 15°, 110° ± 7°, 82° ± 3°. |
| Unlock | `SafeView.swift` | The vault. The dial turns with the hinge, the ring goes red → amber → green, fills during the hold, then the door swings open. |
| Screen | `GameScreen.swift` | Places the safe to the left of the fold and the message to the right, using the fold position from `reservedRegions(kind: .division)`. On the cover screen they stack. |
| Sound | `SoundEffects.swift` | Dial clicks that rise in pitch as you get closer, a chime, a hold tone, and the unlock. All synthesised in code: no audio files. |

The game needs the hinge to stay inside the target for one full second, so
swinging straight through the target does nothing. Leaving early resets the hold.

## Run it

Requires Xcode 27.1 beta with the iOS 27.1 simulator runtime.

1. Open `FoldSafe.xcodeproj` in Xcode 27.1 beta. Xcode 27.0 cannot build it.
2. Pick the **iPhone Duo** simulator and press Run.
3. Tap START on the cover screen.
4. In DeviceHub, click **partially open**. The phone opens, the ring turns green,
   and after a second the safe unlocks. That is Level 1, played with the hinge.

Levels 2 and 3 need angles the public DeviceHub buttons cannot reach (only
closed, about 128°, and flat). Use developer mode's slider, or DeviceHub's
internal hinge slider (see BUILD_NOTES.md), or wait for the hardware.

To run the tests:

```bash
xcodebuild test -project FoldSafe.xcodeproj -scheme FoldSafe -destination 'platform=iOS Simulator,name=iPhone Duo' -parallel-testing-enabled NO
```

Parallel testing is off so that `xcodebuild` tests on your booted iPhone Duo
instead of shutting it down to make clones. Run it with Xcode 27.1 beta as the
active developer directory, or prefix it with
`DEVELOPER_DIR="/Applications/Xcode 27.1 beta.app/Contents/Developer"`.

## Developer mode

Hidden by default. Triple-tap the top-left corner to open it, or launch with the
argument `-FoldSafeDeveloperMode YES`. It shows the input source, the live
angle, the target, the difference, the tolerance, the state, the hold progress
and where the fold is.

Its slider drives the game with a simulated angle. That is always labelled
**SIMULATED INPUT**, and closing developer mode switches back to the real hinge,
so simulated data can never quietly stand in for the real thing.

## Requirements

Xcode 27.1 beta with the iOS 27.1 simulator runtime, which adds the iPhone Duo
simulator.

The hinge API it depends on, SwiftUI's `onHingeChange`, is new in the iOS 27.1
SDK. It does not exist in the iOS 27.0 SDK that ships with Xcode 27.0, so the
project will not build there.

## Licence

MIT. See [LICENSE](LICENSE).
