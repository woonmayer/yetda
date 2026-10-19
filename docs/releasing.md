# Releasing Yetda

A release is one tag: push `vX.Y.Z` and `.github/workflows/release.yml` tests,
builds a universal binary, signs it with Developer ID (hardened runtime),
notarizes and staples the app and the dmg, publishes a GitHub Release and
updates the Homebrew cask.

## One-time setup

1. **Apple Developer Program** (individual, $99/year) on the personal account.
2. **Developer ID Application certificate.** Xcode → Settings → Accounts →
   Manage Certificates → + → *Developer ID Application*. Then in Keychain
   Access, export it with its private key as `yetda-devid.p12` (set a password).
3. **App Store Connect API key** for notarization. App Store Connect → Users
   and Access → Integrations → App Store Connect API → + (role *Developer*).
   Note the Key ID and Issuer ID; download `AuthKey_<KEY_ID>.p8` (only once).
4. **Public places for downloads.** While this repo is private, Release files
   are not downloadable without a login, so:
   - create a public repo `woonmayer/homebrew-tap` (the name must start with
     `homebrew-`; users then run `brew install --cask woonmayer/tap/yetda`),
   - set repo variable `RELEASE_REPO=woonmayer/homebrew-tap` so the dmg is
     attached there too. Remove the variable once yetda itself is public.
5. **Secrets and variables** (yetda → Settings → Secrets and variables → Actions):

   | Kind | Name | Value |
   |---|---|---|
   | secret | `DEVELOPER_ID_P12` | `base64 -i yetda-devid.p12 \| pbcopy` |
   | secret | `DEVELOPER_ID_P12_PASSWORD` | the export password |
   | secret | `NOTARY_KEY_ID` | Key ID |
   | secret | `NOTARY_ISSUER_ID` | Issuer ID |
   | secret | `NOTARY_KEY_P8` | contents of the `.p8` file |
   | secret | `RELEASE_TOKEN` | fine-grained PAT, *Contents: read and write* on yetda and homebrew-tap |
   | variable | `TAP_REPO` | `woonmayer/homebrew-tap` |
   | variable | `RELEASE_REPO` | `woonmayer/homebrew-tap` (only while yetda is private) |

6. **Dry run.** Actions → Release → Run workflow (dry run on). It signs and
   notarizes without publishing; the dmg is attached to the run as an
   artifact. Open it on another Mac (or a fresh user account) and check that
   Gatekeeper lets it open, Screen Recording and Accessibility prompts appear,
   and ⌘⌘ capture + auto-paste work under the hardened runtime.

## Each release

1. Move the `## Unreleased` notes in `CHANGELOG.md` under `## X.Y.Z` and set
   `VERSION` to `X.Y.Z`. Commit.
2. `git tag vX.Y.Z && git push origin main vX.Y.Z`
3. Check the Release page and `brew install --cask woonmayer/tap/yetda` on a
   clean Mac.

## Locally (without CI)

```bash
xcrun notarytool store-credentials yetda-notary \
  --key AuthKey_XXXX.p8 --key-id XXXX --issuer <issuer-id>
YETDA_SIGN_ID="Developer ID Application: … (TEAMID)" \
YETDA_NOTARY_PROFILE=yetda-notary ./scripts/release.sh
./scripts/render-cask.sh woonmayer/homebrew-tap > ../homebrew-tap/Casks/yetda.rb
```

## Landing page (GitHub Pages)

Settings → Pages → *Deploy from a branch* → `main` / `/docs`. The site is
`https://woonmayer.github.io/yetda/` (pages use absolute URLs for `og:image`
and `hreflang`). Pages from a private repo needs GitHub Pro; otherwise turn it
on when the repo goes public.
