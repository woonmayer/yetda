# TODO

## Feedback, analytics, bug tracking

Keep the app itself network-free ("no network access, no analytics" is part of
the pitch, next to secret masking); collect everything outside it.

- [ ] **Feedback → spreadsheet.** Google Form on the personal account
      (woonmayer.py@gmail.com), responses linked to Google Sheets. Questions:
      type (feedback / bug / feature request), details, app version, macOS version.
- [ ] **Send Feedback… menu item.** Opens the form in the browser with the
      app and macOS versions prefilled (the form's "Get pre-filled link" URL).
- [ ] **Report a Bug… menu item.** While the repo is private, the same form
      with type = bug; once public, a prefilled GitHub issue
      (`/issues/new?template=bug.yml&version=…`).
- [x] **GitHub issue templates.** `.github/ISSUE_TEMPLATE/bug.yml` and
      `feature.yml` (version, macOS, terminal, agent, steps).
- [ ] **PostHog on the landing page only.** Visits, language, install-button
      clicks; cookieless mode. Needs the project API key (`phc_…`).
- [ ] **In-app usage stats: not now.** If ever, opt-in (off by default),
      counts only, never capture content; say so in README → Privacy.

## Release

- [x] Going public: fresh single-commit repo (old history kept private in yetda-dev).
- [x] Developer ID + notarization; GitHub Release with a signed dmg
      (`scripts/release.sh`, `.github/workflows/release.yml`).
- [x] Homebrew cask template (`packaging/homebrew/`), updated by the release workflow.
- [ ] One-time setup in docs/releasing.md: Apple Developer Program, Developer ID
      cert, notary API key, `woonmayer/homebrew-tap`, Actions secrets; dry run.
- [ ] Tag v0.3.0.
- [x] Landing: absolute og/canonical/`hreflang` for `/`, `/ko/`, `/ja/`; install via
      Homebrew or dmg.
- [ ] Turn on GitHub Pages (`main` / `/docs`) — needs Pro while private.
- [ ] Record a real screen capture for the README and landing page (next to
      the CSS demo).
- [ ] Launch posts: GeekNews (Show GN, Korean), Hacker News, r/ClaudeAI.

## Product

- [ ] Verify auto-paste with Codex CLI, Gemini CLI and opencode; update the
      README "Works with" table from "should work" to "tested".
- [ ] Try the on-device model check on a Mac with Apple Intelligence on.
- [ ] Menu bar icon in the app icon's style (now an SF Symbol camera).
