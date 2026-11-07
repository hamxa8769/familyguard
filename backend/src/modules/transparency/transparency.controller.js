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
      ],
      report,
    });
  } catch (err) {
    next(err);
  }
}
