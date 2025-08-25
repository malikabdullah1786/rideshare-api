// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ride_share_app/main.dart'; // CORRECTED IMPORT PATH

void main() {
  testWidgets('App starts and shows AuthScreen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that AuthScreen is displayed initially.
    expect(find.text('Ride Share App'), findsOneWidget); // AppBar title
    expect(find.text('Login to your account'), findsOneWidget); // Login screen text
    expect(find.byType(ElevatedButton), findsNWidgets(2)); // Login and Register buttons
  });
}
