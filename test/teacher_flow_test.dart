import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_screen/user_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding, walk, columns, range, and a tablet note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const UserScreen());
    await tester.pumpAndSettle();

    expect(find.text('A band of games\non this phone.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No account. No cloud. No remote AI.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();

    expect(find.text('Open the band.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Pinch one string and count four rings before it fades.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Strike the drum head once, then lift your hand away.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Cover one hole and play a short note on the pipe.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Shake the bell twice and set it down on the table.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-four')));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('columns-toggle')));
    await tester.pump();
    expect(find.text('Cue · 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('columns-toggle')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('tab-range')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('range-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('range-11')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.text('Round of 11 minutes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-tablet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tablet-field')), 'Counted three objects.');
    await tester.tap(find.byKey(const Key('tablet-save')));
    await tester.pumpAndSettle();
    expect(find.text('Counted three objects.'), findsOneWidget);
    expect(find.text('Kept in the band book. Private journal.'), findsOneWidget);
  });
}
