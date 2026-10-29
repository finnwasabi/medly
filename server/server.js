// Ner's Daily sync service: keeps the latest snapshot from the app and runs a private Telegram bot.
// Plain Node, no dependencies. Every setting comes from environment variables, nothing secret lives in the repo.
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, renameSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { timingSafeEqual } from 'node:crypto';

const VN_OFFSET_MS = 7 * 3600 * 1000;
const WEEKDAYS = {
  vi: ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'],
  en: ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
};

// Bot language: Vietnamese by default, English with BOT_LANGUAGE=en.
let language = process.env.BOT_LANGUAGE === 'en' ? 'en' : 'vi';
export const setLanguage = (value) => { language = value === 'en' ? 'en' : 'vi'; };
const t = (vi, en) => (language === 'en' ? en : vi);

// MARK: Formatting (Vietnam time, fixed UTC+7 with no daylight saving)

const pad = (n) => String(n).padStart(2, '0');
const vn = (iso) => new Date(Date.parse(iso) + VN_OFFSET_MS);

export function vnTime(iso) {
  const d = vn(iso);
  return `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}

export function vnDay(iso) {
  const d = vn(iso);
  return `${WEEKDAYS[language][d.getUTCDay()]} ${pad(d.getUTCDate())}/${pad(d.getUTCMonth() + 1)}`;
}

export function vnDateKey(ms) {
  const d = new Date(ms + VN_OFFSET_MS);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

/// The user's name sent with the snapshot, or a neutral word without one.
export const who = (s) => (typeof s?.name === 'string' && s.name.trim()) || t('Người ấy', 'They');

/// Full status for /check and the 09:00 report.
export function statusText(snapshot, now = Date.now()) {
  if (!snapshot) return t('Chưa nhận được dữ liệu nào từ app.', 'No data from the app yet.');
  const s = snapshot;
  const lines = [`💊 ${(typeof s.name === 'string' && s.name.trim()) || "Ner's Daily"}`];
  lines.push(s.lastTakenAt
    ? t(`Uống gần nhất: ${vnTime(s.lastTakenAt)} giờ VN, ${vnDay(s.lastTakenAt)}`, `Last dose: ${vnTime(s.lastTakenAt)} VN time, ${vnDay(s.lastTakenAt)}`)
    : t('Chưa có lần uống nào.', 'No doses yet.'));
  if (s.pausedUntil && Date.parse(s.pausedUntil) > now) {
    lines.push(t(`Đang tạm dừng nhắc tới ${vnTime(s.pausedUntil)} ${vnDay(s.pausedUntil)}.`, `Reminders paused until ${vnTime(s.pausedUntil)} ${vnDay(s.pausedUntil)}.`));
  } else {
    lines.push(t(`Lần tới: ${vnTime(s.nextDueAt)} giờ VN ${vnDay(s.nextDueAt)}, hạn chót ${vnTime(s.deadlineAt)}.`, `Next: ${vnTime(s.nextDueAt)} VN time ${vnDay(s.nextDueAt)}, deadline ${vnTime(s.deadlineAt)}.`));
  }
  const madeUp = s.madeUpCount ?? 0;
  lines.push(t(`Đã uống ${s.daysTaken} ngày, trễ ${s.lateCount ?? 0}, hụt ${s.missedCount - madeUp}`, `Taken ${s.daysTaken} days, late ${s.lateCount ?? 0}, missed ${s.missedCount - madeUp}`)
    + (madeUp ? t(`, đã uống bù ${madeUp}.`, `, made up ${madeUp}.`) : '.'));
  if (s.pillsTotal != null) {
    const refill = s.refillReminder?.enabled && s.pillsRemaining <= s.refillReminder.daysBefore ? t(', cần mua thêm', ', time to buy more') : '';
    lines.push(t(`Còn ${s.pillsRemaining}/${s.pillsTotal} viên${refill}.`, `${s.pillsRemaining}/${s.pillsTotal} pills left${refill}.`));
  }
  const age = now - Date.parse(s.updatedAt);
  lines.push(age > 24 * 3600 * 1000
    ? t(`⚠️ Chưa đồng bộ từ ${vnTime(s.updatedAt)} ${vnDay(s.updatedAt)}.`, `⚠️ Not synced since ${vnTime(s.updatedAt)} ${vnDay(s.updatedAt)}.`)
    : t(`Cập nhật lúc ${vnTime(s.updatedAt)} giờ VN.`, `Updated at ${vnTime(s.updatedAt)} VN time.`));
  return lines.join('\n');
}

/// Message sent on new data. Only for things worth knowing, not on every app launch.
export function changeText(previous, next) {
  const parts = [];
  const taken = (s) => (s?.lastTakenAt ? Date.parse(s.lastTakenAt) : 0);
  if (taken(next) > taken(previous)) {
    let line = t(`✅ ${who(next)} đã uống lúc ${vnTime(next.lastTakenAt)} giờ VN`, `✅ ${who(next)} took the pill at ${vnTime(next.lastTakenAt)} VN time`);
    if (next.pillsTotal != null) line += t(`, còn ${next.pillsRemaining} viên`, `, ${next.pillsRemaining} pills left`);
    parts.push(line + '.');
  } else if (taken(next) < taken(previous)) {
    // The latest take moved back: an undo, or an edit to an earlier time in History.
    parts.push(t(`↩️ ${who(next)} đã hoàn tác hoặc sửa giờ lần uống gần nhất.`, `↩️ ${who(next)} undid or moved the latest dose.`));
  }
  if (previous && next.lateCount > (previous.lateCount ?? 0)) parts.push(t(`🟡 Có thêm lần uống trễ (tổng ${next.lateCount}).`, `🟡 Another late dose (${next.lateCount} in total).`));
  if (previous && next.missedCount > previous.missedCount) parts.push(t(`🔴 Có thêm viên hụt (tổng ${next.missedCount}).`, `🔴 Another missed pill (${next.missedCount} in total).`));
  if (previous && (next.madeUpCount ?? 0) > (previous.madeUpCount ?? 0)) {
    parts.push(t(`🔵 ${who(next)} đã uống bù viên hụt (còn ${next.missedCount - next.madeUpCount} viên hụt chưa bù).`, `🔵 ${who(next)} made up a missed pill (${next.missedCount - next.madeUpCount} still not made up).`));
  }
  if (next.pausedUntil && next.pausedUntil !== previous?.pausedUntil) {
    parts.push(t(`⏸️ ${who(next)} tạm dừng nhắc tới ${vnTime(next.pausedUntil)} ${vnDay(next.pausedUntil)}.`, `⏸️ ${who(next)} paused reminders until ${vnTime(next.pausedUntil)} ${vnDay(next.pausedUntil)}.`));
  }
  const refill = (s) => s?.pillsTotal != null && s.refillReminder?.enabled && s.pillsRemaining <= s.refillReminder.daysBefore;
  if (refill(next) && !refill(previous)) parts.push(t(`🛒 Còn ${next.pillsRemaining} viên, nhớ mua vỉ mới.`, `🛒 ${next.pillsRemaining} pills left, time to buy a new pack.`));
  return parts.length ? parts.join('\n') : null;
}

const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;

/// Checks the contract in docs/spec.md. Returns the first problem found, or null.
export function validateSnapshot(s) {
  if (!s || typeof s !== 'object') return 'body must be a JSON object';
  if (s.schemaVersion !== 1) return 'schemaVersion must be 1';
  if (s.name != null && (typeof s.name !== 'string' || s.name.length > 60)) return 'name must be a short string or null';
  for (const key of ['updatedAt', 'nextDueAt', 'deadlineAt']) {
    if (typeof s[key] !== 'string' || !ISO.test(s[key])) return `${key} must be a UTC ISO 8601 timestamp`;
  }
  for (const key of ['lastTakenAt', 'pausedUntil']) {
    if (s[key] !== null && (typeof s[key] !== 'string' || !ISO.test(s[key]))) return `${key} must be a timestamp or null`;
  }
  for (const key of ['daysTaken', 'missedCount']) {
    if (!Number.isInteger(s[key]) || s[key] < 0) return `${key} must be a non-negative integer`;
  }
  for (const key of ['lateCount', 'madeUpCount']) {
    if (s[key] !== undefined && (!Number.isInteger(s[key]) || s[key] < 0)) return `${key} must be a non-negative integer`;
  }
  for (const key of ['pillsTotal', 'pillsRemaining']) {
    if (s[key] !== null && (!Number.isInteger(s[key]) || s[key] < 0)) return `${key} must be a non-negative integer or null`;
  }
  const r = s.refillReminder;
  if (!r || typeof r.enabled !== 'boolean' || !Number.isInteger(r.daysBefore)) return 'refillReminder is invalid';
  return null;
}

// MARK: State

export function createStore(dir) {
  mkdirSync(dir, { recursive: true });
  const file = join(dir, 'state.json');
  let state = { snapshot: null, message: null, lastReportDay: null, offset: 0 };
  try {
    state = { ...state, ...JSON.parse(readFileSync(file, 'utf8')) };
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  return {
    get: () => state,
    set(patch) {
      state = { ...state, ...patch };
      // Write a temporary file and rename it, so a half-written file never exists.
      writeFileSync(`${file}.tmp`, JSON.stringify(state, null, 2));
      renameSync(`${file}.tmp`, file);
    },
  };
}

// MARK: HTTP

function sameToken(header, token) {
  const given = Buffer.from(header?.startsWith('Bearer ') ? header.slice(7) : '');
  const expected = Buffer.from(token);
  return given.length === expected.length && timingSafeEqual(given, expected);
}

export function createApp({ store, apiToken, notify = () => {} }) {
  return createServer((req, res) => {
    const send = (status, body) => {
      res.writeHead(status, { 'content-type': 'application/json; charset=utf-8' });
      res.end(JSON.stringify(body));
    };
    const path = new URL(req.url, 'http://local').pathname;
    if (path === '/healthz') return send(200, { ok: true });
    if (path !== '/v1/snapshot') return send(404, { error: 'not found' });
    if (!sameToken(req.headers.authorization, apiToken)) return send(401, { error: 'unauthorized' });

    if (req.method === 'GET') {
      const { snapshot } = store.get();
      return snapshot ? send(200, snapshot) : send(404, { error: 'no snapshot yet' });
    }
    if (req.method !== 'POST') return send(405, { error: 'method not allowed' });

    let body = '';
    req.setEncoding('utf8');
    req.on('data', (chunk) => {
      body += chunk;
      if (body.length > 16 * 1024) req.destroy();
    });
    req.on('end', () => {
      let snapshot;
      try {
        snapshot = JSON.parse(body);
      } catch {
        return send(400, { error: 'invalid JSON' });
      }
      const problem = validateSnapshot(snapshot);
      if (problem) return send(400, { error: problem });
      const { snapshot: previous, message } = store.get();
      // Keep only the newest; older ones (sent late after being offline) are ignored.
      if (previous && Date.parse(snapshot.updatedAt) <= Date.parse(previous.updatedAt)) {
        return send(200, { stale: true, message });
      }
      store.set({ snapshot });
      const text = changeText(previous, snapshot);
      if (text) notify(text);
      send(200, { stale: false, message });
    });
  });
}

// MARK: Telegram bot

export function createBot({ token, chatId, store, publicUrl, apiToken, fetchImpl = fetch }) {
  const call = async (method, params) => {
    const response = await fetchImpl(`https://api.telegram.org/bot${token}/${method}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(params),
    });
    const json = await response.json();
    if (!json.ok) throw new Error(`${method}: ${json.description}`);
    return json.result;
  };
  const say = (text) => call('sendMessage', { chat_id: chatId, text, disable_web_page_preview: true });

  const handle = async (text) => {
    const [command] = text.trim().split(/\s+/);
    const argument = text.trim().slice(command.length).trim();
    switch (command.split('@')[0]) {
      case '/check':
        return say(statusText(store.get().snapshot));
      case '/msg':
        store.set({ message: argument || null });
        return say(argument
          ? t(`Đã lưu lời nhắn, ${who(store.get().snapshot)} thấy ở lần đồng bộ tới:\n${argument}`, `Message saved, shown in the app on the next sync:\n${argument}`)
          : t('Đã xoá lời nhắn.', 'Message cleared.'));
      case '/link':
        return say(t(`Mã kết nối, dán vào Cài đặt > Theo dõi cùng trong app Ner's Daily:\n${publicUrl}#${apiToken}`,
          `Connection code, paste it into Settings > Shared tracking in Ner's Daily:\n${publicUrl}#${apiToken}`));
      default:
        return say(t(['/check: trạng thái mới nhất', '/msg <lời nhắn>: gửi lời nhắn hiện trong app (để trống để xoá)',
          '/link: mã kết nối cho app'].join('\n'), ['/check: latest status', '/msg <text>: message shown in the app (empty to clear)',
          '/link: connection code for the app'].join('\n')));
    }
  };

  const poll = async () => {
    for (;;) {
      try {
        const updates = await call('getUpdates', { offset: store.get().offset, timeout: 50, allowed_updates: ['message'] });
        for (const update of updates) {
          store.set({ offset: update.update_id + 1 });
          const message = update.message;
          // Only answer the configured chat; everyone else is ignored.
          if (message?.text && String(message.chat.id) === String(chatId)) await handle(message.text);
        }
      } catch (error) {
        console.error('poll', error.message);
        await new Promise((r) => setTimeout(r, 5000));
      }
    }
  };

  /// The 09:00 Vietnam time report, once a day even across restarts.
  const dailyReport = async (now = Date.now()) => {
    const vnNow = new Date(now + VN_OFFSET_MS);
    const today = vnDateKey(now);
    if (vnNow.getUTCHours() < 9 || store.get().lastReportDay === today) return;
    store.set({ lastReportDay: today });
    await say(`${t('☀️ Bản tin sáng', '☀️ Morning report')}\n${statusText(store.get().snapshot, now)}`);
  };

  return { say, handle, poll, dailyReport, setCommands: () => call('setMyCommands', { commands: [
    { command: 'check', description: t('Trạng thái mới nhất', 'Latest status') },
    { command: 'msg', description: t('Gửi lời nhắn hiện trong app', 'Send a message shown in the app') },
    { command: 'link', description: t('Mã kết nối cho app', 'Connection code for the app') },
  ] }) };
}

// MARK: Main

if (import.meta.url === `file://${process.argv[1]}`) {
  const env = process.env;
  for (const key of ['API_TOKEN', 'PUBLIC_URL']) {
    if (!env[key]) throw new Error(`missing ${key}`);
  }
  const store = createStore(env.DATA_DIR ?? './data');
  const bot = env.BOT_TOKEN && env.CHAT_ID
    ? createBot({ token: env.BOT_TOKEN, chatId: env.CHAT_ID, store, publicUrl: env.PUBLIC_URL, apiToken: env.API_TOKEN })
    : null;
  const notify = (text) => bot?.say(text).catch((e) => console.error('notify', e.message));
  createApp({ store, apiToken: env.API_TOKEN, notify }).listen(Number(env.PORT ?? 8787), () => {
    console.log(`listening on ${env.PORT ?? 8787}, bot ${bot ? 'on' : 'off (BOT_TOKEN or CHAT_ID missing)'}`);
  });
  if (bot) {
    bot.setCommands().catch((e) => console.error('setMyCommands', e.message));
    bot.poll();
    setInterval(() => bot.dailyReport().catch((e) => console.error('report', e.message)), 60 * 1000);
  }
}
