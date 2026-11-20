import { store } from '../config/store.js';

// Push notifications (FCM) — best-effort only.
//
// Design decision: push is a *notification*, never the delivery mechanism.
// The child app polls GET /api/remotecommands?status=pending, so commands
// still arrive when push is not configured, the token is stale, or the
// device is offline. That keeps the feature working without any Firebase
// account, and keeps the backend free of a firebase-admin dependency.
//
// To enable push, set FCM_SERVER_KEY (a Firebase Cloud Messaging server
// key) in .env — see backend/.env.example. No key = push is skipped with a
// log line; nothing fails. APNs is out of scope for this phase (iOS is
// already limited by design — see docs/ETHICS.md).
const FCM_URL = 'https://fcm.googleapis.com/fcm/send';

/**
 * Tell one device its rules changed, so it syncs at once instead of
 * waiting for its next 15-minute poll. Best-effort: no-op (never throws)
 * when push is unconfigured or the device has no token. Same pattern as
 * remotecommands.controller.js — the push is only a nudge; the device
 * fetches the rules themselves by polling.
 * @returns the sendPush result, or { sent: false } when there is no token.
 */
export async function notifyRuleChange(deviceId) {
  try {
    const device = store.devices.find((d) => d.id === deviceId);
    if (!device?.pushToken) return { sent: false, reason: 'no-device-token' };
    return await sendPush({
      token: device.pushToken,
      title: 'FamilyGuard',
      body: 'Your parent updated the rules on this device',
      data: { kind: 'rules-changed', deviceId },
    });
  } catch (err) {
    console.warn('[push] rule-change notification failed:', err.message);
    return { sent: false, reason: 'push-error' };
  }
}

/**
 * Notify the owning parent of an SOS alert.
 *
 * Targeting (no invented scheme): the only push tokens this server stores
 * are device tokens (store.devices[].pushToken, registered via
 * POST /api/devices/:id/push-token). A parent's phone is reachable only if
 * it was registered as a device directly by that parent (registerDevice
 * sets userId + parentId to the parent's id); paired child devices carry
 * parentId but no userId, so they are excluded here. If no such parent
 * device/token exists, this logs and skips — the parent still learns of
 * the SOS by polling GET /api/feed. NOTE: the parent app itself has no FCM
 * wiring yet, so in practice this usually skips until a parent device
 * registers a token; do not treat a skip as an error.
 */
export async function notifyParentOfSos({ deviceId, message }) {
  try {
    const device = store.devices.find((d) => d.id === deviceId);
    const parentId = device?.parentId;
    if (!parentId) {
      console.log('[push] SOS: cannot notify parent — device has no parent.');
      return { sent: false, reason: 'no-parent' };
    }
    // Devices registered directly by the parent (not paired child devices).
    const parentDevices = store.devices.filter(
      (d) =>
        d.id !== deviceId &&
        d.parentId === parentId &&
        d.userId === parentId &&
        d.pushToken,
    );
    if (parentDevices.length === 0) {
      console.log(
        '[push] SOS: no parent device with a push token — parent polls /api/feed instead.',
      );
      return { sent: false, reason: 'no-parent-token' };
    }
    const results = [];
    for (const parentDevice of parentDevices) {
      results.push(
        await sendPush({
          token: parentDevice.pushToken,
          title: 'FamilyGuard SOS',
          body: message || 'Your child triggered an SOS alert',
          data: { kind: 'sos', deviceId },
        }),
      );
    }
    return {
      sent: results.some((r) => r.sent),
      // If nothing was sent, report the real reason (usually
      // 'push-not-configured' when no FCM key is set) instead of a
      // generic error.
      reason: results.some((r) => r.sent)
        ? 'ok'
        : (results[0]?.reason ?? 'fcm-error'),
    };
  } catch (err) {
    console.warn('[push] SOS notification failed:', err.message);
    return { sent: false, reason: 'push-error' };
  }
}

/**
 * Send a push to one device token.
 * @returns {{sent: boolean, reason: string}} — never throws for a missing key.
 */
export async function sendPush({ token, title, body, data = {} }) {
  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey) {
    console.log('[push] FCM_SERVER_KEY not set — skipping push, child polls instead.');
    return { sent: false, reason: 'push-not-configured' };
  }
  // Never send to a missing/invalid token, and never throw for one.
  if (typeof token !== 'string' || !token) {
    return { sent: false, reason: 'no-device-token' };
  }
  try {
    const res = await fetch(FCM_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `key=${serverKey}`,
      },
      body: JSON.stringify({
        to: token,
        notification: { title, body },
        data: Object.fromEntries(
          Object.entries(data).map(([k, v]) => [k, String(v)]),
        ),
        // High priority so lock/SOS commands are not delayed by Doze.
        priority: 'high',
      }),
    });
    if (!res.ok) {
      console.warn(`[push] FCM rejected the message (${res.status})`);
      return { sent: false, reason: `fcm-${res.status}` };
    }
    return { sent: true, reason: 'ok' };
  } catch (err) {
    console.warn('[push] FCM request failed:', err.message);
    return { sent: false, reason: 'fcm-error' };
  }
}
