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
  files: [],            // { deviceId, items: [{name, path, size, date, isImage}] }
  // Phase 1 (foundation for screen control / screenshot / SOS audio).
  remoteCommands: [],   // { id, deviceId, createdBy, type, payload, status, result, createdAt, expiresAt, acknowledgedAt, completedAt }
  mediaCaptures: [],    // { id, deviceId, kind, source, commandId, status, storageRef, sizeBytes, durationSeconds, createdAt, expiresAt, deletedAt }
  auditLog: [],         // { id, deviceId, actorUserId, action, detail, at } — visible to the child
  // Phase 2 (installed apps, browsing sessions, agreement, rewards, keywords).
  installedApps: [],    // { deviceId, packageName, label, versionName, installedAt, systemApp, lastSeenAt }
  browsingSessions: [], // { id, deviceId, packageName, browserLabel, startedAt, endedAt, durationSeconds, syncedAt }
  agreements: [],       // { id, childId, createdBy, rules, status: proposed|accepted|declined, effectiveFrom, createdAt, signedAt, signedNote }
  rewardEvents: [],     // { id, childId, points, reason, badge, date, createdAt } — date is the screen-time date for the daily bonus, null for manual awards
  keywordLists: [],     // { childId, keywords, updatedAt, updatedBy }
};

let counter = 1;
export const nextId = () => String(counter++);
