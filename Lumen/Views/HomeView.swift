import SwiftUI

/// Home page: the dot-matrix ripple on black, dimmed at the edges by a
/// single around-view vignette.
///
/// Composition (thin container only — field and vignette live in their own
/// files per swiftui-pro views):
/// `DotMatrixView` (frame-anchored, safe-area-respecting) → vignette overlay
/// (bleeds) → black base (bleeds). Deliberately no interaction: the matrix
/// is ambient content, not a control.
///
/// Safe-area scoping is load-bearing (MEMORY.md): the Canvas content itself
/// stays safe-area-respecting so its drawn center is frame-anchored and rides
/// the pager offset rigidly. Only the black base and the vignette bleed, via
/// `background` / `overlay` with `ignoresSafeArea` on the decorating view
/// alone — never a trailing `ignoresSafeArea()` on the whole composed body,
/// which pinned the Canvas center to the window on iPhone and produced the
/// ~20-30px vertical hold-and-snap.
///
/// Deliberately no Liquid Glass here (liquid-glass material rule): glass needs
/// varied content behind it to refract, and over a flat black field it reads
/// as a plain tinted rectangle. The matrix _is_ the content layer; there is
/// no floating chrome to glass.
struct HomeView: View {
    var body: some View {
        DotMatrixView()
            .background { Color.black.ignoresSafeArea() }
            .overlay { DotMatrixVignette().ignoresSafeArea() }
            .accessibilityLabel("Dot matrix")
    }
}

#Preview {
    HomeView()
}
