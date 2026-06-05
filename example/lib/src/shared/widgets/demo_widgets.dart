import 'package:flutter/material.dart';

class DemoDetailsScreen extends StatelessWidget {
  const DemoDetailsScreen({
    required this.title,
    required this.eyebrow,
    required this.body,
    required this.checklist,
    this.children = const <Widget>[],
    super.key,
  });

  final String title;
  final String eyebrow;
  final String body;
  final List<String> checklist;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          Text(eyebrow, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          ...children.expand(
            (Widget child) => <Widget>[child, const SizedBox(height: 12)],
          ),
          SectionCard(
            title: 'What to test here',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: checklist
                  .map((String item) => ChecklistLine(label: item))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  const FeatureTile({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onPressed,
    super.key,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(subtitle),
          const SizedBox(height: 16),
          FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD5DBE3)),
        color: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.value,
    required this.color,
    super.key,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class ChecklistLine extends StatelessWidget {
  const ChecklistLine({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
