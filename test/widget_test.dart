import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project4/main.dart';

void main() {
  testWidgets('Home screen shows camera button and empty items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Open Camera'), findsOneWidget);
    expect(find.text('Downloaded Items'), findsOneWidget);
    expect(find.text('No items downloaded yet.'), findsOneWidget);

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    expect(find.text('Camera connection coming next.'), findsOneWidget);
  });
}
