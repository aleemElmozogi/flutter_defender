import 'package:flutter/material.dart';

import 'demo_widgets.dart';

class ManualChecklistCard extends StatelessWidget {
  const ManualChecklistCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      title: 'Manual Verification Checklist',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChecklistLine(
            label:
                'Sensitive screen: verify Android recents are protected and '
                'recording or mirroring triggers blocking behavior.',
          ),
          ChecklistLine(
            label:
                'OTP screen: background for less than 10 seconds, then for more '
                'than 10 seconds, and compare the result.',
          ),
          ChecklistLine(
            label:
                'Authenticated flow: sign in first, then background for more than '
                '20 seconds and confirm logout.',
          ),
          ChecklistLine(
            label:
                'Custom blocking screen: trigger a block and confirm taps do not '
                'reach the underlying route.',
          ),
          ChecklistLine(
            label:
                'Release build on emulator or simulator: guarded routes should '
                'be blocked in release only.',
          ),
        ],
      ),
    );
  }
}

class SecretCard extends StatelessWidget {
  const SecretCard({required this.title, required this.value, super.key});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D2E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: const TextStyle(color: Color(0xFFB9C6D6))),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class OtpCodePreview extends StatelessWidget {
  const OtpCodePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD5DBE3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'One-time password',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              OtpBox('3'),
              OtpBox('8'),
              OtpBox('4'),
              OtpBox('1'),
              OtpBox('7'),
              OtpBox('2'),
            ],
          ),
        ],
      ),
    );
  }
}

class OtpBox extends StatelessWidget {
  const OtpBox(this.value, {super.key});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFB8C4D0)),
      ),
      child: Text(
        value,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    );
  }
}
