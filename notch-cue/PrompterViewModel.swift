import Foundation
import Combine
import CoreVideo
import AVFoundation
import Accelerate
import SwiftUI
import HotKey

final class PrompterViewModel: ObservableObject {

    // MARK: User settings
    @Published var text: String = ""
    @Published var isPlaying: Bool = false
    @Published var offset: CGFloat = 0
    @Published var speed: Double = 27.0
    @Published var fontSize: Double = 10.0
    @Published var lineHeight: Double = 8.0
    @Published var pauseOnHover: Bool = true
    @Published var prompterWidth: CGFloat = 180
    @Published var prompterHeight: CGFloat = 150
    @Published var voiceActivation: Bool = false
    @Published var autoGain: Bool = false
    @Published var isPrompterVisible: Bool = true
    /// When true the prompter window grows into a settings panel under the notch.
    @Published var isExpanded: Bool = false
    /// When true the window is just the compact icon + chevron pill. Starts collapsed.
    @Published var isCollapsedToPill: Bool = true
    /// True while the mouse pointer is over the scrolling stage (drives the
    /// on-screen play/pause controls).
    @Published var isPointerOverStage: Bool = false
    /// Physical notch size, supplied by the window from the active screen.
    @Published var notchSize: CGSize = CGSize(width: 200, height: 32)
    /// Active screen width, supplied by the window.
    @Published var screenWidth: CGFloat = 1440
    /// The actual on-screen size of the visible pill/box, measured live by
    /// PrompterView. The window uses this — not a guess — to size the region
    /// that accepts clicks; everything outside it passes through to apps
    /// underneath. Zero until the first layout pass.
    @Published var visibleContentSize: CGSize = .zero
    /// Largest scroll offset (set by the view from content vs viewport height). 0 = unknown.
    @Published var maxScrollOffset: CGFloat = 0

    // MARK: Multiple answers
    /// All saved answers. `text` always mirrors `scripts[currentScriptIndex]`.
    @Published var scripts: [String] = [""]
    @Published var currentScriptIndex: Int = 0
    @Published var fontDesign: Font.Design = .monospaced
    @Published var selectedScreenIndex: Int = 0
    @Published var enableTopFade: Bool = true
    @Published var enableBottomFade: Bool = true
    @Published var topFadeHeight: Double = 40.0
    @Published var bottomFadeHeight: Double = 40.0
    @Published var showHoverControls: Bool = true
    @Published var hideFromScreenRecording: Bool = true
    @Published var prompterTheme: PrompterTheme = .dark
    @Published var horizontalAlignment: PrompterHorizontalAlignment = .center
    @Published var textAlignment: PrompterTextAlignment = .center
    @Published var showProgressBar: Bool = false
    @Published var enableGlobalKeyboardShortcuts: Bool = false
    @Published var speedIncrement: Double = 2.0
    @Published var manualScrollAmount: Double = 50.0

    var backScrollAmount: Double = 20.0 // pixels to scroll back


    private var timerCancellable: AnyCancellable?
    private var lastTick: CFTimeInterval?
    private var cancellables: Set<AnyCancellable> = []

    // MARK: Global keyboard shortcuts
    private var playPauseHotKey: HotKey?
    private var showHideHotKey: HotKey?
    private var increaseSpeedHotKey: HotKey?
    private var decreaseSpeedHotKey: HotKey?
    private var scrollUpHotKey: HotKey?
    private var scrollDownHotKey: HotKey?

    // User-configurable — edited via the Shortcuts tab's recorder rows.
    // Defaults match what used to be hardcoded.
    @Published var playPauseShortcut = RecordedShortcut(key: .p, modifiers: [.control, .option])
    @Published var showHideShortcut = RecordedShortcut(key: .h, modifiers: [.control, .option])
    @Published var increaseSpeedShortcut = RecordedShortcut(key: .rightArrow, modifiers: [.control, .option])
    @Published var decreaseSpeedShortcut = RecordedShortcut(key: .leftArrow, modifiers: [.control, .option])
    @Published var scrollUpShortcut = RecordedShortcut(key: .upArrow, modifiers: [.control, .option])
    @Published var scrollDownShortcut = RecordedShortcut(key: .downArrow, modifiers: [.control, .option])
    /// Show/hide the whole app — always active regardless of "Enable global
    /// keyboard shortcuts" below (it's the reliable fallback for when the
    /// menu-bar icon has no room to appear at all), so it's tracked and
    /// persisted separately from the others.
    @Published var appToggleShortcut = RecordedShortcut(key: .p, modifiers: [.control, .option, .command])

