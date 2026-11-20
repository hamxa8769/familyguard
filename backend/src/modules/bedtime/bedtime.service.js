// Returns true if `now` falls inside the bedtime window. Handles windows that
// wrap past midnight (e.g. start 22:30, end 6:00). Minute-granular: a 22:30
// bedtime does not lock at 22:00. Minutes default to 0 for schedules saved
// before they existed.
export function isWithinBedtime(schedule, now) {
  const start = (schedule.startHour ?? 0) * 60 + (schedule.startMinute ?? 0);
  const end = (schedule.endHour ?? 0) * 60 + (schedule.endMinute ?? 0);
  if (start === end) return false;
  const at = now.getHours() * 60 + now.getMinutes();
  if (start < end) {
    return at >= start && at < end;
  }
  // Wraps midnight.
  return at >= start || at < end;
}
