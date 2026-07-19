# Instructions
Edit this file using simple, concise, clear language. Avoid unnecessary statements. Be brief yet detailed. Minimal grammar. Write in precise bullet points on what works and what doesn't.

# Implementation

## Architecture

- `LumenApp` and `ContentView` share `ContentView.swift`. No separate app entry point file.
- `ContentView` is the root orchestrator. It layers all views in a `ZStack` and manages visibility via `FocusedState` on `@State` variables. Each child view is wrapped in `FocusContainer` which applies blur/opacity/scale.
- `ContentView` owns the `AmbientEngine` as `@State` and passes it to `AmbientPlayer`.
- `CoreNavigation` handles all page transitions independently of `FocusedState`. It computes its own unfocus progress from drag distance, keeping page-level transitions smooth and decoupled from the top-level focus system.
- `FocusedState` / `FocusContainer` are only used by `ContentView` for orchestrating the greeting → navigation → ambient player startup sequence and the ambient player dim-on-press behavior.
- All UI constants live in `UIConstants` enum namespace. No magic numbers in views.
- No persistence layer exists. All data is hardcoded or ephemeral.

## CoreNavigation

- All 4 pages are rendered simultaneously in a `ZStack` and offset to their base positions. The entire stack moves as one via a single `offset` state. This avoids adding/removing views during transitions.
- Each page is clipped to a continuous `RoundedRectangle` matching the device's screen corner radius.
- `.compositingGroup()` is applied before `.blur()` so blur applies to the fully composited page content rather than individual layers.
- `unfocusProgress(for:)` computes a 0–1 value from the distance between current offset and the target page's offset. Scale, blur, and opacity are interpolated from this single progress value. This is faster and smoother than using `FocusedState` which would require state changes.
- Snap detection uses a 25% threshold of page step width/height. If the drag exceeds this threshold in the right direction, it snaps to that page. Otherwise it falls back to velocity-based prediction (0.12× velocity factor) and picks the nearest adjacent page.
- `adjacentPages(from:)` restricts side pages (left, right, bottom) to only navigate back to center. Center can reach all pages.
- Snap animation: `.spring(duration: 0.45, bounce: 0.05)` — smooth settle with subtle bounce, matching `duration + bounce` API (iOS 17+).
- `.drawingGroup()` offloads the layered ZStack rendering to Metal, preventing frame drops during drag.
- `pageSpacing` (25pt) creates a visible gap between pages during transition.

## FocusedState

- Four states (`visible`, `subdued`, `subduedAlt`, `hidden`) with blur/opacity/scale computed from `UIConstants.Focus` constants.
- `subdued` applies: blur 10, opacity 80%, scale 0.9 (10% reduction).
- `subduedAlt` applies: blur 10, opacity 80%, scale 1.0 (0% reduction). Used when you want blur/opacity dimming without scale reduction.
- `hidden` applies: blur 20, opacity 0%, scale 0.8 (20% reduction).
- `FocusContainer` takes an `alignment` parameter. The `Alignment.anchor` extension maps alignments to `UnitPoint` so `scaleEffect` scales from the correct anchor (e.g., `.bottom` for ambient player).

## HomeView

- `Canvas<EmptyView>` with `rendersAsynchronously: true` prevents the dot matrix from blocking the main thread. The matrix redraws every frame via `TimelineView(.animation)`.
- Dots are arranged in concentric rings: ring `n` has `5n` dots. Total rings scale with screen height plus 2× spacing overflow. Dot spacing is 44pt.
- Dot size is dynamic: `(UIConstants.DotMatrix.dotSize + ripple * UIConstants.DotMatrix.rippleScale) * scale`. Base dot size is 10pt, ripple adds up to 6pt, and the whole thing scales with the long-press scale factor.
- Wave ripple uses `exp(-ringDist² * 0.6)` for a smooth bell-curve falloff. Wave speed scales with ring count to keep the animation consistent across devices.
- Long-press scale has a 0.15s delay before growth begins, preventing accidental scale on quick taps. The 0.6s custom quadratic easeInOut growth and reverse-release animation feel organic. Max scale is 1.5×.
- `DotMatrixPressKey` environment key propagates press state up to `ContentView`, which dims the ambient player during hold.
- Two `RadialGradient` overlays at top and bottom edges (35% screen height each) fade dots to black, creating a vignette without clipping.

## AmbientPlayer

