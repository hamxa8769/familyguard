// Persistence layer for the Phase 1 modules (remote commands, media
// captures, audit log).
//
// Pattern for migrating the whole backend off the in-memory store:
// every new module goes through here. When DATABASE_URL is set, reads and
// writes go to Postgres (see db/migrations/001_init.sql). When it is not
// set, the same functions use the in-memory store in config/store.js, so
// the API still runs end-to-end for local development and demos.
// Older modules still use the store directly; migrating them one at a time
// is tracked in docs/ROADMAP.md.
//
// REMAINING WORK — Postgres split-brain (Phase 5, item 18b; deliberately
// NOT migrated in this round): only remotecommands + media (+ audit) use
// normalised tables here. The other ~24 modules read/write `store`
// directly, and in Postgres mode the JSONB `fg_state` snapshot in
// config/persistence.js is a second copy of the same data, so
// store.remoteCommands / store.mediaCaptures stay empty while the tables
// hold the truth. A full migration would need: move every module to this
// repository (or a per-module repository with the same isPostgres() dual
// path), replace the in-process nextId() counter with DB sequences /
// UUIDs (two server instances currently issue colliding sequential IDs),
// and either drop the fg_state JSONB snapshot or keep it only for the
// modules not yet migrated. See docs/API.md § "Remaining work".
import { unlinkSync } from 'node:fs';
import { basename, dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { pool, query } from '../config/db.js';
import { store, nextId } from '../config/store.js';

// Capture files on disk (backend/src/uploads/<id>.png|.m4a). Only the
// file name is ever used — a stored storageRef is basenamed first, so a
// crafted ref cannot escape the directory.
const uploadsDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'uploads');

function deleteCaptureFile(storageRef) {
  if (!storageRef) return;
  try {
    unlinkSync(join(uploadsDir, basename(storageRef)));
  } catch {
    // Already gone (manual cleanup, or the file was never written).
  }
}

export const isPostgres = () => pool !== null;

const nowIso = () => new Date().toISOString();

// --- Audit log (also visible to the child via /api/transparency) --------

