# Instructions
Edit this file using simple, concise, clear language. Avoid unnecessary statements. Be brief yet detailed. Minimal grammar. Write in precise bullet points on what works and what doesn't.

# Implementation

## Architecture

- `ContentView` is the root orchestrator. It layers all views in a `ZStack` and manages visibility via `FocusedState` on `@State` variables. Each child view is wrapped in `FocusContainer` which applies blur/opacity/scale.
- `CoreNavigation` handles all page transitions independently of `FocusedState`. It computes its own unfocus progress from drag distance, keeping page-level transitions smooth and decoupled from the top-level focus system.
- `FocusedState` / `FocusContainer` are only used by `ContentView` for orchestrating the greeting → navigation → ambient player startup sequence and the ambient player dim-on-press behavior.
- All UI constants live in `UIConstants` enum namespace. No magic numbers in views.
- `LumenApp` (`@main`) and `ContentView` share the same file. No separate app entry point file.

## CoreNavigation

- All 4 pages are rendered simultaneously in a `ZStack` and offset to their base positions. The entire stack moves as one via a single `offset` state. This avoids adding/removing views during transitions.
- `unfocusProgress(for:)` computes a 0–1 value from the distance between current offset and the target page's offset. Scale, blur, and opacity are interpolated from this single progress value. This is faster and smoother than using `FocusedState` which would require state changes.
- Snap detection uses a 25% threshold of page step width/height. If the drag exceeds this threshold in the right direction, it snaps to that page. Otherwise it falls back to velocity-based prediction (0.12× velocity factor) and picks the nearest adjacent page.
- `adjacentPages(from:)` restricts side pages (left, right, bottom) to only navigate back to center. Center can reach all pages.
- `.interactiveSpring(response: 0.4, dampingFraction: 0.8)` gives a responsive but not bouncy snap.
- `.drawingGroup()` offloads the layered ZStack rendering to Metal, preventing frame drops during drag.
- `pageSpacing` (25pt) creates a visible gap between pages during transition.

## FocusedState

- Four states (`visible`, `subdued`, `subduedAlt`, `hidden`) with blur/opacity/scale computed from `UIConstants.Focus` constants.
- `subduedAlt` differs from `subdued` only in scale (0% vs 10%). Used when you want blur/opacity dimming without scale reduction.
- `FocusContainer` takes an `alignment` parameter. The `Alignment.anchor` extension maps alignments to `UnitPoint` so `scaleEffect` scales from the correct anchor (e.g., `.bottom` for ambient player).

## HomeView

- `Canvas` with `rendersAsynchronously: true` prevents the dot matrix from blocking the main thread. The matrix redraws every frame via `TimelineView(.animation)`.
- Dots are arranged in concentric rings: ring `n` has `5n` dots. Total rings scale with screen height plus 2× spacing overflow.
- Wave ripple uses `exp(-ringDist² * 0.6)` for a smooth bell-curve falloff. Wave speed scales with ring count to keep the animation consistent across devices.
- Long-press scale has a 0.15s delay before growth begins, preventing accidental scale on quick taps. The 0.6s quadratic easeInOut growth and reverse-release animation feel organic.
- `DotMatrixPressKey` environment key propagates press state up to `ContentView`, which dims the ambient player during hold.
- Two `RadialGradient` overlays at top and bottom edges fade dots to black, creating a vignette without clipping.

## AmbientPlayer

- Four `PlayerMode` states control the player's shape and content. Mode transitions use a custom spring (0.28 response, 0.92 damping) for quick, fluid morphing.
- `.mini` (45×45 bubble): only play/pause icon, no drag gesture. Tap toggles playback. Starting mode on launch.
- `.compact` (pill): play/pause + "Ambient" label. Entry point for drag gestures. Only entered once user plays.
- `.volume` (70% width slider): horizontal drag maps x-position to volume. Entry from compact via horizontal swipe (>1.5:1 ratio).
- `.expanded` (full source list): vertical list with selection highlighting. Entry from compact via vertical swipe (>1.5:1 ratio). Row detection uses `Int((location.y - 66) / 66)` to map vertical position to source index.
- `.glassEffect(.regular.interactive(), ...)` provides Liquid Glass appearance with interactive blur.
- `.sensoryFeedback(.impact)` on mode changes, `.sensoryFeedback(.selection)` on source selection changes.
- `onChange` of `selectedSourceID` saves playing state, calls `engine.load()`, then resumes only if already playing. This ensures: initial load doesn't auto-play; switching sources while playing continues seamlessly; switching while paused stays paused.
- `onChange` of `engine.isPlaying` switches between `.compact` (playing) and `.mini` (stopped).
- First source is loaded on appear but not played. User opts in by tapping play.

