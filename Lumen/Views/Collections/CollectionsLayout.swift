import Foundation
import SwiftUI

// MARK: - Geometry

struct CollectionsGeometry {
    let size: CGSize

    var diskRadius: CGFloat { size.height * Layout.diskRadiusRatio }
    var diskDiameter: CGFloat { diskRadius * 2 }
    var cardSize: CGFloat { diskDiameter * Layout.cardSizeRatio }
    var orbitPadding: CGFloat { diskRadius * Layout.orbitPaddingRatio }
    var orbitRadius: CGFloat { diskRadius + orbitPadding + cardSize / 2 }
    var diskCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height) }
    var diskDeadZone: CGFloat { diskRadius * Layout.deadZoneRatio }
    var dismissThreshold: CGFloat { cardSize * 0.15 }
    var collapsedCornerRadius: CGFloat { cardSize * Layout.collapsedCornerRatio }
    var tickHeight: CGFloat { diskRadius * Layout.tickHeightRatio }
    var tickWidth: CGFloat { diskRadius * Layout.tickWidthRatio }
    var screenCornerRadius: CGFloat { UIConstants.General.screenCornerRadius }
}

// MARK: - Constants

enum Layout {
    static let cardCount = cards.count

    static let cardSpacing: Double = 360.0 / Double(cardCount)
    static let tickSpacing: Double = 60

    static let diskRadiusRatio: CGFloat = 0.35
    static let cardSizeRatio: CGFloat = 0.5
    static let orbitPaddingRatio: CGFloat = 0.20
    static let deadZoneRatio: CGFloat = 0.06
    static let collapsedCornerRatio: CGFloat = 0.15
    static let tickHeightRatio: CGFloat = 0.1
    static let tickWidthRatio: CGFloat = 0.03

    // Flick snap: momentum row (damping ~0.8 → bounce 0.15, brisk not bouncy),
    // response inside the 0.3–0.4s band. Release velocity is handed to the
    // spring per release (see animateToCard); overlapping snaps blend instead
    // of fighting because interpolatingSpring adds overlapping effects.
    static let flickSnapDuration: TimeInterval = 0.38
    static let flickSnapBounce: Double = 0.15
    static let maxReleaseVelocity: Double = 6
    static let dismissVelocity: CGFloat = 800
    static let carouselFlickVelocity: CGFloat = 700
}

enum CoordinateSpaces {
    static let collections = "CollectionsView"
}

// MARK: - Math Helpers

func degrees(fromRadians radians: Double) -> Double {
    radians * 180.0 / .pi
}

func radians(fromDegrees degrees: Double) -> Double {
    degrees * .pi / 180.0
}

func normalizedAngleDelta(from start: Double, to end: Double) -> Double {
    var delta = end - start
    while delta > 180 { delta -= 360 }
    while delta < -180 { delta += 360 }
    return delta
}

func angle(of point: CGPoint, around center: CGPoint) -> Double {
    degrees(
        fromRadians: atan2(
            point.y - center.y,
            point.x - center.x
        )
    )
}

// MARK: - Shared Card Layout

struct CardLayout {
    let position: CGPoint
    let size: CGSize
    let offsetY: CGFloat
    let cornerRadius: CGFloat
    let rotation: Double
}
