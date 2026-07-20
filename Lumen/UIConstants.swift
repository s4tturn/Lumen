import Foundation
import UIKit
import SwiftUI

enum UIConstants {
    enum Navigation {
        static let pageSpacing: CGFloat = 25
    }

    enum DotMatrix {
        static let dotSize: CGFloat = 10
        static let rippleScale: CGFloat = 6
        static let dotSpacing: CGFloat = 44
        static let waveSpread: Double = 0.55
        static let rotationSpeed: Double = 0.03
        static let baseOpacity: Double = 0.25
        static let activeOpacity: Double = 0.75
    }

    enum Focus {
        static let subduedBlur: CGFloat = 10
        static let subduedOpacity: CGFloat = 80
        static let subduedScale: CGFloat = 10
        static let subduedAltBlur: CGFloat = 10
        static let subduedAltOpacity: CGFloat = 80
        static let subduedAltScale: CGFloat = 0
        static let hiddenBlur: CGFloat = 20
        static let hiddenOpacity: CGFloat = 0
        static let hiddenScale: CGFloat = 20
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
