import CoreGraphics

extension CGPoint {
    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x * rhs, y: lhs.y * rhs)
    }

    static func / (lhs: CGPoint, rhs: CGFloat) -> CGPoint {
        CGPoint(x: lhs.x / rhs, y: lhs.y / rhs)
    }

    var length: CGFloat {
        sqrt(x * x + y * y)
    }

    var normalized: CGPoint {
        let len = length
        guard len > 0 else { return .zero }
        return CGPoint(x: x / len, y: y / len)
    }

    func distance(to other: CGPoint) -> CGFloat {
        (self - other).length
    }

    func midpoint(to other: CGPoint) -> CGPoint {
        CGPoint(x: (x + other.x) / 2, y: (y + other.y) / 2)
    }

    func clamped(to rect: CGRect) -> CGPoint {
        CGPoint(
            x: max(rect.minX, min(rect.maxX, x)),
            y: max(rect.minY, min(rect.maxY, y))
        )
    }
}

extension CGSize {
    static func * (lhs: CGSize, rhs: CGFloat) -> CGSize {
        CGSize(width: lhs.width * rhs, height: lhs.height * rhs)
    }

    var maxDimension: CGFloat {
        max(width, height)
    }

    var minDimension: CGFloat {
        min(width, height)
    }
}

extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    init(center: CGPoint, size: CGSize) {
        self.init(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }
}
