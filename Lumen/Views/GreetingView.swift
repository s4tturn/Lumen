import SwiftUI

struct GreetingView: View {
    var body: some View {
        // A literal string resource rather than one assembled at runtime: the
        // launch screen's one word is the whole localisation surface, and a
        // literal is what gives the string catalogue a key to fill.
        Text("Hello", comment: "The greeting shown over the app as it opens.")
            .font(.system(size: 40, design: .serif))
            .foregroundStyle(.white)
            .containerRelativeFrame(.horizontal) { length, _ in length * 0.8 }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            // The launch word's frame, so the reveal's target is
            // visible while it arrives.
            .debugSurfaceBorder()
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    GreetingView()
        .background { Color.black }
}
