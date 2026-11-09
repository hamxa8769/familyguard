import { store, nextId } from '../../config/store.js';

// snapshot: the device sends cumulative totals for today (Android
// UsageStatsManager), so replace today's rows rather than double-counting.
export async function addEvents(deviceId, events, { snapshot = false } = {}) {
  if (snapshot) {
    const startOfDay = new Date();
    startOfDay.setHours(0, 0, 0, 0);
    store.usageEvents = store.usageEvents.filter(
      (e) => e.deviceId !== deviceId || new Date(e.startedAt) < startOfDay
    );
  }
  const normalised = events.map((e) => ({
    id: nextId(),
    deviceId,
    appName: e.appName,
    startedAt: e.startedAt || new Date().toISOString(),
    durationSeconds: Number(e.durationSeconds) || 0,
  }));
  store.usageEvents.push(...normalised);
  return normalised.length;
}

// Aggregates total seconds per app for a device.
export async function summarise(deviceId) {
  const events = store.usageEvents.filter((e) => e.deviceId === deviceId);
  const byApp = {};
  for (const e of events) {
    byApp[e.appName] = (byApp[e.appName] || 0) + e.durationSeconds;
  }
  const apps = Object.entries(byApp)
    .map(([appName, totalSeconds]) => ({ appName, totalSeconds }))
    .sort((a, b) => b.totalSeconds - a.totalSeconds);
  return { deviceId, totalEvents: events.length, apps };
}
