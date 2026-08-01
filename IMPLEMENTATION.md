# Implementation

## Architecture

- `LumenApp` and `ContentView` share `ContentView.swift`. No separate app entry point file.
- `ContentView` is the root orchestrator. Layers all views in a `ZStack`, manages top-level visibility via `FocusedState` on `@State` variables. Passes `AmbientEngine` as `@State` to `AmbientPlayer`. Environment handlers extracted as method references. Startup uses structured concurrency (`Task.sleep`).
- `CoreNavigation` handles all 4 page transitions independently of `FocusedState`. Computes unfocus progress from drag distance — faster and smoother than state-driven dimming.
- `FocusedState`/`FocusContainer` only used by `ContentView` for startup sequence orchestration and ambient player dimming during dot matrix long-press.
- All UI constants live in `UIConstants` enum. No magic numbers in views. `screenCornerRadius` reads private `_displayCornerRadius` API (fallback 55pt).
- No persistence layer. All data hardcoded or ephemeral.

## CoreNavigation

### Layout & Rendering
- All 4 pages rendered simultaneously in `ZStack`, offset to base positions. Entire stack moves as one via single `offset` state. Avoids adding/removing views during transitions.
- Each page clipped to continuous `RoundedRectangle` matching device screen corner radius.
- `.compositingGroup()` applied before `.blur()` so blur composites the full page first.
- `.drawingGroup()` offloads layered ZStack to Metal, prevents frame drops during drag.
- `pageSpacing` (25pt) creates visible gap between pages during transition.

### Snap Logic
- `unfocusProgress(for:)` computes 0–1 from distance between current offset and target page offset. Scale, blur, opacity all derived from this single value, interpolating `FocusedState.subdued` (see FocusedState section) — navigation uses the same focus language as every other layer.
- Snap threshold: 25% of page step width/height. Falls back to velocity prediction (0.12× factor), picks nearest adjacent page.
- `adjacentPages(from:)`: side pages only navigate back to center. Center reaches all pages.
- Spring snap: `Animation.spring(duration: 0.5, bounce: 0.05)` — fluid settle with subtle bounce. Rubberband return: 0.6s critically damped.

### Rubberbanding
- Valid offset ranges computed per page from `adjacentPages` targets — each axis independently.
- Dragging within valid range: 1:1 direct manipulation (no resistance).
- Dragging past bounds: asymptotic UIScrollView curve `limit × (1 − 1/(|x|×c/limit + 1))` with `limit = 160`, `coefficient = 0.7`. Heavier than default UIScrollView (0.55) — strong resistance, never reaches max displacement.
- Applied per-axis independently — diagonal rubberbanding on both axes simultaneously works naturally.
- Return spring: `Animation.spring(duration: 0.55, bounce: 0.0)` — critically damped, weighty, no float.
- Snap logic uses rubberbanded offset values, making the25% displacement threshold harder to cross in invalid directions — prevents accidental navigation.

## FocusedState

- Four states: `visible`, `subdued`, `subduedAlt`, `hidden`. `visible` is the normal look; the other three are *relationships* to the shared subdued look in `UIConstants.Focus`:
  - `subdued`: recedes — blur 10, dim 0.65, scale 0.9.
  - `subduedAlt`: recedes without shrinking — blur 10, dim 0.65, scale 1.0.
  - `hidden`: dissolves — heavy "blur out" (blur 30) with `subdued`'s scale 0.9, plus a curved accelerating fade (`.easeIn`) to **opacity 0**, so the element is fully gone — no residual glow — by the end of the transition.
