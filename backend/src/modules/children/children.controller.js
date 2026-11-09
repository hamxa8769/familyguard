import { store, nextId } from '../../config/store.js';
import { newPairingCode } from '../pairing/pairing.service.js';

// A child as the parent sees it: profile + paired devices + current pairing code.
function withDevices(child) {
  return {
    ...child,
    devices: store.devices.filter((d) => d.childId === child.id),
  };
}

export async function addChild(req, res, next) {
  try {
    const { displayName, birthYear } = req.body;
    if (!displayName) {
      return res.status(400).json({ error: 'displayName is required' });
    }
    const child = {
      id: nextId(),
      parentId: req.user.id,
      displayName,
      birthYear: birthYear || null,
      pairingCode: newPairingCode(),
      createdAt: new Date().toISOString(),
    };
    store.children.push(child);
    res.status(201).json(withDevices(child));
  } catch (err) {
    next(err);
  }
}

export async function listChildren(req, res, next) {
  try {
    const children = store.children
      .filter((c) => c.parentId === req.user.id)
      .map(withDevices);
    res.json({ children });
  } catch (err) {
    next(err);
  }
}

// Invalidates the old code and issues a new one.
export async function regeneratePairingCode(req, res, next) {
  try {
    const child = store.children.find(
      (c) => c.id === req.params.id && c.parentId === req.user.id
    );
    if (!child) return res.status(404).json({ error: 'Child not found' });
    child.pairingCode = newPairingCode();
    res.json(withDevices(child));
  } catch (err) {
    next(err);
  }
}
