import 'package:flutter/material.dart';

import '../design/geometry.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Pannello con angoli tagliati: il contenitore base dell'interfaccia.
///
/// Gerarchia visiva volutamente a tre livelli, perche' con un solo livello di
/// pannelli una schermata densa diventa illeggibile:
/// * pannello normale  -> bordo `hairline`
/// * `accent` valorizzato -> bordo e titolo colorati (elemento attivo)
/// * `glow: true`      -> alone esterno (elemento che richiede attenzione)
class ChamferPanel extends StatelessWidget {
  const ChamferPanel({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.accent,
    this.cut = 14,
    this.corners = ChamferCorners.all,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
    this.fill,
    this.border,
    this.glow = false,
    this.headerSpacing = 12,
  });

  final Widget child;

  /// Intestazione opzionale. Se presente, viene resa nel registro "tecnico":
  /// maiuscolo, spaziato, con un tratto di colore accanto.
  final String? title;
  final Widget? trailing;

  /// Colore dell'elemento attivo. Se nullo il pannello e' neutro.
  final Color? accent;
  final double cut;
  final ChamferCorners corners;
  final EdgeInsets padding;
  final Color? fill;
  final Color? border;
  final bool glow;
  final double headerSpacing;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = accent ?? CprPalette.inkFaint;
    final Color resolvedBorder = border ?? (accent != null ? CprPalette.veil(accentColor, 0.55) : CprPalette.hairline);

    Widget content = child;
    if (title != null) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              // Tratto di 3px: sostituisce il classico pallino. Piu' anonimo
              // ma coerente con il resto della segnaletica dell'app.
              Container(width: 3, height: 13, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title!.toUpperCase(),
                  style: CprType.label.copyWith(color: accent == null ? CprPalette.inkMuted : accentColor),
                ),
              ),
              ?trailing,
            ],
          ),
          SizedBox(height: headerSpacing),
          content,
        ],
      );
    }

    return Stack(
      children: <Widget>[
        CustomPaint(
          painter: ChamferPainter(
            cut: cut,
            corners: corners,
            fill: fill,
            glow: glow ? CprPalette.veil(accentColor, 0.22) : null,
            glowRadius: 14,
          ),
          foregroundPainter: ChamferPainter(
            cut: cut,
            corners: corners,
            stroke: resolvedBorder,
          ),
          child: ClipPath(
            clipper: ChamferClipper(cut: cut, corners: corners),
            child: Padding(padding: padding, child: content),
          ),
        ),
      ],
    );
  }
}
