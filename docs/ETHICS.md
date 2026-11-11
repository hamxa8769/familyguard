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
  (below). It does **not** capture live camera or microphone.
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
- **Minimisation still applies.** No photos, camera or microphone access.

## 2b. Rules enforced on the phone

Enforcement is built so it can never be mistaken for hidden control:

- **Visible:** a permanent "FamilyGuard is active" notification shows the rule
  state and time left; the web filter shows Android's VPN key icon.
- **Agreed:** the consent notice (v3) lists every rule type; the child must
  accept it again when rules were added. Each permission (usage access,
  display over other apps, VPN) is granted by the child in a system dialog.
- **Never total:** calls, the home screen, Settings and FamilyGuard itself are
  never paused, so the child can always phone someone and see what applies.
- **Two-way:** a paused screen always explains why and links to "Ask for more
  time"; the parent sees whether rules are actually enforced on the device.
- **No accessibility abuse, no anti-uninstall:** FamilyGuard does not use an
  accessibility service, does not hide its icon, and does not block its own
  removal. It is a family tool, not a lock the child can't understand.
- **Web filter privacy:** only domain names are checked, on the phone; nothing
  about browsing is logged or uploaded.

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
