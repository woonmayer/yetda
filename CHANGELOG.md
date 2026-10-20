# Changelog

## Unreleased

- **Feedback** menu: *Report a Bug…* opens the GitHub issue form with your
  Yetda and macOS versions and paste target filled in; *Suggest an Idea…*
  opens the idea form. Nothing is sent until you submit it in the browser.

## 0.3.2

- **Paste Into** menu replaces *Also Paste into*, *Added Apps* and *Paste Key*:
  it names the app the next capture goes to and lists every target — the
  terminals and agent apps on this Mac, then the apps you added — with each
  one's paste key, which you can change per app. Add the app you were just in,
  or any app with **Add App…**. A paste key forced for all apps carries over
  to each terminal and added app.

## 0.3.1

- **Agent desktop apps:** auto-paste also goes to the Claude, Codex and ChatGPT
  desktop apps (with `⌘V`), whichever of them or your terminal you used last.
- **Added Apps** menu: any app you add as a paste target gets `⌘V` by default;
  pick `⌘V` or `Ctrl+V` per app, or remove it.
- **Support Yetda…** menu item and a Sponsor link (GitHub Sponsors); the app
  only opens the page in your browser.

## 0.3.0

- **Hide secrets, closer gaps:** the body of a private key under its
  `BEGIN … PRIVATE KEY` header is hidden, not just the header; a key the
  terminal wrapped onto the next line is hidden on both lines (including when
  neither part is recognizable alone); plain-word passwords
  (`PGPASSWORD=postgres`) are hidden, with only known stand-ins (`required`,
  `<your-key>`, `$TOKEN`, …) left alone.
- The on-device model judges a capture's unknown-format strings in one request,
  so a busy screen no longer times out line by line.
- A new capture cancels a paste still in progress, so an older paste can't put
  its image back on the clipboard.
- The cross-line decisions live in `YetdaCore` (`ScreenshotRedaction`) with tests;
  CI also builds and tests on macOS 26.
- **Signed releases:** Developer ID + hardened runtime, notarized dmg, and a
  Homebrew cask (`brew install --cask woonmayer/tap/yetda`); `scripts/release.sh`
  and a tag-triggered release workflow. Universal binary (Apple silicon + Intel).
- **/shots skill ships with the app:** on first launch Yetda asks once whether to
  install it for Claude Code (`~/.claude/skills`) and Codex (`~/.agents/skills`);
  toggle it per agent from the menu. Its own copies update with the app; edited
  copies are left alone.
- **Renamed ClipShot → Yetda** (옜다, Korean for “here, take it”). New bundle ID
  `io.github.woonmayer.yetda` and capture folder `~/Yetda/`; settings and
  `~/ClipShot/` are carried over on first launch. macOS asks for Screen
  Recording and Accessibility again, since permissions follow the bundle ID.
- Kaku added to the known terminals; **Also Paste into “<app>”** menu item
  adds any other app as an auto-paste target.
- **Hide secrets:** on-device OCR finds API keys, tokens, passwords and card
  numbers in each capture and blacks them out (on by default). Apple's
  on-device model double-checks unknown formats on macOS 26 with Apple
  Intelligence. Masks are solid password-field pills; *Paste Last Capture
  Without Hiding* undoes a mask (original kept in memory for 5 minutes).
- **Also paste text:** optionally paste the capture's OCR text after the image.
- Works with any terminal coding agent (Claude Code, Codex, Gemini CLI,
  opencode, …); README and landing page say so.
- **Paste Key** menu: Automatic, or force `Ctrl+V` / `⌘V` (e.g. Cursor CLI).
- App icon (`scripts/make-icon.sh` regenerates it).
- Landing page in `docs/` for GitHub Pages.
- Promo videos (`assets/promo*.mp4`), built with Remotion in `promo/` (`npm run render`).

## 0.2.0

- **Auto-paste:** after a capture, Yetda brings the last active terminal to
  the front and presses `Ctrl+V`, so the image lands in Claude Code's prompt.
- **⌘⌘ capture:** tap ⌘ twice to capture (toggle in the menu).
- **Paste Recent (⌘⇧1):** thumbnail menu of the 10 newest captures.
- Menu warnings when Screen Recording or Accessibility permission is missing.
- Capture filenames include milliseconds; only Yetda-named files in
  `~/Yetda/` are listed, cleared, or pruned.
- Extra terminals via `defaults write … extraTerminalBundleIDs`.

## 0.1.0

- Menu bar app: ⌘⇧2 region capture to clipboard and `~/Yetda/`, pending
  count badge, 7-day auto-prune, and the `/shots` Claude Code skill.
