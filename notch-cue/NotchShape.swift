import SwiftUI

/// Accurate notch shape using quadratic curves — top corners curve *inward*
/// (concave, to merge with the physical notch), bottom corners curve outward.
/// Ported from the nook-notch project.
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = 6, bottomCornerRadius: CGFloat = 14) {
        self.topCornerRadius = topCornerRadius
        self.bottomCornerRadius = bottomCornerRadius
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { .init(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        // Top-left corner (curves inward)
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY + topCornerRadius),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY - bottomCornerRadius))

        // Bottom-left corner
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + topCornerRadius + bottomCornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.minX + topCornerRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius - bottomCornerRadius, y: rect.maxY))

        // Bottom-right corner
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY - bottomCornerRadius),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.maxY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY + topCornerRadius))

        // Top-right corner (curves inward)
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - topCornerRadius, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        return path
    }
}

/// A short connector that flares from a wide top edge down to a narrower bottom
/// edge with concave sides — used to blend the island line into the box below.
struct IslandNeck: Shape {
    var bottomWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset = max(0, (rect.width - bottomWidth) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: rect.maxY),
            control: CGPoint(x: rect.maxX - inset, y: rect.minY)
        )
        p.addLine(to: CGPoint(x: rect.minX + inset, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.minX + inset, y: rect.minY)
        )
        p.closeSubpath()
        return p
    }
}

/// A "drawer" reveal: the view unrolls downward from its top edge at full
/// width. Pair it with a smooth (bounce-free) animation so the box slides
/// out from under the line as one continuous motion.
private struct RevealFromTop: ViewModifier {
    var progress: CGFloat
    func body(content: Content) -> some View {
        content
            .scaleEffect(x: 1, y: max(0.0001, progress), anchor: .top)
            .opacity(Double(min(1, progress * 1.6)))
    }
}

extension AnyTransition {
    static var revealDrawer: AnyTransition {
        .modifier(active: RevealFromTop(progress: 0), identity: RevealFromTop(progress: 1))
    }
}
