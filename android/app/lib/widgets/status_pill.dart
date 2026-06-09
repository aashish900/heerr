import 'package:flutter/material.dart';

import '../models/enums.dart';

/// Small coloured chip that surfaces a job's lifecycle state. Colour mapping
/// is locked in PLAN.md §8:
///   * queued  → blue
///   * running → amber
///   * done    → green
///   * failed  → red
///
/// Used in the queue tiles + job-detail screen header.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.state, super.key});

  final JobState state;

  static const Map<JobState, (Color, String)> _data = <JobState, (Color, String)>{
    JobState.queued: (Colors.blue, 'queued'),
    JobState.running: (Colors.amber, 'running'),
    JobState.done: (Colors.green, 'done'),
    JobState.failed: (Colors.red, 'failed'),
  };

  @override
  Widget build(BuildContext context) {
    final (Color color, String label) = _data[state]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
