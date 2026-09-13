import 'package:flutter/material.dart';

/// Palette ispirata all'identita' visiva di Cyberpunk RED: giallo segnaletico
/// ad alto contrasto su nero profondo, con accenti ciano e magenta per tutto
/// cio' che e' "cyber" (chrome, rete, alterazioni).
///
/// Regola di progetto: gli accenti saturi si usano per *comunicare stato*,
/// mai come decorazione. Su un foglio personaggio denso di dati, un colore
/// acceso in piu' e' un colore che non significa niente.
abstract final class CprPalette {
  // Fondali, dal piu' profondo al piu' sollevato.
  static const Color voidBlack = Color(0xFF07080A);
  static const Color surfaceSunken = Color(0xFF0B0D10);
  static const Color surface = Color(0xFF101317);
  static const Color surfaceRaised = Color(0xFF171B20);
  static const Color surfaceHover = Color(0xFF1E242A);
  static const Color hairline = Color(0xFF2B323A);
  static const Color hairlineBright = Color(0xFF3D464F);

  // Inchiostri. Tre livelli: leggibile, secondario, decorativo.
  static const Color ink = Color(0xFFE9EEF2);
  static const Color inkMuted = Color(0xFF97A2AC);
  static const Color inkFaint = Color(0xFF5C666F);

  // Accenti strutturali.
  static const Color yellow = Color(0xFFFCEE0A);
  static const Color yellowDeep = Color(0xFFC9BC05);
  static const Color cyan = Color(0xFF22E6D2);
  static const Color magenta = Color(0xFFFF2E88);
  static const Color violet = Color(0xFF8B5CF6);

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

  /// Restituisce il colore del cuore in funzione della percentuale di vita.
  static Color healthColorFor(double ratio) {
    if (ratio <= 0) return healthFlatline;
    if (ratio <= 0.30) return healthCritical;
    if (ratio <= 0.60) return healthWounded;
    return healthFull;
  }

  /// Opacita' utile per "velare" un colore senza perderne la tinta.
  static Color veil(Color c, double alpha) => c.withValues(alpha: alpha);
}