- Values are Apple-grounded (HIG "Materials"): the dim 0.65 matches Apple's guidance to layer a 35%-opacity dark scrim over bright content beneath clear glass; scale 0.9 matches the ~0.9 recession of iOS app-switcher / folder-open cards.
- Each state owns its motion *and* its fade: a `duration` (seconds), a `motion` spring, and a `fade` curve, used when transitioning INTO that state. Per Apple's motion guidance (WWDC18 "Designing Fluid Interfaces", WWDC23 "Animate with springs", HIG "Motion"): spring-driven and critically damped (`extraBounce: 0`). Timings are unhurried for an ambient app — focusing in is responsive (`visible` → `.snappy(duration: 0.4)`); yielding is fluid (`subdued`/`subduedAlt` → `.smooth(duration: 0.55)`); dissolving is longest and most atmospheric (`hidden` → `.smooth(duration: 0.7)` for blur/scale).
- `hidden`'s fade is deliberately different: opacity uses `.easeIn(duration: 0.7)` — Apple's classic exit pacing ("begins slowly, then speeds up") — which lands on exactly 0 at `duration`, guaranteeing invisibility (a spring would asymptote and leave a sub-1% residual).
- `FocusContainer` applies the two animations per property (blur/scale on `state.motion`, opacity on `state.fade`) internally, so call sites just set `state` — timing lives in one place, no `withAnimation` at the call site.
- `FocusContainer` composits content with `.compositingGroup()` before blur so blur/opacity/scale apply to a single layer (correct look, one blur pass), and accepts `alignment` parameter. `Alignment.anchor` extension maps to `UnitPoint` for correct `scaleEffect` anchor (e.g., `.bottom` for ambient player).
- Greeting, navigation, collection button (the Complete pill), and ambient player are all focus-driven through `FocusContainer` — none implement their own dim/blur/fade:
  - greeting: `greetingState` in `ContentView`
  - navigation: `navigationState` for the container; the drag-driven per-page *unfocus* interpolates `FocusedState.subdued` by drag progress (scale/blur/opacity all derived from the state, no inline constants)
  - collection button: `pillState` — a persistent `FocusContainer` (no `if`/`transition(.opacity)`); `isCardExpanded` only gates `.allowsHitTesting` so the hidden pill never blocks touches
  - ambient player: `ambientState`; its internal morph spring (0.35) is widget behavior, not focus

## Startup Sequence

- `startupSequence()` is an `async` function called via `.task` modifier. Beat timings are named constants so each is tuned independently. The whole greeting sequence runs in ~2.0s — a quiet, unhurried open (HIG "Launching" — launch instantly; "Onboarding" — splash just long enough to absorb at a glance):
  - `appearDelay` (100ms): pause before the entrance
  - greeting fades in with `FocusedState.visible` (snappy 0.4s)
  - `holdDuration` (0.8s): greeting dwells fully visible — measured from fade-in *completion* (via `FocusedState.visible.duration`), so dwell never varies with fade speed
  - greeting fades out with `FocusedState.hidden` (curved easeIn 0.7s) as navigation and ambient fade in with `FocusedState.visible` simultaneously — the interface is usable immediately, no separate reveal beat
- `.task` cancels automatically if view leaves hierarchy — no dangling timers.
- All motion is owned by `FocusedState.motion`/`fade`; the startup sequence sets states directly, with no `withAnimation`.
- Initial states: greeting `.hidden`, navigation `.subduedAlt`, ambient `.subdued`.
- Ambient player dims to `.subdued` during dot matrix long-press (fluid 0.55s smooth), returns to `.visible` on release (responsive 0.4s snappy) via `DotMatrixPressKey` environment key.

## HomeView (Dot Matrix)

### Rendering
- `Canvas<EmptyView>` with `rendersAsynchronously: true` keeps main thread free. `TimelineView(.animation)` drives continuous redraw.
- Dots arranged in concentric rings: ring `n` has `5n` dots. Total rings scale with screen height + 2× spacing overflow. Dot spacing: 44pt.
- Dot size: `(10 + ripple × 6) × scale`. Ripple adds up to 6pt, whole thing scales with long-press factor.

