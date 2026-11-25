import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/scan.dart';
import '../theme.dart';
import 'glass_panel.dart';
import 'scan_pin.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Nov 19, 3:30 PM" in the phone's own time zone.
String formatScanTime(DateTime time) {
  final t = time.toLocal();
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final ampm = t.hour < 12 ? 'AM' : 'PM';
  return '${_months[t.month - 1]} ${t.day}, $hour12:$minute $ampm';
}

String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

/// The card that slides up when a pin is tapped:
/// counts per class, date, location type and clean-up status.
class ScanCard extends StatelessWidget {
  const ScanCard({super.key, required this.scan, required this.onClose});

  final Scan scan;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final total = scan.totalContainers;
    final risk = scan.risk;
    final entries = scan.counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxCount = entries.isEmpty ? 1 : math.max(1, entries.first.value);
    final where = scan.precision == LocationPrecision.street
        ? 'Street level (homes stay private)'
        : 'Exact spot (public place)';

    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      borderRadius: 30,
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AedexColors.forRisk(risk),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$total',
                  style: TextStyle(
                    color: AedexColors.onRisk(risk),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${scanLabel(scan)} · $total '
                      '${total == 1 ? 'container' : 'containers'}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AedexColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatScanTime(scan.time)} · $where',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AedexColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Text(
              'No containers found here. Area is clear.',
              style: TextStyle(color: AedexColors.muted),
            )
          else
            for (final e in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, right: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 128,
                      child: Text(
                        e.key.replaceAll('-', ' '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.value / maxCount,
                          minHeight: 8,
                          color: AedexColors.brand,
                          backgroundColor: const Color(0x1F14402F),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 28,
                      child: Text(
                        '${e.value}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: 10),
          const Text(
            'CLEAN-UP STATUS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AedexColors.muted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _StatusSteps(status: scan.status),
          ),
        ],
      ),
    );
  }
}

/// Four bars: reported -> assigned -> cleaned -> verified.
class _StatusSteps extends StatelessWidget {
  const _StatusSteps({required this.status});

  final ScanStatus status;

  @override
  Widget build(BuildContext context) {
    final current = status.index;
    return Semantics(
      label: 'Status: ${status.name}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final step in ScanStatus.values) ...[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: step.index <= current
                          ? AedexColors.brand
                          : const Color(0x2E14402F),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _capitalize(step.name),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: step.index == current
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: step.index <= current
                          ? AedexColors.ink
                          : AedexColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (step != ScanStatus.values.last) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}
