import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../../services/native_collectors.dart';

/// Child side of remote commands: the app polls
/// `GET /api/remotecommands?deviceId=…&status=pending` every 30 seconds
/// (push is a notification only — polling is the delivery contract).
///
/// What happens for each command (all visible to the child, nothing silent):
///  - lock_now: the child taps "Lock now" — the device locks via the
///    device admin, which the user activated in a visible system screen.
///    Without the admin the button explains that instead.
///  - unlock: stops the block watcher (lifts a bedtime/app-block overlay)
///    and reports completed. Android has no remote-unlock API; the screen
///    is already unlocked when the child uses the device.
///  - send_message: shown as a banner; "Mark as read" acknowledges it.
///  - request_screenshot: Accept starts a visible countdown, then
///    Android's own screen-capture dialog. The child can deny it there —
///    the request is then reported as rejected. The PNG is uploaded to
///    the capture the parent created for this command.
///  - request_audio: Accept starts a max-30-second recording with a
///    persistent notification, an on-screen indicator and a beep at
///    start/stop. The clip is uploaded the same way.
///
/// Each poll also syncs the parent-set app-blocking + bedtime rules into
/// the native block watcher (see EnforcementSync).
///
/// Wiring note: the app has no device-registration/login flow yet, so
/// [deviceId] is passed in from main.dart and is empty until that lands
/// (see the "device not registered yet" state below). The polling and
/// acknowledge logic itself is real and matches the backend contract.
class RemoteCommandsScreen extends StatefulWidget {
  const RemoteCommandsScreen({super.key, required this.deviceId});

  final String deviceId;

  @override
  State<RemoteCommandsScreen> createState() => _RemoteCommandsScreenState();
}

class _RemoteCommandsScreenState extends State<RemoteCommandsScreen> {
  final _api = ApiClient();
  Timer? _timer;
  List<RemoteCommand> _pending = [];
  String? _error;
  bool _loading = true;
  String? _busyCommandId;

