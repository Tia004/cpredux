import 'package:cpredux/design/theme.dart';
import 'package:cpredux/widgets/drop_zone.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simula un evento che arriva **dal sistema operativo**.
///
/// Il trascinamento di un file dal Finder non e' riproducibile con `tap` o
/// `drag`: quelli sono eventi interni a Flutter, e la zona di rilascio ascolta
/// il canale nativo `desktop_drop`. Questo test scrive su quel canale, cioe'
/// fa la stessa cosa che fa il sistema operativo quando l'utente lascia il file
/// sopra la finestra. Senza, l'unico modo di sapere se il trascinamento
/// funziona sarebbe provarlo a mano — e una regressione tornerebbe a farsi
/// vedere solo dall'utente.
Future<void> _send(WidgetTester tester, String method, Object? arguments) async {
  final ByteData data = const StandardMethodCodec()
      .encodeMethodCall(MethodCall(method, arguments));
  await tester.binding.defaultBinaryMessenger
      .handlePlatformMessage('desktop_drop', data, (ByteData? _) {});
}

/// Avvicina il file alla zona, come fa il sistema operativo appena il puntatore
/// entra nell'area.
Future<void> _dragOver(WidgetTester tester, Finder zone) async {
  final Offset center = tester.getCenter(zone);
  await _send(tester, 'entered', <double>[center.dx, center.dy]);
  await tester.pump(const Duration(milliseconds: 150));
}

/// Rilascia i file nella zona.
///
/// La forma dell'evento non e' la stessa su tutte le piattaforme: macOS manda
/// `performOperation_macos` con una mappa per file (che distingue anche le
/// cartelle), gli altri `performOperation` con l'elenco dei percorsi. Il test
/// copre entrambe, perche' il programma gira su tutte e tre.
/// La posizione del rilascio arriva dall'evento `entered` precedente: il
/// sistema operativo manda prima dove sta il puntatore, poi cosa e' stato
/// lasciato.
Future<void> _drop(WidgetTester tester, List<Map<String, Object?>> raw) async {
  if (raw.length == 1 && raw.single.containsKey('_paths')) {
    await _send(tester, 'performOperation', raw.single['_paths']);
    return;
  }
  await _send(tester, 'performOperation_macos', raw);
}

Map<String, Object?> _file(String path, {bool isDirectory = false}) =>
    <String, Object?>{'path': path, 'isDirectory': isDirectory, 'fromPromise': false};

Map<String, Object?> _paths(List<String> paths) => <String, Object?>{'_paths': paths};

void main() {
  late List<String> dropped;
  late List<String> rejections;

  Widget host({
    bool enable = true,
    List<String> extensions = const <String>['cpred_sheet'],
  }) {
    return MaterialApp(
      theme: CprTheme.dark(),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 200,
            child: DropZone(
              enable: enable,
              extensions: extensions,
              label: 'Rilascia qui',
              hint: 'scheda del vecchio programma (.cpred_sheet)',
              onDropped: dropped.addAll,
              onRejected: rejections.add,
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  setUp(() {
    dropped = <String>[];
    rejections = <String>[];
  });

  testWidgets('mentre il file e sopra, la zona lo dice', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('RILASCIA QUI'), findsNothing);

    await _dragOver(tester, find.byType(DropZone));

    // Un'area che accetta un rilascio senza segnalarlo lascia l'utente a
    // indovinare se ha trovato il posto giusto.
    expect(find.text('RILASCIA QUI'), findsOneWidget);
    expect(find.textContaining('vecchio programma'), findsOneWidget);

    await _send(tester, 'exited', null);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RILASCIA QUI'), findsNothing);
  });

  testWidgets('una scheda vecchia lasciata sulla zona viene consegnata',
      (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    await _dragOver(tester, find.byType(DropZone));

    await _drop(tester, <Map<String, Object?>>[
      _file('/tmp/Vecchia.cpred_sheet'),
    ]);
    await tester.pump(const Duration(milliseconds: 300));

    expect(dropped, <String>['/tmp/Vecchia.cpred_sheet']);
    expect(rejections, isEmpty);
    // Dopo il rilascio l'avviso sparisce: lasciarlo acceso farebbe credere che
    // il file sia ancora "in volo".
    expect(find.text('RILASCIA QUI'), findsNothing);
  });

  testWidgets('lo stesso rilascio arriva anche nel formato delle altre piattaforme',
      (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    await _dragOver(tester, find.byType(DropZone));

    await _drop(tester, <Map<String, Object?>>[
      _paths(<String>['/tmp/Vecchia.cpred_sheet']),
    ]);
    await tester.pump(const Duration(milliseconds: 300));

    expect(dropped, <String>['/tmp/Vecchia.cpred_sheet']);
  });

  testWidgets('un file di un altro tipo viene rifiutato e il motivo viene detto',
      (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    await _dragOver(tester, find.byType(DropZone));

    await _drop(tester, <Map<String, Object?>>[
      _file('/tmp/Vecchia.cpredux'),
    ]);
    await tester.pump(const Duration(milliseconds: 300));

    // Il caso peggiore non e' il rifiuto: e' il rifiuto **in silenzio**, che
    // sembra un difetto del programma.
    expect(dropped, isEmpty);
    expect(rejections.single, contains('.cpred_sheet'));
    expect(rejections.single, contains('Vecchia.cpredux'));
  });

  testWidgets('una cartella viene rifiutata con il suo motivo', (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    await _dragOver(tester, find.byType(DropZone));

    await _drop(tester, <Map<String, Object?>>[
      _file('/tmp/Schede vecchie', isDirectory: true),
    ]);
    await tester.pump(const Duration(milliseconds: 300));

    expect(dropped, isEmpty);
    expect(rejections.single, contains('cartella'));
  });

  testWidgets('se una delle schede e buona, le altre non vengono perse in silenzio',
      (WidgetTester tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 300));
    await _dragOver(tester, find.byType(DropZone));

    await _drop(tester, <Map<String, Object?>>[
      _file('/tmp/Buona.cpred_sheet'),
      _file('/tmp/Altra.cpred_sheet'),
    ]);
    await tester.pump(const Duration(milliseconds: 300));

    // Arrivano tutte: chi decide quante convertirne e' la schermata, che sa
    // spiegare all'utente cosa e' stato fatto delle altre.
    expect(dropped, <String>['/tmp/Buona.cpred_sheet', '/tmp/Altra.cpred_sheet']);
  });

  testWidgets('con un dialogo aperto la zona non riceve piu niente',
      (WidgetTester tester) async {
    // La libreria avvisa di questo: una zona coperta continua a ricevere i
    // rilasci, quindi un file lasciato sul dialogo di conversione finirebbe
    // sulla zona sotto, che l'utente non sta guardando.
    await tester.pumpWidget(host(enable: false));
    await tester.pump(const Duration(milliseconds: 300));
    await _dragOver(tester, find.byType(DropZone));

    await _drop(tester, <Map<String, Object?>>[
      _file('/tmp/Vecchia.cpred_sheet'),
    ]);
    await tester.pump(const Duration(milliseconds: 300));

    expect(dropped, isEmpty);
    expect(find.text('RILASCIA QUI'), findsNothing);
  });
}
