import AppKit
import SwiftUI
import Combine

/// Non-activating panel that spans the full width of the screen and hangs down
/// from the top. It never moves or resizes — the notch shape is drawn *inside*
/// it by SwiftUI. This mirrors the nook-notch architecture and removes every
/// window-repositioning bug. Clicks outside the visible notch content pass
/// straight through to the menu bar / apps behind.
final class PrompterPanelWindow: NSPanel {
    var acceptsKey = false
    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { false }
}

/// Hosting view that only accepts hits inside the currently-visible notch content.
final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    var hitTestRect: () -> CGRect = { .zero }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard hitTestRect().contains(point) else { return nil }
        return super.hitTest(point)
    }
}

final class PrompterWindow {
    private var window: PrompterPanelWindow!
    private var hosting: PassThroughHostingView<PrompterView>!
    private let viewModel: PrompterViewModel
    private var cancellables: Set<AnyCancellable> = []
    private var mouseTrackingTimer: Timer?

    /// Total window height. Big enough for the tallest expanded panel.
    private let windowHeight: CGFloat = 820

    init(viewModel: PrompterViewModel) {
        self.viewModel = viewModel

        let screen = Self.screen(for: viewModel.selectedScreenIndex)
        let screenFrame = screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        viewModel.notchSize = screen?.notchSize ?? CGSize(width: 200, height: 32)
        viewModel.screenWidth = screenFrame.width

        let windowFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.maxY - windowHeight,
            width: screenFrame.width,
            height: windowHeight
        )

        window = PrompterPanelWindow(
            contentRect: windowFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isFloatingPanel = true
        window.becomesKeyOnlyIfNeeded = true
        window.hidesOnDeactivate = false
        window.hasShadow = false
        window.isMovable = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        // Above everything, including other notch overlays (NotchNook) and the
        // login shield, so our pill is always the one on top.
        window.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        window.allowsToolTipsWhenApplicationIsInactive = true

        // Start click-through everywhere; the mouse-tracking timer below turns
        // this off only while the cursor is actually over the visible content.
        // (hitTest returning nil does NOT pass clicks to windows underneath —
        // it only decides which view *inside* this window handles them. Without
        // this, a full-width, near-full-height, always-on-top panel like this
        // one silently swallows every click under it across the whole screen.)
        window.ignoresMouseEvents = true
        hosting = PassThroughHostingView(rootView: PrompterView(viewModel: viewModel))
        hosting.hitTestRect = { [weak self] in self?.contentHitRect() ?? .zero }
        window.contentView = hosting
        window.setFrame(windowFrame, display: true)

        observe()
        startMouseTracking()
        updateScreenRecordingVisibility(viewModel.hideFromScreenRecording)
        if viewModel.isPrompterVisible { window.orderFrontRegardless() }
    }

    deinit {
        mouseTrackingTimer?.invalidate()
    }