    var audioMonitor: AudioMonitor?
    @Published var showMicrophoneAlert: Bool = false
    /// True while macOS's own microphone-permission dialog is (or may be)
    /// up. The window sits at `CGShieldingWindowLevel()` — the highest
    /// practical level, chosen so this app's pill stays above other notch
    /// overlays — which also means it renders on top of that system dialog,
    /// covering it. `PrompterWindow` observes this to drop its level
    /// temporarily so the OS dialog is actually reachable.
    @Published var isRequestingSystemPermission: Bool = false
    @Published var audioThreshold: Float = 0.01
    @Published var targetLevel: Double = 0.05  // default 5%


    // MARK: UserDefaults keys
    private enum Keys {
        static let text = "PrompterText"
        static let speed = "PrompterSpeed"
        static let fontSize = "PrompterFontSize"
        static let lineHeight = "PrompterLineHeight"
        static let pauseOnHover = "PrompterPauseOnHover"
        static let prompterWidth = "PrompterWidth"
        static let prompterHeight = "PrompterHeight"
        static let voiceActivation = "VoiceActivation"
        static let audioThreshold = "AudioThreshold"
        static let fontDesign = "FontDesign"
        static let selectedScreenIndex = "SelectedScreenIndex"
        static let opacity = "PrompterOpacity"
        static let enableTopFade = "EnableTopFade"
        static let enableBottomFade = "EnableBottomFade"
        static let topFadeHeight = "TopFadeHeight"
        static let bottomFadeHeight = "BottomFadeHeight"
        static let showHoverControls = "ShowHoverControls"
        static let hideFromScreenRecording = "HideFromScreenRecording"
        static let prompterTheme = "PrompterTheme"
        static let horizontalAlignment = "HorizontalAlignment"
        static let textAlignment = "TextAlignment"
        static let showProgressBar = "ShowProgressBar"
        static let enableGlobalKeyboardShortcuts = "EnableGlobalKeyboardShortcuts"
        static let speedIncrement = "SpeedIncrement"
        static let manualScrollAmount = "ManualScrollAmount"
        static let scripts = "PrompterScripts"
        static let playPauseShortcut = "PlayPauseShortcut"
        static let showHideShortcut = "ShowHideShortcut"
        static let increaseSpeedShortcut = "IncreaseSpeedShortcut"
        static let decreaseSpeedShortcut = "DecreaseSpeedShortcut"
        static let scrollUpShortcut = "ScrollUpShortcut"
        static let scrollDownShortcut = "ScrollDownShortcut"
        static let appToggleShortcut = "AppToggleShortcut"
        static let scriptIndex = "PrompterScriptIndex"
    }

