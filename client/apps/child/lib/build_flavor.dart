/// Build flavour of the child app.
///
/// The LITE build (`--dart-define=FG_LITE=true`) leaves out SMS, contacts and
/// call-log access entirely: those permissions are not in its manifest and the
/// features are hidden. It is far less likely to be blocked by Google Play
/// Protect. The FULL build includes them.
const bool kLiteBuild = bool.fromEnvironment('FG_LITE');
