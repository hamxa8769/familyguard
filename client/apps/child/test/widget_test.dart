// Child-app widget tests: transparency and consent must disclose the
// Phase 1 features (remote commands, on-request screenshots, SOS-only
// short audio) and must state what is NOT collected.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familyguard_child/features/transparency/transparency_screen.dart';
import 'package:familyguard_child/consent/consent_screen.dart';

void main() {
  // The screens are ListViews: give the test a tall viewport so items near
  // the end are built (ListView only builds visible children).
  testWidgets('Transparency lists the new features and the limits',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: TransparencyScreen()),
    );
    expect(find.text('What My Parent Sees'), findsOneWidget);
    expect(find.textContaining('Remote commands'), findsOneWidget);
    expect(find.textContaining('Screenshots taken only after'), findsOneWidget);
    expect(find.textContaining('Short audio clips (max 30 seconds)'), findsOneWidget);
    expect(find.textContaining('Which apps are installed'), findsOneWidget);
    expect(find.textContaining('Browser sessions'), findsOneWidget);
    expect(find.textContaining('The family agreement'), findsOneWidget);
    expect(find.textContaining('The web pages or URLs you visit'), findsOneWidget);
    expect(find.textContaining('Continuous or ambient microphone listening'),
        findsOneWidget);
    expect(find.textContaining('Secret screenshots'), findsOneWidget);
  });

  testWidgets('Consent notice mentions screenshot countdown and 30s audio',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ConsentScreen(onAccepted: () {})),
    );
    expect(find.textContaining('screenshot'), findsWidgets);
    expect(find.textContaining('30 seconds'), findsOneWidget);
    expect(find.textContaining('never listens continuously'), findsOneWidget);
    expect(find.text('I understand and accept'), findsOneWidget);
  });
}
