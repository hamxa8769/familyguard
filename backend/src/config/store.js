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
  smsMessages: [],      // { deviceId, items: [{address, body, date, type, threadId?}] }
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
  thumbnails: [],       // { deviceId, key, mime, file (relative path under uploads/thumbs), at } — photo previews (opt-in); legacy entries may still carry data (base64)
  originals: [],        // { deviceId, key, mime, file (relative path under uploads/originals), sizeBytes, at } — full-res files the child uploaded on parent request
  originalRequests: [], // { deviceId, key, requestedAt } — parent requests waiting for the child's next sync
  timeRequests: [],     // { id, deviceId, minutes, reason, status, at, decidedAt }
  bonusTime: [],        // { deviceId, day, minutes, requestId }
  // Phase 5: jtis of revoked JWTs (see middleware/auth.js). Tokens issued
  // before jtis existed have no jti and are grandfathered — they stay
  // valid until they expire. Pruned to the newest 1000 on insert.
  revokedTokenIds: [],
};

// Small key/value bag persisted with the data (e.g. the generated JWT secret).
store.meta = {};

let counter = 1;
export const nextId = () => String(counter++);
export const getCounter = () => counter;
export const setCounter = (n) => {
  counter = Math.max(counter, Number(n) || 1);
};
