# Lumen
## Instructions
Edit this file using simple, concise, clear language. Avoid unnecessary statements. Be brief yet detailed. Minimal grammar.

## Vision
Lumen is a place to slow down, reset, and regain steady momentum. It exists for people who feel overwhelmed, mentally exhausted, or disconnected from their progress. Tasks are not the purpose of the app, they provide the momentum needed to pursue more meaningful parts of life. Completing tasks earns objects that can be collected and eventually placed inside a personal Room, creating a quiet record of growth. Every interaction should leave the user feeling calmer, more grounded, and gently motivated without pressure, urgency, or unnecessary complexity.

## Design & Philosophy
Lumen is built around Apple's latest design language and should always feel like a natural extension of iOS. Prefer native APIs, system behaviors, and platform conventions over custom implementations whenever possible. Liquid Glass is the foundation of the interface, with fluid motion, meaningful depth, restrained visuals, and tactile interactions. Performance is a feature; every animation, gesture, and transition should remain smooth and responsive. The UI should feel elegant, minimal, immersive, and effortless, with exceptional UX taking priority over visual decoration or feature count.

## Current State
- **Startup Sequence** - Time-of-day greeting (`GreetingView`) fades in/out on launch, transitioning to main interface.
- **T-Navigation** - Drag gestures navigate a 4-page layout (`CoreNavigation`): Center (Home), Left (Memory), Right (Breathe), Bottom (Collections). Page transitions compute blur, opacity, and scale locally based on drag distance with spring animations. Uses `.drawingGroup()` for rendering performance.
- **Home Screen** - Async-rendered canvas dot matrix (`HomeView`) with concentric rings, continuous time-based wave ripple, long-press scale reaction with delayed onset and smooth release, and RadialGradient edge fading.
- **Ambient Player** - Gesture-driven `AmbientPlayer` with four modes: `.mini` (45pt play/pause bubble), `.compact` (label pill), `.volume` (70% width slider), `.expanded` (full source list). Uses Liquid Glass, sensory feedback, and spring animations. Backed by `@Observable` `AmbientEngine` (cubic volume, background audio session) and `AmbientSources` (Rain, Wind).
- **Collections** - Turntable (`CollectionsView`) with 6 sample collections rendered as cards. Cards support flick gestures and the turntable disk supports angular drag with velocity-based momentum. Includes light glow effects, reflections, tick marks, and heavy haptic feedback per card snap.
- **Placeholders** - `BreatheView` and `MemoryView` are basic colored screens.

## File Reference

### `ContentView.swift`
**Implementation:**
- Contains `LumenApp` (`@main` entry point) and `ContentView`.
- `ContentView` uses `ZStack` layering: black background, `CoreNavigation` in `FocusContainer`, `GreetingView` in `FocusContainer`, `AmbientPlayer` in `FocusContainer` (bottom-aligned).
- `@State` variables `greetingState`, `navigationState`, `ambientState` of type `FocusedState` control visibility of each layer.
- `startSequence()` animates: greeting fades in after 0.1s, then fades out at 3.1s while navigation and ambient fade in.
- Responds to `onDotMatrixPress` environment callback to dim ambient player during long press on home.
**User Wants:**
- Minimal code. Only handle initialization and layering of views.

### `CoreNavigation.swift`
**Implementation:**
- Private `Page` enum: `.center`, `.left`, `.right`, `.bottom`.
- All pages rendered simultaneously in a `ZStack`, offset to their base positions. The entire stack moves via a single `offset` state.
- `unfocusProgress(for:)` computes 0–1 progress based on distance from a page's target offset. `focusScale`, `focusBlur`, `focusOpacity` derive per-page visual effects from this progress (not using `FocusedState`).
- `dragGesture` updates offset during drag. On end: computes a 25% displacement threshold for snap direction, falls back to velocity-based prediction, then snaps to nearest adjacent page.
- `adjacentPages(from:)` restricts navigation: center can reach all, side pages only return to center.
- Uses `.interactiveSpring(response: 0.4, dampingFraction: 0.8)` for snap animation.
- Uses `.drawingGroup()` for Metal-backed rendering of the layered pages.
**User Wants:**
- Insanely fluid, performant navigation base.
- T-shaped layout with 4 pages.
- Overscroll, bounce effects.

