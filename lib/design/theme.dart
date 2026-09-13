import 'package:flutter/material.dart';

import 'motion.dart';
import 'palette.dart';
import 'typography.dart';

/// Colori del tema chiaro.
///
/// Il giallo di Cyberpunk RED (`#FCEE0A`) su fondo bianco e' **illeggibile**:
/// ha un rapporto di contrasto di circa 1,1:1, ben sotto il minimo di 4,5:1
/// per il testo. In tema chiaro l'accento diventa quindi un giallo oliva scuro
/// che conserva la tinta riconoscibile ma si legge. E' una di quelle cose che
/// si notano subito se sbagliate: un'app che "non si legge al sole" viene
/// abbandonata, anche se il tema scuro e' bellissimo.
abstract final class CprPaletteLight {
  static const Color background = Color(0xFFF1F2F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceRaised = Color(0xFFF7F8FA);
  static const Color surfaceSunken = Color(0xFFEAECEF);
  static const Color hairline = Color(0xFFD3D8DE);
  static const Color hairlineBright = Color(0xFFB6BDC6);

  static const Color ink = Color(0xFF14181C);
  static const Color inkMuted = Color(0xFF56606A);
  static const Color inkFaint = Color(0xFF8A939C);

  /// Accento leggibile su fondo chiaro: mantiene la famiglia del giallo
  /// segnaletico ma scende di luminosita' fino a essere leggibile.
  static const Color accent = Color(0xFF9A8F00);
  static const Color accentSoft = Color(0xFFE8E4B0);
  static const Color cyan = Color(0xFF0B8C80);
  static const Color magenta = Color(0xFFB3185E);
}

abstract final class CprTheme {
  /// Durata di default per le transizioni di scena.
  static const Duration sceneTransition = CprMotion.slow;

  /// Ombra standard dei pannelli sollevati.
  static const List<BoxShadow> panelShadow = <BoxShadow>[
    BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  static ThemeData dark() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: CprPalette.yellow,
      onPrimary: CprPalette.voidBlack,
      primaryContainer: CprPalette.yellowDeep,
      onPrimaryContainer: CprPalette.voidBlack,
      secondary: CprPalette.cyan,
      onSecondary: CprPalette.voidBlack,
      tertiary: CprPalette.magenta,
      onTertiary: CprPalette.voidBlack,
      error: CprPalette.danger,
      onError: CprPalette.voidBlack,
      surface: CprPalette.surface,
      onSurface: CprPalette.ink,
      surfaceContainerLowest: CprPalette.voidBlack,
      surfaceContainerLow: CprPalette.surfaceSunken,
      surfaceContainer: CprPalette.surface,
      surfaceContainerHigh: CprPalette.surfaceRaised,
      surfaceContainerHighest: CprPalette.surfaceHover,
      outline: CprPalette.hairline,
      outlineVariant: CprPalette.hairlineBright,
    );

    return _base(
      scheme: scheme,
      scaffold: CprPalette.voidBlack,
      canvas: CprPalette.surface,
      ink: CprPalette.ink,
      inkMuted: CprPalette.inkMuted,
      inkFaint: CprPalette.inkFaint,
      hairline: CprPalette.hairline,
      hairlineBright: CprPalette.hairlineBright,
      sunken: CprPalette.surfaceSunken,
      raised: CprPalette.surfaceRaised,
      accent: CprPalette.yellow,
    );
  }

  static ThemeData light() {
    const ColorScheme scheme = ColorScheme(
      brightness: Brightness.light,
      primary: CprPaletteLight.accent,
      onPrimary: Colors.white,
      primaryContainer: CprPaletteLight.accentSoft,
      onPrimaryContainer: CprPaletteLight.ink,
      secondary: CprPaletteLight.cyan,
      onSecondary: Colors.white,
      tertiary: CprPaletteLight.magenta,
      onTertiary: Colors.white,
      error: CprPalette.danger,
      onError: Colors.white,
      surface: CprPaletteLight.surface,
      onSurface: CprPaletteLight.ink,
      surfaceContainerLowest: CprPaletteLight.background,
      surfaceContainerLow: CprPaletteLight.surfaceSunken,
      surfaceContainer: CprPaletteLight.surface,
      surfaceContainerHigh: CprPaletteLight.surfaceRaised,
      surfaceContainerHighest: CprPaletteLight.surfaceSunken,
      outline: CprPaletteLight.hairline,
      outlineVariant: CprPaletteLight.hairlineBright,
    );

    return _base(
      scheme: scheme,
      scaffold: CprPaletteLight.background,
      canvas: CprPaletteLight.surface,
      ink: CprPaletteLight.ink,
      inkMuted: CprPaletteLight.inkMuted,
      inkFaint: CprPaletteLight.inkFaint,
      hairline: CprPaletteLight.hairline,
      hairlineBright: CprPaletteLight.hairlineBright,
      sunken: CprPaletteLight.surfaceSunken,
      raised: CprPaletteLight.surfaceRaised,
      accent: CprPaletteLight.accent,
    );
  }

  static ThemeData _base({
    required ColorScheme scheme,
    required Color scaffold,
    required Color canvas,
    required Color ink,
    required Color inkMuted,
    required Color inkFaint,
    required Color hairline,
    required Color hairlineBright,
    required Color sunken,
    required Color raised,
    required Color accent,
  }) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: canvas,
      textTheme: CprType.textTheme(ink: ink).apply(bodyColor: ink, displayColor: ink),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: accent.withValues(alpha: 0.06),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: inkMuted, size: 18),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 420),
        textStyle: CprType.caption.copyWith(color: ink),
        decoration: BoxDecoration(
          color: raised,
          border: Border.all(color: hairlineBright),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: sunken,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        hintStyle: CprType.body.copyWith(color: inkFaint),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}
