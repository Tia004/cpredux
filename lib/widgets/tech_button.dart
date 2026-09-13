import 'package:flutter/material.dart';

import '../design/geometry.dart';
import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';

enum TechButtonVariant {
  /// Azione primaria della schermata. Uno solo per schermata.
  primary,
  secondary,
  ghost,

  /// Azioni distruttive: rimuovere un oggetto, espellere un giocatore.
  danger,
}

/// Pulsante con angoli tagliati e feedback su hover/pressione.
///
/// Il feedback e' deliberatamente a due velocita': l'hover e' quasi istantaneo
/// (110 ms) perche' deve sembrare che l'interfaccia *ascolti*, la pressione e'
/// ancora piu' rapida (90 ms) perche' deve sembrare che *ceda*.
class TechButton extends StatefulWidget {
  const TechButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.variant = TechButtonVariant.secondary,
    this.compact = false,
    this.expand = false,
    this.tooltip,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final TechButtonVariant variant;
  final bool compact;
  final bool expand;
  final String? tooltip;

  @override
  State<TechButton> createState() => _TechButtonState();
}

class _TechButtonState extends State<TechButton> with TickerProviderStateMixin {
  late final AnimationController _hover;
  late final AnimationController _press;

  bool get _enabled => widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(vsync: this, duration: CprMotion.hover);
    _press = AnimationController(vsync: this, duration: CprMotion.press);
  }

  @override
  void dispose() {
    _hover.dispose();
    _press.dispose();
    super.dispose();
  }

  ({Color accent, Color fill, Color fillHover, Color border, Color text}) _colors() {
    switch (widget.variant) {
      case TechButtonVariant.primary:
        return (
          accent: CprPalette.yellow,
          fill: CprPalette.yellow,
          fillHover: const Color(0xFFFFF75C),
          border: CprPalette.yellow,
          text: CprPalette.voidBlack,
        );
      case TechButtonVariant.secondary:
        return (
          accent: CprPalette.yellow,
          fill: CprPalette.surfaceRaised,
          fillHover: CprPalette.surfaceHover,
          border: CprPalette.hairlineBright,
          text: CprPalette.ink,
        );
      case TechButtonVariant.ghost:
        return (
          accent: CprPalette.cyan,
          fill: const Color(0x00000000),
          fillHover: CprPalette.veil(CprPalette.cyan, 0.08),
          border: CprPalette.hairline,
          text: CprPalette.inkMuted,
        );
      case TechButtonVariant.danger:
        return (
          accent: CprPalette.danger,
          fill: CprPalette.veil(CprPalette.danger, 0.14),
          fillHover: CprPalette.veil(CprPalette.danger, 0.26),
          border: CprPalette.veil(CprPalette.danger, 0.6),
          text: CprPalette.danger,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ({Color accent, Color fill, Color fillHover, Color border, Color text}) c = _colors();
    final EdgeInsets padding = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 7)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 11);

    Widget content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(widget.icon, size: widget.compact ? 14 : 16, color: c.text),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label.toUpperCase(),
          style: CprType.label.copyWith(
            color: c.text,
            fontSize: widget.compact ? 10.5 : 11.5,
          ),
        ),
      ],
    );

    Widget button = MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => _enabled ? _hover.forward() : null,
      onExit: (_) => _hover.reverse(),
      child: GestureDetector(
        onTapDown: (_) => _enabled ? _press.forward() : null,
        onTapUp: (_) => _press.reverse(),
        onTapCancel: () => _press.reverse(),
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: Listenable.merge(<Listenable>[_hover, _press]),
          builder: (BuildContext context, _) {
            final double h = _hover.value;
            final double p = _press.value;
            final double opacity = _enabled ? 1.0 : 0.4;

            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: 1 - p * 0.025,
                child: CustomPaint(
                  painter: ChamferPainter(
                    cut: 10,
                    fill: Color.lerp(c.fill, c.fillHover, h),
                    glow: h > 0 ? CprPalette.veil(c.accent, 0.22 * h) : null,
                    glowRadius: 10,
                  ),
                  foregroundPainter: ChamferPainter(
                    cut: 10,
                    stroke: Color.lerp(c.border, CprPalette.veil(c.accent, 0.9), h),
                  ),
                  child: ClipPath(
                    clipper: const ChamferClipper(cut: 10),
                    child: Padding(padding: padding, child: content),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}
