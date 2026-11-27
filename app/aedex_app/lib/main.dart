import 'package:flutter/material.dart';

import 'data/scan_store.dart';
import 'detection/detector.dart';
import 'screens/app_shell.dart';
import 'screens/intro_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Real scans only: saved on this phone, starting empty (no sample data).
  final store = ScanStore(PhoneScanStorage())..load();
  // The intro shows once; the answer is read before the first frame.
  final showIntro = !await IntroMemory.seen();
  runApp(
    AedexApp(store: store, detector: createDetector(), showIntro: showIntro),
  );
}

class AedexApp extends StatefulWidget {
  const AedexApp({
    super.key,
    required this.store,
    required this.detector,
    this.showIntro = false,
  });

  final ScanStore store;
  final ContainerDetector detector;
  final bool showIntro;

  @override
  State<AedexApp> createState() => _AedexAppState();
}

class _AedexAppState extends State<AedexApp> {
  late bool _intro = widget.showIntro;

  void _finishIntro() {
    IntroMemory.markSeen();
    setState(() => _intro = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aedex',
      debugShowCheckedModeBanner: false,
      theme: buildAedexTheme(),
      home: _intro
          ? IntroScreen(onDone: _finishIntro)
          : AppShell(store: widget.store, detector: widget.detector),
    );
  }
}
