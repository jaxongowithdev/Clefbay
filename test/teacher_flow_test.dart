import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:user_screen/user_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('tap sound files are bundled', (tester) async {
    final hit = await rootBundle.load('packages/user_screen/assets/sounds/hit.wav');
    final miss = await rootBundle.load('packages/user_screen/assets/sounds/miss.wav');
    expect(hit.lengthInBytes, greaterThan(1000));
    expect(miss.lengthInBytes, greaterThan(1000));
  });

  testWidgets('onboarding, walk, columns, range, and a tablet note', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const UserScreen());
    await tester.pumpAndSettle();

    expect(find.text('Find the words\nin the glade.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No account. No cloud. No remote AI.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();

    expect(find.text('Trail of 9 minutes'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      final cell = find.byKey(ValueKey('cell-$index'));
      await tester.ensureVisible(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pump();
    }
    expect(find.text('found'), findsWidgets);

    await tester.tap(find.byKey(const Key('tab-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Read the target words under the grid.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Tap the letters of one word from left to right.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('A finished word turns green and scores.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Clear the list to open the next glade.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-four')));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('columns-toggle')));
    await tester.pump();
    expect(find.text('Seek · 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('columns-toggle')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('tab-range')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('range-14')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('range-14')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.text('Trail of 14 minutes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-tablet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tablet-field')), 'Counted three objects.');
    await tester.tap(find.byKey(const Key('tablet-save')));
    await tester.pumpAndSettle();
    expect(find.text('Counted three objects.'), findsOneWidget);
    expect(find.text('Kept in the field book. Private journal.'), findsOneWidget);
  });
}
