import 'package:flutter_test/flutter_test.dart';
import 'package:project4/main.dart';

void main() {
  testWidgets('Home screen shows camera button and downloaded items', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Project 4'), findsOneWidget);
    expect(find.text('Open Camera'), findsOneWidget);
    expect(find.text('Downloaded Items'), findsOneWidget);
    expect(find.text('No items downloaded yet.'), findsOneWidget);
  });
}
