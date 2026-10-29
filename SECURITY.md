# Security policy

## Reporting a vulnerability

Please **do not open a public issue** for security problems.
Use GitHub's private reporting instead: **Security > Report a vulnerability** on this repository.

Include what is affected (the app, the sync server or the release pipeline), steps to reproduce, and the impact you expect.
Reports in English or Vietnamese are both fine. You will get a reply within 7 days. Fixes ship in the next release, and you are credited unless you prefer otherwise.

## Scope

- The iOS app: local data storage, the Keychain-stored connection code, and the notification and alarm handling.
- `server/`: authentication of `/v1/snapshot`, input validation, and the Telegram bot.
- `.github/workflows`: the build and release pipeline.

## Supported versions

Only the latest release receives fixes. SideStore updates installed copies from the source automatically.
