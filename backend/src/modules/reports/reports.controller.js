import { buildDeviceReport } from './reports.service.js';

export async function deviceReport(req, res, next) {
  try {
    res.json(buildDeviceReport(req.params.deviceId));
  } catch (err) {
    next(err);
  }
}
