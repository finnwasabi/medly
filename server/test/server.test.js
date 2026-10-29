import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp, createBot, createStore, changeText, statusText, validateSnapshot, vnTime } from '../server.js';

// Mẫu đúng như docs/spec.md.
const spec = {
  schemaVersion: 1,
  name: 'Ner',
  updatedAt: '2026-10-27T14:03:00Z',
  lastTakenAt: '2026-10-27T14:03:00Z',
  nextDueAt: '2026-10-28T14:00:00Z',
  deadlineAt: '2026-10-28T14:03:00Z',
  daysTaken: 12,
  missedCount: 1,
  lateCount: 0,
  madeUpCount: 0,
  pillsTotal: 28,
  pillsRemaining: 16,
  refillReminder: { enabled: true, daysBefore: 7 },
  pausedUntil: null,
};

const tempStore = () => createStore(mkdtempSync(join(tmpdir(), 'ners-')));

async function withServer(store, run) {
  const sent = [];
  const server = createApp({ store, apiToken: 'secret-token', notify: (t) => sent.push(t) });
  await new Promise((r) => server.listen(0, r));
  const base = `http://127.0.0.1:${server.address().port}`;
  const request = (method, body, token = 'secret-token') => fetch(`${base}/v1/snapshot`, {
    method,
    headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  try {
    await run(request, sent);
  } finally {
    server.close();
  }
}

test('times are shown in Vietnam time', () => {
  assert.equal(vnTime('2026-10-27T14:03:00Z'), '21:03');
  assert.equal(vnTime('2026-10-27T18:30:00Z'), '01:30');
});

test('spec example is valid, broken ones are not', () => {
  assert.equal(validateSnapshot(spec), null);
  assert.equal(validateSnapshot({ ...spec, lateCount: undefined }), null);
  assert.match(validateSnapshot({ ...spec, updatedAt: '2026-10-27 14:03' }), /updatedAt/);
  assert.match(validateSnapshot({ ...spec, schemaVersion: 2 }), /schemaVersion/);
  assert.match(validateSnapshot({ ...spec, pillsRemaining: -1 }), /pillsRemaining/);
});

test('POST keeps only the newest snapshot and reports stale ones', async () => {
  const store = tempStore();
  await withServer(store, async (request, sent) => {
    assert.equal((await request('GET')).status, 404);
    assert.equal((await request('POST', spec, 'wrong')).status, 401);
    assert.equal((await request('POST', { ...spec, daysTaken: 'x' })).status, 400);

    let res = await request('POST', spec);
    assert.deepEqual(await res.json(), { stale: false, message: null });
    assert.equal(sent.length, 1);
    assert.match(sent[0], /Ner đã uống lúc 21:03 giờ VN, còn 16 viên/);

    res = await request('POST', { ...spec, updatedAt: '2026-10-27T13:00:00Z', daysTaken: 99 });
    assert.equal((await res.json()).stale, true);
    assert.equal((await (await request('GET')).json()).daysTaken, 12);

    // Mở app lại mà không có gì mới: lưu nhưng không nhắn.
    await request('POST', { ...spec, updatedAt: '2026-10-27T15:00:00Z' });
    assert.equal(sent.length, 1);
  });
});

test('message set by the bot comes back on the next sync', async () => {
  const store = tempStore();
  store.set({ message: 'Ngủ sớm nha' });
  await withServer(store, async (request) => {
    assert.deepEqual(await (await request('POST', spec)).json(), { stale: false, message: 'Ngủ sớm nha' });
  });
});

test('change text covers miss, late, pause and refill', () => {
  const next = { ...spec, missedCount: 2, lateCount: 1, pillsRemaining: 7, pausedUntil: '2026-10-30T14:00:00Z' };
  const text = changeText({ ...spec, pillsRemaining: 8 }, next);
  assert.match(text, /hụt \(tổng 2\)/);
  assert.match(text, /trễ \(tổng 1\)/);
  assert.match(text, /tạm dừng nhắc tới 21:00/);
  assert.match(text, /Còn 7 viên, nhớ mua vỉ mới/);
  assert.equal(changeText(spec, { ...spec, updatedAt: '2026-10-27T15:00:00Z' }), null);
});

test('make-up dose is reported and counted apart from missed ones', () => {
  const missed = { ...spec, missedCount: 2, madeUpCount: 0 };
  const madeUp = { ...missed, updatedAt: '2026-10-27T15:00:00Z', madeUpCount: 1 };
  assert.match(changeText(missed, madeUp), /uống bù viên hụt \(còn 1 viên hụt chưa bù\)/);
  assert.match(statusText(madeUp, Date.parse('2026-10-28T01:00:00Z')), /hụt 1, đã uống bù 1\./);
  assert.match(validateSnapshot({ ...spec, madeUpCount: -1 }), /madeUpCount/);
});

test('messages use the name from the app, or a neutral word without one', () => {
  assert.match(changeText(null, { ...spec, name: null }), /^✅ Người ấy đã uống/);
  assert.match(statusText({ ...spec, name: 'Mai' }), /^💊 Mai/);
  assert.match(validateSnapshot({ ...spec, name: 'x'.repeat(61) }), /name/);
});

test('undo is reported as undo, not as a new dose at the older time', () => {
  const undone = { ...spec, updatedAt: '2026-10-27T14:05:00Z', lastTakenAt: '2026-10-26T14:01:00Z' };
  assert.equal(changeText(spec, undone), '↩️ Ner đã hoàn tác hoặc sửa giờ lần uống gần nhất.');
  assert.match(changeText(null, spec), /Ner đã uống lúc 21:03/);
});

test('status text marks data older than 24 hours', () => {
  const fresh = statusText(spec, Date.parse('2026-10-28T01:00:00Z'));
  assert.match(fresh, /Đã uống 12 ngày, trễ 0, hụt 1/);
  assert.match(fresh, /Còn 16\/28 viên\./);
  assert.match(fresh, /Cập nhật lúc 21:03 giờ VN/);
  assert.match(statusText(spec, Date.parse('2026-10-29T01:00:00Z')), /Chưa đồng bộ từ 21:03/);
  assert.equal(statusText(null), 'Chưa nhận được dữ liệu nào từ app.');
});

test('bot answers only its chat and sends the 09:00 report once a day', async () => {
  const store = tempStore();
  store.set({ snapshot: spec });
  const calls = [];
  const fetchImpl = async (url, init) => {
    calls.push({ method: url.split('/').pop(), body: JSON.parse(init.body) });
    return { json: async () => ({ ok: true, result: [] }) };
  };
  const bot = createBot({ token: 't', chatId: '42', store, publicUrl: 'https://x/ners', apiToken: 'secret-token', fetchImpl });

  await bot.handle('/msg Uống thuốc rồi ngủ nha');
  assert.equal(store.get().message, 'Uống thuốc rồi ngủ nha');
  await bot.handle('/link');
  assert.match(calls.at(-1).body.text, /https:\/\/x\/ners#secret-token/);
  assert.equal(calls.at(-1).body.chat_id, '42');

  const before = calls.length;
  await bot.dailyReport(Date.parse('2026-10-28T01:30:00Z')); // 08:30 giờ VN: chưa tới giờ
  assert.equal(calls.length, before);
  await bot.dailyReport(Date.parse('2026-10-28T02:00:00Z')); // 09:00 giờ VN
  await bot.dailyReport(Date.parse('2026-10-28T02:01:00Z'));
  assert.equal(calls.length, before + 1);
  assert.match(calls.at(-1).body.text, /Bản tin sáng/);
});
