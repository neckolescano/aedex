import 'package:flutter/material.dart';

import 'screens/map_screen.dart';
import 'theme.dart';

void main() {
  runApp(const AedexApp());
}

class AedexApp extends StatelessWidget {
  const AedexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aedex',
      debugShowCheckedModeBanner: false,
      theme: buildAedexTheme(),
      home: const MapScreen(),
    );
  }
}
