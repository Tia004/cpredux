import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cpredux/widgets/cyber_help_tooltip.dart';
import 'package:cpredux/widgets/dice_3d_table.dart';
import 'package:cpredux/domain/enums.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CyberHelpTooltip Advanced Hover & Bounds Tests', () {
    testWidgets('Hover sopra il ? apre il tooltip e hover sulla bubble lo mantiene aperto', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CyberHelpTooltip(
                title: 'Cyberware Test',
                message: 'Informazioni sui cyberware avanzati.',
                tag: 'Tech',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CyberHelpTooltip), findsOneWidget);
      expect(find.text('CYBERWARE TEST'), findsNothing);

      // Simula puntatore mouse sopra l'icona ?
      final TestGesture gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(CyberHelpTooltip)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // La bubble si è aperta
      expect(find.text('CYBERWARE TEST'), findsOneWidget);
      expect(find.text('Informazioni sui cyberware avanzati.'), findsOneWidget);

      // Muovi il puntatore direttamente all'interno della bubble
      final Offset bubbleCenter = tester.getCenter(find.text('CYBERWARE TEST'));
      await gesture.moveTo(bubbleCenter);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // La bubble DEVE rimanere aperta anche dopo 200ms perché il puntatore è sopra la bubble!
      expect(find.text('CYBERWARE TEST'), findsOneWidget);

      // Ora muovi il puntatore fuori sia dal ? che dalla bubble (es. coordinate 10, 10)
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump();
      // Prima della scadenza del debounce (50ms), è ancora presente
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('CYBERWARE TEST'), findsOneWidget);

      // Dopo la scadenza del debounce timer (> 160ms), la bubble scompare
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('CYBERWARE TEST'), findsNothing);
    });

    testWidgets('Tooltip a bordo schermo non va in overflow orizzontale o verticale', (WidgetTester tester) async {
      // Finestra piccola per testare il clamping
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: <Widget>[
                // Posizionato all'estremo bordo destro superiore (dx: 380, dy: 10)
                Positioned(
                  right: 4,
                  top: 10,
                  child: CyberHelpTooltip(
                    title: 'Bordo Destro',
                    message: 'Spiegazione al bordo estremo.',
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Tap sul tooltip
      await tester.tap(find.text('?'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('BORDO DESTRO'), findsOneWidget);

      // Verifica che la posizione globale del testo sia interamente entro lo schermo [0, 400]
      final Rect titleRect = tester.getRect(find.text('BORDO DESTRO'));
      expect(titleRect.left, greaterThanOrEqualTo(0));
      expect(titleRect.right, lessThanOrEqualTo(400));
      expect(titleRect.top, greaterThanOrEqualTo(0));
      expect(titleRect.bottom, lessThanOrEqualTo(600));
    });
  });

  group('Campaign 3D Dice Integration Tests', () {
    testWidgets('Dice3DTable renderizza correttamente su tavolo 3D con d10 e d6', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 300,
                child: Dice3DTable(
                  die: DiceType.d10,
                  results: <int>[8],
                  total: 13,
                  label: '1D10+5',
                  modifier: 5,
                  isCritical: false,
                  isFumble: false,
                  revealKey: 1,
                  tableHeight: 280.0,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(Dice3DTable), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
      expect(find.text('1D10+5'), findsOneWidget);
    });
  });
}
