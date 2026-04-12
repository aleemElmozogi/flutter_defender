import 'package:flutter/material.dart';

import '../../../app/session/session_controller.dart';
import '../../../shared/widgets/demo_widgets.dart';
import '../../../shared/widgets/security_widgets.dart';

class SensitiveDemoScreen extends StatelessWidget {
  const SensitiveDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoDetailsScreen(
      title: 'Sensitive Screen',
      eyebrow: 'FLAG_SECURE + capture policy',
      body:
          'Use this screen to verify Android recents blanking, screenshot behavior, '
          'and iOS recording or mirroring detection.',
      checklist: <String>[
        'Open Android recents and confirm the protected view is hidden.',
        'Try a screenshot immediately after opening the page.',
        'Start recording or mirroring on iPhone and confirm blocking appears.',
      ],
      children: <Widget>[
        SecretCard(title: 'Card number', value: '4026 1234 5678 9900'),
        SecretCard(title: 'Available balance', value: '\$24,810.44'),
      ],
    );
  }
}

class CustomBlockingDemoScreen extends StatelessWidget {
  const CustomBlockingDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoDetailsScreen(
      title: 'Custom Blocking Screen Demo',
      eyebrow: 'Builder + barrier ownership',
      body:
          'This route uses a custom blocking builder. The plugin still owns the '
          'barrier, so protected content remains untouchable while blocked.',
      checklist: <String>[
        'Trigger a blocking condition and try tapping behind the dialog.',
        'Confirm custom visuals do not change the tap-block behavior.',
      ],
      children: <Widget>[
        SecretCard(title: 'Transfer amount', value: '\$1,250.00'),
      ],
    );
  }
}

class OtpDemoScreen extends StatelessWidget {
  const OtpDemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DemoDetailsScreen(
      title: 'OTP Screen',
      eyebrow: 'Route-scoped timeout',
      body:
          'Background the app for more than 10 seconds. Returning should dismiss '
          'only this route and keep the rest of the stack intact.',
      checklist: <String>[
        'Background for less than 10 seconds: route stays open.',
        'Background for more than 10 seconds: only OTP route pops.',
      ],
      children: <Widget>[OtpCodePreview()],
    );
  }
}

class AuthenticatedDemoScreen extends StatelessWidget {
  const AuthenticatedDemoScreen({required this.sessionController, super.key});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    return DemoDetailsScreen(
      title: 'Authenticated Area',
      eyebrow: 'Background logout demo',
      body:
          'This screen represents a signed-in experience. Background the app for '
          'more than 20 seconds to trigger a full logout request.',
      checklist: const <String>[
        'Sign in before opening this route.',
        'Background for less than 20 seconds: session stays active.',
        'Background for more than 20 seconds: app returns logged out.',
      ],
      children: <Widget>[
        const SecretCard(title: 'User ID', value: 'USR-009813'),
        SecretCard(
          title: 'Current session',
          value: sessionController.authenticated
              ? 'Authenticated'
              : 'Logged out',
        ),
      ],
    );
  }
}
