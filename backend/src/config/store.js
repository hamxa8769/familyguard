// In-process data store used by every module. It is loaded from and saved to
// disk or PostgreSQL by config/persistence.js, so data survives restarts.
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
  files: [],            // { deviceId, items: [{name, path, size, date, isImage}] }
  thumbnails: [],       // { deviceId, key, mime, data(base64), at } — photo previews (opt-in)
  timeRequests: [],     // { id, deviceId, minutes, reason, status, at, decidedAt }
  bonusTime: [],        // { deviceId, day, minutes, requestId }
};

// Small key/value bag persisted with the data (e.g. the generated JWT secret).
store.meta = {};

let counter = 1;
export const nextId = () => String(counter++);
export const getCounter = () => counter;
export const setCounter = (n) => {
  counter = Math.max(counter, Number(n) || 1);
};
