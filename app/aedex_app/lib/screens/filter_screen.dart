import 'package:flutter/material.dart';

import '../filters/scan_filter.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glass_background.dart';

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

  void _lastDays(int n) {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(
      () => _f = _f.copyWith(
        days: DateTimeRange(
          start: today.subtract(Duration(days: n - 1)),
          end: today,
        ),
      ),
    );
  }

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final shown = _f.apply(widget.scans).length;
    final loc = MaterialLocalizations.of(context);
    final days = _f.days;

    return Scaffold(
      body: GlassBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() => _f = ScanFilter.all),
                      child: const Text('Reset all'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(4, 4, 4, 16),
                      child: Text(
                        'What do you want to see?',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _Section(
                      title: 'Clean-up status',
                      child: Column(
                        children: [
                          for (final st in ScanStatus.values)
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _f.statuses.contains(st),
                              title: Text(
                                _cap(st.name),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(_statusHint[st]!),
                              secondary: Text(
                                '${widget.scans.where((s) => s.status == st).length}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onChanged: (on) => setState(() {
                                final next = {..._f.statuses};
                                on == true ? next.add(st) : next.remove(st);
                                _f = _f.copyWith(statuses: next);
                              }),
                            ),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'Days',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Any day'),
                            selected: days == null,
                            onSelected: (_) => setState(
                              () => _f = _f.copyWith(clearDays: true),
                            ),
                          ),
                          ActionChip(
                            label: const Text('Last 7 days'),
                            onPressed: () => _lastDays(7),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.date_range, size: 18),
                            label: Text(
                              days == null
                                  ? 'Pick dates'
                                  : '${loc.formatShortMonthDay(days.start)} – '
                                        '${loc.formatShortMonthDay(days.end)}',
                            ),
                            onPressed: _pickDays,
                          ),
                        ],
                      ),
                    ),
                    _Section(
                      title: 'Containers found',
                      child: Wrap(
                        spacing: 8,
                        children: [
                          for (final r in RiskLevel.values)
                            FilterChip(
                              avatar: CircleAvatar(
                                backgroundColor: AedexColors.forRisk(r),
                                radius: 6,
                              ),
                              label: Text(
                                const {
                                  RiskLevel.clear: 'None',
                                  RiskLevel.some: '1 to 3',
                                  RiskLevel.high: '4 or more',
                                }[r]!,
                              ),
                              selected: _f.risks.contains(r),
                              onSelected: (on) => setState(() {
                                final next = {..._f.risks};
                                on ? next.add(r) : next.remove(r);
                                _f = _f.copyWith(risks: next);
                              }),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(context, _f),
                    icon: const Icon(Icons.map_outlined),
                    label: Text('Show $shown ${shown == 1 ? 'scan' : 'scans'}'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
