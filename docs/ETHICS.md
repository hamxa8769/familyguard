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
- **Data minimisation.** Collects app-usage, location, screen-time, SMS messages
  and contacts — each disclosed to the child (below). It does **not** access
  photos, camera or microphone.
- **Transport security.** HTTPS + JWT; child tokens are scoped.
- **Auditability.** Consent is timestamped and stored.

## 2a. Sensitive data: messages & contacts

Reading SMS content and contacts is the most invasive capability in the app, so it
carries extra safeguards and real constraints worth stating in the report:

- **Full disclosure, not stealth.** The child app lists SMS and contacts on the
  "What My Parent Sees" screen and in the consent notice. The runtime permission is
  granted in a visible system dialog. This is the line between parental control and
  stalkerware.
- **Third-party privacy.** SMS/contacts include people who messaged the child and
  never consented. This is why the feature is defensible only for a genuine **minor
  child** on a parent-owned device, and why metadata-only is the lighter option.
- **Store policy.** Google Play restricts SMS/Call-Log access to default handlers,
  so a parental build that reads SMS is distributed by **sideloaded APK**, not Play.
- **Minimisation still applies.** No photos, camera or microphone access.

## 3. Legal context (discuss in your report)

- Monitoring a **minor child you are the guardian of** is generally lawful; secret
  monitoring of another adult generally is **not** and may be a criminal offence.
- Data-protection law (e.g. GDPR, and local equivalents) requires lawful basis,
  minimisation, and security — reflected above.
- Cite your own jurisdiction's statutes in the final report.

## 4. Limitations acknowledged

- iOS restricts third-party monitoring by design; the app shows a limited state
  there rather than attempting to bypass OS protections.
- The app does not, and should not, attempt to hide itself or evade removal.
