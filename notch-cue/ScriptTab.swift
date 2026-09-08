import SwiftUI

struct ScriptTabView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @FocusState private var isTextEditorFocused: Bool

    /// The panel's own theme-driven text color — NOT a system semantic color
    /// like `.textColor`/`.tertiary`, which follows `colorScheme` and can
    /// drift out of sync with this app's custom panel tint (that mismatch is
    /// exactly what produced white-on-white / black-on-black text before).
    private var fg: Color { viewModel.prompterTheme.panelTextColor }

    private var wordCount: Int {
        viewModel.text
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    /// Measures the actual wrapped text height using real TextKit layout
    /// (`NSLayoutManager`), not `NSString.boundingRect` — Apple's own docs
    /// note `boundingRect` is unreliable for the *aggregate* height of
    /// wrapped multi-line text (it's meant for simpler single-line sizing),
    /// and that's exactly what produced a systematic undercount here versus
    /// the real read time. This also doesn't depend on
    /// `viewModel.maxScrollOffset`, which belongs to whatever the live stage
    /// preview happens to be rendering at that instant and can lag or be
    /// stale right after switching answers or changing settings.
    private var estimatedContentHeight: CGFloat {
        // Deliberately NOT visuallyCompensatedSize — that's only applied to
        // this settings editor's own on-screen display. The actual scrolling
        // teleprompter (attributedText(from:) in PrompterView) renders at
        // the raw fontSize, so the estimate has to match that, not the
        // editor's cosmetic size, or it'll measure a font smaller than
        // what's actually scrolled — undercounting the real duration.
        let nsFont = viewModel.fontDesign.nsFont(size: viewModel.fontSize)
        let width = max(80, viewModel.prompterWidth - 32)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = viewModel.lineHeight

        let textStorage = NSTextStorage(
            string: viewModel.text,
            attributes: [.font: nsFont, .paragraphStyle: paragraphStyle]
        )
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)
        let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        layoutManager.addTextContainer(textContainer)
        layoutManager.glyphRange(for: textContainer) // forces real layout

        // Matches movingText's own top/bottom padding (22 + 44) in PrompterView.
        return layoutManager.usedRect(for: textContainer).height + 66
    }

    private var estimatedSeconds: Double {
        guard viewModel.speed > 0 else { return 0 }
        return Double(estimatedContentHeight) / viewModel.speed
    }

    private var estimatedDurationString: String {
        let total = max(0, Int(estimatedSeconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(fg.opacity(0.06))

                // Placeholder — same font and same padding as the real text
                // editor below, so the two line up instead of the cursor
                // starting somewhere else than where this text starts.
                if viewModel.text.isEmpty {
                    Text("Type your script here...\n\nUse [brackets] for stage directions like [pause], [smile], etc.")
                        .font(.system(size: viewModel.fontDesign.visuallyCompensatedSize(15), design: viewModel.fontDesign))
                        .foregroundStyle(fg.opacity(0.45))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }

                HighlightingTextEditor(
                    text: $viewModel.text,
                    font: viewModel.fontDesign.nsFont(size: viewModel.fontDesign.visuallyCompensatedSize(15)),
                    textColor: NSColor(fg),
                    isFocused: $isTextEditorFocused
                )
                .padding(.horizontal, 5)
                .padding(.vertical, 10)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)
            // A fixed height, not maxHeight: .infinity — that only stretches
            // inside a bounded parent. Inside a ScrollView (unbounded height)
            // it collapses to almost nothing instead, which is why the editor
            // kept shrinking depending on context. This way it's always the
            // same size regardless of where it's embedded.
            .frame(height: 220)

            if !viewModel.text.isEmpty {
                Text("\(wordCount) word\(wordCount == 1 ? "" : "s") · ~\(estimatedDurationString) at \(Int(viewModel.speed)) pt/s")
                    .font(.system(size: 10))
                    .foregroundStyle(fg.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
    }
}