### Wave Ripple
- Uses `exp(-ringDist² × 0.55)` for wider, softer bell-curve falloff. Wave speed scales with `numRings / 6.0` for meditative pace. 0.8s quiet pause between ripples creates breathing rhythm.
- Ring rotation speed: 0.03 rad/s per ring index. All constants in `UIConstants.DotMatrix`.
- Two `RadialGradient` overlays (top/bottom, 35% screen height each) fade dots to black — vignette without clipping.

### Long-Press
- Uses SwiftUI `Spring` model (iOS 17+) instead of custom curve.
- Growth spring: `Spring(duration: 0.55, bounce: 0.05)`. Release spring: `Spring(duration: 0.4, bounce: 0.08)`.
- Release captures velocity at finger-lift via `growthSpring.velocity(fromValue:toValue:initialVelocity:time:)` and feeds into release spring — natural velocity preservation. Max scale: 1.5×. 0.15s minimum hold delay prevents accidental triggers.

## AmbientPlayer

### Player Modes
Four `PlayerMode` states controlling shape and content:

- **mini** (45×45 bubble): play/pause icon only. Tap toggles playback. Starting mode on launch.
- **compact** (pill): play/pause + "Ambient" label. Entry point for drag gestures. Only entered after user plays.
- **volume** (70% width slider): `GeometryReader`-based capsule fill slider. Entry from compact via horizontal swipe (>15pt, >1.5:1 ratio). Volume from `location.x` relative to slider width, 15pt leading offset.
- **expanded** (full source list): vertical list with selection highlighting. Entry from compact via vertical swipe (>30pt, >1.5:1 ratio). Row detection: `Int((location.y - 66) / 66)`.

### Animations & Feedback
- Mode transitions: `.spring(duration: 0.28, bounce: 0.04, blendDuration: 0.2)` — quick fluid morphing with velocity handoff.
- `.sensoryFeedback(.impact(weight: .light, intensity: 0.9), trigger: mode)` on mode changes. `.sensoryFeedback(.selection, trigger: selected)` on source selection.
- `.snappy` animation on source row selection/hover state changes (separate from mode transition spring).

### Glass & Layout
- `.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: style: .continuous))` for Liquid Glass.
- Corner radius: 22.5pt for all modes except `.expanded` which uses `screenCornerRadius - 10`.
- Expanded height: `66 + count × 60 + (count - 1) × 6 + 10`.
- Source rows: 40×40 icon box (rounded rect, cr 10, source color at 0.85 opacity), name, checkmark when selected. Background fill: 0.07 (selected), 0.15 (hovered), additive.

### Playback Logic
- `onChange` of `volume` forwards directly to `engine.volume`.
- `onChange` of `selectedSourceID`: saves playing state, calls `engine.load()`, resumes only if previously playing. Ensures initial load doesn't auto-play; switching while playing continues seamlessly; switching while paused stays paused.
- `onChange` of `engine.isPlaying`: switches to `.compact` (playing) or `.mini` (stopped).
- First source loaded on appear but not played. User opts in by tapping play.

## AmbientEngine

- `@Observable` class (Observation framework). Tracks `isPlaying` and `volume`.
- Volume defaults to 1.0. Cubic curve: `player?.volume = pow(volume, 3)` — matches iOS system volume feel (finer control at low values).
- `load()` creates fresh `AVAudioPlayer` each time, stops/nils previous. Applies cubic volume, sets infinite loop. Avoids state accumulation bugs.
- `configureSession()`: `.playback` category, `.default` mode, empty options. Activates session. No mixing, no ducking. Background audio without interrupting other sources.
- No fade transitions on play/pause. Starts and stops instantly.

## AmbientSources

- `AmbientSource` value type with auto-generated `UUID()` id.
- `url` computed property searches main bundle for `resourceName.fileExtension`. Resilient to bundle structure changes.
- 2 sources: Rain, Wind. Audio files `.m4a` in `Lumen/Ambient/`.

## CollectionsView

