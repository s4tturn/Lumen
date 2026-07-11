import Foundation
import UIKit

enum UIConstants {
    enum Navigation {
        static let pageSpacing: CGFloat = 25
        static let unfocusScale: CGFloat = 15
        static let unfocusBlur: CGFloat = 8
    }

    enum General {
        private static let screen: UIScreen = {
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen ?? UIScreen.main
        }()

        static let screenWidth = screen.bounds.width
        static let screenHeight = screen.bounds.height
        static let screenCornerRadius: CGFloat = screen.value(forKey: "_displayCornerRadius") as? CGFloat ?? 55
    }
}
