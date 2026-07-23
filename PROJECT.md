# Lumen

A place to slow down, reset, and regain steady momentum. Tasks provide the momentum needed to pursue more meaningful parts of life. Completing tasks earns objects collected and placed inside a personal Room.

## Design & Philosophy

Liquid Glass foundation. Fluid motion, meaningful depth, restrained visuals, tactile interactions. Every animation, gesture, and transition stays smooth and responsive. UI is elegant, minimal, immersive, effortless. Performance is a feature.

## Current State

- **Startup** — Time-of-day `GreetingView` fades in/out on launch, transitions to main interface.
- **Navigation** — Drag gestures navigate a 4-page T-layout: Center (Home), Left (Memory), Right (Breathe), Bottom (Collections). Pages compute blur, opacity, scale locally from drag distance with spring animations. `.drawingGroup()` for Metal-backed rendering, `.compositingGroup()` before blur.
- **Home** — Async-rendered Canvas dot matrix with concentric rings, continuous wave ripple, spring-based long-press scale reaction with velocity-preserving release, RadialGradient edge fading.
- **Ambient Player** — Gesture-driven morphing player with 4 modes (mini, compact, volume, expanded). Liquid Glass appearance, spring animations. `@Observable` `AmbientEngine` with cubic volume curve, background audio session. 2 sources: Rain, Wind.
- **Collections** — Turntable with 8 colored collections rendered as cards above the disk. Cards flick, tap-to-expand (fullscreen), drag-to-dismiss. Turntable disk supports angular drag with velocity-based momentum. Tick marks rotate with the disk. Haptics per card ridge crossed. Expanded cards show collection items with horizontal swipe and infinite looping.
- **Breath** — Placeholder (orange screen).
- **Memory** — Placeholder (green screen).

## File Reference

### `Lumen/ContentView.swift`
Entry point (`@main LumenApp`) and root orchestrator.
- `ZStack` layers: black background → `CoreNavigation` → `GreetingView` → `AmbientPlayer` (bottom-aligned) → `CompletePill` (bottom-aligned, 70pt raised).
- `@State` `FocusedState` variables control layer visibility for `startSequence()`.
- `@State` `AmbientEngine` shared instance passed to `AmbientPlayer`.
- Environment keys for `onCardExpand` and `onDotMatrixPress` coordinate cross-layer focus changes.
- Completion pill: center pill always-in-hierarchy anchor morphs between "Complete"/"Completed". Trash circle and counter circle emerge via `glassEffectTransition(.matchedGeometry)` from the center pill's glass shape. `GlassEffectContainer(spacing: 6)` + `glassEffectID` for fluid glass splitting. 45pt elements, 70pt from bottom, `FocusedState` visibility.

### `Lumen/CoreNavigation.swift`
4-page T-layout drag navigation with rubberbanding.
- All pages rendered in `ZStack`, offset to base positions, entire stack moves via single `offset` state.
- `unfocusProgress(for:)` computes 0–1 from drag distance. Scale, blur, opacity derived from this single value.
- Snap decision: 25% displacement threshold, fallback velocity prediction (0.12× factor), snaps to nearest adjacent page.
- `adjacentPages(from:)` restricts side pages to center-only return. Center reaches all.
- Rubberbanding: valid ranges derived from adjacent page targets per axis. Asymptotic UIScrollView curve (160pt limit, 0.7 coefficient) with critically-damped return spring (0.55s, no bounce).
- Spring snap: `Animation.spring(duration: 0.45, bounce: 0.05)`. `.drawingGroup()` + `.compositingGroup()`.

### `Lumen/FocusedStates.swift`
`FocusedState` enum (visible, subdued, subduedAlt, hidden) with computed blur/opacity/scale from `UIConstants.Focus`.
`FocusContainer` applies these to content with configurable alignment anchor.

### `Lumen/UIConstants.swift`
Enum-namespaced constants: Navigation, DotMatrix, Focus, Collections, General.
`General.screenCornerRadius` reads private `_displayCornerRadius` API (fallback 55pt).

### `Lumen/AmbientPlayer.swift`
Gesture-driven player with 4 `PlayerMode` states (mini → compact → volume → expanded).
- Mini: 45pt play/pause bubble. Tap toggles playback. Starting mode.
- Compact: pill with play/pause + "Ambient" label. Drag up → expanded, drag horizontal → volume.
- Volume: 70% width slider. Drag to adjust. Releases back to compact/mini.
- Expanded: full-width source list. Drag highlights rows, release selects.
- `.glassEffect(.regular.interactive(), in: RoundedRectangle(...))` for Liquid Glass.
- Spring animation (0.28s, 0.04 bounce) on mode changes. `.snappy` on source row changes.

### `Lumen/AmbientEngine.swift`
`@Observable` class wrapping `AVAudioPlayer`. Observable `isPlaying` and `volume`. Cubic volume curve (`pow(volume, 3)`). Background audio session. `load()` creates fresh player each time, infinite loop.

### `Lumen/AmbientSources.swift`
`AmbientSource` struct (Identifiable) with name, icon, color, resourceName, fileExtension. Static `all` array: Rain, Wind. Audio in `Lumen/Ambient/`.

### `Lumen/Views/HomeView.swift`
`TimelineView(.animation)` drives a `Canvas<EmptyView>` (opaque, async). Concentric dot rings with time-based rotation. Wave ripple via `exp(-ringDist² * 0.55)`. Spring-based long-press scale using `Spring` model (iOS 17+) with velocity-preserving release. `DotMatrixPressKey` environment key propagates press state.

### `Lumen/Views/CollectionsView.swift`
Turntable carousel with expandable collection cards.
- `CollectionItem` (Identifiable, Equatable) with emoji, name. `Collection` (Identifiable) with name, color, items.
- `CardLayout` pure-data struct derived from fractional index via `cardLayouts()`.
- `CardView` (Equatable) renders card with parallax transforms, expands to fullscreen on tap.
- Ghost card at zIndex 0.5 mirrors expanded card during animate-in/animate-out; turntable sits at zIndex 1, expanded card at zIndex 2.
- `ExpandedCollectionView` renders all items simultaneously with circular wrapping for infinite looping.
- `TickMarksView`: 8 capsule marks at 45° intervals, gradient filled, rotate with turntable.
- 4 named springs: cardSnap, cardExpand, cardDismiss, cardCancel + itemSwipe interpolating spring.
- Disk drag: angular tracking with dead zone, exponential velocity smoothing, asymmetric momentum.
- Card flick: horizontal swipe >1.5:1 ratio, >300 velocity snaps one card angle.
- Expanded drag: direction-locked unified gesture (horizontal → item swipe, vertical → dismiss).
- Single `UIImpactFeedbackGenerator(.medium)` for turntable ridge haptics.

### `Lumen/Views/GreetingView.swift`
Time-of-day greeting (morning/afternoon/evening/night). Serif font, 48pt, white, centered 80% screen width.

### `Lumen/Views/BreatheView.swift`
Placeholder: orange background with "Breathe" text.

### `Lumen/Views/MemoryView.swift`
Placeholder: green background with "Memory" text.

## Project Settings

- **Platform:** iOS 27.0
- **Bundle ID:** `s4tturn.Lumen`
- **Build:** `./deploy.sh` builds via `xcodebuild`, installs via `devicectl`.
