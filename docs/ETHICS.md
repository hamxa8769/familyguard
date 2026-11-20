# Ethical & Legal Considerations

A ready-made chapter for your final-year report. These are also the design
decisions baked into the code.

## 1. Parental control vs. stalkerware

The same technical capability (seeing a device's activity) is legitimate or
abusive depending on **who, consent, and visibility**:

| Legitimate parental control        | Stalkerware / spyware              |
|------------------------------------|------------------------------------|
| Parent ↔ their own minor child     | Any person secretly tracking another |
| Device owned/shared by the parent  | Target's own private device        |
| App is visible; consent is shown   | App is hidden ("stealth mode")     |
| Minimal, relevant data             | Messages, photos, mic, everything  |

This project is deliberately built on the left-hand column.

## 2. Design decisions enforcing this

- **Visible app + persistent "Monitoring: ON" indicator.** No stealth mode.
- **Consent gate.** On the child device, no collector runs until the consent
  notice is accepted (`ConsentService` + `/api/consent`).
- **Data minimisation.** Collects app-usage, location, screen-time, SMS messages,
  contacts, call history, and photo/file listings — each disclosed to the child
  (below). It does **not** capture live camera, and it does **not** listen
  continuously to the microphone (see §2b for the one narrow, consented
  exception: SOS-only short audio, max 30 seconds). v0.7.1 Phase 2 also
  collects: installed-apps inventory, browser-app sessions (which browser,
  when, how long — **never URLs**, see §2c), the family agreement the child
  signed, and reward points/badges. Every new collection is listed on the
  child's "What My Parent Sees" screen and in the consent notice.
- **Transport security.** HTTPS + JWT; child tokens are scoped.
- **Auditability.** Consent is timestamped and stored.

## 2a. Sensitive data: messages & contacts

Reading SMS content, contacts, call history and photos/files is the most invasive
capability in the app, so it carries extra safeguards and real constraints worth
stating in the report (photos are especially sensitive and may contain images of
third parties):

- **Full disclosure, not stealth.** The child app lists SMS and contacts on the
  "What My Parent Sees" screen and in the consent notice. The runtime permission is
  granted in a visible system dialog. This is the line between parental control and
  stalkerware.
- **Third-party privacy.** SMS/contacts include people who messaged the child and
  never consented. This is why the feature is defensible only for a genuine **minor
  child** on a parent-owned device, and why metadata-only is the lighter option.
- **Store policy.** Google Play restricts SMS **and Call-Log** access to default
  handlers, so a parental build that reads them is distributed by **sideloaded
  APK**, not Play.
- **Minimisation still applies.** No photos, camera or continuous microphone
  access (see §2b).

## 2b. Screenshots and SOS-only audio (v0.7.1) — the one narrow exception

Earlier versions of this document said the app "does not capture live
camera or microphone". That is still true for **live camera** and for
**continuous/ambient listening** — those are never built. v0.7.1 adds a
single narrow, consented exception, and only with all of these limits,
enforced in code (see `backend/src/modules/media/`, `docs/ROADMAP.md`):

- **Screenshots:** on-request only. The parent's request creates a
  `remote_commands` row and a `media_captures` row; the child device
  shows a notification and a countdown first, and the child can reject
  the request in the Remote Commands screen.
- **Audio:** SOS-triggered or parent-requested only, **max 30 seconds**
  (enforced by the API and the DB check constraint), with a visible
  on-screen indicator and a sound while recording. The child can see
  every clip in "What My Parent Sees".
- **No continuous listening, no secret screenshots, no live camera.**
  There is no code path that records without a request, and no code
  path that hides a capture from the child.
- **Retention:** captures auto-expire after 7 days (`MEDIA_RETENTION_DAYS`).
- **Consent v2:** these features are listed in the consent notice and the
  transparency screen. A device that consented under v1 must re-confirm
  before any of them runs.
- **Auditability:** every request, capture and deletion is written to
  `audit_log`, which the child can read via `/api/transparency/:deviceId`.

If any of these limits is ever removed, the feature stops being parental
control under §1 and becomes stalkerware — that is a deliberate line in
this project, not an accident of wording.

## 2c. Phase 2 features — screen control, browsing, apps, agreement, rewards, keyword alerts

The same §1 test applies to everything added in v0.7.1 Phase 2. Each item
is disclosed in the consent notice and on "What My Parent Sees", and each
one has a stated OS limit that the code does **not** work around:

- **Screen control (lock now, bedtime, app blocking).** The lock uses the
  device-admin `force-lock` policy only — the admin is activated by the
  user in a visible system screen, and FamilyGuard cannot wipe the
  device, change passwords, or disable the camera/microphone. Bedtime
  and app blocking are enforced by a foreground service with a
  persistent "Monitoring: ON" notification and a visible on-screen
  overlay; the child always sees why an app is blocked. There is no
  Device Owner / kiosk mode, so a determined user can force-stop the
  app — that limit is documented, not bypassed.
- **Browsing history.** Only browser-app sessions: which browser was
  open, when, and for how long. **Visited URLs are never collected** —
  Android does not expose them to third-party apps, and the app does not
  run a VPN or proxy to get them. The consent notice says this plainly.
- **Installed-apps inventory.** App names, package names and versions,
  synced by the child app itself on demand. The child sees the same list.
- **Family agreement.** Rules are proposed by the parent and accepted or
  declined by the child; both sides see the same text and the same
  decision, with the time it was made. A declined agreement stays
  declined until a new one is proposed.
- **Reward system.** Points and badges for healthy habits (for example
  staying inside the screen-time limit). Points are only ever added by
  the parent or by the one automatic rule (screen-time bonus, idempotent
  per child per day); the child can only view them.
- **AI keyword alerts.** This is a **simple keyword list with substring
  matching** on messages the child app already syncs. There is no
  sentiment analysis and no ML model in this release, and the parent
  screen says so — a future model must be added as an explicit,
  disclosed feature, not a silent upgrade. A match creates an alert the
  parent sees; the child is told keyword alerts exist.
- **No continuous listening, no secret screenshots, no live camera,
  no stealth mode** — unchanged from §2b. None of the Phase 2 features
  adds a new capture capability.

- Monitoring a **minor child you are the guardian of** is generally lawful; secret
  monitoring of another adult generally is **not** and may be a criminal offence.
- Data-protection law (e.g. GDPR, and local equivalents) requires lawful basis,
  minimisation, and security — reflected above.
- Cite your own jurisdiction's statutes in the final report.

## 4. Limitations acknowledged

- iOS restricts third-party monitoring by design; the app shows a limited state
  there rather than attempting to bypass OS protections.
- The app does not, and should not, attempt to hide itself or evade removal.
