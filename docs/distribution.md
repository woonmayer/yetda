# Yetda — Distribution Notes

Yetda is two artifacts that must reach a user **together**:

1. a native macOS app (`Yetda.app`) — needs signing/notarization, and
2. a Claude Code skill (`skills/shots/SKILL.md`) — installs to `~/.claude/skills/`.

They communicate through a shared folder (`~/Yetda/`), so neither embeds the
other. The distribution question is: how do both land on a user's machine, in
sync, with as few steps as possible.

## Precedents (what others do)

The "ship a desktop app alongside an AI-agent extension" pattern is young but
already has recognizable shapes:

- **App bundles an MCP server.** The most mature pattern today. A native app
  ships a companion MCP binary and offers an in-app install/repair flow plus
  auto-generated client config. Anthropic's **`.mcpb` (MCP Bundle)** format and
  Claude Desktop **Desktop Extensions** make this a double-click install.
- **Plugin bundles the skill.** A Claude Code **plugin** packages skills,
  commands, hooks, and MCP defs as one installable unit via a marketplace — the
  canonical way to distribute the *skill* half.
- **Companion apps already exist.** Community lists track dozens of native
  Claude Code companion apps; e.g. MCPBundler is a macOS app that syncs skills
  across Claude/Codex.

Yetda uses a **folder handoff**, not MCP, so the MCP packaging paths don't
apply directly — but the "app installs its own extension on first run" idea
from the MCP-companion world transfers cleanly.

## Options for Yetda

### A. App-led (recommended)

The app is the heavy artifact; make it the thing users download, and let it
carry the skill.

- Distribute `Yetda.app` via a **Homebrew cask** (`brew install --cask
  yetda`) and/or a notarized **`.dmg`**.
- On launch, the app **installs/updates `~/.claude/skills/shots/SKILL.md`**
  (idempotent; only rewrite when the bundled version differs). Ship the skill
  inside the app bundle as a resource and copy it out.
- One thing to download; the skill is always in sync with the app version.

Trade-off: requires Developer ID signing + notarization (see Gates).

### B. Skill-led

Publish `/shots` to a **Claude Code plugin marketplace**; its README/install
step tells users to `brew install --cask yetda` for the app.

- Good discoverability for the skill; the app stays a separate install.
- Two steps for the user, and the two halves can drift in version.

### C. Convert the handoff to MCP

Re-implement the bridge as an MCP server so Yetda fits the **`.mcpb` /
Desktop Extensions** one-click ecosystem.

- Biggest reach and a true one-click install.
- Overkill for Yetda's simple folder model, and a meaningful rewrite. Not
  recommended unless the integration grows well beyond "feed recent shots."

## Gates (must-haves before any public release)

- **Developer ID signing + notarization.** The current build signs with an
  *Apple Development* certificate, which is **local-only** — other Macs'
  Gatekeeper will block it. Public distribution needs a **Developer ID
  Application** certificate, `codesign --options runtime`, `notarytool`
  submission, and `stapler staple`.
- **Hardened runtime + entitlements.** Notarization requires the hardened
  runtime. Verify Screen Recording still works under it.
- **Versioning.** Tag releases (`vX.Y.Z`) so the cask and the bundled skill
  version move together.

## Recommended roadmap

1. **Make the app self-install the skill.** Bundle `SKILL.md` as an app
   resource; on launch, write it to `~/.claude/skills/shots/` only when the
   bundled version is newer/different. (Removes the manual `cp` step from the
   README.)
2. **Set up Developer ID notarization** in `build-app.sh` (or a separate
   `release.sh`): sign with Developer ID + hardened runtime, `notarytool
   submit --wait`, `stapler staple`, produce a `.dmg`.
3. **Publish a Homebrew cask** pointing at the notarized `.dmg` release asset.
4. **Tag `v1.0.0`** and attach the `.dmg` to a GitHub release.
5. *(Optional)* List `/shots` on a plugin marketplace for discoverability,
   linking back to the cask.

## Open decisions

- Public repo or keep private? (Currently private.)
- Homebrew: a personal tap (`woonmayer/homebrew-tap`) vs. submitting to
  homebrew-cask (the latter has acceptance criteria).
- License: MIT (decided).

## Sources

- Create and distribute a plugin marketplace — Claude Code Docs:
  https://code.claude.com/docs/en/plugin-marketplaces
- modelcontextprotocol/mcpb (Desktop Extensions, one-click MCP install):
  https://github.com/modelcontextprotocol/mcpb
- Adopting the MCP Bundle format (.mcpb):
  https://blog.modelcontextprotocol.io/posts/2025-11-20-adopting-mcpb/
- Building an MCP server for a Swift-native macOS app:
  https://medium.com/@charidimos/building-an-mcp-server-for-a-swift-native-macos-app-84197137d378
- awesome-claude-code-toolkit (companion apps list):
  https://github.com/rohitg00/awesome-claude-code-toolkit
