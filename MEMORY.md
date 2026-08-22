# iOS 27 Migration — Required Changes for Lumen

> Generated: 2026-08-22  
> Source: iOS 27 developer beta articles (WWDC 2026)

---

## Already Satisfied

These iOS 27 build gates are already met by the current codebase:

| Requirement | Evidence |
|---|---|
| **Launch screen required** | `INFOPLIST_KEY_UILaunchScreen_Generation = YES` in `project.pbxproj` |
| **Scene-based lifecycle required** | `@main struct LumenApp: App` with `WindowGroup` + `INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES` |
| **@State macro compatibility** | No problematic init patterns (no `_count = State(initialValue:)` alongside declaration values) |
| **Observation framework** | Already using `@Observable` throughout |
| **Liquid Glass adoption** | Already using `glassEffect`, `GlassEffectContainer`, `glassEffectID`, `glassEffectTransition` |

---

## Required Modifications

### 1. Replace Static Screen Dimensions (P0 — Critical)

**Why:** iOS 27 makes apps resizable on large iPad displays and via iPhone Mirroring. `UIScreen.main.bounds` is a one-time snapshot that does not update when the window resizes, causing layouts to break.

**Files to modify:**

- **`Lumen/UIConstants.swift`** (lines 32–33)  
  Replace static computed properties with geometry-relative sizing:
  ```swift
  // CURRENT — breaks on window resize
  static var screenWidth: CGFloat { UIScreen.main.bounds.width }
  static var screenHeight: CGFloat { UIScreen.main.bounds.height }
  ```

- **`Lumen/Views/GreetingView.swift`** (line 18)  
  `.frame(width: UIConstants.General.screenWidth * 0.8, ...)` → use `GeometryReader` or `.containerRelativeFrame`

- **`Lumen/Views/HomeView.swift`** (lines 53–66)  
  `.frame(height: UIConstants.General.screenHeight * 0.35)` → geometry-relative

- **`Lumen/AmbientPlayer.swift`** (lines 64–93)  
  `compactWidth`, `volumeWidth`, `currentSize`, `currentBottomPadding` all derive from `screenWidth`/`screenHeight` → must become geometry-relative

- **`Lumen/Views/CollectionsView.swift`**  
  Any hardcoded sizes derived from screen constants must become geometry-relative

**Approach:** Use `GeometryReader` to pass container size into views (as `CoreNavigation` already does with `NavigationLayout`). Alternatively, use SwiftUI's `.containerRelativeFrame` for width/height fractions.

---

### 2. Update Project Settings for Xcode 27 (P0)

**File:** `Lumen.xcodeproj/project.pbxproj`

| Setting | Current | Required |
|---|---|---|
| `IPHONEOS_DEPLOYMENT_TARGET` | `26.5` | `27.0` (or keep lower if backward-compatible) |
| `SWIFT_VERSION` | `5.0` | `6.4` |
| `LastSwiftUpdateCheck` | `2660` | Auto-updated by Xcode |
| `LastUpgradeCheck` | `2660` | Auto-updated by Xcode |
| `CreatedOnToolsVersion` | `26.6` | Auto-updated by Xcode |

**Note:** Xcode 27 is Apple-silicon only. Ensure CI/build servers run on compatible hardware.

---

### 3. Swift 6.4 Concurrency Audit (P1)

**Why:** Swift 6.4 enforces stricter `@MainActor` / `@Sendable` rules. Code that compiled under Swift 5 concurrency mode may now produce warnings or runtime data races.

**File:** `Lumen/AmbientEngine.swift` (lines 123–183)  
- `handleInterruption` and `handleRouteChange` modify `@Observable` properties (`isPlaying`, `interruptedWhilePlaying`) from `NotificationCenter` async sequences. Verify these notifications arrive on the main thread, or explicitly dispatch to `@MainActor`.
- `interruptionTask` and `routeChangeTask` capture `self` weakly in `Task` closures. The class is already `@unchecked Sendable`, but verify no unsendable state escapes across actor boundaries.

**File:** `Lumen/CoreNavigation.swift` (lines 78–194)  
- `NavigationController` is correctly `@MainActor`. No changes expected, but recompile to catch any new compiler diagnostics.

