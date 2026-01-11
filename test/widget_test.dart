// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:hangookji_namgu/main.dart';

void main() {
  testWidgets('App boots', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: NamguApp(),
      ),
    );
    await tester.pump();

    // We render the splash title.
    expect(find.text('남구이야기'), findsOneWidget);

    // Splash has a 2s delayed navigation; advance time so no pending timers remain.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