- Four `PlayerMode` states control the player's shape and content. Mode transitions use `.spring(duration: 0.28, bounce: 0.04, blendDuration: 0.2)` for quick, fluid morphing. `blendDuration: 0.2` ensures smooth velocity handoff during rapid mode changes.
- `.mini` (45×45 bubble): only play/pause icon, no drag gesture. Tap toggles playback. Starting mode on launch.
- `.compact` (pill): play/pause + "Ambient" label. Entry point for drag gestures. Only entered once user plays. Fills available width (nil width).
- `.volume` (70% width slider): `GeometryReader`-based slider with capsule fill. Entry from compact via horizontal swipe (>15pt distance, >1.5:1 horizontal ratio). Volume is mapped from `location.x` relative to slider width, accounting for 15pt leading padding.
- `.expanded` (full source list): vertical list with selection highlighting. Entry from compact via vertical swipe (>30pt distance, >1.5:1 vertical ratio). Row detection uses `Int((location.y - 66) / 66)` to map vertical position to source index. Header area (row 0) does not highlight.
- `.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: style: .continuous))` provides Liquid Glass appearance with interactive blur.
- `.sensoryFeedback(.impact(weight: .light, intensity: 0.9), trigger: mode)` on mode changes. `.sensoryFeedback(.selection, trigger: selected) { _, newValue in newValue }` on source selection (fires only when selected becomes true, not when deselected).
- `.snappy` animation on source row selection/hover state changes, separate from the mode transition spring.
- `onChange` of `volume` directly forwards to `engine.volume`.
- `onChange` of `selectedSourceID` saves playing state, calls `engine.load()`, then resumes only if already playing. This ensures: initial load doesn't auto-play; switching sources while playing continues seamlessly; switching while paused stays paused.
- `onChange` of `engine.isPlaying` switches between `.compact` (playing) and `.mini` (stopped).
- First source is loaded on appear but not played. User opts in by tapping play.
- Expanded height is computed dynamically: `66 + count * 60 + (count - 1) * 6 + 10` where count is the number of sources.
- Corner radius is 22.5pt for all modes except `.expanded` which uses `screenCornerRadius - 10`.
- Source rows show a colored icon box (40×40, rounded rect with corner radius 10, source color at 0.85 opacity), source name, and a checkmark when selected. Background fill opacity changes on hover/select (0.07 for selected, 0.15 for hovered, additive).

## AmbientEngine

- `@Observable` class (Observation framework, not Combine). Properties `isPlaying` and `volume` are tracked automatically.
- `volume` defaults to `1.0`. Setter applies cubic curve: `player?.volume = pow(volume, 3)`. This matches iOS system volume feel where lower values have finer control.
- `load()` creates a fresh `AVAudioPlayer` each time. Previous player is stopped and nilled. This avoids state accumulation bugs. Also applies current cubic volume and sets infinite loop (`numberOfLoops = -1`).
- `configureSession()` sets category to `.playback` with `.default` mode and empty options, then activates the session. No mixing, no ducking. This allows background audio but doesn't interrupt other audio sources.
- No fade transitions on play/pause. Starts and stops instantly.

## AmbientSources

- `AmbientSource` is a simple value type. `id` is auto-generated `UUID()`.
- `url` is a computed property that searches the main bundle for files matching `resourceName.fileExtension`. Resilient to bundle structure changes.
- Only 2 sources (Rain, Wind). Audio files are `.m4a` stored in `Lumen/Ambient/`.

## CollectionsView

- `Collection` struct has `name`, `color`, and auto-generated `id`. 8 sample objects with hardcoded data. No persistence layer.
- `collection(at:)` wraps indices cyclically for infinite scrolling feel.
- `CardView` conforms to `Equatable` for efficient SwiftUI diffing during rapid rotation updates.
- Cards are rendered in a horizontal strip above the turntable. Only the center card (within ±0.5 of fractional index) accepts hit testing. Expanded cards also accept hit testing.
- Card parallax: scale reduces (0.8–1.0 via `max(0.8, 1 - 0.12 * d)`), opacity reduces (0–1 via `max(0, 1 - 0.2 * d)`), rotation adds ±10° (`delta * 10`), and vertical offset increases quadratically with distance from center (`d * d * 16`).
- Cards spacing is `cardSize + 20` where `cardSize` is 70% of screen width. Cards are positioned at `h/2 - 1.15*w - 30` vertically.

### Card Expansion

