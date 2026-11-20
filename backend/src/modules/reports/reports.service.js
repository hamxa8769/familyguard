import { store } from '../../config/store.js';
import { summarise } from '../usage/usage.service.js';
import { isWithinBedtime } from '../bedtime/bedtime.service.js';
import { bonusMinutesToday } from '../screentime/screentime.service.js';
import { listAudit } from '../../db/repository.js';

// Pulls together one device's data into a single parent-facing report.
// Async since v0.9.1: the report now includes the audit log (Phase 5),
// which reads from Postgres when DATABASE_URL is set.
export async function buildDeviceReport(deviceId) {
  const usage = summariseSync(deviceId);
  const limit = store.screenTimeLimits.find((l) => l.deviceId === deviceId) || null;
  const location = store.locations.filter((p) => p.deviceId === deviceId).at(-1) || null;
  const geofenceEvents = store.geofenceEvents.filter((e) => e.deviceId === deviceId).slice(-10);
  const sos = store.sosAlerts.filter((a) => a.deviceId === deviceId && !a.resolved);
  const bedtime = store.bedtimeSchedules.find((b) => b.deviceId === deviceId) || null;
  const blocked = store.blockedApps.find((b) => b.deviceId === deviceId)?.apps ?? [];
  // The transparency screen promises "every command is listed in the
  // audit log below" — the log is part of the report now, newest first.
  const auditLog = await listAudit(deviceId, 100);

  return {
    deviceId,
    generatedAt: new Date().toISOString(),
    usage,
    screenTime: {
      dailyMinutes:
        limit?.dailyMinutes != null ? limit.dailyMinutes + bonusMinutesToday(deviceId) : null,
      bonusMinutes: bonusMinutesToday(deviceId),
      consumedMinutes: Math.round(usage.totalSeconds / 60),
    },
    lastLocation: location,
    recentGeofenceEvents: geofenceEvents,
    activeSosAlerts: sos,
    bedtime: bedtime
      ? { ...bedtime, lockedNow: isWithinBedtime(bedtime, new Date()) }
      : null,
    blockedApps: blocked,
    pendingTimeRequests: store.timeRequests.filter(
      (r) => r.deviceId === deviceId && r.status === 'pending'
    ),
    auditLog,
  };
}

// Today's usage only (the report is a daily summary).
function summariseSync(deviceId) {
  const startOfDay = new Date();
  startOfDay.setHours(0, 0, 0, 0);
  const events = store.usageEvents.filter(
    (e) => e.deviceId === deviceId && new Date(e.startedAt) >= startOfDay
  );
  const byApp = {};
  let totalSeconds = 0;
  for (const e of events) {
    byApp[e.appName] = (byApp[e.appName] || 0) + e.durationSeconds;
    totalSeconds += e.durationSeconds;
  }
  const apps = Object.entries(byApp)
    .map(([appName, seconds]) => ({ appName, totalSeconds: seconds }))
    .sort((a, b) => b.totalSeconds - a.totalSeconds);
  return { totalEvents: events.length, totalSeconds, apps };
}

export { summarise };