    // MARK: Init
    init() {
        loadSettings()
        observeSettingsChanges()
        startTimer()
//        setupKeyboardShortcuts()
        $voiceActivation
            // Skip the emission that fires immediately on subscribe with
            // whatever loadSettings() just restored — only react to the
            // user actually flipping the toggle, never to app launch.
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    self.requestMicrophoneAccessAndStart()
                } else {
                    self.audioMonitor?.stopMonitoring()
                    self.voiceActivationSubscription?.cancel()
                    self.voiceActivationSubscription = nil
                    self.lastSpeechTime = nil
                    if self.isPlaying { self.pause() }
                }
            }
            .store(in: &cancellables)

        $enableGlobalKeyboardShortcuts
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                if enabled {
                    print("Global shortcuts enabled")
                    self.registerGlobalKeyboardShortcuts()
                } else {
                    print("Global shortcuts disabled")
                    self.unregisterGlobalKeyboardShortcuts()
                }
            }
            .store(in: &cancellables)

        // Re-register live whenever a shortcut is re-recorded, and persist it.
        for publisher in [$playPauseShortcut, $showHideShortcut, $increaseSpeedShortcut,
                           $decreaseSpeedShortcut, $scrollUpShortcut, $scrollDownShortcut] {
            publisher
                .dropFirst()
                .removeDuplicates()
                .sink { [weak self] _ in
                    guard let self else { return }
                    self.reregisterGlobalKeyboardShortcutsIfEnabled()
                    self.saveSettings()
                }
                .store(in: &cancellables)
        }

        // Always-on toggle isn't gated by "Enable global keyboard
        // shortcuts" — AppDelegate observes this same publisher directly to
        // re-create its HotKey; this sink just persists the change.
        $appToggleShortcut
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in self?.saveSettings() }
            .store(in: &cancellables)
    }

    private func requestMicrophoneAccessAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            monitorAudio()
        case .notDetermined:
            isRequestingSystemPermission = true
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isRequestingSystemPermission = false
                    if granted {
                        self?.monitorAudio()

                    } else {
                        self?.voiceActivation = false
                        self?.showMicrophoneAlert = true
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.voiceActivation = false
                self.showMicrophoneAlert = true
            }
        @unknown default:
            break
        }
    }


    /// How long to keep scrolling after speech stops, so a brief breath or
    /// pause between words doesn't stutter playback on and off.
    private let voiceActivationHangover: CFTimeInterval = 0.6
    private var lastSpeechTime: CFTimeInterval?
    private var voiceActivationSubscription: AnyCancellable?

    func monitorAudio(){
        if(audioMonitor == nil){
            audioMonitor = AudioMonitor()
        }

        voiceActivationSubscription = audioMonitor!.$rmsLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rmsLevel in
                guard let self = self, self.voiceActivation else { return }
                let detected = rmsLevel > self.audioThreshold
                let now = CFAbsoluteTimeGetCurrent()

                if detected {
                    self.lastSpeechTime = now
                    if !self.isPlaying { self.play() }
                } else if self.isPlaying,
                          let last = self.lastSpeechTime,
                          now - last > self.voiceActivationHangover {
                    self.pause()
                }
            }

        audioMonitor!.startMonitoring()
    }


    // MARK: Play/Pause

    /// True only while playback is suspended *because the pointer is over the prompter*.
    /// A manual Play/Pause clears it so moving the mouse away can't override your choice.
    @Published var isHoverPaused: Bool = false

    /// Resume from wherever the text currently sits — never jump to the start.
    func play() {
        isHoverPaused = false
        lastTick = nil
        isPlaying = true
    }

    /// Stop in place. Position is preserved. This is a deliberate pause.
    func pause() {
        isHoverPaused = false
        lastTick = nil
        isPlaying = false
    }

    /// Explicitly go back to the top.
    func reset() {
        isHoverPaused = false
        isPlaying = false
        lastTick = nil
        offset = 0
    }

    /// Temporary pause while the pointer hovers the prompter (only if the option is on).
    func hoverPause() {
        guard pauseOnHover, isPlaying else { return }
        lastTick = nil
        isPlaying = false
        isHoverPaused = true
    }

    /// Undo a hover pause when the pointer leaves — but not a deliberate pause.
    func hoverResume() {
        guard isHoverPaused else { return }
        isHoverPaused = false
        lastTick = nil
        isPlaying = true
    }

    func scrollBack() {
        offset = max(0, offset - backScrollAmount)
    }

    // MARK: Manual Scroll Control
    func scrollUp() {
        offset = max(0, offset - manualScrollAmount)
    }

    func scrollDown() {
        offset = min(offset + manualScrollAmount, max(0, maxScrollOffset))
    }

    // MARK: Speed Control
    func increaseSpeed() {
        speed = min(40, speed + speedIncrement)
    }

    func decreaseSpeed() {
        speed = max(1, speed - speedIncrement)
    }

    // MARK: Global keyboard shortcuts
    private func registerGlobalKeyboardShortcuts() {
        print("Register hotkeys")

        if let key = playPauseShortcut.key {
            playPauseHotKey = HotKey(key: key, modifiers: playPauseShortcut.modifiers)
            playPauseHotKey?.keyDownHandler = { [weak self] in
                guard let self = self else { return }
                if !self.voiceActivation {
                    if self.isPlaying { self.pause() } else { self.play() }
                }
            }
        }

        if let key = showHideShortcut.key {
            showHideHotKey = HotKey(key: key, modifiers: showHideShortcut.modifiers)
            showHideHotKey?.keyDownHandler = { [weak self] in
                self?.isPrompterVisible.toggle()
            }
        }

        if let key = increaseSpeedShortcut.key {
            increaseSpeedHotKey = HotKey(key: key, modifiers: increaseSpeedShortcut.modifiers)
            increaseSpeedHotKey?.keyDownHandler = { [weak self] in
                self?.increaseSpeed()
            }
        }

        if let key = decreaseSpeedShortcut.key {
            decreaseSpeedHotKey = HotKey(key: key, modifiers: decreaseSpeedShortcut.modifiers)
            decreaseSpeedHotKey?.keyDownHandler = { [weak self] in
                self?.decreaseSpeed()
            }
        }

        if let key = scrollUpShortcut.key {
            scrollUpHotKey = HotKey(key: key, modifiers: scrollUpShortcut.modifiers)
            scrollUpHotKey?.keyDownHandler = { [weak self] in
                self?.scrollUp()
            }
        }

        if let key = scrollDownShortcut.key {
            scrollDownHotKey = HotKey(key: key, modifiers: scrollDownShortcut.modifiers)
            scrollDownHotKey?.keyDownHandler = { [weak self] in
                self?.scrollDown()
            }
        }
    }

    /// Called whenever a shortcut is re-recorded — re-registers everything
    /// so the change takes effect immediately, without needing to toggle
    /// "Enable global keyboard shortcuts" off and back on.
    private func reregisterGlobalKeyboardShortcutsIfEnabled() {
        guard enableGlobalKeyboardShortcuts else { return }
        unregisterGlobalKeyboardShortcuts()
        registerGlobalKeyboardShortcuts()
    }

    private func unregisterGlobalKeyboardShortcuts() {
        print("Unregister hotkeys")
        playPauseHotKey = nil
        showHideHotKey = nil
        increaseSpeedHotKey = nil
        decreaseSpeedHotKey = nil
        scrollUpHotKey = nil
        scrollDownHotKey = nil
    }

    // MARK: Timer
    private var displayTimer: Timer?
    private func startTimer() {
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick(current: CFAbsoluteTimeGetCurrent())
        }
        RunLoop.main.add(timer, forMode: .common)
        displayTimer = timer
    }

    private func tick(current: CFTimeInterval) {
        guard isPlaying else { return }

        let dt: CFTimeInterval
        if let last = lastTick {
            dt = current - last
        } else {
            dt = 0
        }
        lastTick = current

        offset += CGFloat(speed) * CGFloat(dt)

        if offset >= max(0, maxScrollOffset) {
            offset = max(0, maxScrollOffset)
            isPlaying = false
            isHoverPaused = false
        }
    }

    // MARK: Multiple answers

    var answerCount: Int { max(1, scripts.count) }

    /// Persist edits to the answer currently on screen.
    private func stashCurrentText() {
        if scripts.indices.contains(currentScriptIndex) {
            scripts[currentScriptIndex] = text
        }
    }

    func selectScript(_ index: Int) {
        guard scripts.indices.contains(index) else { return }
        stashCurrentText()
        currentScriptIndex = index
        text = scripts[index]
        offset = 0
        isPlaying = false
        isHoverPaused = false
    }

    func nextScript() { selectScript((currentScriptIndex + 1) % answerCount) }
    func previousScript() { selectScript((currentScriptIndex - 1 + answerCount) % answerCount) }

    func addScript() {
        guard scripts.count < 50 else { return }
        stashCurrentText()
        scripts.append("")
        selectScript(scripts.count - 1)
    }

    func removeCurrentScript() {
        guard scripts.count > 1 else { return }
        scripts.remove(at: currentScriptIndex)
        let newIndex = min(currentScriptIndex, scripts.count - 1)
        currentScriptIndex = newIndex
        text = scripts[newIndex]
        offset = 0
        isPlaying = false
    }

    /// Sets the total number of answers directly — unlike `addScript()`,
    /// this never navigates away from whatever answer you're currently
    /// looking at. Growing appends blanks at the end; shrinking trims from
    /// the end, only moving you off the current answer if it no longer exists.
    func resizeAnswers(to target: Int) {
        let clamped = max(1, min(target, 50))
        guard clamped != scripts.count else { return }
        stashCurrentText()
        if clamped > scripts.count {
            scripts.append(contentsOf: Array(repeating: "", count: clamped - scripts.count))
        } else {
            scripts.removeLast(scripts.count - clamped)
            currentScriptIndex = min(currentScriptIndex, scripts.count - 1)
        }
        text = scripts[currentScriptIndex]
    }

    // MARK: Settings persistence
    private func observeSettingsChanges() {
        $text.sink { [weak self] newText in
            guard let self = self else { return }
            if self.scripts.indices.contains(self.currentScriptIndex) {
                self.scripts[self.currentScriptIndex] = newText
            }
            self.saveSettings()
        }.store(in: &cancellables)
        $scripts.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $currentScriptIndex.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $speed.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $fontSize.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $lineHeight.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $pauseOnHover.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $prompterWidth.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $prompterHeight.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $voiceActivation.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $audioThreshold.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $fontDesign.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $selectedScreenIndex.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $enableTopFade.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $enableBottomFade.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $bottomFadeHeight.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $showHoverControls.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $hideFromScreenRecording.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $prompterTheme.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $horizontalAlignment.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $textAlignment.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $showProgressBar.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $enableGlobalKeyboardShortcuts.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $speedIncrement.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
        $manualScrollAmount.sink { [weak self] _ in self?.saveSettings() }.store(in: &cancellables)
    }

    private func loadSettings() {
        let defaults = UserDefaults.standard

        text = defaults.string(forKey: Keys.text) ?? text

        // Multiple answers — fall back to the single saved script for older installs.
        // Fresh installs start with 4 answers — same pattern as every other
        // slider in the app (e.g. fade Height: range 10...150, default 40):
        // a real value partway into the range, not sitting at either end.
        let savedScripts = defaults.stringArray(forKey: Keys.scripts) ?? []
        scripts = savedScripts.isEmpty ? [text] + Array(repeating: "", count: 9) : savedScripts
        currentScriptIndex = min(max(0, defaults.integer(forKey: Keys.scriptIndex)), scripts.count - 1)
        text = scripts[currentScriptIndex]

        speed = defaults.double(forKey: Keys.speed)
        if speed == 0 { speed = 27.0 }
        fontSize = defaults.double(forKey: Keys.fontSize)
        if fontSize == 0 { fontSize = 12.0 }
        lineHeight = defaults.double(forKey: Keys.lineHeight)
        if lineHeight == 0 { lineHeight = 8.0 }
        pauseOnHover = defaults.object(forKey: Keys.pauseOnHover) as? Bool ?? true
        prompterWidth = CGFloat(defaults.double(forKey: Keys.prompterWidth))
        if prompterWidth == 0 { prompterWidth = 180 }
        prompterHeight = CGFloat(defaults.double(forKey: Keys.prompterHeight))
        if prompterHeight == 0 { prompterHeight = 150 }
        voiceActivation = defaults.object(forKey: Keys.voiceActivation) as? Bool ?? false
        let threshold = defaults.double(forKey: Keys.audioThreshold)
        audioThreshold = threshold == 0 ? 0.01 : Float(threshold)

        if let fontDesignRaw = defaults.string(forKey: Keys.fontDesign) {
            fontDesign = Font.Design(rawValue: fontDesignRaw) ?? .default
        }

        selectedScreenIndex = defaults.integer(forKey: Keys.selectedScreenIndex)

        enableTopFade = defaults.object(forKey: Keys.enableTopFade) as? Bool ?? true
        enableBottomFade = defaults.object(forKey: Keys.enableBottomFade) as? Bool ?? true
        topFadeHeight = defaults.double(forKey: Keys.topFadeHeight)
        if topFadeHeight == 0 { topFadeHeight = 40.0 }
        bottomFadeHeight = defaults.double(forKey: Keys.bottomFadeHeight)
        if bottomFadeHeight == 0 { bottomFadeHeight = 40.0 }
        showHoverControls = defaults.object(forKey: Keys.showHoverControls) as? Bool ?? true
        hideFromScreenRecording = defaults.object(forKey: Keys.hideFromScreenRecording) as? Bool ?? true

        if let themeRaw = defaults.string(forKey: Keys.prompterTheme) {
            prompterTheme = PrompterTheme(rawValue: themeRaw) ?? .dark
        }

        if let horizontalAlignRaw = defaults.string(forKey: Keys.horizontalAlignment) {
            horizontalAlignment = PrompterHorizontalAlignment(rawValue: horizontalAlignRaw) ?? .center
        }

        if let textAlignRaw = defaults.string(forKey: Keys.textAlignment) {
            textAlignment = PrompterTextAlignment(rawValue: textAlignRaw) ?? .center
        }

        showProgressBar = defaults.object(forKey: Keys.showProgressBar) as? Bool ?? false

        enableGlobalKeyboardShortcuts = defaults.object(forKey: Keys.enableGlobalKeyboardShortcuts) as? Bool ?? false
        speedIncrement = defaults.double(forKey: Keys.speedIncrement)
        if speedIncrement == 0 { speedIncrement = 2.0 }
        manualScrollAmount = defaults.double(forKey: Keys.manualScrollAmount)
        if manualScrollAmount == 0 { manualScrollAmount = 50.0 }

        playPauseShortcut = Self.loadShortcut(defaults, Keys.playPauseShortcut) ?? playPauseShortcut
        showHideShortcut = Self.loadShortcut(defaults, Keys.showHideShortcut) ?? showHideShortcut
        increaseSpeedShortcut = Self.loadShortcut(defaults, Keys.increaseSpeedShortcut) ?? increaseSpeedShortcut
        decreaseSpeedShortcut = Self.loadShortcut(defaults, Keys.decreaseSpeedShortcut) ?? decreaseSpeedShortcut
        scrollUpShortcut = Self.loadShortcut(defaults, Keys.scrollUpShortcut) ?? scrollUpShortcut
        scrollDownShortcut = Self.loadShortcut(defaults, Keys.scrollDownShortcut) ?? scrollDownShortcut
        appToggleShortcut = Self.loadShortcut(defaults, Keys.appToggleShortcut) ?? appToggleShortcut
    }

    /// Shortcuts are stored as "<keyCode>:<modifierFlags>" — simplest way to
    /// persist two integers under one UserDefaults key.
    private static func loadShortcut(_ defaults: UserDefaults, _ key: String) -> RecordedShortcut? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        let parts = raw.split(separator: ":")
        guard parts.count == 2, let keyCode = UInt32(parts[0]), let modifiers = UInt(parts[1]) else { return nil }
        return RecordedShortcut(keyCode: keyCode, modifierFlags: modifiers)
    }

    private func saveShortcut(_ defaults: UserDefaults, _ key: String, _ shortcut: RecordedShortcut) {
        defaults.set("\(shortcut.keyCode):\(shortcut.modifierFlags)", forKey: key)
    }

    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(text, forKey: Keys.text)
        defaults.set(scripts, forKey: Keys.scripts)
        defaults.set(currentScriptIndex, forKey: Keys.scriptIndex)
        defaults.set(speed, forKey: Keys.speed)
        defaults.set(fontSize, forKey: Keys.fontSize)
        defaults.set(lineHeight, forKey: Keys.lineHeight)
        defaults.set(pauseOnHover, forKey: Keys.pauseOnHover)
        defaults.set(Double(prompterWidth), forKey: Keys.prompterWidth)
        defaults.set(Double(prompterHeight), forKey: Keys.prompterHeight)
        defaults.set(voiceActivation, forKey: Keys.voiceActivation)
        defaults.set(Double(audioThreshold), forKey: Keys.audioThreshold)
        defaults.set(fontDesign.rawValue, forKey: Keys.fontDesign)
        defaults.set(selectedScreenIndex, forKey: Keys.selectedScreenIndex)
        defaults.set(enableTopFade, forKey: Keys.enableTopFade)
        defaults.set(enableBottomFade, forKey: Keys.enableBottomFade)
        defaults.set(topFadeHeight, forKey: Keys.topFadeHeight)
        defaults.set(bottomFadeHeight, forKey: Keys.bottomFadeHeight)
        defaults.set(showHoverControls, forKey: Keys.showHoverControls)
        defaults.set(hideFromScreenRecording, forKey: Keys.hideFromScreenRecording)
        defaults.set(prompterTheme.rawValue, forKey: Keys.prompterTheme)
        defaults.set(horizontalAlignment.rawValue, forKey: Keys.horizontalAlignment)
        defaults.set(textAlignment.rawValue, forKey: Keys.textAlignment)
        defaults.set(showProgressBar, forKey: Keys.showProgressBar)
        defaults.set(enableGlobalKeyboardShortcuts, forKey: Keys.enableGlobalKeyboardShortcuts)
        defaults.set(speedIncrement, forKey: Keys.speedIncrement)
        defaults.set(manualScrollAmount, forKey: Keys.manualScrollAmount)

        saveShortcut(defaults, Keys.playPauseShortcut, playPauseShortcut)
        saveShortcut(defaults, Keys.showHideShortcut, showHideShortcut)
        saveShortcut(defaults, Keys.increaseSpeedShortcut, increaseSpeedShortcut)
        saveShortcut(defaults, Keys.decreaseSpeedShortcut, decreaseSpeedShortcut)
        saveShortcut(defaults, Keys.scrollUpShortcut, scrollUpShortcut)
        saveShortcut(defaults, Keys.scrollDownShortcut, scrollDownShortcut)
        saveShortcut(defaults, Keys.appToggleShortcut, appToggleShortcut)
    }

}
// MARK: - Font.Design Extension for UserDefaults
extension Font.Design: @retroactive RawRepresentable {
    public init?(rawValue: String) {
        switch rawValue {
        case "default": self = .default
        case "serif": self = .serif
        case "rounded": self = .rounded
        case "monospaced": self = .monospaced
        default: return nil
        }
    }

