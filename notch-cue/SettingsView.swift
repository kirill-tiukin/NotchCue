import SwiftUI

// MARK: - Settings Tabs
enum SettingsTab: CaseIterable, Identifiable {
    case script
    case appearance
    case layout
    case behavior
    case voice
    case shortcuts

    var id: Self { self }

        var label: LocalizedStringResource {
            switch self {
            case .script: return "Script"
            case .appearance: return "Appearance"
            case .layout: return "Layout"
            case .behavior: return "Behavior"
            case .voice: return "Voice"
            case .shortcuts: return "Shortcuts"
            }
        }

    var icon: String {
        switch self {
        case .script: return "doc.text"
        case .appearance: return "paintpalette"
        case .layout: return "macwindow"
        case .behavior: return "gearshape"
        case .voice: return "microphone"
        case .shortcuts: return "keyboard"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: PrompterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .script
    @State private var contentVisible = false
    @State private var isClosing = false
    @State private var showResetConfirmation = false

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        return "\(version)"
    }

    var body: some View {
        ZStack {
            if contentVisible {
                settingsContent
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .frame(width: 680)
        .frame(minHeight: 560, maxHeight: 760)
        .background(.ultraThinMaterial)
        .alert("Microphone access denied", isPresented: $viewModel.showMicrophoneAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Enable microphone access in System Settings → Privacy & Security → Microphone.")
        }
        .confirmationDialog("Reset Prompter Position?", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                viewModel.reset()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will stop playback and reset the scroll position to the beginning.")
        }
        .onAppear {
            // Animate in with spring animation
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85).delay(0.05)) {
                contentVisible = true
            }
        }
    }

    private var settingsContent: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                // TODO: It would be cool to put here NotchCue + version instead of having this in the footer, but I have to also get rid of the window handler with "NotchCue Settings" to make it look good.
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)

                ForEach(SettingsTab.allCases) { tab in
                    HStack(spacing: 7) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 16)
                        Text(tab.label)
                            .font(.system(size: 13, weight: .regular))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedTab = tab
                    }
                }

                Spacer()

                Text("NotchCue \(appVersion)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .opacity(0.6)
            }
            .padding(12)
            .frame(width: 170)
            .frame(maxHeight: .infinity)
            .background(Color.primary.opacity(0.04))

            Divider()

            // Content
            VStack(spacing: 0) {
                switch selectedTab {
                case .script:
                    ScriptTabView(viewModel: viewModel)
                case .appearance:
                    AppearanceTabView(viewModel: viewModel)
                case .behavior:
                    BehaviorTabView(viewModel: viewModel)
                case .voice:
                    VoiceTabView(viewModel: viewModel)
                case .layout:
                    LayoutTabView(viewModel: viewModel)
                case .shortcuts:
                    KeyboardTabView(viewModel: viewModel)
                }

                Divider()



                HStack {

                    Button {
                        if viewModel.isPlaying {
                            viewModel.pause()
                        } else {
                            viewModel.play()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 10))
                            Text(viewModel.isPlaying ? "Pause" : "Play")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.automatic)
                    .disabled(viewModel.voiceActivation)

                    Button {
                        showResetConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 10))
                            Text("Reset")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.automatic)

                    Button {
                        viewModel.isPrompterVisible.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.isPrompterVisible ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 10))
                            Text(viewModel.isPrompterVisible ? "Hide" : "Show")
                                .font(.system(size: 12, weight: .medium))
                        }
                    }
                    .buttonStyle(.automatic)
                    .help(viewModel.isPrompterVisible ? "Hide the prompter window" : "Show the prompter window")

                    Spacer()

                    Button("Done") {
                        closeWithAnimation()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func closeWithAnimation() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            contentVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            dismiss()
        }
    }
}