### `FocusedStates.swift`
**Implementation:**
- `FocusedState` enum: `visible`, `subdued`, `subduedAlt`, `hidden`.
- Computed `blur`, `opacity`, `scale` properties sourced from `UIConstants.Focus` constants.
- `FocusContainer` applies blur, opacity, and scale to its content based on state and an `alignment` anchor.
- `Alignment.anchor` extension maps SwiftUI alignments to `UnitPoint` for scale anchor.
**User Wants:**
- Clean, elegant, gorgeous states. Applicable everywhere.
- `visible`: fully visible. `subdued`: blurs, dims, scales down. `subduedAlt`: same as subdued, no scaling. `hidden`: blurs out, dims, scales to disappear.

### `UIConstants.swift`
**Implementation:**
- Enum-based namespace with nested enums: `Navigation`, `DotMatrix`, `Focus`, `General`.
- `Navigation`: `pageSpacing` (25), `unfocusScale`, `unfocusBlur`.
- `DotMatrix`: `dotSize` (10), `rippleScale` (6).
- `Focus`: blur/opacity/scale values for each `FocusedState`.
- `General`: `screenWidth`, `screenHeight` from `UIScreen`, `screenCornerRadius` from private display API.
**User Wants:**
- Minimal code. Declare global constants. Clear separation by subcategory.

### `AmbientPlayer.swift`
**Implementation:**
- `PlayerMode` enum: `.mini`, `.compact`, `.volume`, `.expanded`.
- `.mini`: 45×45pt bubble with play/pause icon. Tap toggles playback. No drag gesture.
- `.compact`: pill with play/pause icon and "Ambient" label. Drag up (>1.5:1 vertical ratio) → `.expanded`. Drag horizontal (>1.5:1 ratio) → `.volume`.
- `.volume`: 70% screen width. Drag maps horizontal position to volume 0–1.
- `.expanded`: full-width source list. Drag highlights rows by vertical position. Release selects hovered source and returns to `.compact`.
- Uses `.glassEffect(.regular.interactive(), ...)` for Liquid Glass appearance.
- `.sensoryFeedback(.impact)` on mode changes, `.sensoryFeedback(.selection)` on source selection.
- Spring animation (0.28 response, 0.92 damping) on mode and playback transitions.
- Loads first source on appear but does not play (opt-in). `onChange` of `selectedSourceID` loads source and resumes only if already playing. `onChange` of `isPlaying` switches mode.
**User Wants:**
- Gesture-based player that morphs on drag gestures.
- Swipe up: vertical selectable list. Horizontal swipe: volume slider. Tap: play/pause.

### `AmbientEngine.swift`
**Implementation:**
- `@Observable` class wrapping `AVAudioPlayer`.
- `isPlaying` and `volume` are observable. `volume` setter applies cubic curve (`pow(volume, 3)`) to player.
- `load()` stops current player, creates new `AVAudioPlayer` from source URL, sets infinite loop, prepares.
- `play()`, `pause()`, `stop()`, `togglePlayPause()` control playback. `stop()` resets `currentTime` and nils the player.
- `init()` calls `configureSession()` which sets `AVAudioSession` category to `.playback` with empty options.
**User Wants:**
- Extremely simple, performant playback engine. Volume with iOS-like curve. Perfect, instant API.

### `AmbientSources.swift`
**Implementation:**
- `AmbientSource` struct, `Identifiable` via `UUID`. Properties: `name`, `icon`, `color`, `resourceName`, `fileExtension`.
- Computed `url` finds the audio file in the main bundle by matching `resourceName.fileExtension`.
- Static `all` array: Rain (`cloud.rain.fill`, cyan, `RainRecorded.m4a`) and Wind (`wind`, gray, `WindRecorded.m4a`).
- Audio files stored in `Lumen/Ambient/` directory.
**User Wants:**
- Extremely simple way to store name, id, icon, color, and file for every source.