    public var rawValue: String {
        switch self {
        case .default: return "default"
        case .serif: return "serif"
        case .rounded: return "rounded"
        case .monospaced: return "monospaced"
        @unknown default: return "default"
        }
    }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .serif: return "Serif"
        case .rounded: return "Rounded"
        case .monospaced: return "Monospaced"
        @unknown default: return "Default"
        }
    }

    var icon: String {
        switch self {
        case .default: return "Aa"
        case .serif: return "Aa"
        case .rounded: return "Aa"
        case .monospaced: return "Aa"
        @unknown default: return "Aa"
        }
    }

    var previewFont: Font {
        switch self {
        case .default: return .system(size: 20, weight: .medium, design: .default)
        case .serif: return .system(size: 20, weight: .medium, design: .serif)
        case .rounded: return .system(size: 20, weight: .medium, design: .rounded)
        case .monospaced: return .system(size: 20, weight: .medium, design: .monospaced)
        @unknown default: return .system(size: 20, weight: .medium, design: .default)
        }
    }

    /// Monospaced (SF Mono) has a taller x-height and wider glyphs than the
    /// default San Francisco design, so it visibly renders bigger at the same
    /// point size. This scales the requested size down for monospaced only,
    /// so switching font design doesn't change the apparent text size.
    func visuallyCompensatedSize(_ size: CGFloat) -> CGFloat {
        self == .monospaced ? size * 0.88 : size
    }

    /// AppKit equivalent, so the NSTextView-backed script editor (and its
    /// placeholder) can actually follow the chosen font design instead of a
    /// hardcoded system font.
    func nsFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        // .monospacedSystemFont is the dedicated, guaranteed-correct API for
        // SF Mono — the `.withDesign(.monospaced)` descriptor trick used
        // below for the other designs is measurably less reliable and can
        // silently fall back to a narrower, non-monospaced font. That
        // mismatch (this font resolving narrower than what SwiftUI's own
        // `Font.system(design: .monospaced)` actually renders on the real
        // scrolling text) is exactly what made the estimated read time
        // undercount the real one.
        if self == .monospaced {
            return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        }
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let design: NSFontDescriptor.SystemDesign
        switch self {
        case .default: design = .default
        case .serif: design = .serif
        case .rounded: design = .rounded
        case .monospaced: design = .monospaced
        @unknown default: design = .default
        }
        guard let descriptor = base.fontDescriptor.withDesign(design) else { return base }
        return NSFont(descriptor: descriptor, size: size) ?? base
    }
}

