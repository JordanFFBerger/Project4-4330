import 'package:flutter_test/flutter_test.dart';
import 'package:project4/main.dart';

void main() {
  testWidgets('Home screen shows the app navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Welcome Back, Trainer!'), findsOneWidget);
    expect(find.text('Log In'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue as guest'));
    await tester.tap(find.text('Continue as guest'));
    await tester.pumpAndSettle();

    expect(find.text('Project 4'), findsOneWidget);
    expect(find.text('Open Camera'), findsOneWidget);
    expect(find.text('Open PFT Map'), findsOneWidget);
    expect(find.text('Set up Pokémon AR'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
    expect(find.text('Photos & videos'), findsOneWidget);
    expect(find.text('Welcome Back, Trainer!'), findsNothing);
  });

  testWidgets('login and registration retain validation', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.ensureVisible(find.text('Log In'));
    await tester.tap(find.text('Log In'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a username and password.'), findsOneWidget);
    await tester.ensureVisible(find.text('New trainer? Create an account'));
    await tester.tap(find.text('New trainer? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Password'), findsOneWidget);
    expect(find.text('Continue as guest'), findsOneWidget);
  });
}
