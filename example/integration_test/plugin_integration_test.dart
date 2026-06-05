import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_defender_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('example boots and exposes guarded flows', (
    WidgetTester tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('flutter_defender example'), findsOneWidget);
    expect(find.text('Feature Lab'), findsOneWidget);
    expect(find.text('Open sensitive screen'), findsOneWidget);
    expect(find.text('Open OTP screen'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open custom blocking demo'),
      300,
    );
    expect(find.text('Open custom blocking demo'), findsOneWidget);
  });
}
