import 'package:flutter_test/flutter_test.dart';

import 'package:cemo/main.dart';

void main() {
  testWidgets('app starts on onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const CemoApp());
    await tester.pump();
    expect(find.text('Skip'), findsOneWidget);
  });
}
