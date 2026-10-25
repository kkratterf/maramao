# Maramao 🐈

**Il Pomodoro che ti ferma coi gatti** (the Pomodoro timer that stops you with cats)

[![CI](https://github.com/kkratterf/maramao/actions/workflows/ci.yml/badge.svg)](https://github.com/kkratterf/maramao/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/kkratterf/maramao)](https://github.com/kkratterf/maramao/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](#license)

A native macOS menu bar app for the Pomodoro technique. Work for 25 minutes, then a cat makes sure you actually take the break. Written in Swift with SwiftUI and AppKit.

---

## The cats

Pick one in the menu bar, or let **🎲 Sorpresa** choose a different one every break. You can try each of them right away from **Prova un concept**.

| | Mode | What happens |
| --- | --- | --- |
| 🐈 | **Il gatto sulla finestra** | A cat walks across the screen, jumps on the window you are working in and sits on it. That window is blocked until the break ends. Switch window? The cat follows. |
| 😹 | **Muro di meme** | The screen fills with cat memes until the break is over. |
| 😴 | **Non svegliare il gatto** | A cat falls asleep on your screen. Touch the mouse and it wakes up and judges you. |
| 🐾 | **Invasione di gatti** | Cats rain from the top of the screen and pile up until everything is buried. |

Breaks can be skipped after a minute (configurable), or never in **modalità severa**.

### Emergency exit

If a break ever gets stuck, or you really have to stop it, press **⌃⌥⌘⌫** (Control-Option-Command-Delete) to end it right away, **modalità severa included**. No shortcut at hand? Click five times quickly in the **top-left corner** of any screen. Neither needs any permission.

As a safety net, Maramao also closes every cat window by force if a break is still on screen 30 seconds after it should have ended.

---

## Install

Download `Maramao-x.y.z.zip` from the [latest release](https://github.com/kkratterf/maramao/releases/latest), unzip it and move `Maramao.app` to `Applications`.

The app is not notarized yet, so the first time macOS will block it. Right-click `Maramao.app` → **Open**, or run:

```bash
xattr -dr com.apple.quarantine /Applications/Maramao.app
```

Maramao needs macOS 13 Ventura or later and no special permissions.

To start Maramao every time you log in, turn on **Apri Maramao all'avvio del Mac** in Settings. It works when Maramao runs from `Maramao.app`; macOS may ask you to allow it in System Settings → General → Login Items.

### Build from source

Needs Xcode 15 or later.

```bash
git clone https://github.com/kkratterf/maramao
cd maramao
swift test                      # unit tests
scripts/build-app.sh release    # builds dist/Maramao.app
open dist/Maramao.app
```

`swift run Maramao` also works for a quick try, without the app bundle.

---

## Contributing

Contributions are welcome, from a new cat to a timer fix.

- **Found a bug or have an idea?** [Open an issue](https://github.com/kkratterf/maramao/issues/new/choose): there are forms for bugs, features and new break concepts.
- **Want to add a cat?** Every break mode is a `BreakMode` in `Sources/Maramao/Modes/`. The shared `CatView` draws the cat, `OverlayWindow` and `BreakHUD` do the rest.
- **Before a PR**, read [`AGENTS.md`](AGENTS.md): it lists the checks to run, the commit format and the rules for break modes. It is written for AI agents and humans alike.

---

## Art

Every cat in Maramao is drawn in code (`Sources/Maramao/Shared/CatView.swift`). No third-party images, memes or GIFs are bundled. Any future CC0 or public-domain asset will be credited here.

---

## License

MIT

---

<p align="center">
  <b>Made with Claude and cats</b>
</p>
