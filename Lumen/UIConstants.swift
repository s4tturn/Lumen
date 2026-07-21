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
        static let glowRadius: CGFloat = 10
        static let glowOpacity: Double = 0.7
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

    enum Collections {
        /// Angular distance between adjacent collection cards (degrees).
        static let cardAngle: Double = 45
        /// What fraction of card height the card occupies relative to screen width.
        static let cardWidthRatio: CGFloat = 0.7
        /// Spacing between card centers.
        static let cardSpacingRatio: CGFloat = 0.2
        /// Dead zone radius for disk drag (pts from center).
        static let diskDeadZone: CGFloat = 100
        /// Velocity threshold (°/s) for momentum-based disk snap.
        static let diskMomentumThreshold: Double = 100
        /// Minimum screen fraction drag to trigger item swipe.
        static let itemSwipeThreshold: CGFloat = 0.2
        /// Minimum velocity to trigger item swipe.
        static let itemSwipeVelocity: CGFloat = 300
        /// Minimum drag distance (pts) to dismiss expanded card.
        static let dismissDistance: CGFloat = 80
        /// Minimum drag velocity (pts/s) to dismiss expanded card.
        static let dismissVelocity: CGFloat = 300
        /// Distance at which dismiss progress reaches 100%.
        static let dismissFullDistance: CGFloat = 150
        /// Tick mark dimensions.
        static let tickWidth: CGFloat = 7
        static let tickHeight: CGFloat = 40
        /// Number of visible cards on each side of center in carousel.
        static let visibleCardRadius: Int = 2
    }

    enum General {
        private static let screen: UIScreen = {
            (UIApplication.shared.connectedScenes.first as? UIWindowScene)!.screen
        }()

        static let screenWidth = screen.bounds.width
        static let screenHeight = screen.bounds.height
        static let screenCornerRadius: CGFloat = screen.value(forKey: "_displayCornerRadius") as? CGFloat ?? 55
    }
}
