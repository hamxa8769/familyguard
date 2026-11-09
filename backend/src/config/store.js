// Simple in-memory store so the API runs end-to-end before Postgres is wired up.
// Swap each module's reads/writes to db.js query() when ready for persistence.
export const store = {
  users: [],
  children: [],        // child profiles (multi-child support)
  devices: [],
  consents: [],
  usageEvents: [],
  screenTimeLimits: [], // { deviceId, dailyMinutes }
  blockedApps: [],      // { deviceId, apps: [] }
  locations: [],        // { deviceId, lat, lng, at }
  geofences: [],        // { id, deviceId, name, lat, lng, radiusM }
  geofenceEvents: [],   // { id, geofenceId, deviceId, type: enter|exit, at }
  sosAlerts: [],        // { id, deviceId, message, at, resolved }
  webFilters: [],       // { deviceId, blockedDomains: [] }
  bedtimeSchedules: [], // { deviceId, startHour, endHour }
  contacts: [],         // { deviceId, items: [{name, number}] }
  smsMessages: [],      // { deviceId, items: [{address, body, date, type}] }
  callLogs: [],         // { deviceId, items: [{number, type, date, duration}] }
  files: [],
  timeRequests: [],     // { id, deviceId, minutes, reason, status, at, decidedAt }
  bonusTime: [],        // { deviceId, day, minutes, requestId }            // { deviceId, items: [{name, path, size, date, isImage}] }
};

let counter = 1;
export const nextId = () => String(counter++);