## AmbientEngine

- `@Observable` class (Observation framework, not Combine). Properties `isPlaying` and `volume` are tracked automatically.
- `volume` setter applies cubic curve: `player?.volume = pow(volume, 3)`. This matches iOS system volume feel where lower values have finer control.
- `load()` creates a fresh `AVAudioPlayer` each time. Previous player is stopped and nilled. This avoids state accumulation bugs.
- `configureSession()` sets category to `.playback` with no options (no mixing, no ducking). This allows background audio but doesn't interrupt other audio sources.
- No fade transitions on play/pause. Starts and stops instantly.

## AmbientSources

- `AmbientSource` is a simple value type. `id` is auto-generated `UUID()`.
- `url` is a computed property that searches the main bundle by filename matching. This is resilient to bundle structure changes.
- Only 2 sources (Rain, Wind). Audio files are `.m4a` stored in `Lumen/Ambient/`.

## CollectionsView

- `@MainActor` annotation ensures all UI state mutations happen on the main thread.
- `CardView` conforms to `Equatable` for efficient SwiftUI diffing during rapid rotation updates.
- 6 sample `Collection` objects with hardcoded data. No persistence layer yet.
- Cards are rendered in a horizontal strip above the turntable. Only the center card (within ±0.5 of fractional index) accepts hit testing.
- `cardFlickGesture`: requires >1.5:1 horizontal ratio and >300 velocity to trigger. Snaps exactly one `cardAngle` (45°) in the flick direction.
- `diskDragGesture`: angular tracking from turntable center. Dead zone (<100px from center) cancels drag. Angular velocity uses exponential smoothing (0.7/0.3 blend). On release: if velocity >100°/s, adds 1–2 extra card angles for momentum. Otherwise snaps to nearest.
- `LightGlowView` renders elliptical radial gradients offset to each card's position. Intensity fades with distance from center card.
- `TurntableReflectionsView` renders inverted, blurred (40pt) copies of nearby cards with a linear mask gradient. Creates a subtle reflection effect below the turntable.
- `TurntableTicksView`: 12 capsule marks at 30° intervals, rotating with total rotation.
- `.glassEffect(.regular, in: Circle())` on the turntable disk for Liquid Glass.
- Heavy haptic feedback per card ridge crossed during both flick and disk drag.

## Startup Sequence

- `ContentView.startSequence()` uses `DispatchQueue.main.asyncAfter` for timing:
  - 0.1s: greeting fades in (1s easeInOut)
  - 3.1s: greeting fades out, navigation and ambient fade in (1s easeInOut)
- `greetingState` starts as `.hidden`, `navigationState` as `.subduedAlt`, `ambientState` as `.subdued`.
- Ambient player dims to `.subdued` during dot matrix long press, returns to `.visible` on release.

## Known Limitations

- No persistence layer. Collections, tasks, and user progress are not saved.
- `UIConstants.General.screenWidth`/`screenHeight` are computed once at launch from `UIScreen`. Orientation changes are not handled.
- `screenCornerRadius` uses a private API key (`_displayCornerRadius`). Falls back to 55pt.
- `AmbientEngine.load()` creates a new player instance each time instead of seeking. Fine for 2 sources but won't scale.
- No error handling in `AmbientEngine` beyond initial session setup print.
- `CollectionsView` uses hardcoded sample data, not connected to any task/object system.
- `CoreNavigation` pages are all rendered simultaneously. Only the visible page is fully opaque, but off-screen pages still consume render resources. `.drawingGroup()` mitigates this.
- Volume slider in `.volume` mode uses raw `location.x` position, which doesn't account for the slider's leading padding offset precisely.

