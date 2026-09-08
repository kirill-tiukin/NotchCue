import SwiftUI
import AppKit

// MARK: - Root: the morphing notch (nook-notch style shell, our teleprompter inside)

struct PrompterView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @State private var contentHeight: CGFloat = 0
    @State private var isHeaderHovered = false

    private var isOpen: Bool { !viewModel.isCollapsedToPill }

    // MARK: Geometry — ported from nook-notch (NotchView.swift)

    private var closedNotchH: CGFloat { max(24, viewModel.notchSize.height) }
    private var closedNotchW: CGFloat { viewModel.notchSize.width }
    /// Extra width beyond the physical notch so the header content sits on the
    /// "shoulders" flanking the notch (nook-notch's `expansionWidth`).
    private var expansionWidth: CGFloat { 2 * max(0, closedNotchH - 12) + 20 }
    /// The island width — the closed pill, and the open shape both use this.
    private var islandWidth: CGFloat { closedNotchW + expansionWidth }

    /// The teleprompter box width. Settings always uses 540; the plain
    /// preview grows with the Width slider (never smaller than the island),
    /// so increasing it actually widens the visible box instead of just the
    /// text/outline inside a box that stays clipped to a fixed, smaller size
    /// — that mismatch (drawn wider than what's actually clipped) was what
    /// read as the box drifting left instead of growing centered.
    private var boxWidth: CGFloat {
        if viewModel.isExpanded { return 540 }
        return max(islandWidth, viewModel.prompterWidth + 24)
    }

    // One NotchShape that morphs. Closed pill stays a fixed size — no more
    // growing on hover; open preview and settings both size to boxWidth.
    private var panelWidth: CGFloat {
        if !isOpen { return islandWidth }
        return max(boxWidth, islandWidth)
    }
    // Fixed radii — growing them on open pinches the shape's bottom edge inward,
    // which reads as the box shrinking. Keep them constant.
    private let shapeTopRadius: CGFloat = 6
    private let shapeBottomRadius: CGFloat = 12

    var body: some View {
        ZStack(alignment: .top) {
            panel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            headerRow
                .frame(height: closedNotchH)

            if isOpen {
                openContent
                    .transition(.opacity)   // geometry does the reveal; content just fades
            }
        }
        .frame(width: panelWidth)
        .background(NotchShape(topCornerRadius: shapeTopRadius, bottomCornerRadius: shapeBottomRadius).fill(viewModel.prompterTheme.shapeFillColor))
        .clipShape(NotchShape(topCornerRadius: shapeTopRadius, bottomCornerRadius: shapeBottomRadius))
        // Applied after clipShape, so the shadow's silhouette follows the
        // island's actual shape, not a plain rectangle around the header.
        .shadow(
            color: .black.opacity(isHeaderHovered ? 0.6 : (isOpen ? 0.4 : 0)),
            radius: isHeaderHovered ? 22 : 16,
            y: 8
        )
        // Report our real, current size so the window can size its
        // click-accepting region to match exactly — not a hardcoded guess
        // that clips off controls near the edges or bottom.
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewModel.visibleContentSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in viewModel.visibleContentSize = newSize }
            }
        )
    }

    // MARK: Header — a chevron control, styled exactly like boring.notch's
    // header buttons (BoringHeader.swift): a black Capsule with a white SF
    // Symbol, PlainButtonStyle. Right-aligned. Down = open, up = collapse.

    private var headerRow: some View {
        HStack(spacing: 4) {
            Spacer(minLength: 0)
            // Shown on the pill and the open preview — hidden only once
            // Settings is expanded, where the control bar's own gear/chevron
            // button already covers it. Background matches the box's own
            // background; the arrow matches the text color, same as
            // everything else in that state.
            if !viewModel.isExpanded {
                Button {
                    toggle()
                } label: {
                    Capsule()
                        .fill(viewModel.prompterTheme.backgroundColor)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                .foregroundColor(viewModel.prompterTheme.textColor)
                                .imageScale(.small)
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(.headline, design: .rounded))
        .foregroundColor(.gray)
        .padding(.horizontal, 6)
        .frame(width: panelWidth, height: closedNotchH, alignment: .center)
        .contentShape(Rectangle())
        // Hover feedback for the whole header area: a real trackpad haptic
        // tick, plus the shadow above growing (no intensity knob exists in
        // the public API — .generic is the most pronounced single pattern
        // available, one clean hit rather than stacking pulses).
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHeaderHovered = hovering }
            if hovering {
                NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
            }
        }
        .onTapGesture { toggle() }
    }

    private func toggle() {
        if isOpen { collapseToPill() } else { openPreview() }
    }

    // MARK: Open content — the teleprompter, exactly as before

    @ViewBuilder
    private var openContent: some View {
        Group {
            if viewModel.isExpanded {
                VStack(spacing: 0) {
                    PrompterStageRepresentable(viewModel: viewModel, contentHeight: $contentHeight)
                        .frame(height: 140)
                    NotchPanelView(viewModel: viewModel)
                        .frame(height: 520)
                }
                .frame(width: boxWidth)
            } else {
                PrompterStageRepresentable(viewModel: viewModel, contentHeight: $contentHeight)
                    .frame(width: boxWidth, height: viewModel.prompterHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        // Box keeps its own width, centred inside the (possibly wider) shape.
        .frame(width: panelWidth)
    }

    // MARK: Transitions

    // boring.notch / nook-notch springs.
    static let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    static let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)
    static var panelMotion: Animation { openAnimation }

    private func openPreview() {
        withAnimation(Self.openAnimation) {
            viewModel.isExpanded = false
            viewModel.isCollapsedToPill = false
        }
    }

    private func collapseToPill() {
        withAnimation(Self.closeAnimation) {
            viewModel.isExpanded = false
            viewModel.isCollapsedToPill = true
        }
    }
}

// MARK: - Scrolling stage (NSView wrapper for scroll-wheel + hover-pause)

struct PrompterStageRepresentable: NSViewRepresentable {
    @ObservedObject var viewModel: PrompterViewModel
    @Binding var contentHeight: CGFloat

    func makeNSView(context: Context) -> PrompterStageNSView {
        PrompterStageNSView(viewModel: viewModel, contentHeight: $contentHeight)
    }

    func updateNSView(_ nsView: PrompterStageNSView, context: Context) {
        nsView.refresh()
    }
}

final class PrompterStageNSView: NSView {
    private let viewModel: PrompterViewModel
    private var hosting: NSHostingView<PrompterStageContent>!
    private var trackingArea: NSTrackingArea?
    private var isHovering = false
    @Binding private var contentHeight: CGFloat

    init(viewModel: PrompterViewModel, contentHeight: Binding<CGFloat>) {
        self.viewModel = viewModel
        self._contentHeight = contentHeight
        super.init(frame: .zero)

        hosting = NSHostingView(rootView: PrompterStageContent(viewModel: viewModel, contentHeight: contentHeight))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        hosting.rootView = PrompterStageContent(viewModel: viewModel, contentHeight: $contentHeight)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea { removeTrackingArea(trackingArea) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        trackingArea = area
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovering = true
        viewModel.isPointerOverStage = true
        viewModel.hoverPause()
    }

    override func mouseExited(with event: NSEvent) {
        isHovering = false
        viewModel.isPointerOverStage = false
        viewModel.hoverResume()
    }

    override func scrollWheel(with event: NSEvent) {
        // Scrolling the text works the same whether settings are open or not —
        // the preview stage at the top of the settings panel is the same
        // scrollable view, just shorter.
        guard isHovering else {
            super.scrollWheel(with: event)
            return
        }
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 12
        let next = viewModel.offset - delta
        let upper = max(0, viewModel.maxScrollOffset)
        viewModel.offset = min(max(0, next), upper)
    }
}

// MARK: - Stage content (text + fades + progress + hover controls)

struct PrompterStageContent: View {
    @ObservedObject var viewModel: PrompterViewModel
    @Binding var contentHeight: CGFloat

    /// Controls are visible whenever the pointer is over the stage OR while it's
    /// playing / hover-paused — so the pause button is always reachable.
    /// "Show controls on hover" (Behavior settings) now actually does what
    /// it says: on, the bar only appears while your pointer is over the
    /// stage — not "always visible" during playback too. Off falls back to
    /// the old always-reachable behavior (so Pause stays findable without
    /// hovering) for anyone who preferred that.
    private var showControls: Bool {
        if viewModel.showHoverControls {
            return viewModel.isPointerOverStage
        }
        return viewModel.isPointerOverStage || viewModel.isPlaying || viewModel.isHoverPaused
    }

    var body: some View {
        ZStack {
            viewModel.prompterTheme.backgroundColor

            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    movingText(availableWidth: geo.size.width)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .offset(y: -viewModel.offset)
                        .background(HeightReader(height: $contentHeight))
                    Spacer(minLength: 0)
                }
                .clipped()
                .onChange(of: viewModel.text) { _, _ in viewModel.offset = 0 }
                .onChange(of: contentHeight) { _, h in
                    viewModel.maxScrollOffset = max(0, h - geo.size.height)
                    // Widening the box re-wraps the text into fewer, wider
                    // lines — shrinking the total content height. Without
                    // this, a scroll position from before the resize could
                    // sit past the new (shorter) end, pushing the text
                    // entirely off the top of the visible box.
                    viewModel.offset = min(viewModel.offset, viewModel.maxScrollOffset)
                }
                .onChange(of: geo.size.height) { _, vh in
                    viewModel.maxScrollOffset = max(0, contentHeight - vh)
                    viewModel.offset = min(viewModel.offset, viewModel.maxScrollOffset)
                }
                .onAppear {
                    viewModel.maxScrollOffset = max(0, contentHeight - geo.size.height)
                    viewModel.offset = min(viewModel.offset, viewModel.maxScrollOffset)
                }
            }
            .mask(
                viewModel.isExpanded
                ? AnyView(LinearGradient(
                    stops: [
                        .init(color: .black, location: 0),
                        .init(color: .black, location: 0.68),
                        .init(color: .clear, location: 0.94)
                    ], startPoint: .top, endPoint: .bottom))
                : AnyView(Color.black)
            )

            VStack(spacing: 0) {
                if viewModel.enableTopFade {
                    LinearGradient(colors: [viewModel.prompterTheme.fadeColor, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: viewModel.topFadeHeight)
                        .allowsHitTesting(false)
                }
                Spacer()
                if viewModel.enableBottomFade {
                    LinearGradient(colors: [.clear, viewModel.prompterTheme.fadeColor], startPoint: .top, endPoint: .bottom)
                        .frame(height: viewModel.bottomFadeHeight)
                        .allowsHitTesting(false)
                }
            }

            if viewModel.showProgressBar {
                HStack {
                    Spacer()
                    ProgressBarView(
                        currentOffset: viewModel.offset,
                        totalHeight: viewModel.maxScrollOffset,
                        theme: viewModel.prompterTheme
                    )
                }
            }

            if showControls {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    controlBar
                        .padding(.bottom, 8)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.2), value: showControls)
    }

    /// Compact pill of round buttons, floating just inside the box's bottom edge.
    private var controlBar: some View {
        // Same rule for every theme: match the surrounding text color
        // (white for Dark, black for Light) instead of always being white.
        let iconColor = viewModel.prompterTheme.textColor
        return HStack(spacing: 6) {
            if viewModel.scripts.count > 1 {
                iconButton("chevron.left.circle.fill", color: iconColor) { viewModel.previousScript() }
            }

            if viewModel.voiceActivation {
                iconButton("microphone.circle.fill", color: iconColor) {}.disabled(true)
            } else {
                let effectivelyPlaying = viewModel.isPlaying || viewModel.isHoverPaused
                iconButton(effectivelyPlaying ? "pause.circle.fill" : "play.circle.fill", color: iconColor) {
                    if effectivelyPlaying { viewModel.pause() } else { viewModel.play() }
                }
            }

            iconButton("backward.circle.fill", color: iconColor) { viewModel.scrollBack() }

            iconButton(viewModel.isExpanded ? "chevron.up.circle.fill" : "gearshape.circle.fill", color: iconColor) {
                withAnimation(PrompterView.panelMotion) { viewModel.isExpanded.toggle() }
            }

            if viewModel.scripts.count > 1 {
                iconButton("chevron.right.circle.fill", color: iconColor) { viewModel.nextScript() }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(viewModel.prompterTheme.controlBarTint.opacity(viewModel.prompterTheme.controlBarTintOpacity))
                )
                .clipShape(Capsule(style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
        )
        .fixedSize()
    }

    private func iconButton(_ name: String, color: Color = .white, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 20))
                .foregroundColor(color)
                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }

    /// Capped to `availableWidth` (the stage's real, current geometry) — not
    /// just `prompterWidth` on its own — so a width bigger than the box
    /// actually containing it can never overflow one side asymmetrically.
    /// The visible box's own width can lag behind (or simply not track)
    /// `prompterWidth` in some states (e.g. Settings pins it to a fixed
    /// 540), so this is the one guarantee that text never draws wider than
    /// what's actually there to center it.
    private func movingText(availableWidth: CGFloat) -> some View {
        let width = min(max(80, viewModel.prompterWidth - 32), max(80, availableWidth - 16))
        return VStack(spacing: viewModel.lineHeight) { textBlock }
            // Paragraph wraps at its original width (box width minus side padding),
            // centred inside the box.
            .frame(width: width)
            // Margin from the outline to the first / last line of text.
            .padding(.top, 22)
            .padding(.bottom, 44)
    }

    private var textBlock: some View {
        let base = viewModel.text.isEmpty ? "Put some text in Settings..." : viewModel.text
        let text = base + "\n\n[end]"
        return Text(attributedText(from: text))
            .multilineTextAlignment(viewModel.textAlignment.swiftUIAlignment)
            .lineSpacing(viewModel.lineHeight)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func attributedText(from text: String) -> AttributedString {
        var attributed = AttributedString(text)
        attributed.font = Font.system(size: viewModel.fontSize, weight: .regular, design: viewModel.fontDesign)
        attributed.foregroundColor = viewModel.prompterTheme.textColor

        if let regex = try? NSRegularExpression(pattern: "\\[[^\\]]+\\]", options: []) {
            let ns = text as NSString
            for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                if let r = Range(match.range, in: text), let ar = Range(r, in: attributed) {
                    attributed[ar].font = Font.system(size: viewModel.fontSize, weight: .regular, design: viewModel.fontDesign).italic()
                    attributed[ar].foregroundColor = viewModel.prompterTheme.textColor.opacity(0.4)
                }
            }
        }
        return attributed
    }
}

// MARK: - Height reader

private struct HeightReader: View {
    @Binding var height: CGFloat
    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { height = proxy.size.height }
                .onChange(of: proxy.size) { _, newSize in height = newSize.height }
        }
    }
}

// MARK: - Progress bar

struct ProgressBarView: View {
    let currentOffset: CGFloat
    let totalHeight: CGFloat
    let theme: PrompterTheme

    private var progress: Double {
        guard totalHeight > 0 else { return 0 }
        return min(max(Double(currentOffset / totalHeight), 0), 1.0)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textColor.opacity(0.15))
                    .frame(width: 4)
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.textColor.opacity(0.6))
                    .frame(width: 4, height: geo.size.height * progress)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(width: 4)
        .padding(.trailing, 6)
        .padding(.vertical, 8)
        .allowsHitTesting(false)
    }
}
