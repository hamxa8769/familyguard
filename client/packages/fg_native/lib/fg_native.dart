/// Native Android collectors for the FamilyGuard child app.
///
/// The Dart side talks to them over these MethodChannels (see the child app's
/// collectors). They live in a plugin — not in MainActivity — so they are also
/// available to the background sync engine.
library fg_native;

const usageChannel = 'familyguard/usage';
const commsChannel = 'familyguard/comms';
const locationChannel = 'familyguard/location';
const filesChannel = 'familyguard/files';
