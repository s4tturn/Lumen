import Foundation
import UIKit
import SwiftUI

enum UIConstants {
    enum Navigation {
        static let pageSpacing: CGFloat = 20
    }

    enum DotMatrix {
        static let dotSize: CGFloat = 10
        static let rippleScale: CGFloat = 6
        static let dotSpacing: CGFloat = 44
        static let waveSpread: Double = 0.55
        static let rotationSpeed: Double = 0.03
        static let baseOpacity: Double = 0.25
        static let activeOpacity: Double = 0.75
        static let glowRadius: CGFloat = 10
        static let glowOpacity: Double = 0.7
    }

    enum Focus {
        static let subduedBlur: CGFloat = 10
        static let subduedDim: Double = 0.75
        static let subduedScale: CGFloat = 0.95
        static let hiddenBlur: CGFloat = 100
        static let hiddenDim: Double = 0
        static let hiddenScale: CGFloat = 0.95
    }

    enum General {
        private static let screen: UIScreen = {
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)!.screen
        }()

        static let screenWidth = screen.bounds.width
        static let screenHeight = screen.bounds.height
        static let screenCornerRadius: CGFloat = screen.value(forKey: "_displayCornerRadius") as? CGFloat ?? 0
        /// Minimum inset kept clear of the screen's rounded corners and home indicator.
        static let safeSpace: CGFloat = 15
    }
    enum Animation {
        static let tracking = SwiftUI.Animation.interactiveSpring(response: 0.1, dampingFraction: 0.86)
        static let snap = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let rubberbandReturn = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 1.0)
        static let reducedMotionFallback = SwiftUI.Animation.easeOut(duration: 0.2)
    }

    enum Collections {
        static let cardAngle: Double = 60
        static let visibleCardRadius: Int = 3
        static let cardWidthRatio: CGFloat = 0.6
        static let cardSpacingRatio: CGFloat = 0.3
        static let expandedBackgroundBlur: CGFloat = 20
        static let tickWidth: CGFloat = 10
        static let tickHeight: CGFloat = 30
        static let diskDeadZone: CGFloat = 40
        static let diskMomentumThreshold: Double = 50
        static let dismissFullDistance: CGFloat = 200
        static let dismissDistance: CGFloat = 100
        static let dismissVelocity: CGFloat = 500
        static let itemSwipeThreshold: CGFloat = 0.3
        static let itemSwipeVelocity: CGFloat = 800
    }
}