- Tap gesture on center card expands it to fullscreen (`screenWidth × screenHeight`, full corner radius, no rotation, no opacity reduction).
- `expandedIndex` tracks which card is expanded. `animatingOutIndex` manages z-index during dismiss animation timing (cleared after 0.5s delay).
- `dismissDragGesture` tracks finger offset on expanded card. Dismisses if drag distance >80pt or velocity magnitude >300. If threshold not met, snaps back with no-bounce cancel spring.
- During drag-to-dismiss: corner radius transitions toward 28 (max 30% of the way), scale shrinks max ~3%, position follows finger exactly for direct-manipulation feel. Progress is computed as `distance / 150`.
- `dismissSpring` (duration 0.35, bounce 0.15) for successful dismiss. `cancelSpring` (duration 0.3, bounce 0) for cancelled dismiss.
- z-index management: expanded card at 2, animating-out card at 1, others at 0.
- Tap on expanded card also collapses (with `transitionSpring`).

### Turntable

- Turntable disk is a simple black circle (`opacity 0.6`) with tick marks overlaid.
- `.glassEffect(.regular, in: Circle())` on the turntable disk for Liquid Glass.
- `.clipShape(Circle())` before glass effect.

### TickMarksView

- 8 capsule marks at 45° intervals, each 7×40pt. Fill is a `LinearGradient` from white to collection color (top to bottom), masked with a `LinearGradient` from white to clear (top to bottom). Rotates with total rotation.

### Card Flick Gesture

- `cardFlickGesture`: requires >1.5:1 horizontal ratio and >300 velocity to trigger. Snaps exactly one `cardAngle` (45°) in the flick direction.

### Disk Drag Gesture

- `diskDragGesture`: angular tracking from turntable center. Dead zone (<100px from center) cancels drag and snaps to nearest. Angular velocity uses exponential smoothing (0.7/0.3 blend). On release: if velocity >100°/s, adds asymmetric extra card angles for momentum (positive velocity adds -2 steps, negative adds +1 step). Otherwise snaps to nearest.
- Heavy `UIImpactFeedbackGenerator` (`.medium` style, `intensity: 1`) per card ridge crossed during both flick and disk drag.

### Named Springs

- `snapSpring`: `Animation.spring(duration: 0.45, bounce: 0.05)` — smooth with subtle bounce for turntable snap-to.
- `transitionSpring`: `Animation.spring(duration: 0.4, bounce: 0.05)` — smooth with subtle bounce for expand/collapse via tap.
- `dismissSpring`: `Animation.spring(duration: 0.35, bounce: 0.15)` — bouncy dismiss respecting gesture momentum.
- `cancelSpring`: `Animation.spring(duration: 0.3, bounce: 0)` — no-bounce cancel when drag doesn't meet threshold.

## Startup Sequence

- `ContentView.startSequence()` uses `DispatchQueue.main.asyncAfter` for timing:
  - 0.1s: greeting fades in (0.8s smooth)
  - 3.1s: greeting fades out, navigation and ambient fade in (0.8s smooth)
- All startup transitions use `.smooth(duration: 0.8)` — Apple's recommended non-spring default for content fades.
- `greetingState` starts as `.hidden`, `navigationState` as `.subduedAlt`, `ambientState` as `.subdued`.
- Ambient player dims to `.subdued` during dot matrix long press with `.smooth(duration: 0.6)`, returns to `.visible` on release.

## Glass Effect Ordering

- Always apply `.rotationEffect` before `.glassEffect`. Glass effect breaks if applied before rotation in the modifier chain. Inner view rotations (e.g., TickMarksView rotation inside a ZStack) are fine as long as the `.glassEffect` is applied after the parent container's layout.

## Known Limitations

- No persistence layer. Collections, user progress, and ambient preferences are not saved between launches.
- `UIConstants.General.screenWidth`/`screenHeight` are computed once at launch from `UIScreen`. Orientation changes are not handled.
- `screenCornerRadius` uses a private API key (`_displayCornerRadius`). Falls back to 55pt.
- `AmbientEngine.load()` creates a new player instance each time instead of seeking. Fine for 2 sources but won't scale.
- No error handling in `AmbientEngine` beyond initial session setup print.
- `CollectionsView` uses hardcoded sample data, not connected to any task/object system.
- `CoreNavigation` pages are all rendered simultaneously. Only the visible page is fully opaque, but off-screen pages still consume render resources. `.drawingGroup()` mitigates this.
- Volume slider in `.volume` mode uses raw `location.x` position with a fixed 15pt padding offset, which doesn't account for GeometryReader frame precision.
- `AmbientPlayer` expanded mode height calculation is based on source count and assumes fixed row sizes (60pt content + 6pt spacing per row). Adding sources with variable heights would break the layout.
- `HomeView` uses a fixed 44pt dot spacing. No adaptive scaling for different screen sizes.
