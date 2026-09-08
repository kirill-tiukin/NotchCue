import SwiftUI

/// A hand-drawn switch, always green when on — no matter what.
///
/// The native `Toggle` with `SwitchToggleStyle(tint:)` looked right at first,
/// but macOS *deliberately* desaturates every control in a window once that
/// window isn't the key/active one — this is system-wide behavior (the same
/// reason buttons/toggles look grayed out in any app's background window),
/// not something specific to this app. Our panel is a non-activating
/// accessory-app window, so it loses key status the moment focus moves
/// anywhere else — which is constantly, during normal use. That's what made
/// the toggles "stop being green" with no apparent trigger. Drawing the
/// switch ourselves sidesteps that entirely: plain shapes and colors don't
/// care about window activation state.
struct GreenSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? Color.green : Color.gray.opacity(0.35))
            .frame(width: 32, height: 18)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .padding(2)
                    .offset(x: isOn ? 7 : -7)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture { isOn.toggle() }
            .animation(.easeInOut(duration: 0.15), value: isOn)
    }
}
