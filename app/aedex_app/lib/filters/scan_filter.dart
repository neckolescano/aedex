import 'package:flutter/material.dart';

import '../models/scan.dart';

/// What the map shows: which statuses, which days and which risk levels.
@immutable
class ScanFilter {
  const ScanFilter({
    this.statuses = const {...ScanStatus.values},
    this.risks = const {...RiskLevel.values},
    this.days,
  });

  static const all = ScanFilter();

  final Set<ScanStatus> statuses;
  final Set<RiskLevel> risks;

  /// Only scans on these days (null = any day).
  final DateTimeRange? days;

  bool matches(Scan s) {
    if (!statuses.contains(s.status)) return false;
    if (!risks.contains(s.risk)) return false;
    final range = days;
    if (range != null) {
      final t = s.time.toLocal();
      final day = DateTime(t.year, t.month, t.day);
      final start = DateUtils.dateOnly(range.start);
      final end = DateUtils.dateOnly(range.end);
      if (day.isBefore(start) || day.isAfter(end)) return false;
    }
    return true;
  }

  List<Scan> apply(List<Scan> scans) => scans.where(matches).toList();

  /// How many filter groups differ from "show everything" (for a badge).
  int get activeCount =>
      (statuses.length < ScanStatus.values.length ? 1 : 0) +
      (risks.length < RiskLevel.values.length ? 1 : 0) +
      (days != null ? 1 : 0);

  ScanFilter copyWith({
    Set<ScanStatus>? statuses,
    Set<RiskLevel>? risks,
    DateTimeRange? days,
    bool clearDays = false,
  }) => ScanFilter(
    statuses: statuses ?? this.statuses,
    risks: risks ?? this.risks,
    days: clearDays ? null : (days ?? this.days),
  );
}
