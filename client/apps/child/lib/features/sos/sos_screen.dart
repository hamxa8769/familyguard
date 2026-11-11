import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:familyguard_core/familyguard_core.dart';
import 'package:familyguard_core/ui.dart';
import '../location/location_collector.dart';

/// Sends an SOS (with location when allowed). Throws [ApiException] on failure.
Future<void> sendSos() async {
  final auth = AuthService.instance;
  LocationPoint? point;
  final loc = LocationCollector();
  if (Platform.isAndroid && await loc.hasPermission()) {
    point = await loc.current();
  }
  await auth.api.post('/api/sos', {
    'deviceId': auth.deviceId,
    'message': 'SOS from ${auth.childName ?? 'your child'}',
    if (point != null) 'lat': point.lat,
    if (point != null) 'lng': point.lng,
  });
}

/// Big SOS button: press and HOLD for 2 seconds (a ring fills) so it can't be
/// sent by accident. Releasing early cancels.
class SosButton extends StatefulWidget {
  const SosButton({super.key, this.size = 180});
  final double size;

  @override
  State<SosButton> createState() => _SosButtonState();
}

enum _SosState { idle, sending, sent }

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _fire();
    });
  _SosState _state = _SosState.idle;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _down() {
    if (_state != _SosState.idle) return;
    HapticFeedback.selectionClick();
    _hold.forward(from: 0);
  }

  void _up() {
    if (_hold.isAnimating) _hold.reverse();
  }

  Future<void> _fire() async {
    HapticFeedback.heavyImpact();
    setState(() => _state = _SosState.sending);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await sendSos();
      if (!mounted) return;
      setState(() => _state = _SosState.sent);
      messenger.showSnackBar(
          const SnackBar(content: Text('SOS sent to your parent')));
      await Future<void>.delayed(const Duration(seconds: 5));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('SOS NOT sent: ${e.message}. Call your parent directly.'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 8),
      ));
    }
    if (!mounted) return;
    _hold.value = 0;
    setState(() => _state = _SosState.idle);
  }

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    final size = widget.size;
    final label = switch (_state) {
      _SosState.idle => 'Hold 2 sec',
      _SosState.sending => 'Sending…',
      _SosState.sent => 'Sent',
    };
    return Semantics(
      button: true,
      label: 'SOS. Press and hold for two seconds to alert your parent.',
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        child: SizedBox.square(
          dimension: size,
          child: AnimatedBuilder(
            animation: _hold,
            builder: (context, _) => Stack(
              alignment: Alignment.center,
              children: [
                // Outer halo + progress ring.
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.tint(c.danger),
                  ),
                ),
                StatRing(
                  value: _state == _SosState.idle ? _hold.value : 1,
                  size: size,
                  stroke: 8,
                  color: c.danger,
                  center: const SizedBox.shrink(),
                ),
                AnimatedScale(
                  scale: _hold.isAnimating ? 0.94 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: size * 0.74,
                    height: size * 0.74,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _state == _SosState.sent ? c.safe : c.danger,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _state == _SosState.sent
                              ? Icons.check_rounded
                              : Icons.sos_rounded,
                          color: Colors.white,
                          size: size * 0.22,
                        ),
                        Text(label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen SOS (reachable from older links/shortcuts).
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = FgColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SosButton(size: 220),
            const SizedBox(height: FgSpace.xl),
            Text('Press and hold to alert your parent',
                style: TextStyle(color: c.textMuted)),
          ],
        ),
      ),
    );
  }
}
