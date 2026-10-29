# Contributing

Thanks for helping. Issues and pull requests are welcome in English or Vietnamese
(*đóng góp bằng tiếng Việt hay tiếng Anh đều được*).

## Branches

| Branch | Purpose |
|---|---|
| `develop` | Integration branch. **Open every pull request against `develop`.** Changes are tested here first. |
| `main` | What is released. Only the maintainer merges `develop` into `main` when cutting a version. |

Both branches are protected: changes land only through pull requests with green CI, with no force pushes or deletions.
Release tags (`v*`) can only be created by the maintainer.

## Workflow

1. Fork the repo and branch off `develop` (`git switch -c fix-snooze-countdown origin/develop`).
2. Make the change and add or adjust tests. Logic belongs in `Packages/NersCore`, which stays pure Foundation and never reads the device clock or time zone directly.
3. Run the checks:
   ```sh
   swift test --package-path Packages/NersCore
   (cd server && node --test)
   xcodegen generate && scripts/build-ipa.sh
   ```
4. Open a pull request against `develop` and fill in the template. Keep it focused on one change.
5. Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md). The changelog and release notes are written in English.

## Guidelines

- Every user-facing string exists in both languages: write it as `L("Tiếng Việt", "English")` at the call site.
- Schedule maths always goes through Vietnam time (`VietnamClock`) and absolute dates. Never use `TimeZone.current` for scheduling.
- The app gives no medical advice. Texts about missed or late pills only point to the leaflet, a doctor or a pharmacist.
- No secrets, tokens, real names or real health data in the repo, the issues or the screenshots.
- Do not use em dashes in text or code comments.

## Releases (maintainer)

1. Merge `develop` into `main` through a pull request.
2. Move **Unreleased** in the changelog to the new version.
3. Tag `main` with `vX.Y.Z`. GitHub Actions builds the `.ipa`, generates `source.json` and publishes the release, so SideStore users get the update.

By contributing you agree that your work is released under the [MIT License](LICENSE) and that you follow the [Code of Conduct](CODE_OF_CONDUCT.md).