### Architecture
- `CollectionItem`: `Identifiable` (UUID) + `Equatable`. `Collection`: `Identifiable` (UUID) with `name`, `color`, `items`.
- `getCollection(at:)` wraps indices cyclically for infinite scrolling feel. Named to avoid collision with computed `collection` property.
- All spring constants as `Animation` extensions (`.cardSnap`, `.cardExpand`, `.cardDismiss`, `.cardCancel`, `.itemSwipe`) using `duration:bounce` API (WWDC2023).
- `CardLayout` pure-data struct (Equatable) describes single card's visual state. `cardLayouts()` computes all 5 visible cards per frame — eliminates scattered math in ViewBuilder.
- Only center card (within ±0.5 of fractional index) accepts hit testing. Expanded cards also accept hit testing.

### CardLayout System
- `cardLayouts(fractional:cardSize:spacing:expandedIndex:)` derives all 5 visible card layouts from single `fractional` index (negative rotation / 45°). Returns `[CardLayout]` with precomputed `scale`, `opacity`, `rotation`, `offsetX`, `offsetY`, `zIndex`.
- Parallax: scale 0.8–1.0 (`max(0.8, 1 - 0.12 × d)`), opacity 0–1 (`max(0, 1 - 0.2 × d)`), rotation ±10° (`delta × 10`), vertical offset quadratic (`d² × 16`), zIndex degrades with distance.
- Card spacing: `cardSize × (1 + cardSpacingRatio)` where `cardSize = screenWidth × 0.7`. Vertical position: `h/2 - 1.15×w - 30`.

### Gestures
Each gesture is a private method on `CollectionsView`, composed via `.highPriorityGesture`, `.simultaneousGesture`, `including:`.

- **cardFlickGesture()**: requires >1.5:1 horizontal ratio, >300 velocity. Snaps one `cardAngle` (45°) in flick direction.
- **diskDragGesture(center:)**: angular tracking from turntable center. 100pt dead zone cancels drag. Angular velocity uses exponential smoothing (0.7/0.3 blend). Release: if velocity >100°/s, asymmetric momentum (positive: -2 steps, negative: +1 step). Otherwise snaps nearest.
- **expandedDragGesture()**: unified gesture for item swipe (horizontal) and dismiss (vertical). Direction locks after 10pt, never changes mid-gesture.
- **handleItemSwipe(value:screenWidth:)**: immediate index update with overshoot offset, single spring settles to 0. Eliminates two-phase async animation that broke on rapid swipes.
- **handleDismiss(value:)**: tracks `dismissOffset` for direct-manipulation card movement. Dismisses if distance >80pt or velocity >300. Snaps back with no-bounce cancel spring otherwise.
- **tapGesture(index:expanded:distance:)**: only responds to center card (distance < 0.5). Sets `animatingIndex` for ghost card, animates expansion with `.cardExpand` spring.

### Card Expansion
- Tap center card expands to fullscreen (screenWidth × screenHeight, full corner radius, no rotation, no opacity reduction).
- `expandedIndex` tracks which card is expanded. `animatingIndex` (single index replaces old `animatingInIndex`/`animatingOutIndex`) manages ghost card z-index during dismiss animation timing (cleared after 0.5s delay).
- Ghost card at zIndex 0.5 mirrors expand/dismiss motion during animation, keeps visual continuity behind turntable (zIndex 1). Expanded card at zIndex 2.
- On expand: `itemIndex` resets to 0, `itemSwipeOffset` and `dismissOffset` reset to zero.

### ExpandedCollectionView
- Renders ALL items via `ForEach` inside `GeometryReader`, each positioned using circular wrapping: `wrappedDelta = raw - round(raw / count) × count`. Shortest path around ring — enables infinite looping.
- Adjacent items blur (up to 10pt) and fade by distance: within 0.5 screens fully visible, 0.5–1.5 screens progressive blur/fade, beyond 1.5 screens opacity 0.
- Collection name fixed at top. No page dots.
- Pure rendering component — no internal gestures or state. All gesture logic in `CollectionsView`.