**Action:** Recompile with Xcode 27 / Swift 6.4 and resolve all new warnings. Pay special attention to:
- Implicit `@MainActor` violations
- `@Sendable` closure captures
- Data race diagnostics in Instruments

---

### 4. Liquid Glass Visual Regression Testing (P1)

**Why:** iOS 27 refines Liquid Glass materials and fullscreen SwiftUI views now use a solid rectangle background instead of transparency. Lumen's custom glass surfaces may shift visually.

**Files to test:**
- `Lumen/AmbientPlayer.swift` — `GlassEffectContainer`, `accessibleGlass` modifier
- `Lumen/Views/CollectionsView.swift` (line 555) — `.glassEffect(.regular, in: Circle())`

**Action:** Run on iOS 27 beta and verify all glass-effect pills, bands, and cards render correctly. Check that:
- `compactPill`, `volumePill`, `expandedBand`, `completedControls` maintain intended appearance
- No unexpected solid backgrounds or blur shifts
- Text and icon contrast remains readable against glass surfaces

---

### 5. App Store Connect Metadata (P2)

**Why:** iOS 27 introduces new App Store requirements effective September 2026.

**Required updates in App Store Connect:**
- **Social media flag:** If Lumen has any social features, mark the app as social media
- **Age rating:** Confirm age rating is set; implement `DeclaredAgeRange` API if app has social/user-generated content features (Lumen currently does not)
- **Privacy documentation:** Update privacy labels for any new data collection patterns

**Note:** Lumen currently has no social features, messaging, or user-generated content, so `DeclaredAgeRange` / `PermissionKit` are likely not required. Verify against App Store Review Guidelines before submission.

---

## Not Applicable to Lumen

These iOS 27 changes do not affect the current codebase:

| Change | Reason |
|---|---|
| `ImageCreator` API removal | Not used anywhere in codebase |
| `ReferenceFileDocument` deprecation | No document-based app |
| `DeclaredAgeRange` / `PermissionKit` | No social features, user-generated content, or messaging |
| `UIApplication.statusBar*` deprecation | Not used |
| On Demand Resources → Background Assets | Not using `NSBundleResourceRequest` |
| MetricKit → MetricManager | No diagnostics code present |
| `UISearchController` scope bar changes | Not used |
| `UIPresentationController` trait inheritance | No custom presentation controllers |
| `UIMenuElement` image visibility | No `UIMenu` usage |
| Swift 6.4 `stat()` ambiguity on `FilePath`/`FileDescriptor` | No file-system path code |
| Sign in with Apple domain change (`private.icloud.com`) | Not using authentication |
| `.reorderable()` / `.swipeActions` | Lumen uses custom drag gestures; new SwiftUI APIs not applicable |
| Foundation Models / Core AI / App Intents | Not integrating on-device AI or Siri in this release |

---

## Summary Checklist

| # | Action | Priority | File(s) |
|---|---|---|---|
| 1 | Replace `UIScreen.main.bounds` with geometry-relative sizing | **P0** | `UIConstants.swift`, `GreetingView.swift`, `HomeView.swift`, `AmbientPlayer.swift`, `CollectionsView.swift` |
| 2 | Bump `IPHONEOS_DEPLOYMENT_TARGET` to `27.0` | **P0** | `project.pbxproj` |
| 3 | Update `SWIFT_VERSION` to `6.4` | **P0** | `project.pbxproj` |
| 4 | Audit `AmbientEngine` concurrency (main-thread mutations from notifications) | **P1** | `AmbientEngine.swift` |
| 5 | Visual regression test all `glassEffect` surfaces on iOS 27 beta | **P1** | `AmbientPlayer.swift`, `CollectionsView.swift` |
| 6 | Verify App Store Connect metadata (age rating, social media flag) | **P2** | App Store Connect |

---

## Notes

- There is no App Store deadline forcing the iOS 27 SDK yet (submission floor remains iOS 26 SDK as of writing).
- Test against iOS 27 beta early — the two hard build gates (launch screen and scene-based lifecycle) are already satisfied, but the `@State` macro change and resizable layout behavior are easier to fix now than at release.
- Swift 6.4 `async` in `defer` blocks is additive and does not require changes unless the pattern is useful for cleanup code in `AmbientEngine`.
