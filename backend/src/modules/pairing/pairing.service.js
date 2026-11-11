import crypto from 'node:crypto';
import { store } from '../../config/store.js';

// No 0/O/1/I so codes are easy to read aloud and type.
const ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function newPairingCode() {
  let code;
  do {
    code = Array.from(crypto.randomBytes(6), (b) => ALPHABET[b % ALPHABET.length]).join('');
  } while (store.children.some((c) => c.pairingCode === code));
  return code;
}
