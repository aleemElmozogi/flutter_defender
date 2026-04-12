import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_defender_example/main.dart';

void main() {
  testWidgets('example home renders guarded actions', (WidgetTester tester) async {
    await tester.pumpWidget(MyApp(sessionController: SessionController()));
    await tester.pumpAndSettle();

    expect(find.text('Open sensitive screen'), findsOneWidget);
    expect(find.text('Open OTP screen'), findsOneWidget);
  });
}
