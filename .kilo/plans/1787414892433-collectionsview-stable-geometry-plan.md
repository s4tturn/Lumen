# Fix: CollectionsView elements expand/shrink during navigation drag

## Context (investigation, no code changed yet)

While dragging between pages in `CoreNavigation`, the cards/disk inside
`CollectionsView` change size. They should stay rigidly sized regardless of page
position or transform.

`CollectionsView` computes **all** layout from a single source:
`CollectionsGeometry(size:)` (`CollectionsView.swift:93`), which derives
`diskRadius`, `cardSize`, `orbitRadius`, etc. purely from `proxy.size` of the
top-level `GeometryReader` (`CollectionsView.swift:361`). As the page is dragged,
that `GeometryReader` sits **inside** the transformed/animated subtree of
`CoreNavigation.pageView` (`CoreNavigation.swift:240-249`), which applies
`.frame(...)`, `.scaleEffect`, `.blur`, `.opacity`, and `.position` while
`dragTranslation` is animated. During that layout pass the `GeometryReader` is
proposed a fluctuating size, so `proxy.size` (and therefore every element) grows
and shrinks.

### Apple documentation position (sosumi)

- `scaleEffect(_:anchor:)` docs: *"The original dimensions of the view are
  considered to be unchanged by scaling the contents."* — so the transform itself
  does not resize layout; the issue is that the **`GeometryReader` is nested under
  the animated/transformed hierarchy** and re-measures a varying proposed size.
- WWDC23 "Beyond scroll views" (`VisualEffect`/`scrollTransition`): visual effects
  like `scaleEffect`/`offset` are explicitly *safe as functions of layout* because
  they do **not** change content size; only layout-affecting changes (frame, font,
  padding) do. This supports keeping layout-determining geometry **separate** from
  visual transforms.

**Conclusion:** Fixing this is NOT against Apple's documentation. The
Apple-idiomatic fix is to measure the page size at the **stable, untransformed
level** (in `pageView`, before the scale/position effects) and pass it into
`CollectionsView`, instead of letting `CollectionsView` measure itself through the
transformed subtree.

## Plan

### 1. Stop measuring through the transformed subtree
In `CoreNavigation.pageView`, capture the page size **before** applying
`.scaleEffect`/`.position`:
```swift
let pageSize = CGSize(width: layout.pageWidth, height: layout.pageHeight)
```
This is stable: `pageWidth/pageHeight` come from CoreNavigation's own
`GeometryReader` (screen size, constant during drag).

### 2. Inject the stable size into CollectionsView
- Add an `init` parameter `pageSize: CGSize` (default to a sensible value for
  `#Preview` and other call sites).
- Remove the top-level `GeometryReader` in `CollectionsView`. Build
  `let geometry = CollectionsGeometry(size: pageSize)` once and use it directly
  everywhere `proxy.size` was used.
- Keep `.frame(width:height:)` on the view (set from `pageSize`) so it is placed
  correctly within the page; do not re-measure it.

### 3. Pass the size from the page
In `CoreNavigation.pageView` (`.page4` branch), construct `CollectionsView` with
`pageSize:` and the existing `collectionsExpanded:` binding.

### 4. Validation
- `xcodebuild -scheme Lumen -destination 'generic/platform=iOS' build` succeeds.
- Manually: drag-navigate toward/away from the Collections page and hold mid-drag.
  Confirm the disk + cards keep a **constant** size and position relative to the
  page (no growth/shrink, no drift).
- Confirm tap-to-expand, swipe-up dismiss, disk rotation, and haptics still work
  (they rely on `geometry`, now sourced from the injected size).
- Confirm `#Preview` in `CollectionsView.swift` still renders (uses default size).

## Affected files
- `Lumen/Views/CollectionsView.swift` — remove nested `GeometryReader`, accept
  `pageSize`, use injected `CollectionsGeometry`.
- `Lumen/CoreNavigation.swift` — compute `pageSize` in `pageView`, pass to
  `CollectionsView`.

## Risks / open questions
- None expected. `CollectionsGeometry` is already a pure function of `CGSize`, so
  the refactor is mechanical.
- Edge case: if `CollectionsView` is ever embedded elsewhere without a measured
  size, the default `CGSize` in the init must be reasonable (e.g. a standard
  screen size) to avoid zero-size layout.
