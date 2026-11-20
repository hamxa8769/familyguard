import { createReadStream, existsSync, mkdirSync, unlinkSync, writeFileSync } from 'node:fs';
import { join, extname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  MAX_SOS_AUDIO_SECONDS,
  createMediaCapture,
  createRemoteCommand,
  getMediaCapture,
  listMediaCaptures,
  logAudit,
  purgeExpiredMedia,
  updateMediaCapture,
} from '../../db/repository.js';
import { store } from '../../config/store.js';
import { parseLimitOffset, pageOf } from '../../middleware/pagination.js';

// Where capture files live on disk (Phase 2). This is local-disk storage
// for the sideload/demo deployment — a production deployment should swap
// it for object storage (S3/GCS) and serve signed URLs instead. Files are
// git-ignored and auto-expire with the capture (MEDIA_RETENTION_DAYS).
const uploadsDir = join(fileURLToPath(new URL('.', import.meta.url)), '..', '..', 'uploads');
const MAX_UPLOAD_BYTES = 8 * 1024 * 1024; // 8 MB: a PNG screenshot or a 30 s AAC clip.
const ALLOWED_MIME = {
  'image/png': '.png',
  'audio/mp4': '.m4a',
  'audio/x-m4a': '.m4a',
  'audio/aac': '.aac',
};

// Media captures: on-request screenshots and SOS-only short audio.
// Hard limits, enforced here and in the schema (duration <= 30s):
//  - NO continuous / ambient listening. Audio is SOS-triggered or
//    parent-requested only, max 30 seconds, with a visible on-screen
//    indicator + sound on the child device.
//  - NO secret screenshots. A screenshot is only taken after a visible
//    notification + countdown on the child device.
//  - Every capture is audit-logged and listed in "What My Parent Sees".
//  - Captures auto-expire after MEDIA_RETENTION_DAYS (default 7).
// Phase 2 adds the file upload (base64 JSON, no new dependency): the child
// native code uploads the PNG / 30 s clip here, and the parent downloads it
// via GET /:id/file.
export async function requestScreenshot(req, res, next) {
  try {
    const { deviceId } = req.body;
    if (!deviceId) return res.status(400).json({ error: 'deviceId is required' });
    const command = await createRemoteCommand({
      deviceId,
      createdBy: req.user.id,
      type: 'request_screenshot',
      payload: {},
    });
    const capture = await createMediaCapture({
      deviceId,
      kind: 'screenshot',
      source: 'parent_request',
      commandId: command.id,
    });
    await logAudit({
      deviceId,
      actorUserId: req.user.id,
      action: 'screenshot:requested',
      detail: { captureId: capture.id, commandId: command.id },
    });
    res.status(201).json({ capture, command });
  } catch (err) {
    next(err);
  }
}

export async function requestAudio(req, res, next) {
  try {
    const { deviceId, source } = req.body;
    if (!deviceId) return res.status(400).json({ error: 'deviceId is required' });
    if (source !== 'sos' && source !== 'parent_request') {
      return res.status(400).json({ error: "source must be 'sos' or 'parent_request'" });
    }
    const command = await createRemoteCommand({
      deviceId,
      createdBy: req.user.id,
      type: 'request_audio',
      payload: { source, maxSeconds: MAX_SOS_AUDIO_SECONDS },
    });
    const capture = await createMediaCapture({
      deviceId,
      kind: 'sos_audio',
      source,
      commandId: command.id,
    });
    await logAudit({
      deviceId,
      actorUserId: req.user.id,
      action: 'audio:requested',
      detail: { captureId: capture.id, commandId: command.id, source },
    });
    res.status(201).json({ capture, command });
  } catch (err) {
    next(err);
  }
}

export async function listCaptures(req, res, next) {
  try {
    const { deviceId } = req.query;
    if (!deviceId) {
      return res.status(400).json({ error: 'deviceId query parameter is required' });
    }
    const captures = await listMediaCaptures(deviceId);
    const { items, total, limit, offset } = pageOf(captures, parseLimitOffset(req));
    res.json({ captures: items, total, limit, offset });
  } catch (err) {
    next(err);
  }
}

export async function getCapture(req, res, next) {
  try {
    const capture = await getMediaCapture(req.params.id);
    if (!capture) return res.status(404).json({ error: 'Capture not found' });
    res.json(capture);
  } catch (err) {
    next(err);
  }
}

