import 'package:flutter/material.dart';

/// Palette ispirata all'identita' visiva di Cyberpunk RED: giallo segnaletico
/// ad alto contrasto su nero profondo, con accenti ciano e magenta per tutto
/// cio' che e' "cyber" (chrome, rete, alterazioni).
///
/// Regola di progetto: gli accenti saturi si usano per *comunicare stato*,
/// mai come decorazione. Su un foglio personaggio denso di dati, un colore
/// acceso in piu' e' un colore che non significa niente.
abstract final class CprPalette {
  // Fondali predefiniti.
  static const Color kDefaultVoidBlack = Color(0xFF07080A);
  static const Color kDefaultSurfaceSunken = Color(0xFF0B0D10);
  static const Color kDefaultSurface = Color(0xFF101317);
  static const Color kDefaultSurfaceRaised = Color(0xFF171B20);
  static const Color kDefaultSurfaceHover = Color(0xFF1E242A);
  static const Color kDefaultHairline = Color(0xFF2B323A);
  static const Color kDefaultHairlineBright = Color(0xFF3D464F);

  // Inchiostri predefiniti.
  static const Color kDefaultInk = Color(0xFFE9EEF2);
  static const Color kDefaultInkMuted = Color(0xFF97A2AC);
  static const Color kDefaultInkFaint = Color(0xFF5C666F);

  // Accenti predefiniti.
  static const Color kDefaultYellow = Color(0xFFFCEE0A);
  static const Color kDefaultYellowDeep = Color(0xFFC9BC05);
  static const Color kDefaultCyan = Color(0xFF22E6D2);
  static const Color kDefaultMagenta = Color(0xFFFF2E88);
  static const Color kDefaultViolet = Color(0xFF8B5CF6);

  // Fondali attivi dinamicamente in base a tema e contrasto.
  static Color voidBlack = kDefaultVoidBlack;
  static Color surfaceSunken = kDefaultSurfaceSunken;
  static Color surface = kDefaultSurface;
  static Color surfaceRaised = kDefaultSurfaceRaised;
  static Color surfaceHover = kDefaultSurfaceHover;
  static Color hairline = kDefaultHairline;
  static Color hairlineBright = kDefaultHairlineBright;

  // Inchiostri attivi.
  static Color ink = kDefaultInk;
  static Color inkMuted = kDefaultInkMuted;
  static Color inkFaint = kDefaultInkFaint;

  // Accenti strutturali attivi.
  static Color yellow = kDefaultYellow;
  static Color yellowDeep = kDefaultYellowDeep;
  static Color cyan = kDefaultCyan;
  static Color magenta = kDefaultMagenta;
  static Color violet = kDefaultViolet;

  // Stati dei Punti Vita: il cuore cambia temperatura con la severita'.
  static const Color healthFull = Color(0xFFFF4D63);
  static const Color healthWounded = Color(0xFFFF9F1C);
  static const Color healthCritical = Color(0xFFD62246);
  // Oltre 0 PV: il cuore e' fermo, desaturato, con anelli di "flatline".
  static const Color healthFlatline = Color(0xFF6E2A33);

  // Umanita': la spira si erode in magenta man mano che il cyberware mangia EMP.
  static const Color humanityIntact = Color(0xFF22E6D2);
  static const Color humanityEroded = Color(0xFFFF2E88);

  // Semantica generica.
  static const Color success = Color(0xFF3DDC84);
  static const Color warning = Color(0xFFFFA62B);
  static const Color danger = Color(0xFFFF3B47);
  static const Color info = Color(0xFF4DA3FF);

