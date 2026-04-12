import 'package:flutter/material.dart';

import '../../../app/session/session_controller.dart';
import '../../../shared/widgets/demo_widgets.dart';
import '../../../shared/widgets/security_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.sessionController, super.key});

  final SessionController sessionController;

  @override
  Widget build(BuildContext context) {
    final bool authenticated = sessionController.authenticated;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_defender example')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(
            'Feature Lab',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'This example is meant for manual security validation. '
            'Each route demonstrates one piece of the plugin contract.',
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              StatusChip(
                label: 'Session',
                value: authenticated ? 'Authenticated' : 'Logged out',
                color: authenticated
                    ? const Color(0xFF1F6F43)
                    : const Color(0xFF6B1F1F),
              ),
              const StatusChip(
                label: 'OTP timeout',
                value: '10 sec',
                color: Color(0xFF234C71),
              ),
              const StatusChip(
                label: 'Auth timeout',
                value: '20 sec',
                color: Color(0xFF5B3C13),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: sessionController.toggleAuth,
                  child: Text(authenticated ? 'Sign out' : 'Sign in'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: sessionController.clearEvents,
                  child: const Text('Clear event log'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildFeatureTiles(context, authenticated),
          const SizedBox(height: 24),
          SectionCard(
            title: 'Event Log',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sessionController.eventLog
                  .map(
                    (String event) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $event'),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          const ManualChecklistCard(),
        ],
      ),
    );
  }

  Widget _buildFeatureTiles(BuildContext context, bool authenticated) {
    return Column(
      children: <Widget>[
        FeatureTile(
          title: 'Sensitive Screen',
          subtitle:
              'Screenshot protection, recents blanking, and capture blocking.',
          buttonLabel: 'Open sensitive screen',
          onPressed: () =>
              _open(context, '/sensitive', 'Opened sensitive screen demo'),
        ),
        const SizedBox(height: 12),
        FeatureTile(
          title: 'OTP Route',
          subtitle: 'Demonstrates route-scoped background timeout behavior.',
          buttonLabel: 'Open OTP screen',
          onPressed: () => _open(context, '/otp', 'Opened OTP screen demo'),
        ),
        const SizedBox(height: 12),
        FeatureTile(
          title: 'Authenticated Session',
          subtitle: 'Use after signing in to verify full logout after timeout.',
          buttonLabel: 'Open authenticated area',
          onPressed: authenticated
              ? () => _open(
                  context,
                  '/authenticated',
                  'Opened authenticated area demo',
                )
              : null,
        ),
        const SizedBox(height: 12),
        FeatureTile(
          title: 'Custom Blocking UI',
          subtitle:
              'Confirms barrier stays active with custom visible content.',
          buttonLabel: 'Open custom blocking demo',
          onPressed: () =>
              _open(context, '/custom-blocking', 'Opened custom blocking demo'),
        ),
      ],
    );
  }

  void _open(BuildContext context, String route, String event) {
    sessionController.recordVisit(event);
    Navigator.of(context).pushNamed(route);
  }
}
