import AppKit

extension NSScreen {
    /// Pixel-perfect size of the physical notch (camera housing) on this screen.
    /// On non-notched displays, returns a sensible fallback sized to the menu bar.
    /// Ported from the nook-notch project.
    var notchSize: CGSize {
        guard safeAreaInsets.top > 0 else {
            return CGSize(width: 224, height: menuBarHeight)
        }

        let notchHeight = safeAreaInsets.top
        let fullWidth = frame.width
        let leftPadding = auxiliaryTopLeftArea?.width ?? 0
        let rightPadding = auxiliaryTopRightArea?.width ?? 0

        guard leftPadding > 0, rightPadding > 0 else {
            return CGSize(width: 180, height: notchHeight)
        }

        // +4 matches boring.notch's calculation for proper alignment
        let notchWidth = fullWidth - leftPadding - rightPadding + 4
        return CGSize(width: notchWidth, height: notchHeight)
    }

    /// Menu-bar height on this specific screen (never below 24).
    var menuBarHeight: CGFloat {
        max(frame.maxY - visibleFrame.maxY, 24)
    }

    var hasPhysicalNotch: Bool { safeAreaInsets.top > 0 }
}
