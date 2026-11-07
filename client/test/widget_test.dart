import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:familyguard/main.dart';

void main() {
  setUp(() {
    // ConsentService reads SharedPreferences on startup; mock it in tests.
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App builds without crashing', (tester) async {
    await tester.pumpWidget(const FamilyGuardApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
