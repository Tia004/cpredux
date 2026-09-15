import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cpredux/domain/cyberware.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/modifiers.dart';
import 'package:cpredux/widgets/cyber_body_viewer.dart';
import 'package:cpredux/widgets/humanity_gauge.dart';

void main() {
  group('Cyberware Domain & Slots Logic Tests', () {
    test('defaultFoundationSlotsFor restituisce gli slot da manuale CP RED', () {
      expect(defaultFoundationSlotsFor(CyberwareCategory.neuralware), 5); // Neural Link: 5 slot
      expect(defaultFoundationSlotsFor(CyberwareCategory.cyberoptics), 3); // Cyberocchio: 3 slot
      expect(defaultFoundationSlotsFor(CyberwareCategory.cyberaudio), 3); // Cyberaudio: 3 slot
      expect(defaultFoundationSlotsFor(CyberwareCategory.cyberlimbs, 'Cyberbraccio'), 4); // Cyberbraccio: 4 slot
      expect(defaultFoundationSlotsFor(CyberwareCategory.cyberlimbs, 'Cybergamba'), 3); // Cybergamba: 3 slot
    });

    test('defaultBodyZoneFor assegna correttamente le zone anatomiche', () {
      expect(defaultBodyZoneFor(CyberwareCategory.neuralware), 'head');
      expect(defaultBodyZoneFor(CyberwareCategory.cyberoptics), 'eyes');
      expect(defaultBodyZoneFor(CyberwareCategory.cyberaudio), 'ears');
      expect(defaultBodyZoneFor(CyberwareCategory.cyberlimbs, 'Cyberbraccio'), 'arms');
      expect(defaultBodyZoneFor(CyberwareCategory.cyberlimbs, 'Cybergamba'), 'legs');
      expect(defaultBodyZoneFor(CyberwareCategory.cyberlimbs, 'Cybermano con Artigli'), 'hands');
      expect(defaultBodyZoneFor(CyberwareCategory.externalCyberware), 'skin');
      expect(defaultBodyZoneFor(CyberwareCategory.internalCyberware), 'torso');
    });

    test('CyberBodyZone enum risolve correttamente da id stringa', () {
      expect(CyberBodyZone.fromId('head'), CyberBodyZone.head);
      expect(CyberBodyZone.fromId('EYES'), CyberBodyZone.eyes);
      expect(CyberBodyZone.fromId('unknown'), CyberBodyZone.torso); // Fallback sicuro
    });

    test('Calcolo capienza e saturazione slot (TUTTI GLI SLOT OCCUPATI)', () {
      // 1. Componente fondamentale: Cyberocchio con 3 slot
      final Cyberware cybereye = Cyberware(
        id: 'eye_01',
        name: 'Cyberocchio Sinistro',
        category: CyberwareCategory.cyberoptics,
        isFoundational: true,
        optionSlots: 3,
        slotsRequired: 0,
        bodyZone: 'eyes',
      );

      // 2. Opzione 1: Teleobiettivo (1 slot)
      final Cyberware opt1 = Cyberware(
        id: 'opt_01',
        name: 'Teleobiettivo',
        category: CyberwareCategory.cyberoptics,
        isFoundational: false,
        slotsRequired: 1,
        parentFoundationId: 'eye_01',
        bodyZone: 'eyes',
      );

      // 3. Opzione 2: Visione Notturna (1 slot)
      final Cyberware opt2 = Cyberware(
        id: 'opt_02',
        name: 'Visione Notturna',
        category: CyberwareCategory.cyberoptics,
        isFoundational: false,
        slotsRequired: 1,
        parentFoundationId: 'eye_01',
        bodyZone: 'eyes',
      );

      final List<Cyberware> installed = <Cyberware>[cybereye, opt1, opt2];

      // Slot usati finora: 2 su 3
      int used = installed
          .where((Cyberware c) => c.parentFoundationId == cybereye.id)
          .fold<int>(0, (int sum, Cyberware c) => sum + c.slotsRequired);
      expect(used, 2);
      expect(used >= cybereye.optionSlots, isFalse);

      // 4. Terza opzione: Dartgun oculare (1 slot) -> satura gli slot!
      final Cyberware opt3 = Cyberware(
        id: 'opt_03',
        name: 'Micro-Dartgun Oculare',
        category: CyberwareCategory.cyberoptics,
        isFoundational: false,
        slotsRequired: 1,
        parentFoundationId: 'eye_01',
        bodyZone: 'eyes',
      );
      installed.add(opt3);

      used = installed
          .where((Cyberware c) => c.parentFoundationId == cybereye.id)
          .fold<int>(0, (int sum, Cyberware c) => sum + c.slotsRequired);
      expect(used, 3);
      expect(used >= cybereye.optionSlots, isTrue); // TUTTI GLI SLOT OCCUPATI!

      // Se proviamo a verificare una quarta opzione (1 slot aggiuntivo) su una base piena:
      const int candidateSlots = 1;
      final bool isOvercapacity = (used + candidateSlots) > cybereye.optionSlots;
      expect(isOvercapacity, isTrue);
    });

    test('Serializzazione e deserializzazione JSON di Cyberware con slot e bodyZone', () {
      final Cyberware original = Cyberware(
        id: 'neural_01',
        name: 'Collegamento Neuronale',
        category: CyberwareCategory.neuralware,
        isFoundational: true,
        optionSlots: 5,
        slotsRequired: 0,
        bodyZone: 'head',
        humanityLost: 7,
        proficiencyModifiers: <ProficiencyModifier>[
          ProficiencyModifier(proficiencyId: 'lang_japanese', value: 2),
        ],
      );

      final Map<String, Object?> json = original.toJson();
      expect(json['isFoundational'], isTrue);
      expect(json['optionSlots'], 5);
      expect(json['slotsRequired'], 0);
      expect(json['bodyZone'], 'head');

      final Cyberware restored = Cyberware.fromJson(json);
      expect(restored.id, 'neural_01');
      expect(restored.name, 'Collegamento Neuronale');
      expect(restored.isFoundational, isTrue);
      expect(restored.optionSlots, 5);
      expect(restored.slotsRequired, 0);
      expect(restored.bodyZone, 'head');
      expect(restored.humanityLost, 7);
      expect(restored.proficiencyModifiers.length, 1);
      expect(restored.proficiencyModifiers.first.proficiencyId, 'lang_japanese');
      expect(restored.proficiencyModifiers.first.value, 2);
    });
  });

  group('CyberBodyViewer & HumanityGauge UI Tests', () {
    testWidgets('CyberBodyViewer si renderizza correttamente e supporta layer e filtri zona', (WidgetTester tester) async {
      String? selectedZone;
      String? installedZoneId;

      final List<Cyberware> cyberware = <Cyberware>[
        Cyberware(
          id: 'c1',
          name: 'Neural Link',
          category: CyberwareCategory.neuralware,
          isFoundational: true,
          optionSlots: 5,
          bodyZone: 'head',
          humanityLost: 7,
        ),
        Cyberware(
          id: 'c2',
          name: 'Cyberbraccio Destro',
          category: CyberwareCategory.cyberlimbs,
          isFoundational: true,
          optionSlots: 4,
          bodyZone: 'arms',
          humanityLost: 7,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CyberBodyViewer(
                cyberware: cyberware,
                selectedZone: selectedZone,
                onZoneSelected: (String? z) => selectedZone = z,
                onInstallInZone: (String z) => installedZoneId = z,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(CyberBodyViewer), findsOneWidget);
      expect(find.text('DIAGNOSTICA CORPOREA // BIO-CYBER SCANNER'), findsOneWidget);
      expect(find.text('ONLINE'), findsOneWidget);

      // Verifica i pulsanti dei layer anatomici
      expect(find.text('TUTTI I SISTEMI'), findsOneWidget);
      expect(find.text('SCHELETRO'), findsOneWidget);
      expect(find.text('VASCOLARE'), findsOneWidget);
      expect(find.text('NERVOSO'), findsOneWidget);

      // Clicca sul layer "SCHELETRO"
      await tester.tap(find.text('SCHELETRO'));
      await tester.pump();

      // Clicca sulla callout "TESTA" per selezionarla
      await tester.tap(find.text('TESTA'));
      await tester.pump();
      expect(selectedZone, 'head');
    });

    testWidgets('HumanityGauge renderizza la silhouette neon della testa e non va in overflow', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: HumanityGauge(
                current: 45,
                max: 60,
                size: 190,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HumanityGauge), findsOneWidget);
      expect(find.text('45'), findsOneWidget);
      expect(find.text('/ 60'), findsOneWidget);
      expect(find.text('-15 PERSA'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
