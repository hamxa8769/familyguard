import { store } from '../../config/store.js';

export function startOfToday() {
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  return d;
}

// Extra minutes granted today via approved "more time" requests.
export function bonusMinutesToday(deviceId) {
  const today = startOfToday().getTime();
  return store.bonusTime
    .filter((b) => b.deviceId === deviceId && new Date(b.day).getTime() === today)
    .reduce((sum, b) => sum + b.minutes, 0);
}
