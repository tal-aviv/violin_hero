// Smoke test for Violin Hero.
//
// Boots the real app root (`ViolinHeroApp`) with an empty local store and
// verifies it resolves login state and lands on the login screen without
// throwing. This gives us basic regression coverage that the widget tree
// builds end-to-end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:violin_hero/main.dart';

void main() {
  testWidgets('ViolinHeroApp boots to the login screen', (tester) async {
    // No stored account/session.
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ViolinHeroApp());

    // First frame shows the loading spinner while login state loads.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the async login-state load settle.
    await tester.pumpAndSettle();

    // With no stored session we land on the login screen.
    expect(find.text('Violin Hero'), findsOneWidget);
    expect(find.text('Login'), findsWidgets);
    expect(find.text('Create account'), findsOneWidget);
  });
}
