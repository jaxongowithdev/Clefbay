import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_screen/user_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding, walk, breath, range, and a tablet note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const UserScreen());
    await tester.pumpAndSettle();

    expect(find.text('A paper teacher\nfor this phone.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No account. No cloud. No remote AI.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();

    expect(find.text('Your next ticket.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Rest one hand on something solid.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Turn to face a different wall.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Take six slow steps in that direction.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Stop and name the next useful thing.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-four')));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('breath-toggle')));
    await tester.pump();
    expect(find.text('Inhale · 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('breath-toggle')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('tab-range')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('range-18')));
    await tester.pumpAndSettle();
    expect(find.text('18'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-tablet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tablet-field')), 'Counted three objects.');
    await tester.tap(find.byKey(const Key('tablet-save')));
    await tester.pumpAndSettle();
    expect(find.text('Counted three objects.'), findsOneWidget);
    expect(find.text('Stamped on this phone. Private journal.'), findsOneWidget);
  });
}