// MARK: - Appearance Tab
struct AppearanceTabView: View {
    @ObservedObject var viewModel: PrompterViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Script")
                    .font(.system(size: 13, weight: .medium))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Style")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach([Font.Design.default, .serif, .rounded, .monospaced] as [Font.Design], id: \.self) { (design: Font.Design) in
                            let isSelected: Bool = viewModel.fontDesign == design
                            let isGlass = viewModel.prompterTheme.isGlass
                            let backgroundColor: Color = isGlass
                                ? .clear
                                : (isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                            let contentColor: Color = isGlass
                                ? viewModel.prompterTheme.panelTextColor.opacity(isSelected ? 1 : 0.4)
                                : (isSelected ? Color.accentColor : Color.primary)
                            let borderColor: Color = isGlass
                                ? viewModel.prompterTheme.panelTextColor.opacity(isSelected ? 0.6 : 0.15)
                                : (isSelected ? Color.accentColor : Color.primary.opacity(0.2))
                            Button {
                                viewModel.fontDesign = design
                            } label: {
                                VStack(spacing: 4) {
                                    Text(design.icon)
                                        .font(design.previewFont)
                                    Text(design.displayName)
                                        .font(.system(size: 11))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(backgroundColor)
                                .foregroundStyle(contentColor)
                                .contentShape(Rectangle())
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(borderColor, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SettingSlider(
                    label: "Size",
                    value: $viewModel.fontSize,
                    range: 8...80,
                    step: 1,
                    unit: "pt"
                )

                SettingSlider(
                    label: "Line spacing",
                    value: $viewModel.lineHeight,
                    range: 0...20,
                    step: 1,
                    unit: "pt"
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Alignment")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(PrompterTextAlignment.allCases, id: \.self) { alignment in
                            let isSelected = viewModel.textAlignment == alignment
                            let isGlass = viewModel.prompterTheme.isGlass
                            Button {
                                viewModel.textAlignment = alignment
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: alignment.icon)
                                        .font(.system(size: 16))
                                    Text(alignment.displayName)
                                        .font(.system(size: 11))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    isGlass
                                        ? .clear
                                        : (isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                                )
                                .foregroundStyle(
                                    isGlass
                                        ? viewModel.prompterTheme.panelTextColor.opacity(isSelected ? 1 : 0.4)
                                        : (isSelected ? Color.accentColor : Color.primary)
                                )
                                .contentShape(Rectangle())
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            isGlass
                                                ? viewModel.prompterTheme.panelTextColor.opacity(isSelected ? 0.6 : 0.15)
                                                : (isSelected ? Color.accentColor : Color.primary.opacity(0.2)),
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                Text("Theme")
                    .font(.system(size: 13, weight: .medium))

                HStack(spacing: 8) {
                    ForEach(PrompterTheme.allCases, id: \.self) { theme in
                        let isSelected = viewModel.prompterTheme == theme
                        let isGlass = viewModel.prompterTheme.isGlass
                        Button {
                            viewModel.prompterTheme = theme
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: theme.icon)
                                    .font(.system(size: 16))
                                Text(theme.displayName)
                                    .font(.system(size: 11))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                isGlass
                                    ? .clear
                                    : (isSelected ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                            )
                            .foregroundStyle(
                                isGlass
                                    ? viewModel.prompterTheme.panelTextColor.opacity(isSelected ? 1 : 0.4)
                                    : (isSelected ? Color.accentColor : Color.primary)
                            )
                            .contentShape(Rectangle())
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        isGlass
                                            ? viewModel.prompterTheme.panelTextColor.opacity(isSelected ? 0.6 : 0.15)
                                            : (isSelected ? Color.accentColor : Color.primary.opacity(0.2)),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider()

                Text("Fade Effects")
                    .font(.system(size: 13, weight: .medium))

                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.enableTopFade)

                    VStack(alignment: .leading) {
                        Text("Top fade")
                            .font(.system(size: 13))
                        Text("Fade out content at the top of the prompter")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.enableTopFade {
                    SettingSlider(
                        label: "Height",
                        value: $viewModel.topFadeHeight,
                        range: 10...150,
                        step: 5,
                        unit: "px"
                    )
                }

                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.enableBottomFade)

                    VStack(alignment: .leading) {
                        Text("Bottom fade")
                            .font(.system(size: 13))
                        Text("Fade out content at the bottom of the prompter")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.enableBottomFade {
                    SettingSlider(
                        label: "Height",
                        value: $viewModel.bottomFadeHeight,
                        range: 10...150,
                        step: 5,
                        unit: "px"
                    )
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Behavior Tab
struct BehaviorTabView: View {
    @ObservedObject var viewModel: PrompterViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SettingSlider(
                    label: "Scroll speed",
                    value: $viewModel.speed,
                    range: 1...100,
                    step: 1,
                    unit: "pt/s"
                )

                Divider()

                Text("Mouse Interaction")
                    .font(.system(size: 13, weight: .medium))

                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.pauseOnHover)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pause on hover")
                            .font(.system(size: 13))
                        Text("Pause scrolling when mouse enters the prompter window")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.showHoverControls)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show controls on hover")
                            .font(.system(size: 13))
                        Text("Display controls when hovering")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.showProgressBar)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show progress bar")
                            .font(.system(size: 13))
                        Text("Display a vertical progress indicator on the right side")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                Text("Privacy")
                    .font(.system(size: 13, weight: .medium))

                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.hideFromScreenRecording)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hide from screen recordings")
                            .font(.system(size: 13))
                        Text("Prevent the prompter from appearing in screen shares")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Voice Tab
struct VoiceTabView: View {
    @ObservedObject var viewModel: PrompterViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.voiceActivation)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Voice activation")
                            .font(.system(size: 13, weight: .medium))
                        Text("Automatically scroll when speaking is detected")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.voiceActivation {
                    Divider()

                    SettingSlider(
                        label: "Detection threshold",
                        value: Binding(
                            get: { Double(viewModel.audioThreshold) },
                            set: { viewModel.audioThreshold = Float($0) }
                        ),
                        range: 0.0...0.1,
                        step: 0.005,
                        unit: "%"
                    )

                    Text("Adjust sensitivity for voice detection. Lower values detect quieter speech.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Audio level monitor")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        HStack {
                            let rms = viewModel.audioMonitor?.rmsLevel ?? 0
                            let percentage = min(max(rms / 0.1, 0), 1.0) * 100
                            let color: Color = rms > Float(viewModel.audioThreshold) ? .green : .red

                            ProgressView(value: percentage / 100)
                                .progressViewStyle(
                                    LinearProgressViewStyle(tint: color)
                                )
                                .frame(height: 10)

                            Text(percentage / 100, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                    }

                    Text("Speak to test your microphone levels")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Layout Tab
struct LayoutTabView: View {
    @ObservedObject var viewModel: PrompterViewModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Window")
                    .font(.system(size: 13, weight: .medium))

                SettingSlider(
                    label: "Width",
                    value: Binding(
                        get: { Double(viewModel.prompterWidth) },
                        set: { viewModel.prompterWidth = CGFloat($0) }
                    ),
                    range: 150...600,
                    step: 10,
                    unit: "px"
                )

                SettingSlider(
                    label: "Height",
                    value: Binding(
                        get: { Double(viewModel.prompterHeight) },
                        set: { viewModel.prompterHeight = CGFloat($0) }
                    ),
                    range: 80...500,
                    step: 10,
                    unit: "px"
                )

                Divider()

                Text("Display")
                    .font(.system(size: 13, weight: .medium))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Screen")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Picker("", selection: $viewModel.selectedScreenIndex) {
                        ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                            Text("\(screen.localizedName) (\(index + 1))").tag(index)
                        }
                    }
                    .labelsHidden()
                }

                Text("Choose which screen the prompter appears on")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }
}

// TODO: add option to change shortcuts
// MARK: - Keyboard Tab
struct KeyboardTabView: View {
    @ObservedObject var viewModel: PrompterViewModel
    // Shared across every recorder row below — starting one row's recording
    // automatically ends any other, instead of two rows independently
    // thinking they're both recording and stealing each other's keys.
    @State private var activeRecordingID: String?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    GreenSwitch(isOn: $viewModel.enableGlobalKeyboardShortcuts)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enable global keyboard shortcuts")
                            .font(.system(size: 13, weight: .medium))
                        Text("Control the prompter without having to focus on it")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.enableGlobalKeyboardShortcuts {
                    Divider()

                    Text("Keyboard Shortcuts")
                        .font(.system(size: 13, weight: .medium))

                    VStack(alignment: .leading, spacing: 4) {
                        ShortcutRecorderRow(id: "appToggle", icon: "power.circle", title: "Show / Hide NotchCue", shortcut: $viewModel.appToggleShortcut, activeRecordingID: $activeRecordingID)
                        ShortcutRecorderRow(id: "playPause", icon: "play.fill", title: "Play / Pause", shortcut: $viewModel.playPauseShortcut, activeRecordingID: $activeRecordingID)
                        ShortcutRecorderRow(id: "showHide", icon: "eye.fill", title: "Show / Hide Prompter", shortcut: $viewModel.showHideShortcut, activeRecordingID: $activeRecordingID)
                        ShortcutRecorderRow(id: "decreaseSpeed", icon: "arrow.left", title: "Decrease Speed", shortcut: $viewModel.decreaseSpeedShortcut, activeRecordingID: $activeRecordingID)
                        ShortcutRecorderRow(id: "increaseSpeed", icon: "arrow.right", title: "Increase Speed", shortcut: $viewModel.increaseSpeedShortcut, activeRecordingID: $activeRecordingID)
                        ShortcutRecorderRow(id: "scrollUp", icon: "arrow.up", title: "Scroll Up", shortcut: $viewModel.scrollUpShortcut, activeRecordingID: $activeRecordingID)
                        ShortcutRecorderRow(id: "scrollDown", icon: "arrow.down", title: "Scroll Down", shortcut: $viewModel.scrollDownShortcut, activeRecordingID: $activeRecordingID)
                    }

                    Text("\"Show / Hide NotchCue\" stays active even if this whole section is turned off — it's the reliable fallback for when the menu-bar icon has no room to appear.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Text("Click a shortcut, then press the new key combo. Needs at least one modifier key (⌃ ⌥ ⇧ ⌘). Press Esc to cancel.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)

                    Divider()

                    Text("Speed Control")
                        .font(.system(size: 13, weight: .medium))

                    SettingSlider(
                        label: "Speed increment",
                        value: $viewModel.speedIncrement,
                        range: 1...10,
                        step: 1,
                        unit: "pt/s"
                    )

                    Text("Amount to increase/decrease speed with keyboard shortcuts")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    Divider()

                    Text("Scroll Control")
                        .font(.system(size: 13, weight: .medium))

                    SettingSlider(
                        label: "Scroll amount",
                        value: $viewModel.manualScrollAmount,
                        range: 10...100,
                        step: 5,
                        unit: "px"
                    )

                    Text("Number of pixels to scroll with keyboard shortcuts")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }
}

// MARK: Shortcut row
struct ShortcutRow: View {
    let icon: String
    let title: LocalizedStringKey
    let shortcut: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(shortcut)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Slider Component
struct SettingSlider: View {
    let label: LocalizedStringKey
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    var isPercentage: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                if unit == "%" && !isPercentage {
                    Text(value * 10, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                } else if isPercentage {
                    Text(value, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(Int(value)) \(unit)")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}
