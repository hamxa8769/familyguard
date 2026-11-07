import 'package:flutter/material.dart';

/// Child-side panic button. Long-press sends an SOS to the parent.
/// TODO: POST /api/sos { deviceId, message, lat, lng }.
class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

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
              onLongPress: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('SOS sent to your parent')),
              ),
              child: Container(
                width: 180,
                height: 180,
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: const Center(
                  child: Text('SOS',
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
