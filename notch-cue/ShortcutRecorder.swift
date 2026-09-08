import SwiftUI
import AppKit

/// One row in the Shortcuts tab: an icon, a label, and a clickable badge
/// showing the current combo. Click it, then press the new key combo —
/// requires at least one modifier so it doesn't hijack plain letter keys
/// globally. Press Escape to cancel without changing anything.
///
/// `activeRecordingID` is shared across every row in the same list (each
/// row passes its own `id` and the same binding) — that's what makes
/// starting one row's recording automatically stop any other that was
/// mid-recording. Each row previously tracked its own independent
/// `isRecording`, with nothing coordinating between them, so two rows could
/// end up "recording" at once and stealing each other's key presses.
struct ShortcutRecorderRow: View {
    let id: String
    let icon: String
    let title: LocalizedStringKey
    @Binding var shortcut: RecordedShortcut
    @Binding var activeRecordingID: String?
    @State private var pulse = false

    private var isRecording: Bool { activeRecordingID == id }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 13))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                activeRecordingID = id
            } label: {
                HStack(spacing: 5) {
                    if isRecording {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 5, height: 5)
                            .opacity(pulse ? 1 : 0.25)
                    }
                    Text(isRecording ? "Press keys…" : shortcut.displayString)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(isRecording ? .white : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isRecording ? Color.accentColor : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.15), lineWidth: 1)
                )
                .scaleEffect(isRecording ? 1.05 : 1)
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.15), value: isRecording)
            .onChange(of: isRecording) { _, recording in
                if recording {
                    pulse = false
                    withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        pulse = true
                    }
                }
            }
            .background(
                KeyCatcherView(isActive: isRecording) { keyCode, modifiers, cancelled in
                    if activeRecordingID == id { activeRecordingID = nil }
                    guard !cancelled, !modifiers.isEmpty else { return }
                    shortcut = RecordedShortcut(keyCode: keyCode, modifierFlags: modifiers.rawValue)
                }
            )
        }
        .padding(.vertical, 4)
    }
}

/// Invisible view that becomes first responder while `isActive` and reports
/// the next key press (or Escape to cancel) back via `onCapture`.
private struct KeyCatcherView: NSViewRepresentable {
    var isActive: Bool
    var onCapture: (_ keyCode: UInt32, _ modifiers: NSEvent.ModifierFlags, _ cancelled: Bool) -> Void

    func makeNSView(context: Context) -> CatcherNSView {
        let view = CatcherNSView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: CatcherNSView, context: Context) {
        nsView.onCapture = onCapture
        if isActive {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    final class CatcherNSView: NSView {
        var onCapture: ((UInt32, NSEvent.ModifierFlags, Bool) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            if event.keyCode == 53 { // Escape
                onCapture?(0, [], true)
                return
            }
            let relevant = event.modifierFlags.intersection([.command, .option, .control, .shift])
            onCapture?(UInt32(event.keyCode), relevant, false)
        }
    }
}
