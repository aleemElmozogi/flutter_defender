import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_defender/flutter_defender.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_defender_example/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('guarded routes and bypass transitions work on the platform', (
    WidgetTester tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();

    expect(find.text('flutter_defender example'), findsOneWidget);
    expect(find.text('Feature Lab'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Open sensitive screen'), 300);
    expect(find.text('Open sensitive screen'), findsOneWidget);
    await tester.tap(find.text('Open sensitive screen'));
    await tester.pumpAndSettle();
    expect(find.text('Sensitive Screen'), findsOneWidget);
    expect(FlutterDefender.instance.shouldConcealGuardedContent, isFalse);

    await FlutterDefender.instance.init(ignoreScreenBlocking: true);
    await tester.pumpAndSettle();
    expect(FlutterDefender.instance.screenBlockingIgnored, isTrue);
    expect(find.text('Sensitive Screen'), findsOneWidget);

    await FlutterDefender.instance.init();
    await tester.pumpAndSettle();
    expect(FlutterDefender.instance.screenBlockingIgnored, isFalse);
    expect(FlutterDefender.instance.shouldConcealGuardedContent, isFalse);
    app.appNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Open OTP screen'), 300);
    expect(find.text('Open OTP screen'), findsOneWidget);
    await tester.tap(find.text('Open OTP screen'));
    await tester.pumpAndSettle();
    expect(find.text('OTP Screen'), findsOneWidget);
    app.appNavigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(FlutterDefender.instance.hasBlockingOverlay, isFalse);

    await tester.scrollUntilVisible(
      find.text('Open custom blocking demo'),
      300,
    );
    expect(find.text('Open custom blocking demo'), findsOneWidget);
  });
}
