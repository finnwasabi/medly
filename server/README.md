# Sync service and Telegram bot

A single Node file (`server.js`) with no dependencies, for Node 22 or later. It keeps the latest status snapshot sent
by the app and runs a private Telegram bot that answers one chat only. The data contract is in
[`docs/spec.md`](../docs/spec.md).

## Environment

| Variable | Required | Meaning |
|---|---|---|
| `API_TOKEN` | yes | Token the app uses to send snapshots (`Authorization: Bearer ...`). Generate one with `openssl rand -hex 24`. |
| `PUBLIC_URL` | yes | Public address of the service, for example `https://example.com/ners`. The bot combines it with the token into the connection code. |
| `BOT_TOKEN` | no | Bot token from BotFather. Without it only the API runs. |
| `CHAT_ID` | no | The only chat the bot answers and writes to. |
| `PORT` | no | Defaults to `8787`. |
| `DATA_DIR` | no | Defaults to `./data` and holds `state.json`. |

## Bot

- `/check`: latest status of every medication, with a Refresh button. `/msg <text>`: a note shown on the app's Today
  screen after the next sync; `/msg` alone shows the current note. `/clearmsg` removes it. `/link`: the connection code
  to paste into the app's Settings, with a Copy button. `/help` and `/start` list the commands.
- Writes on its own when something worth knowing happens: a dose taken, an undo, a new late or missed dose, a make-up,
  a pause, low pills, a medication added or removed.
- A 09:00 Vietnam time report every day. Data older than 24 hours is flagged as not synced since then.
- Sets its command menu and profile descriptions on every start. Accepts snapshots from 0.1.x apps (version 1) too.

## Run

```sh
npm test
API_TOKEN=... PUBLIC_URL=https://example.com/ners node server.js
```

With Docker Compose, using the official Node image and mounting the source:

```yaml
ners-daily:
  image: node:24-alpine
  working_dir: /app
  command: node server.js
  user: "1000:1000"
  env_file: ./ners-daily/.env
  volumes:
    - ./ners-daily/server.js:/app/server.js:ro
    - ./ners-daily/data:/app/data
  restart: unless-stopped
```
