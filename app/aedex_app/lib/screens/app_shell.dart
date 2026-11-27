import 'package:flutter/material.dart';

import '../data/scan_store.dart';
import '../detection/detector.dart';
import '../filters/scan_filter.dart';
import '../models/scan.dart';
import '../theme.dart';
import '../widgets/glass_panel.dart';
import 'filter_screen.dart';
import 'home_screen.dart';
import 'hotspots_screen.dart';
import 'map_screen.dart';
import 'scan_screen.dart';

/// The four tabs and the floating glass tab bar. Owns the shared state:
/// which tab is open and the map filter. Scans live in [ScanStore].
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.store, required this.detector});

  final ScanStore store;
  final ContainerDetector detector;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const _home = 0, _map = 1, _scan = 2, _hotspots = 3;

  int _tab = _home;
  ScanFilter _filter = ScanFilter.all;
  final _focus = ValueNotifier<String?>(null);

  void _showOnMap(String id) {
    // A scan hidden by the filter would not show up: reset the filter.
    final scan = widget.store.byId(id);
    if (scan != null && !_filter.matches(scan)) _filter = ScanFilter.all;
    setState(() => _tab = _map);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.value = id);
  }

  Future<void> _openFilters() async {
    final result = await Navigator.of(context).push<ScanFilter>(
      MaterialPageRoute(
        builder: (_) =>
            FilterScreen(initial: _filter, scans: widget.store.scans),
      ),
    );
    if (result != null) setState(() => _filter = result);
  }

  Future<void> _saveScan(Scan scan) async {
    await widget.store.add(scan);
    _showOnMap(scan.id);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final store = widget.store;
        if (!store.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final all = store.scans;
        return Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _tab,
            children: [
              HomeScreen(
                scans: all,
                onOpenScan: () => setState(() => _tab = _scan),
                onOpenHotspots: () => setState(() => _tab = _hotspots),
                onShowOnMap: _showOnMap,
              ),
              MapScreen(
                allScans: all,
                filter: _filter,
                onFilterChanged: (f) => setState(() => _filter = f),
                onOpenFilters: _openFilters,
                onAdvance: store.advanceStatus,
                focus: _focus,
              ),
              ScanScreen(detector: widget.detector, onSave: _saveScan),
              HotspotsScreen(scans: all),
            ],
          ),
          bottomNavigationBar: _GlassTabBar(
            index: _tab,
            onSelect: (i) => setState(() => _tab = i),
          ),
        );
      },
    );
  }
}

class _GlassTabBar extends StatelessWidget {
  const _GlassTabBar({required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.map_outlined, Icons.map, 'Map'),
    (Icons.photo_camera_outlined, Icons.photo_camera, 'Scan'),
    (Icons.blur_circular_outlined, Icons.blur_circular, 'Hotspots'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: GlassPanel(
        tinted: false,
        borderRadius: 28,
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: _items[i].$3,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => onSelect(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        // Butter marks the open tab; ink on butter is the
                        // brand's readable pair.
                        color: i == index
                            ? AedexColors.butter
                            : Colors.transparent,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == index ? _items[i].$2 : _items[i].$1,
                            size: 20,
                            color: i == index
                                ? AedexColors.ink
                                : AedexColors.muted,
                          ),
                          Text(
                            _items[i].$3,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: i == index
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: i == index
                                  ? AedexColors.ink
                                  : AedexColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
