import SwiftUI

struct GreetingView: View {
    private let greeting: String = {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        default:      return "Hello"
        }
    }()

    var body: some View {
        Text(greeting)
            .font(.system(size: 40, design: .serif))
            .foregroundStyle(.white)
            .containerRelativeFrame(.horizontal) { length, _ in length * 0.8 }
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    GreetingView()
        .background { Color.black }
}
