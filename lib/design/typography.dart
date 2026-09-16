import 'package:flutter/material.dart';
import 'palette.dart';

/// Tipografia. Due famiglie con ruoli netti:
///
/// * **mono** per ogni numero e ogni dato di gioco. Non e' una scelta
///   estetica: con un font a larghezza fissa le cifre non "ballano" quando
///   il valore cambia, quindi le animazioni dei contatori restano leggibili
///   invece di far saltellare tutta la riga.
/// * **sans** per etichette e testo.
///
/// Le famiglie sono elencate come *fallback chain*: Flutter prova in ordine e
/// usa la prima disponibile, cosi' lo stesso codice rende bene su macOS,
/// Windows e Linux senza spedire font. Quando vorrai il carattere definitivo
/// (condensato, stile segnaletica) basta aggiungere i .ttf in `assets/fonts`
/// e dichiararli in pubspec: qui c'e' gia' il punto di aggancio.
abstract final class CprType {
  static const List<String> monoFamily = <String>[
    'SF Mono',
    'Menlo',
    'Consolas',
    'Roboto Mono',
    'DejaVu Sans Mono',
    'Courier New',
  ];

  static const List<String> sansFamily = <String>[
    'SF Pro Text',
    'Inter',
    'Segoe UI Variable Text',
    'Segoe UI',
    'Ubuntu',
    'Roboto',
    'Helvetica Neue',
  ];

  /// Micro-etichette in maiuscolo con spaziatura: intestazioni di sezione,
  /// unita' di misura, badge. E' il registro "tecnico" dell'interfaccia.
  static const TextStyle label = TextStyle(
    fontFamilyFallback: sansFamily,
    fontSize: 11,
    height: 1.1,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle caption = TextStyle(
    fontFamilyFallback: sansFamily,
    fontSize: 12,
    height: 1.35,
    letterSpacing: 0.1,
  );

  static const TextStyle body = TextStyle(
    fontFamilyFallback: sansFamily,
    fontSize: 14,
    height: 1.45,
    letterSpacing: 0.05,
  );

  static const TextStyle title = TextStyle(
    fontFamilyFallback: sansFamily,
    fontSize: 20,
    height: 1.2,
    letterSpacing: 0.2,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle display = TextStyle(
    fontFamilyFallback: sansFamily,
    fontSize: 40,
    height: 1.05,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w800,
  );

  /// Numeri grandi: vitals, contatori. Larghezza fissa + cifre tabulari
  /// implicite (il mono le ha per natura).
  static const TextStyle numeral = TextStyle(
    fontFamilyFallback: monoFamily,
    fontSize: 28,
    height: 1.0,
    letterSpacing: -0.5,
    fontWeight: FontWeight.w700,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle numeralSmall = TextStyle(
    fontFamilyFallback: monoFamily,
    fontSize: 14,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  /// Testo monospaziato con cifre tabulari.
  ///
  /// Serve dove l'allineamento verticale delle cifre conta piu' della
  /// larghezza: un'espressione di dado, un valore di regola, una colonna di
  /// numeri che si confrontano a occhio. Con un carattere proporzionale le
  /// cifre "1" occupano meno spazio delle altre e la colonna si sfalsa.
  static TextStyle mono(Color color, {double size = 13, FontWeight weight = FontWeight.w500}) => TextStyle(
        fontFamilyFallback: monoFamily,
        fontSize: size,
        height: 1.25,
        color: color,
        fontWeight: weight,
        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
      );

  /// Testo con i colori applicati per il tema in uso.
  ///
  /// Il colore e' un parametro e non una costante di palette: e' cio' che
  /// permettera' al tema chiaro di funzionare senza riscrivere ogni widget.
  static TextTheme textTheme({Color? ink}) {
    final Color resolvedInk = ink ?? CprPalette.ink;
    return TextTheme(
      displayLarge: display,
      titleLarge: title,
      bodyMedium: body,
      bodySmall: caption,
      labelSmall: label,
    ).apply(
      bodyColor: resolvedInk,
      displayColor: resolvedInk,
    );
  }
}
