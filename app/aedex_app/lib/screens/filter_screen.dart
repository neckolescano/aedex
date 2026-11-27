import 'package:flutter/material.dart';

import '../filters/scan_filter.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/glass_background.dart';
import '../widgets/glass_controls.dart';

/// Pick which scans the map shows. Returns the new [ScanFilter] on "Show".
class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key, required this.initial, required this.scans});

  final ScanFilter initial;

  /// All saved scans, to show counts and how many will match.
  final List<Scan> scans;

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late ScanFilter _f = widget.initial;

  static const _statusHint = {
    ScanStatus.reported: 'Needs a team',
    ScanStatus.assigned: 'Team on it',
    ScanStatus.cleaned: 'Awaiting check',
    ScanStatus.verified: 'Confirmed clear',
  };

  Future<void> _pickDays() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _f.days,
    );
    if (range != null) setState(() => _f = _f.copyWith(days: range));
  }

  /// The day strip: the 6 most recent days that have scans, oldest first.
  List<DateTime> _recentDays() {
    final days = <DateTime>{
      for (final s in widget.scans) DateUtils.dateOnly(s.time.toLocal()),
    }.toList()..sort();
    return days.length > 6 ? days.sublist(days.length - 6) : days;
  }

  int _scansOn(DateTime day) => widget.scans
      .where((s) => DateUtils.isSameDay(s.time.toLocal(), day))
      .length;

  /// Tapping a day selects only that day; tapping it again clears it.
  void _tapDay(DateTime day) {
    final d = _f.days;
    final onlyThis =
        d != null &&
        DateUtils.isSameDay(d.start, day) &&
        DateUtils.isSameDay(d.end, day);
    setState(
      () => _f = onlyThis
          ? _f.copyWith(clearDays: true)
          : _f.copyWith(
              days: DateTimeRange(start: day, end: day),
            ),
    );
  }

  bool _dayInRange(DateTime day) {
    final d = _f.days;
    if (d == null) return false;
    return !day.isBefore(DateUtils.dateOnly(d.start)) &&
        !day.isAfter(DateUtils.dateOnly(d.end));
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final shown = _f.apply(widget.scans).length;
    final loc = MaterialLocalizations.of(context);
    final days = _f.days;
    final recent = _recentDays();

    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 80),
                children: [
                  Row(
                    children: [
                      GlassIconButton(
                        icon: Icons.close,
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      DecoratedBox(
                        decoration: frostDecoration(radius: 22),
                        child: Material(
                          type: MaterialType.transparency,
                          child: InkWell(
                            customBorder: const StadiumBorder(),
                            onTap: () => setState(() => _f = ScanFilter.all),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Text(
                                'Reset all',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AedexColors.brand,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 10, 4, 12),
                    child: Text(
                      'What do you want to see?',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  const _Label('Clean-up status'),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.0,
                    children: [
                      for (final st in ScanStatus.values)
                        _StatusTile(
                          title: _cap(st.name),
                          hint: _statusHint[st]!,
                          count: widget.scans
                              .where((s) => s.status == st)
                              .length,
                          selected: _f.statuses.contains(st),
                          onTap: () => setState(() {
                            final next = {..._f.statuses};
                            next.contains(st) ? next.remove(st) : next.add(st);
                            _f = _f.copyWith(statuses: next);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _Label('Days'),
                  if (recent.isNotEmpty) ...[
                    SizedBox(
                      height: 68,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: recent.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final day = recent[i];
                          return _DayTile(
                            weekday: loc.narrowWeekdays[day.weekday % 7],
                            day: day.day,
                            scans: _scansOn(day),
                            selected: _dayInRange(day),
                            onTap: () => _tapDay(day),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GlassChip(
                        label: 'Any day',
                        selected: days == null,
                        onTap: () =>
                            setState(() => _f = _f.copyWith(clearDays: true)),
                      ),
                      GlassChip(
                        label: days == null
                            ? 'Pick dates'
                            : '${loc.formatShortMonthDay(days.start)} – '
                                  '${loc.formatShortMonthDay(days.end)}',
                        selected: false,
                        onTap: _pickDays,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const _Label('Containers found'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final r in RiskLevel.values)
                        _RiskPill(
                          risk: r,
                          label: const {
                            RiskLevel.clear: 'None',
                            RiskLevel.some: '1 to 3',
                            RiskLevel.high: '4 or more',
                          }[r]!,
                          selected: _f.risks.contains(r),
                          onTap: () => setState(() {
                            final next = {..._f.risks};
                            next.contains(r) ? next.remove(r) : next.add(r);
                            _f = _f.copyWith(risks: next);
                          }),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: TintButton(
                  label: 'Show $shown ${shown == 1 ? 'scan' : 'scans'}',
                  icon: Icons.map_outlined,
                  height: 48,
                  onPressed: () => Navigator.pop(context, _f),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: Color(0xFF1E3A2D),
        ),
      ),
    );
  }
}

/// One clean-up status: tinted green when shown on the map.
class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.title,
    required this.hint,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String hint;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AedexColors.ink;
    final sub = selected ? const Color(0xD9FFFFFF) : const Color(0xFF3E4943);
    return Semantics(
      checked: selected,
      button: true,
      label: '$title, $count scans',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: selected
            ? tintDecoration(radius: 24)
            : frostDecoration(radius: 24),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: fg,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? const Color(0x33FFFFFF)
                              : Colors.transparent,
                          border: Border.all(
                            color: selected
                                ? Colors.white
                                : const Color(0x5914402F),
                            width: 1.5,
                          ),
                        ),
                        child: selected
                            ? const Icon(
                                Icons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  Text(hint, style: TextStyle(fontSize: 11, color: sub)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day in the strip: weekday letter, date and how many scans.
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.weekday,
    required this.day,
    required this.scans,
    required this.selected,
    required this.onTap,
  });

  final String weekday;
  final int day;
  final int scans;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AedexColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Day $day, $scans scans',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: selected
            ? tintDecoration(radius: 22)
            : frostDecoration(radius: 22),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: SizedBox(
              width: 50,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: fg.withValues(alpha: 0.75),
                    ),
                  ),
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: fg,
                    ),
                  ),
                  Text(
                    '$scans',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: fg.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A risk level toggle with its pin colour as a dot.
class _RiskPill extends StatelessWidget {
  const _RiskPill({
    required this.risk,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final RiskLevel risk;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: selected
            ? tintDecoration(radius: 22)
            : frostDecoration(radius: 22),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AedexColors.forRisk(risk),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AedexColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
