import SwiftUI

struct GreetingView: View {
    var body: some View {

        Text("Hello", comment: "The greeting shown over the app as it opens.")
            .font(.system(size: 40, design: .serif))
            .foregroundStyle(.white)
            .containerRelativeFrame(.horizontal) { length, _ in length * 0.8 }
            .lineLimit(1)
            .minimumScaleFactor(0.85)

            .debugSurfaceBorder()
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    GreetingView()
        .background { Color.black }
}
