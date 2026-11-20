// Permissions screen (Phase 4): on a non-Android host permissionItems()
// is empty, so the screen shows its empty state and the "Allow all"
// button, which must be a no-op over zero items — not a crash.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familyguard_child/permissions/permissions_screen.dart';

void main() {
  testWidgets('Permissions screen shows empty state and Allow all is a no-op',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(home: PermissionsScreen()),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nothing to allow on this device.'), findsOneWidget);
    expect(find.text('Allow all'), findsOneWidget);
    await tester.tap(find.text('Allow all'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to allow on this device.'), findsOneWidget);
  });

  testWidgets('Permissions screen onboarding shows Allow all and Continue',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(home: PermissionsScreen(onDone: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.text('Allow access'), findsOneWidget);
    expect(find.text('Allow all'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);
    expect(find.textContaining('skip any of them'), findsOneWidget);
  });
}
