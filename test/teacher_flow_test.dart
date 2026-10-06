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

    expect(find.text('Match the instruments\non this phone.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No account. No cloud. No remote AI.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();

    expect(find.text('Round of 12 minutes'), findsOneWidget);
    for (var step = 1; step <= 3; step++) {
      final good = find.byWidgetPredicate(
        (widget) => widget.key is ValueKey<String> && (widget.key as ValueKey<String>).value.startsWith('good-'),
      );
      expect(good, findsWidgets);
      await tester.ensureVisible(good.first);
      await tester.pumpAndSettle();
      await tester.tap(good.first);
      await tester.pump();
      expect(find.text('${step * 200}'), findsWidgets);
    }

    await tester.tap(find.byKey(const Key('tab-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Tap the instrument that matches the first mark.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Tap a second tile of the same instrument.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Follow the three marks from left to right.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Clear the row and take the points.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-four')));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('columns-toggle')));
    await tester.pump();
    expect(find.text('Pick · 4'), findsOneWidget);
    await tester.tap(find.byKey(const Key('columns-toggle')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('tab-range')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('range-20')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('range-20')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-home')));
    await tester.pumpAndSettle();
    expect(find.text('Round of 20 minutes'), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab-tablet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tablet-field')), 'Counted three objects.');
    await tester.tap(find.byKey(const Key('tablet-save')));
    await tester.pumpAndSettle();
    expect(find.text('Counted three objects.'), findsOneWidget);
    expect(find.text('Kept in the hall book. Private journal.'), findsOneWidget);
  });
}
