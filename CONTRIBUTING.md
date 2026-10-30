# Contributing

Thanks for helping. Issues and pull requests are welcome in English or Vietnamese.
Code, comments, commits, the changelog and release notes are written in English.

## Branches

| Branch | Purpose |
|---|---|
| `develop` | Integration branch. **Open every pull request against `develop`.** Changes are tested here first. |
| `main` | What is released. Only the maintainer merges `develop` into `main` when cutting a version. |

Both branches are protected: changes land only through pull requests with green CI, with no force pushes or deletions.
Release tags (`v*`) can only be created by the maintainer.

## Workflow

1. Fork the repo and branch off `develop` (`git switch -c fix-snooze-countdown origin/develop`).
2. Make the change and add or adjust tests. Logic belongs in `Packages/PillotCore`, which stays pure Foundation and never reads the device clock or time zone directly.
3. Run the checks:
   ```sh
   swift test --package-path Packages/PillotCore
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

1. On `develop`, move **Unreleased** in the changelog to the new version through a pull request.
2. Merge `develop` into `main` through a pull request, and wait until it is actually merged.
3. Tag the tip of `main` with `vX.Y.Z`. GitHub Actions builds the `.ipa`, generates `source.json` and publishes the release, so SideStore users get the update.

The release workflow first runs `scripts/check-release.sh` and refuses the tag unless it is the tip of `main`, contains everything on `develop`, and the changelog has a `## [X.Y.Z]` section. Run it locally before pushing the tag: `git fetch origin && scripts/check-release.sh vX.Y.Z`.

By contributing you agree that your work is released under the [MIT License](LICENSE) and that you follow the [Code of Conduct](CODE_OF_CONDUCT.md).
