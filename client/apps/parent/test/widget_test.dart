// Parent-app widget tests: the dashboard registry must contain the
// Phase 1 modules, and the home screen must show them.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:familyguard_parent/feature_registry.dart';
import 'package:familyguard_parent/main.dart';
import 'package:familyguard_parent/state/app_controller.dart';

void main() {
  // The merged app signs in before showing the shell: seed a saved token
  // and load the controller so the home renders (assertions unchanged).
  setUp(() async {
    SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});
    await AppController.instance.load();
  });
  test('Feature registry contains the remote-commands and media modules', () {
    final ids = FeatureRegistry.all.map((f) => f.id).toList();
    expect(ids, contains('remote_commands'));
    expect(ids, contains('media'));
    expect(ids, contains('apps'));
    expect(ids, contains('browsing'));
    expect(ids, contains('agreement'));
    expect(ids, contains('rewards'));
    expect(ids, contains('keywords'));
    expect(ids, contains('dashboard'));
    expect(ids, contains('alerts'));
  });

  testWidgets('Parent home shows the new feature tiles',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ParentApp());
    expect(find.text('Remote Commands'), findsOneWidget);
    expect(find.text('Screenshots & Audio'), findsOneWidget);
    expect(find.text('FamilyGuard — Parent'), findsOneWidget);
  });
}
