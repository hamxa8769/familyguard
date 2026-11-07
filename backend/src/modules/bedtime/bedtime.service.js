// Returns true if `now` falls inside the bedtime window. Handles windows that
// wrap past midnight (e.g. start 22, end 6).
export function isWithinBedtime(schedule, now) {
  const hour = now.getHours();
  const { startHour, endHour } = schedule;
  if (startHour === endHour) return false;
  if (startHour < endHour) {
    return hour >= startHour && hour < endHour;
  }
  // Wraps midnight.
  return hour >= startHour || hour < endHour;
}
