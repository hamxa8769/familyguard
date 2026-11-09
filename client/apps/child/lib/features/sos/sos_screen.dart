import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:familyguard_core/familyguard_core.dart';
import '../location/location_collector.dart';

/// Child-side panic button. Long-press sends an SOS (with location when
/// available) to the parent.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _sending = false;

  Future<void> _send() async {
    final auth = AuthService.instance;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
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
      messenger.showSnackBar(
        const SnackBar(content: Text('SOS sent to your parent')),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('SOS NOT sent: ${e.message}. Call your parent directly.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Press and hold to alert your parent',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            GestureDetector(
              onLongPress: _sending ? null : _send,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                    color: _sending ? Colors.red.shade200 : Colors.red,
                    shape: BoxShape.circle),
                child: Center(
                  child: _sending
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SOS',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
