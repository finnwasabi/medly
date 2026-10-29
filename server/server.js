// Ner's Daily sync service: keeps the latest snapshot from the app and runs a private Telegram bot.
// Plain Node, no dependencies. Every setting comes from environment variables, nothing secret lives in the repo.
import { createServer } from 'node:http';
import { readFileSync, writeFileSync, renameSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { timingSafeEqual } from 'node:crypto';

const VN_OFFSET_MS = 7 * 3600 * 1000;
const WEEKDAYS = ['Chủ Nhật', 'Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy'];

// MARK: Formatting (giờ VN, cố định UTC+7, Việt Nam không có giờ mùa hè)

const pad = (n) => String(n).padStart(2, '0');
const vn = (iso) => new Date(Date.parse(iso) + VN_OFFSET_MS);

export function vnTime(iso) {
  const d = vn(iso);
  return `${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}

export function vnDay(iso) {
  const d = vn(iso);
  return `${WEEKDAYS[d.getUTCDay()]} ${pad(d.getUTCDate())}/${pad(d.getUTCMonth() + 1)}`;
}

export function vnDateKey(ms) {
  const d = new Date(ms + VN_OFFSET_MS);
  return `${d.getUTCFullYear()}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}`;
}

/// Trạng thái đầy đủ cho /check và bản tin 09:00.
export function statusText(snapshot, now = Date.now()) {
  if (!snapshot) return 'Chưa nhận được dữ liệu nào từ app.';
  const s = snapshot;
  const lines = ["💊 Ner's Daily"];
  lines.push(s.lastTakenAt
    ? `Uống gần nhất: ${vnTime(s.lastTakenAt)} giờ VN, ${vnDay(s.lastTakenAt)}`
    : 'Chưa có lần uống nào.');
  if (s.pausedUntil && Date.parse(s.pausedUntil) > now) {
    lines.push(`Đang tạm dừng nhắc tới ${vnTime(s.pausedUntil)} ${vnDay(s.pausedUntil)}.`);
  } else {
    lines.push(`Lần tới: ${vnTime(s.nextDueAt)} giờ VN ${vnDay(s.nextDueAt)}, hạn chót ${vnTime(s.deadlineAt)}.`);
  }
  const madeUp = s.madeUpCount ?? 0;
  lines.push(`Đã uống ${s.daysTaken} ngày, trễ ${s.lateCount ?? 0}, hụt ${s.missedCount - madeUp}`
    + (madeUp ? `, đã uống bù ${madeUp}.` : '.'));
  if (s.pillsTotal != null) {
    const refill = s.refillReminder?.enabled && s.pillsRemaining <= s.refillReminder.daysBefore ? ', cần mua thêm' : '';
    lines.push(`Còn ${s.pillsRemaining}/${s.pillsTotal} viên${refill}.`);
  }
  const age = now - Date.parse(s.updatedAt);
  lines.push(age > 24 * 3600 * 1000
    ? `⚠️ Chưa đồng bộ từ ${vnTime(s.updatedAt)} ${vnDay(s.updatedAt)}.`
    : `Cập nhật lúc ${vnTime(s.updatedAt)} giờ VN.`);
  return lines.join('\n');
}

/// Tin báo ngay khi có dữ liệu mới. Chỉ báo khi có chuyện đáng biết, không báo mỗi lần app mở.
export function changeText(previous, next) {
  const parts = [];
  const taken = (s) => (s?.lastTakenAt ? Date.parse(s.lastTakenAt) : 0);
  if (taken(next) > taken(previous)) {
    let line = `✅ Ner đã uống lúc ${vnTime(next.lastTakenAt)} giờ VN`;
    if (next.pillsTotal != null) line += `, còn ${next.pillsRemaining} viên`;
    parts.push(line + '.');
  } else if (taken(next) < taken(previous)) {
    // Lần uống mới nhất lùi lại: hoàn tác, hoặc sửa giờ sớm hơn trong Lịch sử.
    parts.push('↩️ Ner đã hoàn tác hoặc sửa giờ lần uống gần nhất.');
  }
  if (previous && next.lateCount > (previous.lateCount ?? 0)) parts.push(`🟡 Có thêm lần uống trễ (tổng ${next.lateCount}).`);
  if (previous && next.missedCount > previous.missedCount) parts.push(`🔴 Có thêm viên hụt (tổng ${next.missedCount}).`);
  if (previous && (next.madeUpCount ?? 0) > (previous.madeUpCount ?? 0)) {
    parts.push(`🔵 Ner đã uống bù viên hụt (còn ${next.missedCount - next.madeUpCount} viên hụt chưa bù).`);
  }
  if (next.pausedUntil && next.pausedUntil !== previous?.pausedUntil) {
    parts.push(`⏸️ Ner tạm dừng nhắc tới ${vnTime(next.pausedUntil)} ${vnDay(next.pausedUntil)}.`);
  }
  const refill = (s) => s?.pillsTotal != null && s.refillReminder?.enabled && s.pillsRemaining <= s.refillReminder.daysBefore;
  if (refill(next) && !refill(previous)) parts.push(`🛒 Còn ${next.pillsRemaining} viên, nhớ mua vỉ mới.`);
  return parts.length ? parts.join('\n') : null;
}

const ISO = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/;

/// Kiểm đúng hợp đồng trong docs/spec.md. Trả lỗi đầu tiên tìm thấy, hoặc null.
export function validateSnapshot(s) {
  if (!s || typeof s !== 'object') return 'body must be a JSON object';
  if (s.schemaVersion !== 1) return 'schemaVersion must be 1';
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
      // Ghi file tạm rồi đổi tên để không bao giờ còn file ghi dở.
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
      // Chỉ giữ bản mới nhất; bản cũ hơn (gửi trễ sau khi mất mạng) bị bỏ qua.
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
        return say(argument ? `Đã lưu lời nhắn, Ner thấy ở lần đồng bộ tới:\n${argument}` : 'Đã xoá lời nhắn.');
      case '/link':
        return say(`Mã kết nối, dán vào Cài đặt > Theo dõi cùng trong app của Ner:\n${publicUrl}#${apiToken}`);
      default:
        return say(['/check: trạng thái mới nhất', '/msg <lời nhắn>: gửi lời nhắn hiện trong app (để trống để xoá)',
          '/link: mã kết nối cho app'].join('\n'));
    }
  };

  const poll = async () => {
    for (;;) {
      try {
        const updates = await call('getUpdates', { offset: store.get().offset, timeout: 50, allowed_updates: ['message'] });
        for (const update of updates) {
          store.set({ offset: update.update_id + 1 });
          const message = update.message;
          // Chỉ trả lời đúng chat của Tùng, mọi người khác bị lờ.
          if (message?.text && String(message.chat.id) === String(chatId)) await handle(message.text);
        }
      } catch (error) {
        console.error('poll', error.message);
        await new Promise((r) => setTimeout(r, 5000));
      }
    }
  };

  /// Bản tin 09:00 giờ VN, mỗi ngày một lần kể cả khi tiến trình khởi động lại.
  const dailyReport = async (now = Date.now()) => {
    const vnNow = new Date(now + VN_OFFSET_MS);
    const today = vnDateKey(now);
    if (vnNow.getUTCHours() < 9 || store.get().lastReportDay === today) return;
    store.set({ lastReportDay: today });
    await say(`☀️ Bản tin sáng\n${statusText(store.get().snapshot, now)}`);
  };

  return { say, handle, poll, dailyReport, setCommands: () => call('setMyCommands', { commands: [
    { command: 'check', description: 'Trạng thái mới nhất' },
    { command: 'msg', description: 'Gửi lời nhắn cho Ner' },
    { command: 'link', description: 'Mã kết nối cho app' },
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
