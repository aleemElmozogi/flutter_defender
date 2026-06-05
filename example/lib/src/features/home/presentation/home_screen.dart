import 'package:flutter/material.dart';
import 'package:flutter_defender/flutter_defender.dart';

import '../../../app/session/defender_demo_profiles.dart';
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
              StatusChip(
                label: 'Profile',
                value: sessionController.activeProfile.label,
                color: const Color(0xFF4A286B),
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
          _buildProfileSection(),
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
              'Screenshot protection, recents blanking, and capture blocking. '
              'Use Theme Override, Arabic Locale, or Message Resolvers to verify default overlay customization.',
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
              'Apply the Custom Builder profile, then confirm the host-drawn visuals still keep the plugin barrier active.',
          buttonLabel: 'Open custom blocking demo',
          onPressed: () =>
              _open(context, '/custom-blocking', 'Opened custom blocking demo'),
        ),
        const SizedBox(height: 12),
        FeatureTile(
          title: 'Secure Storage Helper',
          subtitle:
              'Apply the Secure Storage On profile, then run write/read/delete against the built-in helper.',
          buttonLabel: 'Run secure storage demo',
          onPressed: _exerciseSecureStorage,
        ),
      ],
    );
  }

  Widget _buildProfileSection() {
    return SectionCard(
      title: 'Configuration Profiles',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Each profile reapplies FlutterDefender.init(...) with a different set of options so the example can exercise the full config surface.',
          ),
          const SizedBox(height: 16),
          ...DefenderDemoProfile.values.expand((DefenderDemoProfile profile) {
            final bool isActive = profile == sessionController.activeProfile;
            return <Widget>[
              _ProfileTile(
                profile: profile,
                isActive: isActive,
                onPressed: () => sessionController.applyProfile(profile),
              ),
              const SizedBox(height: 12),
            ];
          }),
        ],
      ),
    );
  }

  void _open(BuildContext context, String route, String event) {
    sessionController.recordVisit(event);
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _exerciseSecureStorage() async {
    try {
      const String key = 'demo.token';
      const String value = 'token-123';
      await FlutterDefender.instance.secureWrite(key: key, value: value);
      final String? resolved = await FlutterDefender.instance.secureRead(key);
      sessionController.recordVisit(
        'Secure write/read result: ${resolved ?? "null"}',
      );
      await FlutterDefender.instance.secureDelete(key);
      final String? afterDelete = await FlutterDefender.instance.secureRead(
        key,
      );
      sessionController.recordVisit(
        'Secure read after delete: ${afterDelete ?? "null"}',
      );
    } catch (error) {
      sessionController.recordVisit(
        'Secure storage demo failed: enable the Secure Storage On profile.',
      );
      debugPrint('Secure storage demo error: $error');
    }
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.profile,
    required this.isActive,
    required this.onPressed,
  });

  final DefenderDemoProfile profile;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? const Color(0xFF5B3CDB) : const Color(0xFFD5DBE3),
        ),
        color: isActive ? const Color(0xFFF3F0FF) : Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  profile.label,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              FilledButton.tonal(
                onPressed: isActive ? null : onPressed,
                child: Text(isActive ? 'Active' : 'Apply'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(profile.description),
          const SizedBox(height: 8),
          Text(
            profile.checklistHint,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xFF475467)),
          ),
        ],
      ),
    );
  }
}