export async function logAudit({ deviceId, actorUserId, action, detail = {} }) {
  const entry = {
    id: nextId(),
    deviceId,
    actorUserId: actorUserId ?? null,
    action,
    detail,
    at: nowIso(),
  };
  if (isPostgres()) {
    await query(
      `INSERT INTO audit_log (id, device_id, actor_user_id, action, detail, at)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [entry.id, deviceId, entry.actorUserId, action, JSON.stringify(detail), entry.at],
    );
  } else {
    store.auditLog.push(entry);
  }
  return entry;
}

export async function listAudit(deviceId, limit = 100) {
  if (isPostgres()) {
    const { rows } = await query(
      `SELECT id, device_id AS "deviceId", actor_user_id AS "actorUserId",
              action, detail, at FROM audit_log
       WHERE device_id = $1 ORDER BY at DESC LIMIT $2`,
      [deviceId, limit],
    );
    return rows;
  }
  return store.auditLog
    .filter((e) => e.deviceId === deviceId)
    .slice(-limit)
    .reverse();
}

// --- Remote commands ------------------------------------------------------

export const COMMAND_TYPES = [
  'lock_now',
  'unlock',
  'send_message',
  'request_screenshot',
  'request_audio',
];

export const COMMAND_TTL_MINUTES = Number(process.env.COMMAND_TTL_MINUTES ?? 60);

function commandFromRow(row) {
  return {
    id: row.id,
    deviceId: row.device_id,
    createdBy: row.created_by,
    type: row.type,
    payload: row.payload,
    status: row.status,
    result: row.result,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    acknowledgedAt: row.acknowledged_at,
    completedAt: row.completed_at,
  };
}

export async function createRemoteCommand({ deviceId, createdBy, type, payload = {} }) {
  const expiresAt = new Date(Date.now() + COMMAND_TTL_MINUTES * 60_000).toISOString();
  if (isPostgres()) {
    const id = nextId();
    const { rows } = await query(
      `INSERT INTO remote_commands
         (id, device_id, created_by, type, payload, status, created_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, 'pending', now(), $6) RETURNING *`,
      [id, deviceId, createdBy, type, JSON.stringify(payload), expiresAt],
    );
    return commandFromRow(rows[0]);
  }
  const command = {
    id: nextId(),
    deviceId,
    createdBy,
    type,
    payload,
    status: 'pending',
    result: null,
    createdAt: nowIso(),
    expiresAt,
    acknowledgedAt: null,
    completedAt: null,
  };
  store.remoteCommands.push(command);
  return command;
}

export async function expireStaleCommands() {
  const now = new Date().toISOString();
  if (isPostgres()) {
    await query(
      `UPDATE remote_commands SET status = 'expired'
       WHERE status = 'pending' AND expires_at < $1`,
      [now],
    );
    return;
  }
  for (const c of store.remoteCommands) {
    if (c.status === 'pending' && c.expiresAt < now) c.status = 'expired';
  }
}

export async function listRemoteCommands({ deviceId, status, createdBy }) {
  await expireStaleCommands();
  if (isPostgres()) {
    const conditions = ['device_id = $1'];
    const params = [deviceId];
    if (status) {
      params.push(status);
      conditions.push(`status = $${params.length}`);
    }
    if (createdBy) {
      params.push(createdBy);
      conditions.push(`created_by = $${params.length}`);
    }
    const { rows } = await query(
      `SELECT * FROM remote_commands WHERE ${conditions.join(' AND ')}
       ORDER BY created_at DESC LIMIT 100`,
      params,
    );
    return rows.map(commandFromRow);
  }
  return store.remoteCommands
    .filter(
      (c) =>
        c.deviceId === deviceId &&
        (!status || c.status === status) &&
        (!createdBy || c.createdBy === createdBy),
    )
    .slice()
    .reverse();
}

export async function getRemoteCommand(id) {
  if (isPostgres()) {
    const { rows } = await query('SELECT * FROM remote_commands WHERE id = $1', [id]);
    return rows[0] ? commandFromRow(rows[0]) : null;
  }
  return store.remoteCommands.find((c) => c.id === id) ?? null;
}

export async function updateRemoteCommand(id, { status, result }) {
  if (isPostgres()) {
    const sets = [];
    const params = [id];
    if (status) {
      params.push(status);
      sets.push(`status = $${params.length}`);
      if (status === 'acknowledged') sets.push('acknowledged_at = now()');
      if (status === 'completed') sets.push('completed_at = now()');
    }
    if (result !== undefined) {
      params.push(JSON.stringify(result));
      sets.push(`result = $${params.length}`);
    }
    if (sets.length === 0) return getRemoteCommand(id);
    const { rows } = await query(
      `UPDATE remote_commands SET ${sets.join(', ')} WHERE id = $1 RETURNING *`,
      params,
    );
    return rows[0] ? commandFromRow(rows[0]) : null;
  }
  const command = store.remoteCommands.find((c) => c.id === id);
  if (!command) return null;
  if (status) {
    command.status = status;
    if (status === 'acknowledged') command.acknowledgedAt = nowIso();
    if (status === 'completed') command.completedAt = nowIso();
  }
  if (result !== undefined) command.result = result;
  return command;
}

// --- Media captures (metadata only in Phase 1) ----------------------------

export const MEDIA_RETENTION_DAYS = Number(process.env.MEDIA_RETENTION_DAYS ?? 7);
export const MAX_SOS_AUDIO_SECONDS = 30;

function mediaFromRow(row) {
  return {
    id: row.id,
    deviceId: row.device_id,
    kind: row.kind,
    source: row.source,
    commandId: row.command_id,
    status: row.status,
    storageRef: row.storage_ref,
    sizeBytes: row.size_bytes == null ? null : Number(row.size_bytes),
    durationSeconds: row.duration_seconds,
    createdAt: row.created_at,
    expiresAt: row.expires_at,
    deletedAt: row.deleted_at,
  };
}

export async function createMediaCapture({ deviceId, kind, source, commandId }) {
  const expiresAt = new Date(
    Date.now() + MEDIA_RETENTION_DAYS * 24 * 60 * 60_000,
  ).toISOString();
  if (isPostgres()) {
    const id = nextId();
    const { rows } = await query(
      `INSERT INTO media_captures
         (id, device_id, kind, source, command_id, status, created_at, expires_at)
       VALUES ($1, $2, $3, $4, $5, 'requested', now(), $6) RETURNING *`,
      [id, deviceId, kind, source, commandId ?? null, expiresAt],
    );
    return mediaFromRow(rows[0]);
  }
  const capture = {
    id: nextId(),
    deviceId,
    kind,
    source,
    commandId: commandId ?? null,
    status: 'requested',
    storageRef: null,
    sizeBytes: null,
    durationSeconds: null,
    createdAt: nowIso(),
    expiresAt,
    deletedAt: null,
  };
  store.mediaCaptures.push(capture);
  return capture;
}

export async function purgeExpiredMedia() {
  const now = new Date().toISOString();
  if (isPostgres()) {
    // RETURNING the refs so the disk files can be unlinked too — flipping
    // the status alone leaked the bytes on disk (audit §6/§9.9).
    const { rows } = await query(
      `UPDATE media_captures SET status = 'expired'
       WHERE status IN ('requested', 'captured', 'delivered')
         AND expires_at < $1 RETURNING id, storage_ref`,
      [now],
    );
    for (const r of rows) deleteCaptureFile(r.storage_ref);
    return rows.map((r) => r.id);
  }
  const expired = store.mediaCaptures.filter(
    (m) => ['requested', 'captured', 'delivered'].includes(m.status) && m.expiresAt < now,
  );
  for (const m of expired) {
    m.status = 'expired';
    deleteCaptureFile(m.storageRef);
  }
  return expired.map((m) => m.id);
}

export async function listMediaCaptures(deviceId) {
  await purgeExpiredMedia();
  if (isPostgres()) {
    const { rows } = await query(
      `SELECT * FROM media_captures WHERE device_id = $1 ORDER BY created_at DESC LIMIT 100`,
      [deviceId],
    );
    return rows.map(mediaFromRow);
  }
  return store.mediaCaptures
    .filter((m) => m.deviceId === deviceId)
    .slice()
    .reverse();
}

export async function getMediaCapture(id) {
  if (isPostgres()) {
    const { rows } = await query('SELECT * FROM media_captures WHERE id = $1', [id]);
    return rows[0] ? mediaFromRow(rows[0]) : null;
  }
  return store.mediaCaptures.find((m) => m.id === id) ?? null;
}

export async function updateMediaCapture(id, { status, storageRef, sizeBytes, durationSeconds }) {
  if (durationSeconds != null && durationSeconds > MAX_SOS_AUDIO_SECONDS) {
    throw new Error(`Audio is capped at ${MAX_SOS_AUDIO_SECONDS} seconds`);
  }
  if (isPostgres()) {
    const sets = [];
    const params = [id];
    if (status) {
      params.push(status);
      sets.push(`status = $${params.length}`);
      if (status === 'deleted') sets.push('deleted_at = now()');
    }
    if (storageRef !== undefined) {
      params.push(storageRef);
      sets.push(`storage_ref = $${params.length}`);
    }
    if (sizeBytes !== undefined) {
      params.push(sizeBytes);
      sets.push(`size_bytes = $${params.length}`);
    }
    if (durationSeconds !== undefined) {
      params.push(durationSeconds);
      sets.push(`duration_seconds = $${params.length}`);
    }
    if (sets.length === 0) return getMediaCapture(id);
    const { rows } = await query(
      `UPDATE media_captures SET ${sets.join(', ')} WHERE id = $1 RETURNING *`,
      params,
    );
    return rows[0] ? mediaFromRow(rows[0]) : null;
  }
  const capture = store.mediaCaptures.find((m) => m.id === id);
  if (!capture) return null;
  if (status) {
    capture.status = status;
    if (status === 'deleted') capture.deletedAt = nowIso();
  }
  if (storageRef !== undefined) capture.storageRef = storageRef;
  if (sizeBytes !== undefined) capture.sizeBytes = sizeBytes;
  if (durationSeconds !== undefined) capture.durationSeconds = durationSeconds;
  return capture;
}
