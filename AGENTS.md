# AGENTS.md

Rules for AI coding agents (Claude, Codex, Copilot, Cursor, ...) and humans working on Maramao.
Read this file before changing anything. If a rule here conflicts with an instruction from the maintainer, the maintainer wins.

## What this repo is

Maramao is a native macOS Pomodoro timer that lives in the menu bar. When it is time for a break, cats stop you from working.

| Path | What it is |
| --- | --- |
| `Sources/MaramaoCore` | Pure Pomodoro logic (`PomodoroCycle`, `formatClock`). No AppKit, fully unit-tested |
| `Sources/Maramao/App` | SwiftUI `MenuBarExtra` app, menu panel, settings window |
| `Sources/Maramao/Core` | `PomodoroEngine` (clock), `BreakCoordinator`, `BreakMode` protocol, `AppSettings`, `BreakModeID` |
| `Sources/Maramao/Shared` | Building blocks for break modes: `OverlayWindow`, `BreakHUD`, `CatView` (the procedural cat) |
| `Sources/Maramao/Resources` | `Localizable.xcstrings`: String Catalog, Italian keys with English translations |
| `Sources/Maramao/Modes/<Name>` | One folder per break concept, each a `BreakMode` |
| `Tests/MaramaoCoreTests` | XCTest for `MaramaoCore` |
| `Resources/Info.plist` | App bundle metadata, including the version |
| `scripts/build-app.sh` | Wraps the SwiftPM binary into `dist/Maramao.app` and a zip |
| `site/` | The project website (static HTML/CSS/JS, Italian), deployed to GitHub Pages by `.github/workflows/pages.yml` |

## Language of the project

- **Code, comments, doc comments, commit messages, PR titles and PR descriptions: English.**
- Everything the user sees in the app (menu, settings, cat captions, HUD) is written in **Italian** first: that is the product, not a style choice. Italian is the source language of the String Catalog and every string also gets an **English** translation, used when macOS runs in English (see "Rules for changes").

## Build and test

Needs macOS 13+ and Xcode 15+ (Swift 5.9). These mirror CI (`.github/workflows/ci.yml`):

```bash
swift build
swift test
scripts/build-app.sh release   # dist/Maramao.app
open dist/Maramao.app
```

Every break mode can be tried without waiting 25 minutes: menu bar → "Prova un concept".

The website has no build step: preview it with `python3 -m http.server -d site 8000` and open http://localhost:8000.

## Rules for changes

- **CI must be green** before a PR is ready. Never skip, delete or weaken a test to get green.
- Logic that does not need AppKit goes in `MaramaoCore` and ships with tests.
- **A new break mode** gets its own folder in `Sources/Maramao/Modes/`, a case in `BreakModeID` (emoji, Italian title and subtitle) and a line in `BreakCoordinator.make`. It must respect the `BreakMode` contract documented in `Core/BreakMode.swift`:
  - every window it opens is closed by `end()` within ~3 seconds, even if `end()` arrives mid-animation;
  - it shows the countdown (use `BreakHUD`) and honours `BreakContext.requestSkip()`;
  - it works on every connected display or picks one deliberately;
  - it works **without** Accessibility or Screen Recording permissions. If an optional extra needs one, it degrades gracefully when the permission is missing.
- **Cats are drawn in code (`CatView`) or come from CC0/public-domain art**, credited in the README. No copyrighted memes, GIFs or stickers, no hotlinking images from the web.
- Keep PRs small and focused: one issue, one PR. Do not mix refactors with behaviour changes.
- No third-party dependencies without a reason written in the PR description.
- Match the style of the surrounding code.
- **Every new UI string needs an English translation** in `Sources/Maramao/Resources/Localizable.xcstrings` (String Catalog). Italian is the source language: the key is the Italian text. SwiftUI literals (`Text("…")`, `Button("…")`) are looked up automatically; a plain `String` shown to the user must use `String(localized: "…")`. Counts get plural variants (`one`/`other`) in the catalog, for both `it` and `en`. Translate cat lines with personality, not word for word. CI runs `scripts/check-strings.py`, which fails on a missing English entry, or on a `String(localized:)` key or a SwiftUI literal (`Text`, `Button`, `Toggle`, `Label`, `Section`, `Picker`, `.help`, ...) that is not in the catalog. Text that must never be translated (version lines, "z" for a snoring cat) uses `Text(verbatim:)`.

## Docs, roadmap and planning

- **Do not commit docs, roadmaps, plans, audits, reports or design notes to this repo.** No `ROADMAP.md`, `PLAN.md`, `docs/`, `notes/`. The roadmap lives outside the repo.
- Allowed documentation: `README.md` (user-facing usage only), code comments, and this file plus `CLAUDE.md`.
- **Backlog = GitHub issues only.** No GitHub Projects, no milestones. Every issue carries labels:
  - area: `app`, `cats`, `ci`, `bug`
  - priority: `P0`, `P1`, `P2`
  - version: `v0.1`, `v0.2`, `v0.3`, ...
