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

    expect(find.text('Fit the horn\nin the bay.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No account. No cloud. No remote AI.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-advance')));
    await tester.pumpAndSettle();

    expect(find.text('Bay of 9 minutes'), findsOneWidget);
    expect(find.text('GHI NHỚ GIAI ĐIỆU'), findsOneWidget);
    for (var index = 0; index < 4; index++) {
      final part = find.byKey(ValueKey('part-$index'));
      await tester.ensureVisible(part);
      await tester.pumpAndSettle();
      await tester.tap(part);
      await tester.pump();
    }
    expect(find.text('built'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hall-map')));
    await tester.pumpAndSettle();
    expect(find.text('String Forest'), findsOneWidget);
    expect(find.text('MỞ KHÓA KHU VỰC MỚI'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hall-shelf')));
    await tester.pumpAndSettle();
    expect(find.text('SƯU TẬP'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shelf-violin')));
    await tester.pumpAndSettle();
    expect(find.text('VIOLIN'), findsOneWidget);
    expect(find.text('NGHE LẠI GIAI ĐIỆU'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hall-shop')));
    await tester.pumpAndSettle();
    expect(find.text('CỬA HÀNG'), findsOneWidget);
    expect(find.text('MUA NGAY'), findsOneWidget);

    await tester.tap(find.byKey(const Key('hall-board')));
    await tester.pumpAndSettle();
    expect(find.text('BẢNG XẾP HẠNG'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-walk')));
    await tester.pumpAndSettle();
    expect(find.text('Open String Forest on the map.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Tap Bell, Valve, Slide, then Mouth.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('A finished horn turns gold and scores.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('walk-advance')));
    await tester.pump();
    expect(find.text('Clear the build to open the next bay.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-four')));
    await tester.pumpAndSettle();
    expect(find.text('Ready'), findsOneWidget);
    await tester.tap(find.byKey(const Key('columns-toggle')));
    await tester.pump();
    expect(find.text('Fit · 4'), findsOneWidget);
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
    expect(find.text('Bay of 14 minutes'), findsOneWidget);

    await tester.tap(find.byKey(const Key('tab-tablet')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('tablet-field')), 'Counted three objects.');
    await tester.tap(find.byKey(const Key('tablet-save')));
    await tester.pumpAndSettle();
    expect(find.text('Counted three objects.'), findsOneWidget);
    expect(find.text('Kept in the field book. Private journal.'), findsOneWidget);
  });
}
