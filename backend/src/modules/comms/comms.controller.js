import { store } from '../../config/store.js';

function upsert(collection, deviceId, items) {
  const existing = collection.find((c) => c.deviceId === deviceId);
  if (existing) {
    existing.items = items;
  } else {
    collection.push({ deviceId, items });
  }
}

export async function syncComms(req, res, next) {
  try {
    const { contacts, sms, callLog } = req.body;
    if (Array.isArray(contacts)) upsert(store.contacts, req.params.deviceId, contacts);
    if (Array.isArray(sms)) upsert(store.smsMessages, req.params.deviceId, sms);
    if (Array.isArray(callLog)) upsert(store.callLogs, req.params.deviceId, callLog);
    res.status(201).json({
      deviceId: req.params.deviceId,
      contacts: Array.isArray(contacts) ? contacts.length : 0,
      sms: Array.isArray(sms) ? sms.length : 0,
      callLog: Array.isArray(callLog) ? callLog.length : 0,
    });
  } catch (err) {
    next(err);
  }
}

export async function getComms(req, res, next) {
  try {
    const contacts =
      store.contacts.find((c) => c.deviceId === req.params.deviceId)?.items ?? [];
    const sms =
      store.smsMessages.find((c) => c.deviceId === req.params.deviceId)?.items ?? [];
    const callLog =
      store.callLogs.find((c) => c.deviceId === req.params.deviceId)?.items ?? [];
    res.json({ deviceId: req.params.deviceId, contacts, sms, callLog });
  } catch (err) {
    next(err);
  }
}
