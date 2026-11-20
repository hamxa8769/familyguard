import { buildDeviceReport } from '../reports/reports.service.js';

// Returns the same data a parent sees, plus a plain-language list of what is
// being collected — shown to the child so monitoring is never hidden.
export async function whatParentSees(req, res, next) {
  try {
    const report = buildDeviceReport(req.params.deviceId);
    res.json({
      notice: 'This is exactly what your parent/guardian can see about this device.',
      collected: [
        'Which apps are used and for how long',
        'This device\'s location and location history',
        'Screen-time usage against the daily limit',
        'Geofence enter/exit events',
        'SOS alerts you trigger',
        'Remote commands from your parent (lock now, unlock, messages) — every command is listed in the audit log below',
        'Screenshots taken only after a notification and countdown on this device (never secret)',
        'Short audio clips (max 30 seconds) only when you press SOS or after a visible request — never continuous listening',
        'Your SMS messages (sender, text and time)',
        'Your contacts (names and numbers)',
        'Your call history (number, type, time, duration)',
        'Your photos and files (name, album, size, date)',
        ...(req.device?.photoPreviews
          ? ['Small previews of your newest 100 photos (your parent turned this on)']
          : []),
      ],
      photoPreviews: req.device?.photoPreviews === true,
      report,
    });
  } catch (err) {
    next(err);
  }
}
