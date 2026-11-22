import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import 'package:cemo/main.dart';

/// Walks through the main screens on sample content to catch layout and
/// theme errors (every screen must build under the Forui theme).
void main() {
  Future<void> signIn(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const CemoApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(find.text('Join Cemo.'), findsOneWidget);
    await tester.tap(find.text('Continue with Apple'));
    await tester.pumpAndSettle();
  }

  Finder navItem(String label) => find.descendant(of: find.byType(FBottomNavigationBar), matching: find.text(label));

  testWidgets('home tabs build', (WidgetTester tester) async {
    await signIn(tester);
    expect(find.text('Cemo'), findsOneWidget);
    expect(find.text('Reading list'), findsOneWidget);

    await tester.tap(find.text('Pinned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();

    await tester.tap(navItem('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Search across every note, link and conversation.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'zzzz-no-match');
    await tester.pumpAndSettle();
    expect(find.text('Check the spelling or try a shorter word.'), findsOneWidget);

    await tester.tap(navItem('Reminders'));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming'), findsOneWidget);

    await tester.tap(navItem('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'.toUpperCase()), findsOneWidget);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
  });

  testWidgets('category sheet, selection and confirm dialog', (WidgetTester tester) async {
    await signIn(tester);

    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('New category'), findsNothing);

    await tester.longPress(find.text('Work'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Archive “Work”?'), findsOneWidget);
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();
    expect(find.text('“Work” archived'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('“Work” archived'), findsNothing);
  });

  testWidgets('conversation screen builds and selects', (WidgetTester tester) async {
    await signIn(tester);
    await tester.tap(find.text('Reading list'));
    await tester.pumpAndSettle();
    expect(find.text('All notes'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    expect(find.text('Media, links and docs'), findsOneWidget);
    await tester.tap(find.text('Media, links and docs'));
    await tester.pumpAndSettle();
    expect(find.text('Links'), findsOneWidget);
    await tester.tap(find.text('Links'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(EditableText), 'A new note');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Send'));
    await tester.pumpAndSettle();
    expect(find.text('A new note'), findsOneWidget);

    await tester.longPress(find.text('A new note'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Forward'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Cancel selection'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Forward'), findsNothing);
  });
}
