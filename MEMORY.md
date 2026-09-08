# MEMORY.md — Lumen (2026-09-05)

## Architecture

- **Pager** (`Lumen/CoreNavigation.swift`): cross map memory (0,0), home (1,0),
  breathe (2,0), collections (1,1). `PagingMetrics`: `step = size + spacing(20)`.
  `NavigationController` holds settled `currentPage` + one live `dragOffset`,
  read ONLY by the container offset — never by page bodies. Drag tracks 1:1
  unanimated; `go(to:)` returns `dragOffset` to zero inside the settle animation.
  Gesture: `DragGesture(minimumDistance: 8, .local)`, disabled while expanded.
- **PageView**: settle-stable inputs, `Equatable`, recede via dim + blur only
  (no scale — scale completion reads as positional shift on landing). Order:
  `frame → compositingGroup → blur → clip(.rect 40) → opacity → offset`.
  Deliberately NO `geometryGroup`: the barrier re-times inner `.position()`
  against the outer offset spring, diverging content from frame mid-settle.
  Offscreen pages leave hit-testing and the a11y tree.
- **Debug views**: all removed 2026-09-05 (quarter-grid `DebugPageOverlay` on
  every page, pink collections base slab). Ship UI only.
- **Collections**: fixed `frame(pageSize)`, no trailing `ignoresSafeArea`
  (fixed size + expansion = ambiguous alignment). Disk flick: 1:1 rotation,
  low-passed release velocity → `.interpolatingSpring(0.38, bounce 0.15)`;
  taps/VoiceOver use `.smooth(0.35)`, no bounce.
- **Shell**: `ContentView` black base + focus containers + greeting + ambient,
  whole-stack `ignoresSafeArea`. Named animation vocabulary only (see
  `UIConstants.Animation`). All motion Reduce-Motion-gated.

## Issue — HomeView vertical ridge/snap (RESOLVED 2026-09-05)

- **Symptom** (iPhone 11): at rest, dot-matrix Canvas aligned to its frame.
  On vertical overscroll drag, the Canvas stayed **screen-pinned in Y** while
  its frame + debug grid followed the finger 1:1; X tracked fine. After
  ~20-30px of travel it **snapped** back into frame alignment. Symmetric on
  return. Never reproduced on Mac ("Designed for iPad").
- **Root cause**: `HomeView` applied trailing `.ignoresSafeArea()` to the whole
  composed view (`TimelineView`/`Canvas` + both gradient overlays). The safe
  area is window-anchored, so the expanded Canvas center stayed window-pinned
  in Y while the page frame slid — a ~34pt home-indicator inset reads as a
  20-30px ridge. X insets are 0 in portrait, so horizontal always tracked.
  Clean on Mac because its safe-area insets are ~0. `TimelineView(.animation)`
  + `rendersAsynchronously` only shaped the catch-up as a snap, not the cause.
- **Fix** (`Lumen/Views/HomeView.swift`): Canvas stays safe-area-respecting
  (frame-anchored); bleed scoped to backgrounds only — black base bleeds all
  edges, top/bottom veils pin to their frame edge via `.background(alignment:)`
  and bleed into `.top` / `.bottom` respectively. Verified on device: content
  tracks 1:1 in both axes, no hold, no snap; edges still full-bleed black.
- **Rule going forward**: never `ignoresSafeArea` a whole page body inside the
  fixed `PageView` frame. Content stays safe; only backgrounds bleed.

## Home dot matrix (2026-09-05)

- Split per swiftui-pro views: `HomeView` (thin container: press state,
  safe-area scoping, a11y) + `DotMatrixView` (`Canvas` + `TimelineView`,
  `DotMatrixField` renderer) + `DotMatrixVignette` (single centered radial
  falloff dimming all edges, replacing the old top/bottom veils).
- No glow: each ring is one crisp fill; the wave reads through size +
  opacity only. Ripple swell hardcoded to 9pt (`UIConstants.DotMatrix`
  `rippleScale`). No interaction on Home: the matrix is ambient content, not
  a control (hold-to-expand removed — press state, gesture, and render-side
  scale are all gone; `DotMatrixView` takes only `rippleScale`).
