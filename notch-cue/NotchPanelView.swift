import SwiftUI
import AppKit

/// The settings panel that lives *inside* the notch window when it is expanded.
/// No separate window, no sidebar — this is literally the original app's own
/// Settings tabs (`SettingsView.swift`'s `ScriptTabView`/`AppearanceTabView`/
/// `LayoutTabView`/`BehaviorTabView`/`VoiceTabView`/`KeyboardTabView`) stacked
/// one after another instead of switched via a sidebar, since there's no
/// separate window here to put a sidebar in.
struct NotchPanelView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @FocusState private var isAnswerCountFocused: Bool

    private var fg: Color { viewModel.prompterTheme.panelTextColor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let tabs = Array(SettingsTab.allCases.enumerated())
                ForEach(tabs, id: \.element.id) { index, tab in
                    tabHeader(tab)
                    content(for: tab)
                    if index < tabs.count - 1 {
                        Divider().padding(.vertical, 4)
                    }
                }
            }
        }
        .background(viewModel.prompterTheme.panelBackgroundColor)
        .foregroundStyle(fg)
        .tint(fg)
        .environment(\.colorScheme, viewModel.prompterTheme.isDarkLike ? .dark : .light)
        // Was attached to the old standalone SettingsView, which is no
        // longer part of the actual view hierarchy — the alert never fired.
        // This is what makes it show right after pressing Voice activation
        // when permission was denied, instead of never appearing at all.
        .alert("Microphone access denied", isPresented: $viewModel.showMicrophoneAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enable microphone access in System Settings → Privacy & Security → Microphone.")
        }
    }

    private func tabHeader(_ tab: SettingsTab) -> some View {
        HStack(spacing: 6) {
            Image(systemName: tab.icon)
                .font(.system(size: 11, weight: .semibold))
            Text(tab.label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(fg.opacity(0.7))
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func content(for tab: SettingsTab) -> some View {
        switch tab {
        case .script:
            answersRow
            ScriptTabView(viewModel: viewModel)
        case .appearance:
            AppearanceTabView(viewModel: viewModel)
        case .layout:
            LayoutTabView(viewModel: viewModel)
        case .behavior:
            BehaviorTabView(viewModel: viewModel)
        case .voice:
            VoiceTabView(viewModel: viewModel)
        case .shortcuts:
            KeyboardTabView(viewModel: viewModel)
        }
    }

    /// Multi-answer switching — a feature this app has that upstream doesn't.
    /// Two separate controls for two separate things: the field sets *how
    /// many* answers exist; the slider (kept in sync with the prev/next
    /// buttons — same underlying value, `currentScriptIndex`) picks *which*
    /// one you're currently looking at.
    private var answersRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Number of answers").font(.caption).foregroundStyle(fg)
                Spacer()
                TextField("", value: answerCountIntBinding, format: .number)
                    .textFieldStyle(.plain)
                    .multilineTextAlignment(.trailing)
                    .focused($isAnswerCountFocused)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(width: 44)
                    .background(fg.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isAnswerCountFocused ? Color.accentColor : fg.opacity(0.15), lineWidth: isAnswerCountFocused ? 2 : 1)
                    )
            }

            // Always visible (not just when count > 1) so it's easy to find —
            // disabled rather than hidden when there's nothing to navigate to.
            HStack(spacing: 8) {
                Button { viewModel.previousScript() } label: { Image(systemName: "chevron.left") }
                Text("Answer \(viewModel.currentScriptIndex + 1) of \(viewModel.scripts.count)")
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: .infinity)
                Button { viewModel.nextScript() } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(viewModel.scripts.count < 2)
            .opacity(viewModel.scripts.count < 2 ? 0.4 : 1)

            // Scrubs between existing answers — dragging this moves the same
            // `currentScriptIndex` the prev/next buttons above move, so the
            // two always agree with each other.
            Slider(value: currentAnswerIndexBinding, in: 0...Double(max(1, viewModel.scripts.count - 1)), step: 1)
                .disabled(viewModel.scripts.count < 2)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    /// Sets how many answers exist — typing a bigger number than currently
    /// exist just appends blanks (see `resizeAnswers`), it doesn't touch
    /// which one you're currently on.
    private var answerCountIntBinding: Binding<Int> {
        Binding(
            get: { viewModel.scripts.count },
            set: { viewModel.resizeAnswers(to: $0) }
        )
    }

    /// Which answer is currently shown — the same value the prev/next
    /// buttons change, so dragging the slider and tapping those buttons stay
    /// in sync with each other.
    private var currentAnswerIndexBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.currentScriptIndex) },
            set: { viewModel.selectScript(Int($0.rounded())) }
        )
    }
}
