import 'package:flutter_test/flutter_test.dart';
import 'package:project4/main.dart';

void main() {
  testWidgets('Home screen shows the app navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Project 4'), findsOneWidget);
    expect(find.text('Open Camera'), findsOneWidget);
    expect(find.text('Open PFT Map'), findsOneWidget);
    expect(find.text('Set up Pokémon AR'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Photos & videos'), findsOneWidget);
  });
}
