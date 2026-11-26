import 'package:flutter/material.dart';

import 'data/scan_store.dart';
import 'detection/detector.dart';
import 'screens/app_shell.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Real scans only: saved on this phone, starting empty (no sample data).
  final store = ScanStore(PhoneScanStorage())..load();
  runApp(AedexApp(store: store, detector: createDetector()));
}

class AedexApp extends StatelessWidget {
  const AedexApp({super.key, required this.store, required this.detector});

  final ScanStore store;
  final ContainerDetector detector;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aedex',
      debugShowCheckedModeBanner: false,
      theme: buildAedexTheme(),
      home: AppShell(store: store, detector: detector),
    );
  }
}