  @override
  void initState() {
    super.initState();
    if (widget.deviceId.isNotEmpty) {
      _poll();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _poll());
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _poll() async {
    try {
      final data = await _api.get(
        '/api/remotecommands?deviceId=${widget.deviceId}&status=pending',
      );
      final commands = (data['commands'] as List? ?? [])
          .map((c) => RemoteCommand.fromMap(c as Map))
          .toList();
      if (mounted) {
        setState(() {
          _pending = commands;
          _error = null;
          _loading = false;
        });
      }
      // Best-effort rule sync; EnforcementSync never throws.
      await EnforcementSync.sync(_api, widget.deviceId);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _ack(RemoteCommand command, String status) async {
    try {
      await _api.post('/api/remotecommands/${command.id}/ack', {'status': status});
      await _poll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Command $status')),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update command: ${e.message}')),
        );
      }
    }
  }

  void _snack(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _handleLock(RemoteCommand command) async {
    setState(() => _busyCommandId = command.id);
    try {
      final active = await NativeCollectors.isAdminActive();
      if (!active) {
        _snack('Device admin is not activated — tap "Activate device admin" first.');
        return;
      }
      await NativeCollectors.lockNow();
      await _ack(command, 'completed');
    } on PlatformException catch (e) {
      _snack('Could not lock: ${e.message}');
    } finally {
      if (mounted) setState(() => _busyCommandId = null);
    }
  }

  Future<void> _handleUnlock(RemoteCommand command) async {
    await NativeCollectors.stopWatcher();
    await _ack(command, 'completed');
  }

  /// Finds the media capture the parent created for this command, uploads
  /// the file the native service produced, and completes the command.
  Future<void> _uploadCaptureResult(
    RemoteCommand command,
    Map<String, dynamic> result,
    String mimeType,
    int? durationSeconds,
  ) async {
    final path = result['path'] as String?;
    if (path == null) {
      await _ack(command, 'rejected');
      return;
    }
    try {
      final data = await _api.get('/api/media?deviceId=${widget.deviceId}');
      final captures = (data['captures'] as List? ?? [])
          .where((c) => (c as Map)['commandId'] == command.id)
          .toList();
      if (captures.isEmpty) {
        _snack('No capture was created for this command on the server.');
        return;
      }
      final captureId = (captures.first as Map)['id'].toString();
      await NativeCollectors.uploadCapture(
        api: _api,
        captureId: captureId,
        filePath: path,
        mimeType: mimeType,
        durationSeconds: durationSeconds,
      );
      await _ack(command, 'completed');
    } on ApiException catch (e) {
      _snack('Upload failed: ${e.message}');
    }
  }

  /// Polls the native capture-result file until it appears or times out.
  Future<Map<String, dynamic>?> _waitForCaptureResult(
    String commandId, {
    required Duration timeout,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final result = await NativeCollectors.getCaptureResult();
      if (result != null && result['commandId'] == commandId) return result;
      await Future.delayed(const Duration(seconds: 2));
    }
    return null;
  }

  Future<void> _handleScreenshot(RemoteCommand command) async {
    setState(() => _busyCommandId = command.id);
    try {
      await _ack(command, 'acknowledged');
      await NativeCollectors.requestScreenshot(commandId: command.id);
      final result = await _waitForCaptureResult(
        command.id,
        timeout: const Duration(seconds: 90),
      );
      if (result == null) {
        _snack('Screenshot timed out — the request stays acknowledged.');
        return;
      }
      if (result['error'] != null) {
        _snack('Screenshot was not taken (${result['error']}).');
        await _ack(command, 'rejected');
        return;
      }
      await _uploadCaptureResult(command, result, 'image/png', null);
    } on PlatformException catch (e) {
      _snack('Screenshot failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _busyCommandId = null);
    }
  }

  Future<void> _handleAudio(RemoteCommand command) async {
    setState(() => _busyCommandId = command.id);
    try {
      if (!await NativeCollectors.hasAudioPermission()) {
        await NativeCollectors.requestAudioPermission();
        _snack('Microphone permission was requested — accept it, then tap Accept again.');
        return;
      }
      await _ack(command, 'acknowledged');
      final startedAt = DateTime.now();
      await NativeCollectors.startSosAudio(commandId: command.id);
      final result = await _waitForCaptureResult(
        command.id,
        timeout: const Duration(seconds: 45),
      );
      if (result == null) {
        _snack('Audio recording timed out — the request stays acknowledged.');
        return;
      }
      if (result['error'] != null) {
        _snack('Audio was not recorded (${result['error']}).');
        await _ack(command, 'rejected');
        return;
      }
      final duration = DateTime.now().difference(startedAt).inSeconds.clamp(0, 30);
      await _uploadCaptureResult(command, result, 'audio/mp4', duration);
    } on PlatformException catch (e) {
      _snack('Audio failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _busyCommandId = null);
    }
  }

  String _label(RemoteCommand command) {
    switch (command.type) {
      case 'lock_now':
        return 'Your parent locked this device';
      case 'unlock':
        return 'Your parent unlocked this device';
      case 'send_message':
        return 'Message from your parent: ${command.payload['text'] ?? ''}';
      case 'request_screenshot':
        return 'Your parent requested a screenshot — you will see a countdown first';
      case 'request_audio':
        return 'Your parent requested a short audio clip (max 30 seconds)';
      default:
        return 'Command from your parent: ${command.type}';
    }
  }

  Widget _actionsFor(RemoteCommand command) {
    final busy = _busyCommandId == command.id;
    if (busy) return const LinearProgressIndicator();
    switch (command.type) {
      case 'lock_now':
        return Row(
          children: [
            FilledButton(
              onPressed: () => _handleLock(command),
              child: const Text('Lock now'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                await NativeCollectors.requestAdmin();
                _snack('Activate FamilyGuard in the device-admin screen that opened.');
              },
              child: const Text('Activate device admin'),
            ),
          ],
        );
      case 'unlock':
        return FilledButton(
          onPressed: () => _handleUnlock(command),
          child: const Text('Acknowledge unlock'),
        );
      case 'send_message':
        return OutlinedButton(
          onPressed: () => _ack(command, 'acknowledged'),
          child: const Text('Mark as read'),
        );
      case 'request_screenshot':
        return Row(
          children: [
            FilledButton(
              onPressed: () => _handleScreenshot(command),
              child: const Text('Accept'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _ack(command, 'rejected'),
              child: const Text('Reject'),
            ),
          ],
        );
      case 'request_audio':
        return Row(
          children: [
            FilledButton(
              onPressed: () => _handleAudio(command),
              child: const Text('Accept'),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () => _ack(command, 'rejected'),
              child: const Text('Reject'),
            ),
          ],
        );
      default:
        return OutlinedButton(
          onPressed: () => _ack(command, 'acknowledged'),
          child: const Text('Acknowledge'),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Remote Commands')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : widget.deviceId.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'This device is not registered yet, so there are no remote '
                    'commands to show. Once device registration lands, commands '
                    'from your parent will appear here — and nothing will ever '
                    'run without showing here first.',
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _poll,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Checked every 30 seconds. Screenshot and audio '
                            'requests need your answer — they never start '
                            'silently.',
                          ),
                        ),
                      ),
                      if (_error != null)
                        ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text('Could not load commands: $_error'),
                        ),
                      if (_pending.isEmpty && _error == null)
                        const ListTile(
                          leading: Icon(Icons.check_circle_outline),
                          title: Text('No pending commands'),
                        ),
                      for (final command in _pending)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_label(command),
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                _actionsFor(command),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}
