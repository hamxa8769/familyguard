/// One installed app, from the native PackageManager inventory
/// (Android) or the installed-programs list (Windows).
class InstalledApp {
  const InstalledApp({
    required this.packageName,
    required this.label,
    this.versionName = '',
    this.installedAt,
    this.systemApp = false,
  });

  final String packageName;
  final String label;
  final String versionName;
  final int? installedAt;
  final bool systemApp;

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) => InstalledApp(
        packageName: (map['packageName'] ?? '').toString(),
        label: (map['label'] ?? map['packageName'] ?? '').toString(),
        versionName: (map['versionName'] ?? '').toString(),
        installedAt: map['installedAt'] is int
            ? map['installedAt'] as int
            : int.tryParse((map['installedAt'] ?? '').toString()),
        systemApp: map['systemApp'] == true,
      );
}