- Before opening an issue, search for duplicates. Reference the issue from the PR (`Closes #N`).

## Naming conventions

### Commits

[Conventional Commits](https://www.conventionalcommits.org/): `type(scope): summary`

- Summary in English, imperative mood, lower case, no trailing period, ≤ 72 characters.
- Types: `feat`, `fix`, `perf`, `refactor`, `test`, `docs` (README/comments only), `ci`, `build`, `chore`, `revert`.
- Scopes: `core`, `app`, `engine`, `settings`, `cat` (shared cat drawing), `walking-cat`, `meme-wall`, `sleepy-cat`, `cat-pile` (one per break mode, kebab-case), `ci`, `release`.
- Breaking changes: `feat(core)!: ...` plus a `BREAKING CHANGE:` footer.
- Body explains *why*, wrapped at 72 columns.

Examples: `feat(walking-cat): follow the focused window`, `fix(engine): keep the countdown after sleep`, `ci: upload the app bundle`.

### Pull requests

- **Title = a Conventional Commit line** (same format as above). Prefer squash merge, so the title becomes the commit on `main`.
- Description: what changed, why, how it was tested, and `Closes #N`. A screen recording for anything visual.
- Add the matching **area label** (`app`, `cats`, `bug`, `ci`). Release notes are grouped by these labels (`.github/release.yml`); use `skip-changelog` for changes users don't care about.
- Open as draft while CI is red or work is incomplete.

### Branches

`type/short-kebab-description`, e.g. `feat/walking-cat`, `fix/hud-multiple-displays`.
Agent platforms that assign their own branch names (e.g. `claude/...`) are fine; the PR title carries the convention.

## Releases

- SemVer, tags `vX.Y.Z`. Releases follow the same naming as `kkratterf/fratmscript`: the release title is the bare tag (`v0.3.0`, never "Maramao v0.3.0"), published by `github-actions[bot]`, notes generated from `.github/release.yml` (sections by area label, in Italian). Assets keep the names the cask, `install.sh` and the appcast expect: `Maramao-X.Y.Z.zip`, `Maramao-X.Y.Z.dmg`, `SHA256SUMS.txt`.
- Minor release = a version milestone, cut when all `P0` issues of that version label are closed and `main` is green. Patch release when a user-facing fix lands.
- **Merging the version-bump PR is the release.** Nobody has to start a workflow by hand.

### How to cut a release (agents and humans)

1. Check that every `P0` issue of the version label is closed and `main` is green.
2. Open a PR titled `chore(release): vX.Y.Z` that only changes `Resources/Info.plist`: `CFBundleShortVersionString` to `X.Y.Z` and `CFBundleVersion` up by one. Label it `skip-changelog`.
3. Merge it (squash) once CI is green. `release.yml` runs on every push to `main` that touches `Resources/Info.plist`. Its `plan` job reads the version; if the tag `vX.Y.Z` does not exist yet, it tests, builds and signs `Maramao.app`, makes the DMG and checksums, tags, publishes the GitHub Release with notes grouped by label, then commits the Homebrew cask bump (and the Sparkle appcast, when the key is set) to `main`.
4. Check the "Release" run in Actions and the new release page, then tell the maintainer the version is out.

- A version with a suffix (`0.3.0-beta.1`) becomes a pre-release and leaves the cask and the appcast alone.
- Other edits to `Info.plist` (for example `SUPublicEDKey`) trigger the workflow too, find the tag already there and publish nothing.
- If a release run fails, fix the cause in a normal PR that changes `release.yml` (or `Info.plist`): merging it runs the workflow again, which publishes the version whose tag is still missing. The maintainer can also start `release.yml` by hand (`workflow_dispatch`) with the version. The same manual start with `dry_run: true` builds and signs everything and publishes nothing (the files go to the workflow artifacts).
- **No `CHANGELOG.md`.** The changelog lives only in GitHub Release notes.

### What agents cannot do here

Agent sandboxes are refused these actions, so ask the maintainer instead of retrying or working around them:

- start, re-run or cancel workflows (`workflow_dispatch`, re-runs): that is why releases start from a merge;
- delete branches or tags, force-push;
- create, edit or delete GitHub Releases (a wrong title or note is fixed by the maintainer, or by changing `release.yml` for the next one);
- change repository settings: description, topics, Pages, secrets, branch protection;
- add the signing secrets (`APPLE_*`, `SPARKLE_ED_PRIVATE_KEY`).

## Merging

- Agents may push branches, open PRs and merge their own PRs once CI is green and the PR closes its issue(s). Agents never push directly to `main`, force-push `main`, or bypass a failing check. The maintainer is told about releases, not about every merge.
- Never rewrite history on someone else's branch.
