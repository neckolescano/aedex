import 'dart:io';

import 'package:aedex_app/data/scan_store.dart';
import 'package:aedex_app/filters/scan_filter.dart';
import 'package:aedex_app/hotspots/zones.dart';
import 'package:aedex_app/models/scan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The sample file is used ONLY as test data; the app itself starts empty.
  final sample = parseScans(File('../sample_scans.json').readAsStringSync());

  group('ScanStore', () {
    test('starts empty when nothing is saved', () async {
      final store = ScanStore(MemoryScanStorage());
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.scans, isEmpty);
    });

    test('adds, saves and loads again, newest first', () async {
      final storage = MemoryScanStorage();
      final store = ScanStore(storage);
      await store.load();
      for (final s in sample) {
        await store.add(s);
      }
      final again = ScanStore(storage);
      await again.load();
      expect(again.scans, hasLength(10));
      expect(again.scans.first.id, 'scan-010'); // Nov 21, 4:20 PM
    });

    test(
      'moves a scan along the clean-up flow and stops at verified',
      () async {
        final store = ScanStore(MemoryScanStorage());
        await store.load();
        await store.add(sample.first); // reported
        for (final expected in [
          ScanStatus.assigned,
          ScanStatus.cleaned,
          ScanStatus.verified,
          ScanStatus.verified,
        ]) {
          await store.advanceStatus('scan-001');
          expect(store.byId('scan-001')!.status, expected);
        }
      },
    );
  });

  group('findZones', () {
    test('groups nearby scans and ranks by containers waiting', () {
      final zones = findZones(sample);
      expect(zones, isNotEmpty);
      expect(zones.first.name, 'Zone A');
      for (var i = 1; i < zones.length; i++) {
        expect(zones[i - 1].waiting >= zones[i].waiting, isTrue);
      }
      // Every scan lands in exactly one zone.
      expect(zones.fold(0, (n, z) => n + z.scans.length), sample.length);
    });

    test('cleaned and verified scans do not count as waiting', () {
      final done = sample
          .where(
            (s) =>
                s.status == ScanStatus.cleaned ||
                s.status == ScanStatus.verified,
          )
          .toList();
      expect(findZones(done).every((z) => z.waiting == 0), isTrue);
    });

    test('no scans, no zones', () => expect(findZones(const []), isEmpty));
  });

  group('ScanFilter', () {
    test('shows everything by default', () {
      expect(ScanFilter.all.apply(sample), hasLength(10));
      expect(ScanFilter.all.activeCount, 0);
    });

    test('status: only reported', () {
      final f = ScanFilter.all.copyWith(statuses: {ScanStatus.reported});
      expect(f.apply(sample), hasLength(5));
      expect(f.activeCount, 1);
    });

    test('risk: only 4 or more', () {
      final f = ScanFilter.all.copyWith(risks: {RiskLevel.high});
      expect(f.apply(sample).every((s) => s.totalContainers >= 4), isTrue);
    });

    test('days: Nov 21 only', () {
      final f = ScanFilter.all.copyWith(
        days: DateTimeRange(
          start: DateTime(2026, 11, 21),
          end: DateTime(2026, 11, 21),
        ),
      );
      // Times are compared in the phone's own time zone.
      final expected = sample.where((s) {
        final t = s.time.toLocal();
        return t.year == 2026 && t.month == 11 && t.day == 21;
      }).length;
      expect(f.apply(sample), hasLength(expected));
    });
  });
}
