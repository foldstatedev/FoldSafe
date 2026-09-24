# FoldSafe

A prototype iPhone Duo game you play by folding the phone. Open and close it to
find a hidden hinge angle, hold it there, and the safe cracks open. There are no
on-screen controls during play: the hinge is the controller.

It is a proof of concept, not a product. It answers one question: can the
physical hinge of iPhone Duo be the primary controller for a game?

## Requirements

Xcode 27.1 beta with the iOS 27.1 simulator runtime, which adds the iPhone Duo
simulator.

The hinge API it depends on, SwiftUI's `onHingeChange`, is new in the iOS 27.1
SDK. It does not exist in the iOS 27.0 SDK that ships with Xcode 27.0, so the
project will not build there.

## Licence

MIT. See [LICENSE](LICENSE).
