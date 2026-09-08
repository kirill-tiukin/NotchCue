<img width="128" height="128" alt="NotchCue logo" src="docs/logo.png" />

# NotchCue for macOS

A teleprompter that lives inside your MacBook's notch. Click it, it opens into a
scrolling text box right where the camera is — so you're always looking near
the lens instead of off to the side of the screen.

## Features

- **Notch-anchored pill UI** — collapses to a small pill in the notch, expands
  into the prompter (and back) with a tap
- **Multiple answers** — keep several scripts loaded and switch between them
  with prev/next, without leaving the notch
- **Four themes** — Dark, Light, and two Glass variants (a real frosted
  material, not a flat color, so whatever's behind the box shows through)
- **Fully custom keyboard shortcuts** — click any shortcut in Settings and
  press your own combo to rebind it; changes apply immediately
- **Voice activation** — starts and stops scrolling based on your mic input,
  no button presses needed
- **Hidden from screen recording** — toggle it invisible to screen shares and
  recordings while staying visible to you
- **Adjustable everything** — font (Default/Serif/Rounded/Monospaced), size,
  line spacing, alignment, scroll speed, top/bottom fade, width/height,
  multi-monitor screen selection
- **Menu-bar controlled** — no Dock icon; toggle visibility from the menu bar
  or a global hotkey

## Install

1. Download the latest `NotchCue.zip` from the
   [Releases page](https://github.com/kirill-tiukin/NotchCue/releases/latest).
2. Unzip it and drag `NotchCue.app` into `/Applications`.
3. First launch: this build isn't notarized by Apple (no paid developer
   account), so Gatekeeper will block it — do this **once**:
   - Right-click `NotchCue.app` → **Open** → click **Open** again in the
     dialog that appears (a plain double-click will just refuse to launch it).
   - If macOS still says it's damaged/can't be opened, run this in Terminal,
     then try again: `xattr -cr /Applications/NotchCue.app`
4. macOS will ask for microphone access — only needed if you turn on Voice
   activation; you can deny it and everything else still works.

Requires macOS 14 or later. No Dock icon on purpose — look for it in the
menu bar, or use the global shortcut (⌃⌥⌘P by default, and fully
re-bindable in Settings) to show/hide it.

## Building from source

```bash
brew install xcodegen
xcodegen generate
open notch-cue.xcodeproj
```

Requires macOS 14+ and Xcode 15+. Dependencies (currently just
[HotKey](https://github.com/soffes/HotKey)) are pulled in automatically via
Swift Package Manager on first build.

