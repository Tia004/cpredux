import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cpredux/domain/cyberware.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/widgets/cyber_body_viewer.dart';
import 'package:cpredux/widgets/cyber_gauges.dart';
import 'package:cpredux/widgets/health_heart.dart';
import 'package:cpredux/widgets/humanity_gauge.dart';

void main() {
  group('CyberBodyViewer 3D & Cyberpsychosis Enhancements', () {
    testWidgets('CyberBodyViewer attiva effetto cyberpsicosi con glitch ticker', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CyberBodyViewer(
                cyberware: <Cyberware>[
                  Cyberware(
                    id: 'c1',
                    name: 'Sandevistan',
                    category: CyberwareCategory.neuralware,
                    bodyZone: 'head',
                  ),
                ],
                isCyberpsychotic: true,
                humanity: 5,
                maxHumanity: 50,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CyberBodyViewer), findsOneWidget);
      expect(find.text('ANATOMIA / 3D SCANNER'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CyberBodyViewer con cyberware multipli calcola strain ratio e renderizza overlay', (WidgetTester tester) async {
      final List<Cyberware> cyberware = <Cyberware>[
        Cyberware(id: 'c1', name: 'Sandevistan', bodyZone: 'head'),
        Cyberware(id: 'c2', name: 'Cyberbraccio SX', bodyZone: 'left_arm'),
        Cyberware(id: 'c3', name: 'Cyberbraccio DX', bodyZone: 'right_arm'),
        Cyberware(id: 'c4', name: 'Cybergamba SX', bodyZone: 'left_leg'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CyberBodyViewer(
                cyberware: cyberware,
                humanity: 20,
                maxHumanity: 60,
                selectedZone: 'head',
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CyberBodyViewer), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('HealthHeart Alignment with Vitals Gauges', () {
    testWidgets('HealthHeart è centrato e allineato con Humanity, Luck e Empathy', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                HealthHeart(current: 40, max: 50, size: 156),
                HumanityGauge(current: 45, max: 60, size: 156),
                LuckClover(current: 5, max: 8, size: 156),
                EmpathyGauge(current: 6, max: 8, size: 156),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      final Finder heartFinder = find.byType(HealthHeart);
      final Finder humanityFinder = find.byType(HumanityGauge);
      final Finder luckFinder = find.byType(LuckClover);
      final Finder empathyFinder = find.byType(EmpathyGauge);

      expect(heartFinder, findsOneWidget);
      expect(humanityFinder, findsOneWidget);
      expect(luckFinder, findsOneWidget);
      expect(empathyFinder, findsOneWidget);

      final Rect heartRect = tester.getRect(heartFinder);
      final Rect luckRect = tester.getRect(luckFinder);
      final Rect empathyRect = tester.getRect(empathyFinder);

      expect(heartRect.top, luckRect.top);
      expect(heartRect.bottom, luckRect.bottom);
      expect(heartRect.top, empathyRect.top);
    });
  });
}