### CardView (Efficient)
- `Equatable` with explicit `==` comparing all properties: `layout`, `size`, `expanded`, `dismissOffset`/`progress`, `swipeOffset`, `itemIndex`.
- Takes single `CardLayout` struct instead of 5+ individual parameters — reduces diff surface, makes equatability natural.
- Computes corner radius, scale, offset, content blur/opacity from layout + expanded state.
- During dismiss drag: corner radius transitions from `screenCornerRadius` down, scale reduces slightly, content blurs.

### Turntable
- Black circle (opacity 0.6) with tick marks overlaid. `.glassEffect(.regular, in: Circle())`. `.clipShape(Circle())` before glass effect.

### TickMarksView
- 8 capsule marks at 45° intervals, 7×40pt each. `LinearGradient` white→collection-color (top→bottom), masked with white→clear gradient. Rotates with total rotation.

### Haptics
- Single `UIImpactFeedbackGenerator(.medium)` created once per view instance. `prepare()` before batch, `impactOccurred(intensity: 1)` for each ridge crossed during disk drag. Also fires on card flick end.
- Item swipe uses separate lightweight generator.

### UIConstants.Collections
- `cardAngle` (45°), `cardWidthRatio` (0.7), `cardSpacingRatio` (0.2)
- `diskDeadZone` (100pt), `diskMomentumThreshold` (100°/s)
- `itemSwipeThreshold` (0.2), `itemSwipeVelocity` (300)
- `dismissDistance` (80pt), `dismissVelocity` (300), `dismissFullDistance` (150pt)
- `tickWidth` (7), `tickHeight` (40), `visibleCardRadius` (2)

## Glass Effect Ordering

- Apply `.rotationEffect` before `.glassEffect`. Glass effect breaks if applied before rotation in modifier chain. Inner view rotations (e.g., TickMarksView rotation inside ZStack) are safe as long as `.glassEffect` is applied after parent container's layout.

## Project Settings

- iOS-only build. `SDKROOT = iphoneos`, `SUPPORTED_PLATFORMS = "iphoneos iphonesimulator"`, `TARGETED_DEVICE_FAMILY = 1`.
- Mac Catalyst, MacDesignedForIPhone, and XRDesignedForIPhone all disabled.
- Platform settings (`SDKROOT`, `SUPPORTED_PLATFORMS`, `SUPPORTS_*`, `TARGETED_DEVICE_FAMILY`, `IPHONEOS_DEPLOYMENT_TARGET`) at project level — inherited by all targets.
- Signing and Info.plist settings at target level only.
- `ALWAYS_SEARCH_USER_PATHS = NO` suppresses headermap migration warning.
- Release: `DEAD_CODE_STRIPPING = YES`, `SWIFT_COMPILATION_MODE = wholemodule`, `SWIFT_OPTIMIZATION_LEVEL = "-O"`.

## Known Limitations

- No persistence layer. Collections, user progress, ambient preferences not saved between launches.
- `screenWidth`/`screenHeight` computed once at launch from `UIScreen`. Orientation changes not handled.
- `screenCornerRadius` reads private API key `_displayCornerRadius`. Falls back to 55pt.
- `AmbientEngine.load()` creates new player instance each time instead of seeking. Fine for 2 sources but won't scale to many.
- No error handling in `AmbientEngine` beyond initial session setup print.
- `CollectionsView` uses hardcoded sample data, not connected to task/object system.
- `CoreNavigation` renders all pages simultaneously. Off-screen pages still consume render resources despite `.drawingGroup()` mitigation.
- Volume slider uses raw `location.x` with fixed 15pt offset — doesn't account for `GeometryReader` frame precision.
- Expanded mode height calculation assumes fixed row sizes (60pt + 6pt spacing). Variable-height sources would break layout.
- `HomeView` uses fixed 44pt dot spacing. No adaptive scaling for different screen sizes.
- `BreatheView` and `MemoryView` are placeholder shells (colored background + title label).
