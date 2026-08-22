import SwiftUI

struct GreetingView: View {
    private let greeting: String = {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<21: return "Good evening."
        default:      return "Good night."
        }
    }()

    var body: some View {
        Text(greeting)
            .font(.system(size: 48, design: .serif))
            .foregroundColor(.white)
            .containerRelativeFrame(.horizontal) { length, _ in length * 0.8 }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    GreetingView()
        .background(Color.black)
}
