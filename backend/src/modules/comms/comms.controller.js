import { createHash } from 'node:crypto';
import { store } from '../../config/store.js';
import { logAudit } from '../../db/repository.js';

// Contacts / SMS / call log for one device.
//
// Sync is still replace-all per type (a delta/append sync is remaining
// work — see the Phase 2 report). Only the types present in the request
// body are replaced, so a device that only has SMS permission does not
// wipe the contacts or call log it cannot read.

function upsert(collection, deviceId, items) {
  const existing = collection.find((c) => c.deviceId === deviceId);
  if (existing) {
    existing.items = items;
  } else {
    collection.push({ deviceId, items });
  }
}

/** Normalised number: strip spaces, dashes, brackets and dots; keep a leading +. */
export function normaliseNumber(value) {
  return String(value ?? '').replace(/[\s\-().]/g, '');
}

function itemsOf(collection, deviceId) {
  return collection.find((c) => c.deviceId === deviceId)?.items ?? [];
}

function contactsFor(deviceId) {
  return itemsOf(store.contacts, deviceId);
}

/** Display name for a number, matched on the normalised number. */
function contactNameFor(deviceId, number) {
  const norm = normaliseNumber(number);
  if (!norm) return null;
  const hit = contactsFor(deviceId).find((c) => normaliseNumber(c.number) === norm);
  return hit?.name || null;
}

export async function syncComms(req, res, next) {
  try {
    const { contacts, sms, callLog } = req.body;
    if (Array.isArray(contacts)) upsert(store.contacts, req.params.deviceId, contacts);
    if (Array.isArray(sms)) upsert(store.smsMessages, req.params.deviceId, sms);
    if (Array.isArray(callLog)) upsert(store.callLogs, req.params.deviceId, callLog);
    res.status(201).json({
      deviceId: req.params.deviceId,
      contacts: Array.isArray(contacts) ? contacts.length : 0,
      sms: Array.isArray(sms) ? sms.length : 0,
      callLog: Array.isArray(callLog) ? callLog.length : 0,
    });
  } catch (err) {
    next(err);
  }
}

function parseLimitOffset(req) {
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 200, 1), 500);
  const offset = Math.max(parseInt(req.query.offset, 10) || 0, 0);
  return { limit, offset };
}

export async function getComms(req, res, next) {
  try {
    const deviceId = req.params.deviceId;
    const q = typeof req.query.q === 'string' ? req.query.q.trim().toLowerCase() : '';
    const type = req.query.type !== undefined ? Number(req.query.type) : null;
    const address = typeof req.query.address === 'string' && req.query.address !== ''
      ? normaliseNumber(req.query.address)
      : null;
    const { limit, offset } = parseLimitOffset(req);

    const matchesQ = (...values) =>
      q === '' || values.some((v) => String(v ?? '').toLowerCase().includes(q));

    let contacts = contactsFor(deviceId).filter((c) =>
      matchesQ(c.name, c.number, normaliseNumber(c.number))
    );
    contacts = [...contacts].sort((a, b) =>
      String(a.name ?? '').toLowerCase().localeCompare(String(b.name ?? '').toLowerCase())
    );

    let sms = itemsOf(store.smsMessages, deviceId).filter((m) => {
      if (type !== null && !Number.isNaN(type) && Number(m.type) !== type) return false;
      if (address && normaliseNumber(m.address) !== address) return false;
      return matchesQ(m.body, m.address, normaliseNumber(m.address));
    });
    sms = [...sms].sort((a, b) => (b.date || 0) - (a.date || 0));
    const total = sms.length;
    const page = sms.slice(offset, offset + limit);

    // Call log: filtered, newest first, capped (same limit window as SMS).
    let callLog = itemsOf(store.callLogs, deviceId).filter((c) => {
      if (type !== null && !Number.isNaN(type) && Number(c.type) !== type) return false;
      if (address && normaliseNumber(c.number) !== address) return false;
      return matchesQ(c.number, normaliseNumber(c.number));
    });
    callLog = [...callLog]
      .sort((a, b) => (b.date || 0) - (a.date || 0))
      .slice(0, 500);

    // `total` is the filtered SMS count — the paginated list. Contacts and
    // the call log are returned in full (filtered), capped at 500 calls.
    res.json({ deviceId, total, limit, offset, contacts, sms: page, callLog });
  } catch (err) {
    next(err);
  }
}

// ---- Conversations ---------------------------------------------------------

/** Group key: the SMS thread id when present, else the normalised address. */
function conversationKey(m) {
  if (m.threadId !== undefined && m.threadId !== null && String(m.threadId) !== '') {
    return `t:${m.threadId}`;
  }
  return `a:${normaliseNumber(m.address) || 'unknown'}`;
}

function buildConversations(deviceId) {
  const sms = itemsOf(store.smsMessages, deviceId);
  const groups = new Map();
  for (const m of sms) {
    const key = conversationKey(m);
    let g = groups.get(key);
    if (!g) {
      g = {
        key,
        address: String(m.address ?? ''),
        threadId: m.threadId ?? null,
        contactName: contactNameFor(deviceId, m.address),
        count: 0,
        lastDate: 0,
        lastBody: '',
      };
      groups.set(key, g);
    }
    g.count++;
    if ((m.date || 0) >= g.lastDate) {
      g.lastDate = m.date || 0;
      g.lastBody = String(m.body ?? '');
    }
  }
  return [...groups.values()].sort((a, b) => b.lastDate - a.lastDate);
}

export async function getConversations(req, res, next) {
  try {
    res.json({ deviceId: req.params.deviceId, conversations: buildConversations(req.params.deviceId) });
  } catch (err) {
    next(err);
  }
}

