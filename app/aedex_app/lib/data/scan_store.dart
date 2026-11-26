import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/scan.dart';

/// Where saved scans live. Today: on this phone. Later, a shared server
/// (so a whole barangay sees one map) only needs a new [ScanStorage].
abstract class ScanStorage {
  Future<String?> read();
  Future<void> write(String json);
}

/// Saves the scans as one JSON text on the phone (shared_preferences).
class PhoneScanStorage implements ScanStorage {
  static const _key = 'aedex_scans_v1';

  @override
  Future<String?> read() async =>
      (await SharedPreferences.getInstance()).getString(_key);

  @override
  Future<void> write(String json) async =>
      (await SharedPreferences.getInstance()).setString(_key, json);
}

/// Keeps scans in memory only. Used by tests.
class MemoryScanStorage implements ScanStorage {
  MemoryScanStorage([this.saved]);
  String? saved;

  @override
  Future<String?> read() async => saved;

  @override
  Future<void> write(String json) async => saved = json;
}

/// The app's list of real scans. Screens listen to it and redraw when a
/// scan is added or its status changes ([ChangeNotifier]).
class ScanStore extends ChangeNotifier {
  ScanStore(this._storage);

  final ScanStorage _storage;
  List<Scan> _scans = const [];
  bool _loaded = false;

  /// Newest first.
  List<Scan> get scans => _scans;
  bool get isLoaded => _loaded;

  Future<void> load() async {
    final text = await _storage.read();
    _scans = text == null ? [] : parseScans(text);
    _sort();
    _loaded = true;
    notifyListeners();
  }

  Future<void> add(Scan scan) async {
    _scans = [scan, ..._scans];
    _sort();
    await _save();
  }

  /// Moves a scan one step along reported -> assigned -> cleaned -> verified.
  Future<void> advanceStatus(String id) async {
    _scans = [
      for (final s in _scans)
        if (s.id == id && nextStatus(s.status) != null)
          s.copyWith(status: nextStatus(s.status))
        else
          s,
    ];
    await _save();
  }

  Scan? byId(String id) {
    for (final s in _scans) {
      if (s.id == id) return s;
    }
    return null;
  }

  void _sort() => _scans.sort((a, b) => b.time.compareTo(a.time));

  Future<void> _save() async {
    notifyListeners();
    await _storage.write(encodeScans(_scans));
  }
}

/// JSON text -> scans. Accepts the `{"scans": [...]}` shape of the task file.
List<Scan> parseScans(String jsonText) {
  final data = jsonDecode(jsonText) as Map<String, dynamic>;
  final list = data['scans'] as List<dynamic>;
  return list
      .map((item) => Scan.fromJson(item as Map<String, dynamic>))
      .toList();
}

String encodeScans(List<Scan> scans) => jsonEncode({
  'scans': [for (final s in scans) s.toJson()],
});