// MARK: - PrompterTheme Enum
enum PrompterTheme: String, CaseIterable {
    case dark = "dark"
    case light = "light"
    /// Modeled on nook-notch: the box itself is invisible — no fill, no
    /// shape, just the text floating over whatever's behind it. White text
    /// for dark surroundings, black text for light surroundings.
    case transparentDark = "transparentDark"
    case transparentLight = "transparentLight"

    var displayName: LocalizedStringKey {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .transparentDark: return "Glass (white)"
        case .transparentLight: return "Glass (black)"
        }
    }

    /// Drives `.environment(\.colorScheme, ...)` so native controls (toggles,
    /// pickers) render correctly regardless of which variant is active.
    var isDarkLike: Bool {
        switch self {
        case .dark, .transparentDark: return true
        case .light, .transparentLight: return false
        }
    }

    /// True for the two glass variants — option buttons/chips throughout the
    /// settings tabs drop their filled backgrounds and become just colored
    /// text/icons (matching "invisible except the text") when this is true.
    var isGlass: Bool {
        self == .transparentDark || self == .transparentLight
    }

    var icon: String {
        switch self {
        case .dark: return "moon.fill"
        case .light: return "sun.max.fill"
        case .transparentDark: return "circle.lefthalf.filled"
        case .transparentLight: return "circle.righthalf.filled"
        }
    }

    /// The stage's floating control-bar capsule is a real frosted material
    /// in every theme now — not just Glass — so the text scrolling behind it
    /// always shows through, blurred and dimmed rather than a flat opaque
    /// color. A per-theme colored tint sits on top of that same material, so
    /// each theme still reads as its own color instead of all four looking
    /// like the same gray glass.
    var controlBarTint: Color {
        switch self {
        // No color identity here on purpose — just the frosted material
        // itself with a faint neutral highlight, not tinted toward any hue.
        case .dark: return .white
        case .light: return Color(red: 0.15, green: 0.15, blue: 0.17)
        case .transparentDark: return .white
        case .transparentLight: return .black
        }
    }

    /// How strongly that tint shows over the material — Light stays clearly
    /// colored; Dark and the Glass themes keep theirs subtle/neutral.
    var controlBarTintOpacity: Double {
        switch self {
        case .light: return 0.55
        case .dark, .transparentDark, .transparentLight: return 0.1
        }
    }

    /// The teleprompter stage's own background — fully transparent for the
    /// glass themes, so only the text is visible over the desktop/whatever
    /// is behind the box.
    var backgroundColor: Color {
        switch self {
        case .dark: return .black
        case .light: return .white
        case .transparentDark, .transparentLight: return .clear
        }
    }

    /// The settings panel's background — "almost invisible" rather than
    /// fully transparent, so there's still a legible surface to read
    /// controls against (matches nook-notch's own subtle-material look).
    var panelBackgroundColor: Color {
        switch self {
        case .dark: return .black
        case .light: return .white
        // Swapped relative to the stage's own background/text colors on
        // purpose — "Glass (white)" should show a white-ish settings panel
        // and "Glass (black)" a black-ish one, matching their names. The
        // teleprompter stage's colors are untouched.
        case .transparentDark: return .white.opacity(0.35)
        case .transparentLight: return .black.opacity(0.35)
        }
    }

    /// The outer pill/box shape's own fill. Kept red for the two original
    /// themes (the app's established look); invisible for the glass themes.
    var shapeFillColor: Color {
        switch self {
        // Matches the theme's own color — black box for Dark, white box for
        // Light — instead of a hardcoded brand color.
        case .dark, .light: return backgroundColor
        case .transparentDark, .transparentLight: return .clear
        }
    }

    var textColor: Color {
        switch self {
        case .dark, .transparentDark: return .white
        case .light, .transparentLight: return .black
        }
    }

    /// The settings panel's own text color — kept separate from `textColor`
    /// (used by the teleprompter stage, untouched) because `panelBackgroundColor`
    /// is deliberately swapped for the glass themes (white panel for "Glass
    /// (white)", black for "Glass (black)"): using the stage's `textColor`
    /// there would put white text on a white panel and black text on black.
    var panelTextColor: Color {
        switch self {
        case .dark: return .white
        case .light: return .black
        case .transparentDark: return .black
        case .transparentLight: return .white
        }
    }

    var fadeColor: Color {
        switch self {
        case .dark: return .black
        case .light: return .white
        case .transparentDark: return .black.opacity(0)
        case .transparentLight: return .white.opacity(0)
        }
    }
}

// MARK: - PrompterHorizontalAlignment Enum
enum PrompterHorizontalAlignment: String, CaseIterable {
    case left = "left"
    case center = "center"
    case right = "right"

    var displayName: LocalizedStringKey {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        }
    }

    var icon: String {
        switch self {
        case .left: return "arrow.left.line"
        case .center: return "arrow.left.right"
        case .right: return "arrow.right.line"
        }
    }
}

// MARK: - PrompterTextAlignment Enum
enum PrompterTextAlignment: String, CaseIterable {
    case leading = "leading"
    case center = "center"
    case trailing = "trailing"

    var displayName: LocalizedStringKey {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        case .trailing: return "Right"
        }
    }

    var icon: String {
        switch self {
        case .leading: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .trailing: return "text.alignright"
        }
    }

    var swiftUIAlignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}
