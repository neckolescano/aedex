import 'package:flutter/material.dart';

import '../models/scan.dart';
import '../theme.dart';

/// One round pin on the map: coloured by risk, showing the container count.
class ScanPin extends StatelessWidget {
  const ScanPin({
    super.key,
    required this.scan,
    required this.selected,
    required this.onTap,
  });

  final Scan scan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final risk = scan.risk;
    final total = scan.totalContainers;
    return Semantics(
      button: true,
      selected: selected,
      label: '${scanLabel(scan)}, $total containers, ${scan.status.name}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            // A light spot near the top-left makes the pin look like a
            // glossy drop of glass.
            gradient: RadialGradient(
              center: const Alignment(-0.35, -0.45),
              radius: 0.9,
              colors: [
                Color.lerp(AedexColors.forRisk(risk), Colors.white, 0.45)!,
                AedexColors.forRisk(risk),
              ],
              stops: const [0, 0.6],
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AedexColors.brand : const Color(0xE6FFFFFF),
              width: selected ? 4 : 2.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x47141E19),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$total',
            style: TextStyle(
              color: AedexColors.onRisk(risk),
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// "scan-006" -> "Scan 006"
String scanLabel(Scan scan) => 'Scan ${scan.id.replaceFirst('scan-', '')}';
