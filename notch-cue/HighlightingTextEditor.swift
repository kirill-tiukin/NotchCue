import SwiftUI

struct HighlightingTextEditor: NSViewRepresentable {
    @Binding var text: String
    var font: NSFont = .systemFont(ofSize: 15, weight: .regular)
    /// Explicit, theme-driven text color — NSTextView otherwise defaults to
    /// the system's semantic `.textColor`, which follows `colorScheme` and
    /// can drift out of sync with this app's own custom panel colors (that's
    /// what produced white-on-white text).
    var textColor: NSColor = .labelColor
    var isFocused: FocusState<Bool>.Binding?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 2)
        // NSTextContainer adds its own 5pt lineFragmentPadding by default,
        // on top of textContainerInset — that hidden extra offset is why the
        // cursor never lined up with the SwiftUI placeholder text no matter
        // how the outer paddings were balanced.
        textView.textContainer?.lineFragmentPadding = 0
        textView.isAutomaticQuoteSubstitutionEnabled = true
        textView.isAutomaticDashSubstitutionEnabled = true
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = font
        textView.textColor = textColor
        textView.insertionPointColor = textColor
        textView.delegate = context.coordinator
        textView.textContainer?.widthTracksTextView = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView
        context.coordinator.textView = textView

        // Set initial text and apply highlighting
        textView.string = text
        context.coordinator.applyHighlighting(textView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.font != font {
            textView.font = font
            context.coordinator.applyHighlighting(textView)
        }

        if textView.textColor != textColor {
            textView.textColor = textColor
            textView.insertionPointColor = textColor
            context.coordinator.applyHighlighting(textView)
        }

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting(textView)
        }
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: HighlightingTextEditor
        weak var textView: NSTextView?

        private static let annotationPattern = try! NSRegularExpression(
            pattern: "\\[+.*?]",
            options: []
        )

        init(_ parent: HighlightingTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            applyHighlighting(textView)
        }

        func applyHighlighting(_ textView: NSTextView) {
            guard let textStorage = textView.textStorage else { return }
            guard textStorage.length > 0 else { return }
            textStorage.beginEditing()
            let text = textStorage.string
            let fullRange = NSRange(location: 0, length: textStorage.length)

            // Preserve selection across re-highlighting
            let selectedRanges = textView.selectedRanges

            let matches = Self.annotationPattern.matches(in: text, options: [], range: fullRange)
            for match in matches {
                let annotationAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFontManager.shared.convert(parent.font, toHaveTrait: .italicFontMask),
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .backgroundColor: NSColor.secondaryLabelColor.withAlphaComponent(0.08)
                ]
                textStorage.addAttributes(annotationAttributes, range: match.range)
            }

            textStorage.endEditing()

            // Restore selection
            textView.selectedRanges = selectedRanges
        }
    }
}
