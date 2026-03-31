import Foundation

extension CGRect {

    /// Inset the rect by uniform padding on all sides
    func insetBy(padding: CGFloat) -> CGRect {
        insetBy(dx: padding, dy: padding)
    }

    /// Center point of the rect
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    /// Snap all values to whole pixels for crisp rendering
    var pixelAligned: CGRect {
        CGRect(
            x: origin.x.rounded(.down),
            y: origin.y.rounded(.down),
            width: size.width.rounded(.up),
            height: size.height.rounded(.up)
        )
    }
}
