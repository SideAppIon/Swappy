import AppKit
import SwiftUI

/// Animation presets. Everything collapses to "no animation" when the user enabled Reduce Motion,
/// and nothing here runs while the window is closed, so the idle cost stays at zero.
enum Motion {
    static var reduced: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// Bars, rings and other values settling into place.
    static var value: Animation? { reduced ? nil : .spring(response: 0.55, dampingFraction: 0.82) }
    /// Digits, hover and press feedback.
    static var quick: Animation? { reduced ? nil : .spring(response: 0.3, dampingFraction: 0.85) }
    /// Sliding between the main screen and a detail page.
    static var page: Animation? { reduced ? nil : .spring(response: 0.42, dampingFraction: 0.88) }

    static func reveal(_ index: Int) -> Animation? {
        reduced ? nil : .spring(response: 0.5, dampingFraction: 0.8).delay(0.04 + Double(index) * 0.055)
    }
}

private struct RevealedKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// False while the window is closed; flips to true when it opens, which starts the entrance animations.
    var revealed: Bool {
        get { self[RevealedKey.self] }
        set { self[RevealedKey.self] = newValue }
    }
}

/// Cards rise into place one after another when the window opens.
private struct Reveal: ViewModifier {
    @Environment(\.revealed) private var revealed
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 16)
            .scaleEffect(revealed ? 1 : 0.96)
            .animation(Motion.reveal(index), value: revealed)
    }
}

/// Soft breathing used only while swap is actively being written.
private struct Pulse: ViewModifier {
    let active: Bool
    @Environment(\.revealed) private var revealed
    @State private var dim = false

    func body(content: Content) -> some View {
        // Never keeps animating behind a closed window.
        let on = active && revealed
        content
            .opacity(on && dim ? 0.3 : 1)
            .scaleEffect(on && dim ? 0.85 : 1)
            .onAppear { update(on) }
            .onChange(of: on) { update($0) }
    }

    private func update(_ on: Bool) {
        guard on, !Motion.reduced else {
            withAnimation(.default) { dim = false }
            return
        }
        withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) { dim = true }
    }
}

/// Scales a card down slightly while it is pressed.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}

extension View {
    func reveal(_ index: Int) -> some View { modifier(Reveal(index: index)) }
    func pulse(_ active: Bool) -> some View { modifier(Pulse(active: active)) }

    /// Digits roll to their new value instead of jumping.
    func rolling(_ value: String) -> some View {
        contentTransition(.numericText()).animation(Motion.quick, value: value)
    }
}