// Child reports a capture is done (Phase 2 native code calls this after
// taking the screenshot / recording the clip). The file itself is not
// uploaded here yet — storageRef is filled in by the Phase 2 upload step.
export async function completeCapture(req, res, next) {
  try {
    const { storageRef, sizeBytes, durationSeconds } = req.body;
    if (durationSeconds != null && durationSeconds > MAX_SOS_AUDIO_SECONDS) {
      return res.status(400).json({
        error: `Audio is capped at ${MAX_SOS_AUDIO_SECONDS} seconds`,
      });
    }
    // storageRef is a bare file name under uploads/ — never a path. A
    // caller-supplied '../../etc/passwd' must not escape that directory.
    if (storageRef != null) {
      if (
        typeof storageRef !== 'string' ||
        storageRef === '' ||
        storageRef.includes('/') ||
        storageRef.includes('\\') ||
        storageRef.includes('..')
      ) {
        return res.status(400).json({ error: 'storageRef must be a plain file name' });
      }
    }
    const capture = await getMediaCapture(req.params.id);
    if (!capture) return res.status(404).json({ error: 'Capture not found' });
    if (capture.status !== 'requested') {
      return res.status(409).json({ error: `Capture is already ${capture.status}` });
    }
    const updated = await updateMediaCapture(req.params.id, {
      status: 'captured',
      storageRef,
      sizeBytes,
      durationSeconds,
    });
    await logAudit({
      deviceId: capture.deviceId,
      actorUserId: req.user.id,
      action: `${capture.kind}:captured`,
      detail: { captureId: capture.id },
    });
    res.json(updated);
  } catch (err) {
    next(err);
  }
}

// Child uploads the capture file (base64 JSON). Enforces the 30 s audio
// cap and the 8 MB size cap; stores the file under backend/uploads/ and
// marks the capture captured. The parent downloads it via getFile.
export async function uploadCapture(req, res, next) {
  try {
    const { dataBase64, mimeType, durationSeconds } = req.body;
    if (durationSeconds != null && durationSeconds > MAX_SOS_AUDIO_SECONDS) {
      return res.status(400).json({
        error: `Audio is capped at ${MAX_SOS_AUDIO_SECONDS} seconds`,
      });
    }
    const ext = ALLOWED_MIME[mimeType];
    if (!ext) {
      return res.status(400).json({
        error: `mimeType must be one of: ${Object.keys(ALLOWED_MIME).join(', ')}`,
      });
    }
    if (typeof dataBase64 !== 'string' || dataBase64.length === 0) {
      return res.status(400).json({ error: 'dataBase64 is required' });
    }
    const bytes = Buffer.from(dataBase64, 'base64');
    if (bytes.length === 0 || bytes.length > MAX_UPLOAD_BYTES) {
      return res.status(413).json({ error: `File must be 1 byte to ${MAX_UPLOAD_BYTES} bytes` });
    }
    const capture = await getMediaCapture(req.params.id);
    if (!capture) return res.status(404).json({ error: 'Capture not found' });
    if (capture.status !== 'requested') {
      return res.status(409).json({ error: `Capture is already ${capture.status}` });
    }
    mkdirSync(uploadsDir, { recursive: true });
    const fileName = `${capture.id}${ext}`;
    writeFileSync(join(uploadsDir, fileName), bytes);
    const updated = await updateMediaCapture(req.params.id, {
      status: 'captured',
      storageRef: fileName,
      sizeBytes: bytes.length,
      durationSeconds,
    });
    await logAudit({
      deviceId: capture.deviceId,
      actorUserId: req.user.id,
      action: `${capture.kind}:uploaded`,
      detail: { captureId: capture.id, sizeBytes: bytes.length },
    });
    res.json(updated);
  } catch (err) {
    next(err);
  }
}

// Parent (or the child, for their own transparency log) downloads the file.
export async function getFile(req, res, next) {
  try {
    const capture = await getMediaCapture(req.params.id);
    if (!capture) return res.status(404).json({ error: 'Capture not found' });
    if (capture.status === 'deleted' || capture.status === 'expired' || !capture.storageRef) {
      return res.status(404).json({ error: 'File not available' });
    }
    // Defence in depth: only the file name is ever used, even if a stored
    // storageRef predates the validation in completeCapture.
    const fileName = basename(capture.storageRef);
    const file = join(uploadsDir, fileName);
    if (!existsSync(file)) return res.status(404).json({ error: 'File not found on disk' });
    const mime = extname(file) === '.png' ? 'image/png' : 'audio/mp4';
    res.setHeader('Content-Type', mime);
    res.setHeader('Content-Disposition', `attachment; filename="${fileName}"`);
    createReadStream(file).pipe(res);
  } catch (err) {
    next(err);
  }
}

export async function deleteCapture(req, res, next) {
  try {
    const capture = await getMediaCapture(req.params.id);
    if (!capture) return res.status(404).json({ error: 'Capture not found' });
    const updated = await updateMediaCapture(req.params.id, { status: 'deleted' });
    if (capture.storageRef) {
      try {
        unlinkSync(join(uploadsDir, basename(capture.storageRef)));
      } catch {
        // File already gone (e.g. manual cleanup); the record is deleted anyway.
      }
    }
    await logAudit({
      deviceId: capture.deviceId,
      actorUserId: req.user.id,
      action: `${capture.kind}:deleted`,
      detail: { captureId: capture.id },
    });
    res.json(updated);
  } catch (err) {
    next(err);
  }
}

// Run on a schedule (or on each list call, which already purges): marks
// expired captures so their files can be deleted by the storage layer.
export async function purgeExpired(req, res, next) {
  try {
    const expiredIds = await purgeExpiredMedia();
    res.json({ purged: expiredIds });
  } catch (err) {
    next(err);
  }
}
