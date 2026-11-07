import { store, nextId } from '../../config/store.js';

export async function addEvents(deviceId, events) {
  const normalised = events.map((e) => ({
    id: nextId(),
    deviceId,
    appName: e.appName,
    startedAt: e.startedAt,
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
