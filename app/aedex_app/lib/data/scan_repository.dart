import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/scan.dart';

/// Where the map gets its scans. Today: the sample file bundled with the app.
/// Later (Phase 3) the real model's results come in here, and the map
/// does not need to change.
class ScanRepository {
  ScanRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const sampleAsset = 'assets/sample_scans.json';

  final AssetBundle _bundle;

  Future<List<Scan>> loadScans() async {
    final text = await _bundle.loadString(sampleAsset);
    return parseScans(text);
  }
}

/// Turns the JSON text into Scan objects. Kept separate so tests can call it.
List<Scan> parseScans(String jsonText) {
  final data = jsonDecode(jsonText) as Map<String, dynamic>;
  final list = data['scans'] as List<dynamic>;
  return list
      .map((item) => Scan.fromJson(item as Map<String, dynamic>))
      .toList();
}
