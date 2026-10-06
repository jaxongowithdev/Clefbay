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

    expect(find.text('A kiln for\nattention.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No account. No cloud. No remote AI.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();

    expect(find.text('Fire the next slip.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Stand so your weight is even.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Find the farthest corner you can see.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Walk there, counting eight steps.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Stay for one breath and name what is next.'), findsOneWidget);

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
    await tester.ensureVisible(find.byKey(const Key('range-22')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('range-22')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.text('Slip of 22 minutes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-tablet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tablet-field')), 'Counted three objects.');
    await tester.tap(find.byKey(const Key('tablet-save')));
    await tester.pumpAndSettle();
    expect(find.text('Counted three objects.'), findsOneWidget);
    expect(find.text('Pressed on this phone. Private journal.'), findsOneWidget);
  });
}
