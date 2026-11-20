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
 * Send a push to one device token.
 * @returns {{sent: boolean, reason: string}} — never throws for a missing key.
 */
export async function sendPush({ token, title, body, data = {} }) {
  const serverKey = process.env.FCM_SERVER_KEY;
  if (!serverKey) {
    console.log('[push] FCM_SERVER_KEY not set — skipping push, child polls instead.');
    return { sent: false, reason: 'push-not-configured' };
  }
  if (!token) return { sent: false, reason: 'no-device-token' };
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
