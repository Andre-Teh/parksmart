// Smoke test for the shared PrimaryButton widget used across ParkSmart's
// screens. Avoids pumping MyApp directly since that requires a live
// Firebase connection (Firebase.initializeApp in main()).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parksmart/widgets/custom_button.dart';

void main() {
  testWidgets('PrimaryButton shows label and responds to taps', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Start Session',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Start Session'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton shows a spinner and disables taps when loading', (
    WidgetTester tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Start Session',
            isLoading: true,
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Start Session'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapped, isFalse);
  });
}