### `Views/HomeView.swift`
**Implementation:**
- `DotMatrixPressKey` environment key with `(Bool) -> Void` callback, exposed as `onDotMatrixPress` in `EnvironmentValues`.
- `TimelineView(.animation)` provides continuous time updates.
- `Canvas(opaque: true, rendersAsynchronously: true)` draws concentric dot rings. Each ring has `5 * ringIndex` dots arranged in a circle with time-based rotation.
- Wave animation: `wavePosition` cycles through rings, producing a ripple effect via `exp(-ringDist² * 0.6)`. Wave speed scales with ring count.
- `onLongPressGesture(minimumDuration: 0.15)` tracks press state. Scale animation has 0.15s delay before growth, 0.6s `easeInOut` (quadratic) animation, and smooth reverse on release.
- Two `RadialGradient` overlays at top and bottom edges fade dots to black.
**User Wants:**
- A relaxing entry to the app. Mesmerising dot matrix that reacts when held.

### `Views/CollectionsView.swift`
**Implementation:**
- Private models: `CollectionTask` (emoji, name), `Collection` (name, color, tasks).
- `collectionsData`: 6 sample collections (Morning, Work, Evening, Fitness, Mind, Rest) with 3 tasks each.
- Shared helpers: `CardShape` (rounded rect with gradient fill and stroke), `cardFillGradient`, `cardStrokeGradient`.
- `CardView`: Equatable, renders card with emoji, name, shadow, scale/opacity/rotation/offset transforms.
- `LightGlowView`: renders elliptical `RadialGradient` glows around nearby cards based on fractional position.
- `TurntableReflectionsView`: renders inverted, blurred card reflections below the turntable.
- `TurntableTicksView`: 12 capsule tick marks around the disk, rotating with total rotation.
- `cardsLayer`: renders 5 cards centered on `currentIndex`, with parallax scale/offset, only center card accepts hit testing.
- `turntableLayer`: circle with glassEffect, ticks, reflections. Disk drag uses `simultaneousGesture`.
- `cardFlickGesture`: horizontal swipe on center card, velocity-based direction (>300), snaps one card angle (45°).
- `diskDragGesture`: angular tracking from center. Dead zone: <100px from center cancels drag. Tracks angular velocity with exponential smoothing. On release: momentum-based multi-step snap or nearest snap.
- Heavy `UIImpactFeedbackGenerator` haptics per card ridge crossed. `@MainActor` on struct.
- Uses `.glassEffect(.regular, in: Circle())` on turntable disk.
**User Wants:**
- A gorgeous turntable at the bottom with cards on top. Turntable rotates cards; flicking cards rotates both.

### `Views/GreetingView.swift`
**Implementation:**
- Computed `greeting` from current hour: morning (5–12), afternoon (12–17), evening (17–21), night (default).
- `Text` with `system(size: 48, design: .serif)`, white, centered in 80% screen width, `lineLimit(1)`, `minimumScaleFactor(0.5)`.
**User Wants:**
- An elegant greeting based on time of day.

### `Views/BreatheView.swift`
**Implementation:**
- Placeholder: `ZStack` with `Color.orange` and `Text("Breathe")`.
**User Wants:**
- A relaxing, animated "breathing live blob" in the center of the screen.
- A selection of breathing methods (e.g., box, 4-7-8, alternate nostril).
- Each breathing method should have its own unique, custom-implemented blob animation.

### `Views/MemoryView.swift`
**Implementation:**
- Placeholder: `ZStack` with `Color.green` and `Text("Memory")`.
**User Wants:**
- Quick way to view all accomplished tasks and objects.
- Top section: Latest 4 objects in a horizontal list.
- Bottom section: Rest of the accomplished tasks in a vertical scroll.
- Import/export option for a clean, minimal JSON file that stores all objects and tasks.
