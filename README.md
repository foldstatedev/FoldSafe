# FoldSafe

A prototype iPhone Duo game you play by folding the phone. Open and close it to
find a hidden hinge angle, hold it there, and the safe cracks open. There are no
on-screen controls during play: the hinge is the controller.

Built for Fold State Episode 3. It is a proof of concept, not a product. It
answers one question: can the physical hinge of iPhone Duo be the primary
controller for a game?

> **Tested in the simulator only.** FoldSafe has been tested in the iPhone Duo
> simulator. Physical iPhone Duo hardware has not yet been tested.

## The hinge API

FoldSafe reads the hinge through one public API: SwiftUI's `onHingeChange`, new
in the iOS 27.1 SDK. It reports a continuous angle from 0° (closed) to 180°
(flat), plus a status. It does not exist in the iOS 27.0 SDK, which is why the
project needs Xcode 27.1 beta. FoldSafe uses no private API.

In the iPhone Duo simulator, all three levels were unlocked by hinge updates
arriving through `onHingeChange`, with DeviceHub simulating the hinge.
[BUILD_NOTES.md](BUILD_NOTES.md) has the evidence: exact API signatures, logs
and measurements.

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

## Build and run in the simulator

Requires Xcode 27.1 beta with the iOS 27.1 simulator runtime, which adds the
iPhone Duo simulator.

1. Open `FoldSafe.xcodeproj` in Xcode 27.1 beta. Xcode 27.0 cannot build it.
2. Pick the **iPhone Duo** simulator and press Run.
3. Tap START on the cover screen.
4. In DeviceHub, click **partially open**. The simulated phone opens to about
   128°, the ring turns green, and after a second the safe unlocks. That is
   Level 1, driven through `onHingeChange`.

DeviceHub's normal controls only reach three positions: closed, about 128° and
flat. For Levels 2 and 3, use developer mode's slider.

## Tests

```bash
xcodebuild test -project FoldSafe.xcodeproj -scheme FoldSafe -destination 'platform=iOS Simulator,name=iPhone Duo' -parallel-testing-enabled NO
```

Twelve unit tests cover the game logic: distance, the tolerance edges, the
one-second hold and its cancellation, level progression, Play Again and New
Targets. Parallel testing is off so that `xcodebuild` tests on your booted
iPhone Duo instead of shutting it down to make clones. Run it with Xcode 27.1
beta as the active developer directory, or prefix it with
`DEVELOPER_DIR="/Applications/Xcode 27.1 beta.app/Contents/Developer"`.

## Developer mode

Hidden by default. Triple-tap the top-left corner to open it, or launch with the
argument `-FoldSafeDeveloperMode YES`. It shows the input source, the live
angle, the target, the difference, the tolerance, the state, the hold progress
and where the fold is.

Its slider drives the game with a simulated angle. That is always labelled
**SIMULATED INPUT**, and closing developer mode switches back to
`onHingeChange`, so simulated data can never quietly stand in for hinge updates.

## What has been tested

Tested with Xcode 27.1 beta in the iPhone Duo simulator:

- the hinge path through Apple's public `onHingeChange` API
- all three levels, unlocked by hinge updates from the simulator
- developer mode's simulated input
- the game logic, through 12 automated tests

Not yet verified, because it needs physical iPhone Duo hardware:

- the real hinge's feel, precision and sensor behaviour
- holding an angle steady by hand, especially Level 3's ±3°
- the gameplay experience on a real device

Building for a device needs your own development team under Signing &
Capabilities. That has not been tried.

## Continuous hinge testing

DeviceHub's normal controls expose only a few fixed postures. During
development, an internal and unsupported DeviceHub control was used to test
arbitrary hinge angles in the simulator. That control is not part of Apple's
public app API and may change or disappear in future Xcode or DeviceHub
versions.

FoldSafe itself does not depend on that internal control. The app receives
hinge information through Apple's public `onHingeChange` API.

## Tech stack

- Swift 6 and SwiftUI, with AVFAudio for the sounds.
- iOS 27.1, iPhone only.
- No third-party dependencies, no backend, no network access, and no
  environment variables or secrets.

## Licence

MIT. See [LICENSE](LICENSE).
