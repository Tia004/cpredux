import 'dart:io';

import 'package:cpredux/app/app.dart';
import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/data/app_paths.dart';
import 'package:cpredux/design/theme.dart';
import 'package:cpredux/features/settings/settings_screen.dart';
import 'package:cpredux/widgets/inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Avanza a fotogrammi, come un'applicazione vera.
///
/// Non si usa `pumpAndSettle`: il pallino \"tavolo aperto\" e il cuore hanno
/// controller in `repeat()`, e \"aspetta che tutto si fermi\" non finirebbe mai.
Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

Future<void> _disposeTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

/// La riga che contiene un'etichetta, per non dover contare le occorrenze di
/// \"Attivo\" e \"Spento\", che nell'elenco compaiono quattro volte.
Finder _rowOf(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(Row)).first;

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('cpredux_settings_test');
    AppPaths.overrideForTesting(
      config: temp.path,
      data: temp.path,
      documents: temp.path,
    );
  });

  tearDown(() {
    AppPaths.clearOverrides();
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  group('impostazioni', () {
    Future<AppState> openSettings(WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await _settle(tester);
      return state;
    }

    // Il caso che ha fatto cadere l'applicazione: la schermata non si
    // costruiva, e il sintomo era \"crasha quando apro le impostazioni\".
    testWidgets('la schermata si costruisce senza eccezioni', (WidgetTester tester) async {
      await openSettings(tester);

      expect(find.text('IMPOSTAZIONI'), findsOneWidget);
      // I titoli dei pannelli sono in maiuscolo: e' il registro "tecnico"
      // dell'intestazione, uguale in tutta l'applicazione.
      expect(find.text('GIOCO E CALCOLO'), findsOneWidget);
      expect(find.text('DOVE SONO I TUOI FILE'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('mostra i percorsi veri, non delle costanti', (WidgetTester tester) async {
      await openSettings(tester);

      // I percorsi sono l'unico modo di sapere dove sono finiti i propri file:
      // se fossero sbagliati, il pannello mentirebbe.
      expect(find.text(temp.path), findsWidgets);

      await _disposeTree(tester);
    });

    testWidgets('i tre interruttori comandano le impostazioni giuste',
        (WidgetTester tester) async {
      final AppState state = await openSettings(tester);

      expect(state.settings.autosave, isTrue);

      await tester.tap(
        find.descendant(of: _rowOf('Salvataggio automatico'), matching: find.text('SPENTO')),
      );
      await _settle(tester);
      expect(state.settings.autosave, isFalse);

      await tester.tap(
        find.descendant(of: _rowOf('Calcolo automatico del carico'), matching: find.text('SPENTO')),
      );
      await _settle(tester);
      expect(state.settings.enableLoad, isFalse);

      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('una finestra stretta non manda in overflow la schermata',
        (WidgetTester tester) async {
      final AppState state = AppState();
      addTearDown(state.dispose);

      tester.view.physicalSize = const Size(880, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        AppScope(
          state: state,
          child: MaterialApp(
            theme: CprTheme.dark(),
            home: const Scaffold(body: SettingsScreen()),
          ),
        ),
      );
      await _settle(tester);

      // A 880 px il selettore a segmenti sta ancora accanto alla sua etichetta:
      // il caso interessante e' proprio quello stretto, perche' una riga
      // "etichetta + controllo" e' la prima cosa che non ci sta piu'.
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });

    testWidgets('dalla schermata iniziale si arriva alle impostazioni',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const CpredApp());
      await _settle(tester);

      await tester.tap(find.text('Impostazioni'));
      await _settle(tester);

      expect(find.text('IMPOSTAZIONI'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await _disposeTree(tester);
    });
  });

  group('selettore a segmenti', () {
    /// Due etichette di lunghezza diversa: serve a verificare che i segmenti
    /// finiscano della **stessa** larghezza.
    Widget segmented({ValueChanged<bool>? onChanged}) => TechSegmented<bool>(
          value: true,
          items: const <bool>[true, false],
          labelOf: (bool v) => v ? 'Nascondibile' : 'Visibile',
          onChanged: onChanged ?? (_) {},
        );

    testWidgets('in una riga si stringe sulle etichette invece di cadere',
        (WidgetTester tester) async {
      // **Il caso che faceva cadere le impostazioni.** In una `Row` un figlio
      // non flessibile riceve larghezza illimitata: un controllo che usa
      // `Expanded` non e' impaginabile li' dentro.
      await tester.pumpWidget(
        MaterialApp(
          theme: CprTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 600,
              child: Row(
                children: <Widget>[
                  const Expanded(child: Text('Un etichetta lunga a sufficienza')),
                  segmented(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);

      final double width = tester.getSize(find.byType(TechSegmented<bool>)).width;
      final Finder segments = find.descendant(
        of: find.byType(TechSegmented<bool>),
        matching: find.byType(AnimatedContainer),
      );
      final double first = tester.getSize(segments.at(0)).width;
      final double second = tester.getSize(segments.at(1)).width;
      final double longestLabel = tester.getSize(find.text('NASCONDIBILE')).width;

      // I due segmenti sono uguali fra loro e larghi quanto l'etichetta piu'
      // lunga, e il controllo **non** occupa i 600 px disponibili: si stringe.
      //
      // Il confronto con la larghezza dell'etichetta ha qualche pixel di
      // tolleranza perche' la misura intrinseca di un testo e la sua
      // impaginazione vera non coincidono al pixel (arrotondamenti di spaziatura
      // e crinale): quello che conta qui e' che il controllo si stringa e non si
      // allarghi a riempire.
      expect(first, moreOrLessEquals(second, epsilon: 0.5));
      expect(first, moreOrLessEquals(longestLabel, epsilon: 4));
      expect(width, moreOrLessEquals(longestLabel * 2, epsilon: 4));
      expect(width, lessThan(600));

      await _disposeTree(tester);
    });

    testWidgets('in una colonna occupa la larghezza che gli viene data',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CprTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[segmented()],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(TechSegmented<bool>)).width, moreOrLessEquals(500, epsilon: 1));

      await _disposeTree(tester);
    });

    testWidgets('toccare un segmento riporta il valore scelto', (WidgetTester tester) async {
      bool? chosen;
      await tester.pumpWidget(
        MaterialApp(
          theme: CprTheme.dark(),
          home: Scaffold(
            body: SizedBox(
              width: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[segmented(onChanged: (bool v) => chosen = v)],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('VISIBILE'));
      await tester.pump();

      expect(chosen, isFalse);

      await _disposeTree(tester);
    });
  });
}