    /// Polls the global cursor position (no Accessibility permission needed —
    /// unlike an event monitor, this only *reads* `NSEvent.mouseLocation`) and
    /// only lets the window accept clicks while the cursor is over the actual
    /// visible pill/box. This is the real fix for the window eating every
    /// click on screen: `ignoresMouseEvents` is the only thing that makes
    /// clicks fall through to whatever is underneath.
    private func startMouseTracking() {
        mouseTrackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self, let window = self.window else { return }
            let screenPoint = NSEvent.mouseLocation
            let windowPoint = window.convertPoint(fromScreen: screenPoint)
            let inside = self.contentHitRect().contains(windowPoint)
            if window.ignoresMouseEvents == inside {
                window.ignoresMouseEvents = !inside
            }
        }
        mouseTrackingTimer?.tolerance = 1.0 / 60.0
    }

    // MARK: Hit testing

    /// Rect (window coords, origin bottom-left) covering the currently-visible
    /// notch content so only that area steals clicks; everything else passes
    /// through to the menu bar / apps behind.
    private func contentHitRect() -> CGRect {
        let winW = window.frame.width
        let winH = window.frame.height

        // The real, measured size of the pill/box (published live by
        // PrompterView via a GeometryReader) — not a guessed constant. A
        // guessed rect smaller than the actual content silently clips off
        // controls near the edges/bottom (that's what made things like the
        // Voice activation toggle unclickable). Small margin so edge-hugging
        // controls (sliders, segmented pickers) aren't clipped by rounding.
        let measured = viewModel.visibleContentSize
        if measured.width > 0, measured.height > 0 {
            let margin: CGFloat = 10
            let w = measured.width + margin * 2
            let h = measured.height + margin
            return CGRect(x: (winW - w) / 2, y: winH - h, width: w, height: h)
        }

        // Fallback before the first layout pass reports a size.
        if viewModel.isCollapsedToPill {
            let w: CGFloat = 360
            let h = viewModel.notchSize.height + 52
            return CGRect(x: (winW - w) / 2, y: winH - h, width: w, height: h)
        }
        let w: CGFloat = viewModel.isExpanded ? 560 : 400
        let h: CGFloat = viewModel.isExpanded ? 800 : 200
        return CGRect(x: (winW - w) / 2, y: winH - h, width: w, height: h)
    }

    // MARK: Observation

    private func observe() {
        viewModel.$isExpanded
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] expanded in
                guard let self = self else { return }
                self.window.acceptsKey = expanded
                if expanded {
                    self.window.makeKey()
                } else {
                    self.window.resignKey()
                }
            }
            .store(in: &cancellables)

        viewModel.$isPrompterVisible
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                guard let self = self else { return }
                if visible {
                    self.window.alphaValue = 0
                    self.window.orderFrontRegardless()
                    NSAnimationContext.runAnimationGroup { $0.duration = 0.2; self.window.animator().alphaValue = 1 }
                } else {
                    NSAnimationContext.runAnimationGroup({ $0.duration = 0.15; self.window.animator().alphaValue = 0 },
                                                         completionHandler: { self.window.orderOut(nil) })
                }
            }
            .store(in: &cancellables)

        viewModel.$hideFromScreenRecording
            .receive(on: RunLoop.main)
            .sink { [weak self] hide in self?.updateScreenRecordingVisibility(hide) }
            .store(in: &cancellables)

        viewModel.$selectedScreenIndex
            .receive(on: RunLoop.main)
            .sink { [weak self] index in self?.reposition(for: index) }
            .store(in: &cancellables)

        // The window normally sits at CGShieldingWindowLevel() — the highest
        // practical level — so it stays above other notch overlays. That
        // also covers macOS's own system dialogs (like the mic-permission
        // prompt), so drop to a normal floating level while one may be up.
        viewModel.$isRequestingSystemPermission
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] requesting in
                guard let self else { return }
                self.window.level = requesting
                    ? .floating
                    : NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
                // The system permission dialog takes key-window status while
                // it's up. Once it's gone, reclaim it if the panel is still
                // supposed to be interactive — otherwise every control
                // (toggle tints included) renders in macOS's "inactive
                // window" gray state until something else happens to
                // refocus us.
                if !requesting, self.viewModel.isExpanded {
                    self.window.makeKey()
                }
            }
            .store(in: &cancellables)
    }

    private func reposition(for index: Int) {
        guard let screen = Self.screen(for: index) else { return }
        let f = screen.frame
        viewModel.notchSize = screen.notchSize
        viewModel.screenWidth = f.width
        window.setFrame(NSRect(x: f.minX, y: f.maxY - windowHeight, width: f.width, height: windowHeight), display: true)
    }

    private static func screen(for index: Int) -> NSScreen? {
        let screens = NSScreen.screens
        if index >= 0, index < screens.count { return screens[index] }
        return NSScreen.main
    }

    private func updateScreenRecordingVisibility(_ hide: Bool) {
        window.sharingType = hide ? .none : .readOnly
    }
}
