import 'package:flutter/material.dart';

import '../design/geometry.dart';
import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Barra di una statistica (le dieci caratteristiche di CP RED).
///
/// Le barre sono a segmenti, non piene, perche' le caratteristiche sono
/// *punti interi* da 1 a 8: una barra continua suggerisce una precisione che
/// il gioco non ha. Contando i segmenti si sa il valore senza leggere il
/// numero — e in sessione si guarda la scheda di sfuggita, non la si studia.
class StatMeter extends StatelessWidget {
  const StatMeter({
    super.key,
    required this.label,
    required this.shortLabel,
    required this.value,
    this.max = 8,
    this.modifier = 0,
    this.accent,
    this.isEssential = false,
    this.onTap,
  });

  final String label;
  final String shortLabel;
  final int value;
  final int max;

  /// Modificatore temporaneo (cyberware, droghe, effetti). Zero = nessuno.
  /// Non e' fuso nel valore base: la scheda deve poter tornare indietro.
  final int modifier;
  final Color? accent;

  /// Le abilita'/statistiche "essenziali" costano doppio in progressione:
  /// il marker evita di doverlo ricordare a memoria.
  final bool isEssential;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color base = accent ?? CprPalette.yellow;
    final int effective = (value + modifier).clamp(0, max);
    final bool boosted = modifier > 0;
    final bool reduced = modifier < 0;
    final Color barColor = boosted
        ? CprPalette.cyan
        : reduced
            ? CprPalette.danger
            : base;

    return Semantics(
      label: '$label: $value${modifier != 0 ? ' (${modifier > 0 ? '+' : ''}$modifier)' : ''} su $max',
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: <Widget>[
              // Sigla in mono, larghezza fissa: le tre colonne restano
              // allineate anche tra statistiche con nomi lunghi.
              SizedBox(
                width: 46,
                child: Text(
                  shortLabel.toUpperCase(),
                  style: CprType.label.copyWith(color: accent ?? CprPalette.inkMuted),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SegmentedBar(
                  value: effective,
                  max: max,
                  color: barColor,
                  ghostValue: value,
                ),
              ),
              const SizedBox(width: 10),
              if (isEssential)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Abilita essenziale (costo doppio)',
                    child: Icon(Icons.bolt, size: 13, color: CprPalette.veil(base, 0.7)),
                  ),
                ),
              SizedBox(width: 22, child: _animatedValue(effective, barColor)),
              if (modifier != 0)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '${modifier > 0 ? '+' : ''}$modifier',
                    style: CprType.label.copyWith(
                      fontSize: 10.5,
                      color: boosted ? CprPalette.cyan : CprPalette.danger,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _animatedValue(int effective, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: effective.toDouble(), end: effective.toDouble()),
      duration: CprMotion.value,
      curve: CprMotion.enter,
      builder: (BuildContext context, double v, _) => Text(
        effective.toString(),
        textAlign: TextAlign.right,
        style: CprType.numeralSmall.copyWith(color: color, fontSize: 15),
      ),
    );
  }
}

class _SegmentedBar extends StatelessWidget {
  const _SegmentedBar({
    required this.value,
    required this.max,
    required this.color,
    required this.ghostValue,
  });

  final int value;
  final int max;
  final Color color;

  /// Valore base senza modificatori: viene mostrato come traccia spenta sotto
  /// il riempimento, cosi' si vede *da dove* arriva il bonus.
  final int ghostValue;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: value.toDouble(), end: value.toDouble()),
      duration: CprMotion.value,
      curve: CprMotion.enter,
      builder: (BuildContext context, double animated, Widget? _) {
        return SizedBox(
          height: 14,
          child: Row(
            children: List<Widget>.generate(max, (int i) {
              final bool filled = i < value;
              final bool ghost = i < ghostValue && !filled;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == max - 1 ? 0 : 2),
                  child: AnimatedContainer(
                    duration: CprMotion.hover,
                    decoration: BoxDecoration(
                      color: filled
                          ? CprPalette.veil(color, i < animated ? 0.95 : 0.6)
                          : ghost
                              ? CprPalette.veil(CprPalette.inkFaint, 0.35)
                              : CprPalette.surfaceRaised,
                      border: Border.all(
                        color: filled ? CprPalette.veil(color, 0.9) : CprPalette.hairline,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

/// Divisore a chamfer, usato tra le sezioni della scheda.
class ChamferDivider extends StatelessWidget {
  const ChamferDivider({super.key, this.color, this.height = 1});

  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: ChamferPainter(
          cut: 4,
          fill: color ?? CprPalette.hairline,
          corners: ChamferCorners.all,
        ),
      ),
    );
  }
}
