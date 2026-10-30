<!-- Open pull requests against `develop`, not `main`. -->

## What

<!-- What changes and why. Link the issue if there is one: "Closes #123". -->

## How it was checked

<!-- Tests added or run, simulator or device, light and dark mode, both languages. -->

## Screenshots

<!-- For UI changes: before and after, light and dark, Vietnamese and English. Use made-up names only. -->

## Checklist

- [ ] The base branch is `develop`
- [ ] `swift test --package-path Packages/PillotCore` passes
- [ ] `cd server && node --test` passes (if `server/` changed)
- [ ] Every new user-facing string has Vietnamese and English (`L("…", "…")`)
- [ ] Scheduling goes through Vietnam time and absolute dates only
- [ ] No medical advice in new texts, no secrets or real personal data
- [ ] A line under **Unreleased** in `CHANGELOG.md` (in English)
