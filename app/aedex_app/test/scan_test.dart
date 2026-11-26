import 'dart:io';

import 'package:aedex_app/data/scan_store.dart';
import 'package:aedex_app/models/scan.dart';
import 'package:aedex_app/widgets/scan_card.dart';
import 'package:aedex_app/widgets/scan_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('riskFor', () {
    test('0 is clear, 1-3 is some, 4+ is high', () {
      expect(riskFor(0), RiskLevel.clear);
      expect(riskFor(1), RiskLevel.some);
      expect(riskFor(3), RiskLevel.some);
      expect(riskFor(4), RiskLevel.high);
      expect(riskFor(10), RiskLevel.high);
    });
  });

  group('sample_scans.json', () {
    final scans = parseScans(File('../sample_scans.json').readAsStringSync());

    test('loads all 10 scans', () {
      expect(scans, hasLength(10));
    });

    test('reads counts, totals, status and precision', () {
      final s6 = scans.firstWhere((s) => s.id == 'scan-006');
      expect(s6.counts, {'Drain-Inlet': 2, 'Bottle': 6, 'Cup': 2});
      expect(s6.totalContainers, 10);
      expect(s6.risk, RiskLevel.high);
      expect(s6.status, ScanStatus.reported);
      expect(s6.precision, LocationPrecision.exact);
    });

    test('a scan with no containers is clear', () {
      final s5 = scans.firstWhere((s) => s.id == 'scan-005');
      expect(s5.totalContainers, 0);
      expect(s5.risk, RiskLevel.clear);
    });

    test('only known class names appear', () {
      const classes = {
        'Bottle',
        'Coconut-Exocarp',
        'Drain-Inlet',
        'Tire',
        'Vase',
        'Cup',
        'Plastic-Container',
        'Pail-Basin',
      };
      for (final s in scans) {
        expect(classes.containsAll(s.counts.keys), isTrue, reason: s.id);
      }
    });

    test('a scan survives saving and loading (toJson / fromJson)', () {
      final again = parseScans(encodeScans(scans));
      expect(again, hasLength(scans.length));
      for (var i = 0; i < scans.length; i++) {
        expect(again[i].toJson(), scans[i].toJson());
      }
    });
  });

  testWidgets('ScanCard shows counts, date and status', (tester) async {
    final scan = Scan.fromJson({
      'id': 'scan-001',
      'time': '2026-11-18T07:40:00+08:00',
      'lat': 14.6011,
      'lng': 120.9855,
      'location_precision': 'street',
      'counts': {'Tire': 2, 'Cup': 3},
      'status': 'reported',
    });
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScanCard(scan: scan, onClose: () => closed = true),
        ),
      ),
    );

    expect(find.text('Scan 001 · 5 containers'), findsOneWidget);
    expect(find.text('Tire'), findsOneWidget);
    expect(find.text('Cup'), findsOneWidget);
    expect(find.textContaining('Street level'), findsOneWidget);
    expect(find.textContaining(formatScanTime(scan.time)), findsOneWidget);
    expect(find.text('Reported'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    expect(closed, isTrue);
  });

  testWidgets('ScanPin shows the total and reacts to a tap', (tester) async {
    final scan = Scan.fromJson({
      'id': 'scan-009',
      'time': '2026-11-21T07:05:00+08:00',
      'lat': 14.6033,
      'lng': 120.9877,
      'location_precision': 'exact',
      'counts': {'Tire': 3, 'Plastic-Container': 4, 'Bottle': 3},
      'status': 'reported',
    });
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: ScanPin(
              scan: scan,
              selected: false,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('10'), findsOneWidget);
    await tester.tap(find.byType(ScanPin));
    expect(tapped, isTrue);
  });
}
