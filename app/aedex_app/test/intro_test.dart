import 'package:aedex_app/screens/intro_screen.dart';
import 'package:aedex_app/theme.dart';
import 'package:aedex_app/widgets/patak.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Reduce motion on: Patak stands still and pages jump, so pumpAndSettle ends.
Widget _host(VoidCallback onDone) => MaterialApp(
  theme: buildAedexTheme(useGoogleFont: false),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: IntroScreen(onDone: onDone),
    ),
  ),
);

// Only the Patak on the visible card: the logo is a Patak too, and the
// pager keeps the next card built.
Finder _pose(PatakPose p) => find
    .descendant(
      of: find.byType(PageView),
      matching: find.byWidgetPredicate((w) => w is Patak && w.pose == p),
    )
    .hitTestable();

void main() {
  testWidgets('Next walks through Taob, Taktak, Tuyo, Takip', (tester) async {
    var done = false;
    await tester.pumpWidget(_host(() => done = true));

    expect(find.text('Find the water. Stop the bite.'), findsOneWidget);
    expect(find.text('Tip it over'), findsOneWidget);
    expect(_pose(PatakPose.wave), findsOneWidget);

    const steps = [
      ('Tap it', PatakPose.searching),
      ('Dry it', PatakPose.happy),
      ('Cover it', PatakPose.sleepy),
    ];
    for (final (meaning, pose) in steps) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text(meaning), findsOneWidget);
      expect(_pose(pose), findsOneWidget);
    }

    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Get started'));
    expect(done, isTrue);
  });

  testWidgets('Skip finishes the intro right away', (tester) async {
    var done = false;
    await tester.pumpWidget(_host(() => done = true));
    await tester.tap(find.text('Skip'));
    expect(done, isTrue);
  });

  testWidgets('tapping a campaign word jumps to its card', (tester) async {
    await tester.pumpWidget(_host(() {}));
    // "Tuyo" is both a campaign word and (after the jump) the card title.
    await tester.tap(find.text('Tuyo').last);
    await tester.pumpAndSettle();
    expect(find.text('Dry it'), findsOneWidget);
  });

  test('the intro is remembered after it is seen', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await IntroMemory.seen(), isFalse);
    await IntroMemory.markSeen();
    expect(await IntroMemory.seen(), isTrue);
  });
}
