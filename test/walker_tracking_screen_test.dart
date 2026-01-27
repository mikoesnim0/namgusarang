import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hangookji_namgu/features/steps/steps_provider.dart';
import 'package:hangookji_namgu/screens/walker/walker_tracking_screen.dart';

void main() {
  testWidgets('Walker tracking page reflects streamed steps', (tester) async {
    final controller = StreamController<int>();

    addTearDown(() {
      controller.close();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          todayStepsProvider.overrideWith((ref) => controller.stream),
        ],
        child: const MaterialApp(home: WalkerTrackingScreen()),
      ),
    );

    controller.add(0);
    await tester.pumpAndSettle();
    expect(find.text('Walked'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    controller.add(1);
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);

    controller.add(1200);
    await tester.pumpAndSettle();
    expect(find.text('1,200'), findsOneWidget);
  });
}
