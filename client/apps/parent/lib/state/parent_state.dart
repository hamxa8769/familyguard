import 'package:flutter/foundation.dart';
import 'package:familyguard_core/familyguard_core.dart';

/// The parent's children + which child device the screens are showing.
/// Every device-specific screen reads [selectedDevice].
class ParentState extends ChangeNotifier {
  ParentState._();
  static final ParentState instance = ParentState._();

  ApiClient get api => AuthService.instance.api;

  List<ChildProfile> children = const [];
  String? _selectedDeviceId;
  bool loading = false;
  String? error;

  /// Saved token rejected — the parent must sign in again.
  bool unauthorized = false;

  List<(ChildProfile, DeviceInfo)> get devices => [
        for (final c in children)
          for (final d in c.devices) (c, d),
      ];

  (ChildProfile, DeviceInfo)? get selected {
    for (final pair in devices) {
      if (pair.$2.id == _selectedDeviceId) return pair;
    }
    return devices.isEmpty ? null : devices.first;
  }

  String? get selectedDeviceId => selected?.$2.id;

  String labelFor(String deviceId) {
    for (final (c, d) in devices) {
      if (d.id == deviceId) return '${c.displayName} (${d.deviceName})';
    }
    return 'Device $deviceId';
  }

  void select(String deviceId) {
    _selectedDeviceId = deviceId;
    notifyListeners();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    unauthorized = false;
    notifyListeners();
    try {
      final res = await api.get('/api/children');
      children = (res['children'] as List)
          .map((c) => ChildProfile.fromMap(c as Map))
          .toList();
    } on ApiException catch (e) {
      error = e.message;
      unauthorized = e.isUnauthorized;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<ChildProfile> addChild(String name) async {
    final res = await api.post('/api/children', {'displayName': name});
    final child = ChildProfile.fromMap(res as Map);
    await refresh();
    return child;
  }

  Future<void> newPairingCode(String childId) async {
    await api.post('/api/children/$childId/pairing-code', {});
    await refresh();
  }

  // ---- Per-device report cache (stale-while-revalidate) ----
  final Map<String, Map> _reports = {};
  final Set<String> _reportLoading = {};
  final Map<String, String> _reportErrors = {};

  /// Last report we have for [deviceId] (shown instantly, then refreshed).
  Map? reportFor(String deviceId) => _reports[deviceId];
  bool reportLoading(String deviceId) => _reportLoading.contains(deviceId);
  String? reportError(String deviceId) => _reportErrors[deviceId];

  Future<void> loadReport(String deviceId) async {
    if (_reportLoading.contains(deviceId)) return;
    _reportLoading.add(deviceId);
    notifyListeners();
    try {
      final res = await api.get('/api/reports/$deviceId');
      _reports[deviceId] = res as Map;
      _reportErrors.remove(deviceId);
    } on ApiException catch (e) {
      _reportErrors[deviceId] = e.message;
      if (e.isUnauthorized) unauthorized = true;
    } finally {
      _reportLoading.remove(deviceId);
      notifyListeners();
    }
  }

  void clear() {
    _reports.clear();
    _reportErrors.clear();
    children = const [];
    _selectedDeviceId = null;
    error = null;
    notifyListeners();
  }
}
