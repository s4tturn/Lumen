# Liquid Glass — Complete Reference

Every modifier, effect, transition, variant, and usage pattern for Liquid Glass in SwiftUI (iOS 26+).

---

## Table of Contents

1. [Glass Structure](#1-glass-structure)
2. [glassEffect(\_:in:)](#2-glasseffect_in)
3. [DefaultGlassEffectShape](#3-defaultglasseffectshape)
4. [GlassEffectContainer](#4-glasseffectcontainer)
5. [glassEffectID(\_:in:)](#5-glasseffectid_in)
6. [glassEffectTransition(\_:)](#6-glasseffecttransition_)
7. [glassEffectUnion(id:namespace:)](#7-glasseffectunionidnamespace)
8. [Button Styles](#8-button-styles)
9. [GlassBackgroundEffect (visionOS)](#9-glassbackgroundeffect-visionos
10. [backgroundExtensionEffect()](#10-backgroundextensioneffect)
11. [How Glass Adapts Automatically](#11-how-glass-adapts-automatically)
12. [Accessibility Behaviors](#12-accessibility-behaviors)
13. [Tinting Deep Dive](#13-tinting-deep-dive)
14. [HIG Design Guidelines](#14-hig-design-guidelines)
15. [Performance Considerations](#15-performance-considerations)
16. [Current Usage in Lumen](#16-current-usage-in-lumen)

---

## 1. Glass Structure

**Declaration:** `struct Glass`
**Availability:** iOS 26.0+, iPadOS 26.0+, Mac Catalyst 26.0+, macOS 26.0+, tvOS 26.0+, watchOS 26.0+
**Conforms to:** `Equatable`, `Sendable`

The core configuration type for the Liquid Glass material. You pass instances to `glassEffect(_:in:)`.

### Type Properties (Variants)

| Variant | Signature | Description |
|---------|-----------|-------------|
| **`regular`** | `static var regular: Glass` | The standard Liquid Glass material. Adapts dynamically — blurs content behind it, adjusts luminosity, flips between light and dark based on what's underneath. Used by all system components. Works over any content, at any size. The default and most versatile variant. |
| **`clear`** | `static var clear: Glass` | Permanently more transparent. Does **not** have adaptive behaviors (no automatic light/dark switching). Allows rich content underneath to come through and interact with the glass. **Requires a dimming layer** for legibility — add a transparent black background beneath. Only use when all three conditions are met: (1) over media-rich content, (2) dimming layer won't harm content, (3) content above is bold and bright. **Never mix clear and regular in the same interface.** |
| **`identity`** | `static var identity: Glass` | No-op variant. Content remains unaffected as if no glass effect was applied. Useful for placeholder states, conditional glass, or when you need the modifier in the chain but want no visual effect. |

**Clear variant example with dimming layer:**
```swift
Label("Flag", systemImage: "flag.fill")
    .padding()
    .glassEffect(.clear)
    .background(.black.opacity(0.3))
```

### Instance Methods (Configuration Chain)

These return a modified `Glass` instance and can be chained fluently.

| Method | Signature | Description |
|--------|-----------|-------------|
| **`.interactive()`** | `func interactive(_ isEnabled: Bool = true) -> Glass` | Enables touch and pointer interaction responses — the glass flexes, bounces, and shimmers on press. Matches the behavior provided by the `.glass` button style to standard buttons. On iOS, use for custom controls or containers with interactive elements. Pass `false` to disable. |
| **`.tint()`** | `func tint(_ color: Color?) -> Glass` | Adds a tint color. Uses a technique that respects glass properties: generates a range of tones mapped to content brightness underneath, inspired by how colored glass works in reality. The tint changes hue, brightness, and saturation depending on what's behind it. Compatible with all glass behaviors. Use sparingly for primary actions only — never tint everything. Pass `nil` to remove tint. |

### Chaining Examples

```swift
// Default — regular capsule, non-interactive
.glassEffect()

// Interactive regular
.glassEffect(.regular.interactive())

// Tinted regular
.glassEffect(.regular.tint(.orange))

// Tinted + interactive
.glassEffect(.regular.tint(.red).interactive())

// Clear
.glassEffect(.clear)

// Identity (no-op)
.glassEffect(.identity)
```

---

## 2. glassEffect(_:in:)

**Signature:**
```swift
func glassEffect(
    _ glass: Glass = .regular,
    in shape: some Shape = DefaultGlassEffectShape()
) -> some View
```

**Availability:** iOS 26.0+

The primary modifier to apply Liquid Glass to any custom view.

### What It Does

When you use this modifier, the system:
1. Renders a shape anchored behind the view with the Liquid Glass material
2. Applies the foreground effects of Liquid Glass over the view

SwiftUI anchors the Liquid Glass to the view's bounds — the material fills the entire frame including padding.

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `glass` | `Glass` | `.regular` | The glass variant and configuration to apply |
| `shape` | `some Shape` | `DefaultGlassEffectShape()` (Capsule) | The shape defining the glass area behind the view |

### Custom Shapes

Any `Shape` can be used. Common patterns:

```swift
// Default capsule
.glassEffect()

// Explicit capsule
.glassEffect(in: Capsule())

// Circle
.glassEffect(in: Circle())

// Rounded rectangle with corner radius
.glassEffect(in: .rect(cornerRadius: 16.0))

// Continuous rounded rectangle
.glassEffect(in: RoundedRectangle(cornerRadius: 22.5, style: .continuous))
```

### Modifier Ordering

Apply `glassEffect` **after** other modifiers that affect the appearance of the view. The modifier captures the content to send to the container to render.

**Critical rule from IMPLEMENTATION.md:** Apply `.rotationEffect` **before** `.glassEffect`. Glass effect breaks if applied before rotation in the modifier chain. Inner view rotations (inside ZStack) are safe as long as `.glassEffect` is applied after the parent container's layout.

```swift
// CORRECT — rotation before glass
.rotationEffect(.degrees(45))
.glassEffect(.regular, in: Circle())

// WRONG — glass breaks if applied before rotation
.glassEffect(.regular, in: Circle())
.rotationEffect(.degrees(45))
```

### Without a Container

Each glass effect renders independently. Performance is lower and glass elements cannot sample each other — nearby glass in separate containers produces inconsistent visual results.

### With a Container

Effects share rendering, improve performance, and can blend/merge/morph.

---

## 3. DefaultGlassEffectShape

**Declaration:** `struct DefaultGlassEffectShape`
**Conforms to:** `Shape`, `View`, `Animatable`

The default shape applied by glass effects — a **Capsule**.

You never instantiate this directly. SwiftUI creates it as the default parameter of `glassEffect(_:in:)`.

---

## 4. GlassEffectContainer

**Declaration:** `@MainActor struct GlassEffectContainer<Content: View>`
**Availability:** iOS 26.0+, iPadOS 26.0+, Mac Catalyst 26.0+, macOS 26.0+, tvOS 26.0+, watchOS 26.0+
**Conforms to:** `View`

A view that combines multiple Liquid Glass shapes into a single shape that can morph individual shapes into one another.

### What It Does

1. **Performance:** Combines multiple glass effects into a single rendering pass
2. **Visual blending:** Allows glass shapes to blend and merge when near each other
3. **Morphing:** Enables fluid morphing animations between glass shapes during transitions
4. **Shared sampling:** Lets glass elements share their sampling region so reflections/refractions are consistent

### Critical Rule

> Glass cannot sample other glass. Having nearby glass elements in **different** containers results in inconsistent behavior. Using a glass container allows these elements to share their sampling region, providing a consistent visual result.

### Initializer

```swift
init(
    spacing: CGFloat? = nil,
    @ContentBuilder content: () -> Content
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `spacing` | `CGFloat?` | `nil` | Controls when glass effects begin to blend. Larger values = blending starts sooner as shapes approach. |

### Spacing Behavior

- If container spacing > layout spacing → effects blend at rest (views are too close)
- Animating views in/out causes shapes to morph apart/together as space changes
- The spacing interacts with the geometry of the shapes themselves to determine when and which shapes morph

### Example

```swift
GlassEffectContainer(spacing: 40.0) {
    HStack(spacing: 40.0) {
        Image(systemName: "scribble.variable")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()

        Image(systemName: "eraser.fill")
            .frame(width: 80, height: 80)
            .font(.system(size: 36))
            .glassEffect()
            .offset(x: -40) // Shows how effects react in a container
    }
}
```

### Performance Warning

Creating too many containers and applying too many effects degrades performance. Limit the number of glass effects onscreen simultaneously.

---

## 5. glassEffectID(_:in:)

**Signature:**
```swift
func glassEffectID(
    _ id: (some Hashable & Sendable)?,
    in namespace: Namespace.ID
) -> some View
```

**Availability:** iOS 26.0+

Associates a unique identity value to Liquid Glass effects within a namespace. Used for morphing transitions.

### How It Works

1. Declare a `@Namespace` property
2. Assign unique IDs to each glass effect you want to animate
3. Wrap everything in `GlassEffectContainer`
4. Toggle visibility inside `withAnimation { }`

SwiftUI uses the identifier to animate shapes to and from each other during transitions. It uses the container spacing along with the geometry of the shapes to determine when and which shapes morph into/out of which.

The `glassEffectID` and `glassEffectTransition` modifiers only affect their content during view hierarchy transitions or animations.

### Example

```swift
@State private var isExpanded = false
@Namespace private var namespace

var body: some View {
    GlassEffectContainer(spacing: 40.0) {
        HStack(spacing: 40.0) {
            Image(systemName: "scribble.variable")
                .frame(width: 80, height: 80)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectID("pencil", in: namespace)

            if isExpanded {
                Image(systemName: "eraser.fill")
                    .frame(width: 80, height: 80)
                    .font(.system(size: 36))
                    .glassEffect()
                    .glassEffectID("eraser", in: namespace)
            }
        }
    }

    Button("Toggle") {
        withAnimation {
            isExpanded.toggle()
        }
    }
    .buttonStyle(.glass)
}
```

---

## 6. glassEffectTransition(_:)

**Signature:**
```swift
func glassEffectTransition(_ transition: GlassEffectTransition) -> some View
```

**Availability:** iOS 26.0+

Specifies the type of transition to use when a glass effect is added or removed from the view hierarchy within a `GlassEffectContainer`.

### GlassEffectTransition Type

**Declaration:** `struct GlassEffectTransition`
**Conforms to:** `Sendable`

| Transition | Signature | Description |
|-----------|-----------|-------------|
| **`.matchedGeometry`** | `static var matchedGeometry: GlassEffectTransition` | **Default transition.** Derives the appearing/disappearing shape's geometry from a nearby shape within the container spacing. If a newly appearing shape is within spacing of any existing shape, it uses that shape's geometry to transition out of. When using `.default` animation, applies additional scale/offset effects when the identity of the shape doesn't change but its content does — opt out by providing a specific animation like `.spring`. |
| **`.materialize`** | `static var materialize: GlassEffectTransition` | Fades in content and animates in or out the glass material, but does **not** attempt to match geometry of any other glass effects. Use for effects positioned farther apart than the container's spacing, or for simpler/standalone transitions. |
| **`.identity`** | `static var identity: GlassEffectTransition` | No transition changes applied. |

### Decision Guide

| Scenario | Use |
|----------|-----|
| Shape appears/disappears near another shape (within container spacing) | `.matchedGeometry` |
| Shape appears/disappears far from other shapes (beyond container spacing) | `.materialize` |
| No transition animation needed | `.identity` |
| Custom transition needed | Use `.materialize` with `withAnimation(_:_:)` |

### Example

```swift
var body: some View {
    GlassEffectContainer(spacing: 10.0) {
        HStack(spacing: 10.0) {
            Image(systemName: "pencil")
                .frame(width: 20, height: 20)
                .glassEffect()
                .glassEffectID("pencil", in: namespace)

            if isExpanded {
                Image(systemName: "note")
                    .frame(width: 20, height: 20)
                    .glassEffect()
                    .glassEffectID("note", in: namespace)
                    .glassEffectTransition(.matchedGeometry)
            }
        }
    }
}
```

### Best Practices from Apple

- Use `matchedGeometry` and `materialize` consistently across your app
- The system applies more than opacity changes with the available transition types
- Use `matchedGeometry` for shapes within container spacing
- Use `materialize` for shapes outside container spacing
- Provide a consistent experience by using the same transition type for similar interactions

---

## 7. glassEffectUnion(id:namespace:)

**Signature:**
```swift
func glassEffectUnion(
    id: (some Hashable & Sendable)?,
    namespace: Namespace.ID
) -> some View
```

**Availability:** iOS 26.0+

Combines the geometries of multiple views into a **single** Liquid Glass shape, even when content is at rest (not transitioning).

### When to Use

- When multiple views' geometries should contribute to one unified glass capsule at rest
- Views created dynamically
- Views that live outside a layout container (not in HStack/VStack)
- When you want grouped glass elements to appear as a single merged region

### How It Works

All Liquid Glass effects with the same shape, same glass variant, and same union ID are combined into a single shape with the applied Liquid Glass material.

### Example

```swift
let symbolSet = ["cloud.bolt.rain.fill", "sun.rain.fill", "moon.stars.fill", "moon.fill"]

GlassEffectContainer(spacing: 20.0) {
    HStack(spacing: 20.0) {
        ForEach(symbolSet.indices, id: \.self) { item in
            Image(systemName: symbolSet[item])
                .frame(width: 80, height: 80)
                .font(.system(size: 36))
                .glassEffect()
                .glassEffectUnion(id: item < 2 ? "1" : "2", namespace: namespace)
        }
    }
}
```

This creates two unified glass regions: indices 0-1 share union ID "1", indices 2-3 share union ID "2".

---

## 8. Button Styles

System-provided button styles that apply Liquid Glass automatically.

### `.glass`

**Type:** `GlassButtonStyle` (conforms to `PrimitiveButtonStyle`)
**Availability:** iOS 26.0+

A button style that applies glass border artwork based on the button's context.

```swift
Button("Action") { }
    .buttonStyle(.glass)
```

### `.glassProminent`

**Type:** `GlassProminentButtonStyle` (conforms to `PrimitiveButtonStyle`)
**Availability:** iOS 26.0+

A button style that applies prominent glass border artwork based on the button's context. Uses tint for emphasis.

```swift
Button("Primary") { }
    .buttonStyle(.glassProminent)
```

### `.glass(_:)`

Glass with a custom `Glass` configuration:

```swift
Button("Clear Glass") { }
    .buttonStyle(.glass(.clear))
```

### Platform Equivalents

| SwiftUI | UIKit | AppKit |
|---------|-------|--------|
| `.glass` | `UIButton.Configuration.glass()` | `NSButton.BezelStyle.glass` |
| `.glassProminent` | `.prominentGlass()` | — |
| — | `.clearGlass()` | — |
| — | `.prominentClearGlass()` | — |

---

## 9. GlassBackgroundEffect (visionOS)

**Protocol:** `GlassBackgroundEffect`
**Availability:** visionOS 1.0+

A specification for the appearance of a 3D glass background with thickness, specularity, glass blur, shadows, and other effects. Because of its physical depth, the glass background influences z-axis layout.

### Modifiers

**With automatic container-relative shape:**
```swift
.glassBackgroundEffect(displayMode: .always)
```

**With custom shape:**
```swift
.glassBackgroundEffect(in: .rect(cornerRadius: 20), displayMode: .always)
```

### GlassBackgroundDisplayMode

Controls when the glass background is displayed.

### Conforming Types

| Type | Description |
|------|-------------|
| `AutomaticGlassBackgroundEffect` | Default — context-based automatic effect |
| `PlateGlassBackgroundEffect` | Plate glass background |
| `FeatheredGlassBackgroundEffect` | Feathered edges with customizable padding and soft edge radius |

### Customization

```swift
.glassBackgroundEffect(in: .rect(cornerRadius: 20))
.glassBackgroundEffect(in: Circle())
```

### ZStack Warning

To ensure proper rendering in a `ZStack`, add the modifier to the stack rather than to one view in the stack. For implicit stacks (via `overlay` or `background`), create an explicit `ZStack` inside the content closure.

---

## 10. backgroundExtensionEffect()

**Signature:**
```swift
func backgroundExtensionEffect(isEnabled: Bool = true) -> some View
```

**Availability:** iOS 26.0+

Duplicates the view's content into mirrored copies placed around the view on any edge with available safe area. Applies a blur effect on top to blur out the copies.

### Purpose

Creates the illusion of content extending behind a sidebar or inspector panel without actually scrolling content there. Mirrors the adjacent content and applies blur.

### Use Cases

- Hero images in NavigationSplitView that extend under the sidebar
- Tinted backgrounds that feel expansive
- Full edge-to-edge content experiences

### Example

```swift
Image("hero")
    .resizable()
    .aspectRatio(contentMode: .fill)
    .backgroundExtensionEffect()
```

### Platform Equivalents

| SwiftUI | UIKit | AppKit |
|---------|-------|--------|
| `.backgroundExtensionEffect()` | `UIBackgroundExtensionView` | `NSBackgroundExtensionView` |

---

## 11. How Glass Adapts Automatically

Liquid Glass is composed of multiple layers that continuously adapt based on what's behind it. All of this happens automatically — no code required.

### Light/Dark Switching

- **Small elements** (tab bars, nav bars, toolbars): Constantly adapt, flipping from light to dark and vice versa based on background content to maximize contrast
- **Large elements** (menus, sidebars): Adapt based on context but do **not** flip from light to dark — surface area is too large and transitions would be distracting

### Shadow Adaptation

- Shadow opacity **increases** over text to create additional separation
- Shadow opacity **decreases** over solid light backgrounds
- This provides consistent separation and legibility regardless of what's behind

### Highlight Response

- Light sources exist in an environment that behaves like the real world
- Highlights respond to geometry naturally
- On interactions (lock/unlock), lights move in space, causing light to travel around the material
- On some devices, lighting responds to device motion — glass is aware of its position in the real world

### Touch Response

- Material **illuminates from within** as feedback on interaction
- Glow starts right under fingertips and spreads throughout the element
- Glow extends onto any nearby Liquid Glass elements
- Interacts with the flexible properties of the material in a natural, fluid way

### Size Adaptation

When glass morphs to larger sizes (e.g., presenting a menu from a toolbar button):
- Simulates a **thicker, more substantial material**
- Casts **deeper, richer shadows**
- Has **more pronounced lensing and refraction effects**
- Shows **softer scattering of light**

These changes enhance perceived depth and aid legibility of content within the glass element.

### Window Focus (macOS/iPadOS)

When a window loses focus, Liquid Glass shifts its appearance and visually recedes to guide attention to the active window.

### Foreground Adaptation

- Symbols and glyphs on top of glass flip from light to dark (mirroring the glass's behavior) to maximize contrast
- All content placed on the `regular` variant automatically receives this treatment
- Custom colors are supported but should be used selectively

---

## 12. Accessibility Behaviors

These are applied automatically whenever Liquid Glass is used. No code changes needed.

### Reduced Transparency

- Makes Liquid Glass **frostier**
- Obscures more of the content behind it
- Activated when user enables "Reduce Transparency" in device settings

### Increased Contrast

- Makes elements predominantly **black or white**
- Highlights them with a **contrasting border**
- Activated when user enables "Increase Contrast" in device settings

### Reduced Motion

- **Decreases intensity** of some visual effects
- **Disables elastic properties** for the material
- Activated when user enables "Reduce Motion" in device settings

### User-Preferred Look

Users can choose a preferred look for Liquid Glass in their device's settings. The appearance of regular and clear variants can differ in response to this setting.

### Testing Recommendation

Test your app's custom elements, colors, and animations with different configurations of these accessibility settings to ensure a good experience for all users.

---

## 13. Tinting Deep Dive

### How It Works

Selecting a color generates a range of tones that are **mapped to content brightness** underneath the tinted element. It draws inspiration from how colored glass works in reality — changing hue, brightness, and saturation depending on what's behind it without deviating too much from the intended color.

### Key Properties

- Emphasizes the physicality of the material
- Helps legibility and contrast
- Natively compatible with all behaviors of glass (lensing, interaction, morphing)

### Correct Usage

- Tinting should **only** bring emphasis to **primary elements and actions**
- A single tinted button among untinted ones stands out clearly as the primary action
- Tint is vibrant and adaptive — it preserves transparency

### Incorrect Usage

- **Don't** tint all elements — when everything is tinted, nothing stands out and it becomes confusing
- If you want color in your app, do it in the content layer, not the glass layer
- **Don't** use solid fills instead of tinting — solid fills are completely opaque and break the visual character of Liquid Glass

### Code

```swift
// Tinted primary action
.glassEffect(.regular.tint(.red).interactive(), in: Capsule())

// Untinted (standard)
.glassEffect(.regular.interactive(), in: Capsule())
```

---

## 14. HIG Design Guidelines

### Where to Use Liquid Glass

| Location | Suitability |
|----------|-------------|
| Tab bars | ✅ Primary use |
| Sidebars | ✅ Primary use |
| Toolbars | ✅ Primary use |
| Floating controls | ✅ Primary use |
| Sheets / Popovers | ✅ System-provided automatically |
| Action sheets | ✅ System-provided, now anchored to source |
| Dialogs | ✅ System-provided, morph out of buttons |
| Custom badges / indicators | ✅ Sparingly |
| Custom primary actions | ✅ Sparingly |

### Where NOT to Use Liquid Glass

| Location | Reason |
|----------|--------|
| Content layer (lists, tables) | Competes with other elements, muddies hierarchy |
| Stacked on glass | Glass-on-glass is cluttered and confusing |
| Every element | Overuse distracts from content |
| App backgrounds | Use standard materials instead |

### Standard Materials vs Liquid Glass

| Material | Use For |
|----------|---------|
| Liquid Glass | Navigation/functional layer floating above content |
| `.ultraThin` | Content layer — full-screen views needing light scheme |
| `.thin` | Content layer — overlay views partially obscuring content, light scheme |
| `.regular` | Content layer — overlay views partially obscuring content |
| `.thick` | Content layer — overlay views partially obscuring content, dark scheme |

### Regular vs Clear Decision Tree

```
Is it over media-rich content (photos, videos)?
├── No  → Use regular
└── Yes → Will a dimming layer harm the content?
    ├── Yes → Use regular
    └── No  → Is the content above bold and bright?
        ├── No  → Use regular
        └── Yes → Use clear + dimming layer
```

### Clear Variant Dimming

For optimal contrast with clear glass:
- **Bright content:** Add a dark dimming layer of 35% opacity
- **Dark content:** No dimming layer needed
- **AVKit media controls:** They provide their own dimming layer

```swift
// Localized dimming for small glass elements
.glassEffect(.clear)
.background(.black.opacity(0.3))
```

### Shape Guidelines

Three shape types for concentric layouts:
1. **Fixed shapes** — constant corner radius
2. **Capsules** — radius = half the container height
3. **Concentric shapes** — radius = parent radius minus padding

Capsules naturally support concentricity — use throughout the system for sliders, switches, bars, buttons, rounded table views. On macOS, use rounded rectangles for mini/small/medium controls in dense layouts.

### Color in Controls

- Be judicious with color in controls and navigation
- Leverage system colors or define custom colors with light/dark variants
- Use increased contrast variants
- Avoid overcrowding or layering glass elements on top of each other

### Scroll Edge Effects

Scroll edge effects work in concert with Liquid Glass:
- **Soft** (default, most cases, iOS/iPadOS): Subtle transition, works well with interactive elements using glass
- **Hard** (mostly macOS): Stronger, more opaque boundary — ideal for interactive text, controls without backgrounds, pinned table headers

Don't mix or stack them. Apply one scroll edge effect per view.

---

## 15. Performance Considerations

### Optimization Rules

1. **Limit glass effects onscreen** simultaneously
2. **Use `GlassEffectContainer`** to combine multiple effects — single rendering pass
3. **Avoid too many containers** — creating many containers degrades performance
4. **Avoid effects outside containers** — they cannot share the sampling region
5. **Profile regularly** with Xcode's SwiftUI Performance Instrument

### Why Containers Matter

Glass samples content from an area larger than itself. Without a container, each glass element independently samples its surroundings, leading to:
- Higher rendering cost (multiple sampling passes)
- Inconsistent visual results (glass near other glass in different containers)

A container lets glass elements share their sampling region, providing both performance improvement and visual consistency.

### The Apple Warning

> "Creating too many Liquid Glass effect containers and applying too many effects to views outside of containers can degrade performance. Limit the use of Liquid Glass effects onscreen at the same time."

---

## 16. Current Usage in Lumen

### AmbientPlayer.swift

Single glass surface for the gesture-driven player:

```swift
.glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
```

- Uses `regular` variant with `interactive()` for touch response
- Continuous rounded rectangle matches player shape
- Corner radius adapts: 22.5pt for mini/compact/volume, `screenCornerRadius - 10` for expanded
- No container needed — single glass element

### CollectionsView.swift

Turntable disk glass:

```swift
.glassEffect(.regular, in: Circle())
```

- Uses `regular` variant without `interactive()` — disk is not a button
- Circle shape matches turntable geometry
- Applied after `.clipShape(Circle())` and before `.position(center)`
- No container needed — single glass element

### ContentView.swift

Completion pill system with morphing transitions:

```swift
// Container wrapping all completion elements
GlassEffectContainer(spacing: 6) { ... }

// Center pill — ALWAYS in hierarchy (anchor for glass morphing)
// Morphs between "Complete" and "Completed" states
.glassEffect(.regular.interactive(), in: Capsule())
.glassEffectID("center", in: glassMorph)

// Trash button — conditionally appears, morphs FROM center pill
.glassEffect(.regular.tint(.red).interactive(), in: Circle())
.glassEffectID("trash", in: glassMorph)
.glassEffectTransition(.matchedGeometry)

// Counter pill — conditionally appears, morphs FROM center pill
.glassEffect(.regular.interactive(), in: Circle())
.glassEffectID("counter", in: glassMorph)
.glassEffectTransition(.matchedGeometry)
```

**Key pattern:** Center pill is the **stable anchor** (always in hierarchy, no `.glassEffectTransition`). Trash and counter appear/disappear with `.glassEffectTransition(.matchedGeometry)` — they derive their initial glass geometry from the nearby center pill shape, creating the fluid morph/split effect.

**APIs used:**
- `GlassEffectContainer` with `spacing: 6` ✅
- `glassEffect(_:in:)` with Capsule and Circle shapes ✅
- `.interactive()` on all elements ✅
- `.tint(.red)` on trash button ✅
- `glassEffectID(_:in:)` with `@Namespace` for morphing ✅
- `glassEffectTransition(.matchedGeometry)` on appearing/disappearing elements ✅

**APIs not yet used:**
- `Glass.clear` / `Glass.identity` variants
- `.materialize` / `.identity` transitions
- `glassEffectUnion(id:namespace:)`
- `.glass` / `.glassProminent` button styles
- `backgroundExtensionEffect()`
- `glassBackgroundEffect()` (visionOS only)