  /// Applica il tema base e il sottotema a tutta l'applicazione in tempo reale.
  static void applyTheme({
    String baseTheme = 'dark',
    String subTheme = 'cyberpunk2077',
    Color? customAccent,
  }) {
    final bool isLight = baseTheme == 'light';
    final bool isOled = baseTheme == 'oled';

    if (isLight) {
      voidBlack = const Color(0xFFE6E8EC);
      surfaceSunken = const Color(0xFFEEF0F4);
      surface = const Color(0xFFF7F8FA);
      surfaceRaised = const Color(0xFFFFFFFF);
      surfaceHover = const Color(0xFFE2E5EA);
      hairline = const Color(0xFFCCD1D9);
      hairlineBright = const Color(0xFFAAB2BD);
      ink = const Color(0xFF111418);
      inkMuted = const Color(0xFF4A5562);
      inkFaint = const Color(0xFF7B8694);
    } else if (isOled) {
      voidBlack = const Color(0xFF000000);
      surfaceSunken = const Color(0xFF000000);
      surface = const Color(0xFF060608);
      surfaceRaised = const Color(0xFF0F0F12);
      surfaceHover = const Color(0xFF18181D);
      hairline = const Color(0xFF27272D);
      hairlineBright = const Color(0xFF404049);
      ink = const Color(0xFFF4F6F8);
      inkMuted = const Color(0xFFA2ABB4);
      inkFaint = const Color(0xFF67727D);
    } else {
      // Dark (Default)
      voidBlack = kDefaultVoidBlack;
      surfaceSunken = kDefaultSurfaceSunken;
      surface = kDefaultSurface;
      surfaceRaised = kDefaultSurfaceRaised;
      surfaceHover = kDefaultSurfaceHover;
      hairline = kDefaultHairline;
      hairlineBright = kDefaultHairlineBright;
      ink = kDefaultInk;
      inkMuted = kDefaultInkMuted;
      inkFaint = kDefaultInkFaint;
    }

    switch (subTheme) {
      case 'cyberpunkRed':
        yellow = isLight ? const Color(0xFFC40026) : const Color(0xFFE8002D);
        yellowDeep = isLight ? const Color(0xFF9E001E) : const Color(0xFFB50022);
        cyan = isLight ? const Color(0xFF0B8C80) : const Color(0xFFFF4D63);
        magenta = isLight ? const Color(0xFFB3185E) : const Color(0xFFFF8500);
      case 'militech':
        yellow = isLight ? const Color(0xFF00993D) : const Color(0xFF00FF66);
        yellowDeep = isLight ? const Color(0xFF007A30) : const Color(0xFF00C850);
        cyan = isLight ? const Color(0xFF0B8C80) : const Color(0xFF22E694);
        magenta = isLight ? const Color(0xFFB3185E) : const Color(0xFF8AE02B);
      case 'custom':
        final Color accent = customAccent ?? (isLight ? const Color(0xFF9A8F00) : const Color(0xFFFCEE0A));
        yellow = accent;
        yellowDeep = isLight ? Color.lerp(accent, Colors.black, 0.25)! : Color.lerp(accent, Colors.black, 0.20)!;
        cyan = isLight ? const Color(0xFF0B8C80) : const Color(0xFF22E6D2);
        magenta = isLight ? const Color(0xFFB3185E) : const Color(0xFFFF2E88);
      case 'cyberpunk2077':
      default:
        yellow = isLight ? const Color(0xFF9A8F00) : const Color(0xFFFCEE0A);
        yellowDeep = isLight ? const Color(0xFF7D7400) : const Color(0xFFC9BC05);
        cyan = isLight ? const Color(0xFF0B8C80) : const Color(0xFF22E6D2);
        magenta = isLight ? const Color(0xFFB3185E) : const Color(0xFFFF2E88);
    }
  }

  /// Restituisce il colore del cuore in funzione della percentuale di vita.
  static Color healthColorFor(double ratio) {
    if (ratio <= 0) return healthCritical;
    if (ratio <= 0.30) return healthCritical;
    if (ratio <= 0.60) return healthWounded;
    return healthFull;
  }

  /// Opacita' utile per "velare" un colore senza perderne la tinta.
  static Color veil(Color c, double alpha) => c.withValues(alpha: alpha);
}

/// Palette per schermi OLED: neri assoluti `#000000` con bordi e superfici ad alto contrasto.
abstract final class CprPaletteOled {
  static const Color voidBlack = Color(0xFF000000);
  static const Color surfaceSunken = Color(0xFF000000);
  static const Color surface = Color(0xFF070708);
  static const Color surfaceRaised = Color(0xFF101012);
  static const Color surfaceHover = Color(0xFF18181C);
  static const Color hairline = Color(0xFF26262B);
  static const Color hairlineBright = Color(0xFF3E3E46);

  static const Color ink = Color(0xFFF2F4F7);
  static const Color inkMuted = Color(0xFFA0ABB5);
  static const Color inkFaint = Color(0xFF65707A);
}

/// Accenti cromatici per i sottotemi dell'applicazione.
abstract final class CprSubThemes {
  // 1. Cyberpunk 2077 (Default / Attuale)
  static const Color cp77Yellow = Color(0xFFFCEE0A);
  static const Color cp77Cyan = Color(0xFF22E6D2);
  static const Color cp77Magenta = Color(0xFFFF2E88);

  // 2. Cyberpunk RED (Rosso cremisi/sangue)
  static const Color cpredPrimary = Color(0xFFE8002D);
  static const Color cpredSecondary = Color(0xFFFF4D63);
  static const Color cpredTertiary = Color(0xFFFF8500);

  // 3. Militech (Verde tattico fosforo e smeraldo militare)
  static const Color militechPrimary = Color(0xFF00FF66);
  static const Color militechSecondary = Color(0xFF22E694);
  static const Color militechTertiary = Color(0xFF8AE02B);
}
