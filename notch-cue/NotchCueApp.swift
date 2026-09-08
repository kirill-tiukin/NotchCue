import SwiftUI
import AppKit
import HotKey
import Combine

@main
struct NotchCueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The UI lives in the notch and the menu-bar item; this scene only exists
        // because an App needs one. It is never shown.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = PrompterViewModel()
    private var prompterWindow: PrompterWindow!
    private var statusItem: NSStatusItem!
    private var toggleHotKey: HotKey?
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        prompterWindow = PrompterWindow(viewModel: viewModel)
        NSApp.setActivationPolicy(.accessory)

        // No fallback text injected here — an empty script correctly shows
        // the real placeholder UI in ScriptTabView instead.

        setUpStatusItem()

        // Always-on global shortcut to show/hide — works even when the menu
        // bar is too full for the status icon to appear. Configurable now
        // (Settings > Shortcuts), not a fixed combo, so this re-registers it
        // live whenever the user re-records it there.
        registerToggleHotKey()
        viewModel.$appToggleShortcut
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.registerToggleHotKey() }
            .store(in: &cancellables)

        viewModel.isPrompterVisible = true
        refreshStatusIcon()
    }

    private func registerToggleHotKey() {
        guard let key = viewModel.appToggleShortcut.key else { return }
        toggleHotKey = HotKey(key: key, modifiers: viewModel.appToggleShortcut.modifiers)
        toggleHotKey?.keyDownHandler = { [weak self] in self?.toggleVisibility() }
    }

    // MARK: Menu-bar toggle

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.isVisible = true
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(statusItemClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "NotchCue — click to show or hide"
        button.title = ""
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let wantsMenu = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)

        if wantsMenu {
            statusItem.menu = buildMenu()
            sender.performClick(nil)      // opens the menu
            statusItem.menu = nil         // restore plain click behaviour
        } else {
            toggleVisibility()
        }
    }

    @objc private func toggleVisibility() {
        viewModel.isPrompterVisible.toggle()
        refreshStatusIcon()
    }

    @objc private func openSettingsPanel() {
        viewModel.isPrompterVisible = true
        viewModel.isCollapsedToPill = false
        viewModel.isExpanded = true
        refreshStatusIcon()
    }

    private func refreshStatusIcon() {
        guard let button = statusItem?.button else { return }
        // Filled pill while visible, outline while hidden — same on/off
        // convention as the old eye.fill/eye.slash SF Symbols, just this
        // app's own dynamic-island shape instead.
        let assetName = viewModel.isPrompterVisible ? "MenuBarIconSolid" : "MenuBarIcon"
        let image = NSImage(named: assetName)
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.title = image == nil ? "NP" : ""
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let toggle = NSMenuItem(
            title: viewModel.isPrompterVisible ? "Hide Prompter" : "Show Prompter",
            action: #selector(toggleVisibility),
            keyEquivalent: "h"
        )
        toggle.keyEquivalentModifierMask = [.command, .option]
        toggle.target = self
        menu.addItem(toggle)

        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettingsPanel), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit NotchCue",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        return menu
    }
}
