import { store, nextId } from '../../config/store.js';

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
      createdAt: new Date().toISOString(),
    };
    store.children.push(child);
    res.status(201).json(child);
  } catch (err) {
    next(err);
  }
}

export async function listChildren(req, res, next) {
  try {
    const children = store.children.filter((c) => c.parentId === req.user.id);
    res.json({ children });
  } catch (err) {
    next(err);
  }
}
