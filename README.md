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
| 🔴 | **Caccia al laser** | Your mouse pointer turns into a red laser dot and a cat chases it all over the screen, pouncing when it stops. Leave the mouse alone and the cat sits down to groom. |
| ⌨️ | **Il gatto sulla tastiera** | A cat falls asleep on a big keyboard. Every key you press ends up as cat-typing ("mmmmrrrrrooooow"), and Cmd-Q won't get you out. |

Breaks can be skipped after a minute (configurable), or never in **modalità severa**.

### Emergency exit

If a break ever gets stuck, or you really have to stop it, press **⌃⌥⌘⌫** (Control-Option-Command-Delete) to end it right away, **modalità severa included**. No shortcut at hand? Click five times quickly in the **top-left corner** of any screen. Neither needs any permission.

As a safety net, Maramao also closes every cat window by force if a break is still on screen 30 seconds after it should have ended.

### Keyboard shortcuts

They work from any app and need no special permission. Turn each one on or off in Settings → **Scorciatoie**.

| Shortcut | Action |
| --- | --- |
| ⌃⌥⌘P | Start a pomodoro, or pause / resume it |
| ⌃⌥⌘B | Take the cat break now |
| ⌃⌥⌘S | Skip the current phase (a break only once skipping is allowed) |

---

## Install

Maramao needs **macOS 13 Ventura or later** and no special permissions. Pick one of the two ways below.

### 1. The DMG (drag and drop)

1. Download `Maramao-x.y.z.dmg` from the [latest release](https://github.com/kkratterf/maramao/releases/latest).
2. Open it and drag the cat onto **Applicazioni** (`Applications`).
3. Eject the disk image.

Every release also ships a plain `Maramao-x.y.z.zip` and a `SHA256SUMS.txt` to check the downloads (`shasum -a 256 -c SHA256SUMS.txt --ignore-missing`).

### 2. The one-liner

```bash
curl -fsSL https://raw.githubusercontent.com/kkratterf/maramao/main/install.sh | sh
```

The script downloads the latest release, checks its SHA-256, quits Maramao if it is running, installs `Maramao.app` in `/Applications` (or `~/Applications` if `/Applications` is not writable), clears the quarantine flag and offers to open it. Read it first if you like: it is [short](install.sh).

| Variable | Effect |
| --- | --- |
| `MARAMAO_VERSION=v0.1.0` | install a specific release instead of the latest |
| `MARAMAO_INSTALL_DIR=~/Apps` | install somewhere else |
| `MARAMAO_NO_OPEN=1` | do not offer to open Maramao at the end |

Variables go after the pipe: `curl -fsSL .../install.sh | MARAMAO_VERSION=v0.1.0 sh`.

### 3. First launch and Gatekeeper

Maramao is not notarized by Apple yet, so the first time you open a copy from the DMG or the zip macOS says it cannot verify the developer. Either:

- right-click `Maramao.app` in Applications → **Apri** (Open) → **Apri** again, or
- try to open it once, then go to **System Settings → Privacy & Security** and click **Apri comunque** (Open Anyway).

If macOS still refuses, clear the quarantine flag by hand:

```bash
xattr -dr com.apple.quarantine /Applications/Maramao.app
```

The install script does this for you. You only need to do it once per version.

### 4. Where is it?

Maramao lives in the **menu bar**, top right: look for the 🐱 (it turns into 🍅 and a countdown while you work). There is no Dock icon and no window until you click it. From the menu you start the timer, pick a cat, open the settings, or try a break right away with **Prova un concept**.

To start Maramao every time you log in, turn on **Apri Maramao all'avvio del Mac** in Settings. macOS may ask you to allow it in System Settings → General → Login Items.

### 5. Updating

Install the new version the same way: drag the new DMG's app over the old one (choose **Sostituisci**, Replace), or run the one-liner again. Your settings are kept.

### 6. Uninstalling

```bash
curl -fsSL https://raw.githubusercontent.com/kkratterf/maramao/main/install.sh | sh -s -- --uninstall
```

This quits Maramao, deletes `Maramao.app` and its settings (`defaults delete com.kkratterf.maramao`). By hand: quit Maramao from its menu, move `Maramao.app` to the Bin, and optionally run that `defaults delete` command. The login item, if you turned it on, goes away with the app.

### 7. Build from source

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