export async function getConversation(req, res, next) {
  try {
    const deviceId = req.params.deviceId;
    const raw = String(req.params.address ?? '');
    // The address segment may be a thread id ("t:12" / "12") or a number.
    const wanted = raw.startsWith('t:')
      ? raw
      : /^\d+$/.test(raw)
        ? `t:${raw}`
        : `a:${normaliseNumber(raw)}`;
    const group = buildConversations(deviceId).find((g) => g.key === wanted);
    if (!group) return res.status(404).json({ error: 'Conversation not found' });
    const messages = itemsOf(store.smsMessages, deviceId)
      .filter((m) => conversationKey(m) === group.key)
      .sort((a, b) => (a.date || 0) - (b.date || 0));
    res.json({
      deviceId,
      key: group.key,
      address: group.address,
      threadId: group.threadId,
      contactName: group.contactName,
      count: messages.length,
      messages,
    });
  } catch (err) {
    next(err);
  }
}

// ---- Export ----------------------------------------------------------------

function csvCell(value) {
  const s = String(value ?? '');
  return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s;
}

function csvRow(cells) {
  return cells.map(csvCell).join(',');
}

function smsTypeLabel(type) {
  return Number(type) === 2 ? 'sent' : 'incoming';
}

function callTypeLabel(type) {
  return { 1: 'incoming', 2: 'outgoing', 3: 'missed' }[Number(type)] ?? 'incoming';
}

function iso(dateMillis) {
  const d = new Date(Number(dateMillis) || 0);
  return Number.isNaN(d.getTime()) ? '' : d.toISOString();
}

const EXPORT_TYPES = new Set(['sms', 'contacts', 'calls', 'all']);
const EXPORT_FORMATS = new Set(['csv', 'json']);

export async function exportComms(req, res, next) {
  try {
    const deviceId = req.params.deviceId;
    const format = String(req.query.format ?? 'csv').toLowerCase();
    const type = String(req.query.type ?? 'all').toLowerCase();
    if (!EXPORT_FORMATS.has(format)) {
      return res.status(400).json({ error: 'format must be csv or json' });
    }
    if (!EXPORT_TYPES.has(type)) {
      return res.status(400).json({ error: 'type must be sms, contacts, calls or all' });
    }
    if (format === 'csv' && type === 'all') {
      return res
        .status(400)
        .json({ error: 'type=all needs format=json; pick one type for csv' });
    }

    const contacts = contactsFor(deviceId);
    const sms = itemsOf(store.smsMessages, deviceId);
    const callLog = itemsOf(store.callLogs, deviceId);
    const counts = { sms: sms.length, contacts: contacts.length, calls: callLog.length };
    const stamp = new Date().toISOString().slice(0, 10);

    await logAudit({
      deviceId,
      actorUserId: req.user.id,
      action: 'comms:export',
      detail: { format, type, ...counts },
    });

    // The retained counts travel with the download (header + JSON meta) so
    // an export is never silently mistaken for the full history.
    res.setHeader('X-Export-Counts', `sms=${counts.sms}; contacts=${counts.contacts}; calls=${counts.calls}`);

    if (format === 'json') {
      const body = {
        deviceId,
        exportedAt: new Date().toISOString(),
        counts,
        note: `Retained on the server at export time: ${counts.sms} SMS, ${counts.contacts} contacts, ${counts.calls} calls. Older messages are lost until delta sync lands (see syncComms).`,
      };
      if (type === 'sms' || type === 'all') body.sms = sms;
      if (type === 'contacts' || type === 'all') body.contacts = contacts;
      if (type === 'calls' || type === 'all') body.callLog = callLog;
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      res.setHeader(
        'Content-Disposition',
        `attachment; filename="familyguard-comms-${deviceId}-${stamp}.json"`
      );
      return res.send(JSON.stringify(body, null, 2));
    }

    // CSV: one type per file, UTF-8 BOM so Excel opens it correctly.
    let csv;
    if (type === 'sms') {
      csv = [
        csvRow(['date_iso', 'address', 'contact_name', 'type', 'body']),
        ...sms.map((m) =>
          csvRow([
            iso(m.date),
            m.address,
            contactNameFor(deviceId, m.address) ?? '',
            smsTypeLabel(m.type),
            m.body,
          ])
        ),
      ].join('\r\n');
    } else if (type === 'contacts') {
      csv = [
        csvRow(['name', 'number']),
        ...contacts.map((c) => csvRow([c.name, c.number])),
      ].join('\r\n');
    } else {
      csv = [
        csvRow(['date_iso', 'number', 'contact_name', 'type', 'duration_seconds']),
        ...callLog.map((c) =>
          csvRow([
            iso(c.date),
            c.number,
            contactNameFor(deviceId, c.number) ?? '',
            callTypeLabel(c.type),
            c.duration ?? 0,
          ])
        ),
      ].join('\r\n');
    }
    res.setHeader('Content-Type', 'text/csv; charset=utf-8');
    res.setHeader(
      'Content-Disposition',
      `attachment; filename="familyguard-comms-${deviceId}-${stamp}-${type}.csv"`
    );
    return res.send(`\ufeff${csv}\r\n`);
  } catch (err) {
    next(err);
  }
}

/** Dedupe key used by a future delta sync: (address, date, type, body-hash). */
export function smsDedupeKey(m) {
  const hash = createHash('sha256').update(String(m.body ?? '')).digest('hex').slice(0, 12);
  return `${normaliseNumber(m.address)}|${m.date}|${m.type}|${hash}`;
}
