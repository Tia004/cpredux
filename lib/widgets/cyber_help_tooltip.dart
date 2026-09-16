import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/typography.dart';

/// Un badge con punto interrogativo '?' hoverabile che fa apparire un fumetto (speech bubble)
/// con una freccia direzionale che punta verso il '?'.
///
/// Caratteristiche:
/// - Appare quando si hovera il badge '?'.
/// - Rimane aperto se il puntatore si sposta sopra la bubble stessa per permettere la lettura.
/// - Scompare quando non si hovera più né il badge né la bubble.
/// - Calcola dinamicamente le coordinate per non andare MAI in overflow fuori dalla schermata.
class CyberHelpTooltip extends StatefulWidget {
  const CyberHelpTooltip({
    super.key,
    required this.title,
    required this.message,
    this.tag,
    this.accent,
    this.size = 16.0,
  });

  final String title;
  final String message;
  final String? tag;
  final Color? accent;
  final double size;

  Color get resolvedAccent => accent ?? CprPalette.cyan;

  @override
  State<CyberHelpTooltip> createState() => _CyberHelpTooltipState();
}

class _CyberHelpTooltipState extends State<CyberHelpTooltip> {
  OverlayEntry? _overlayEntry;
  bool _isTargetHovered = false;
  bool _isBubbleHovered = false;
  Timer? _hideTimer;

  void _showOverlay() {
    if (!mounted) return;
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(milliseconds: 160), () {
      if (!mounted) return;
      if (!_isTargetHovered && !_isBubbleHovered) {
        _hideOverlay();
        if (mounted) setState(() {});
      }
    });
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (BuildContext overlayContext) {
        if (!mounted) return const SizedBox.shrink();
        final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null || !renderBox.hasSize) {
          return const SizedBox.shrink();
        }

        final Offset targetPos = renderBox.localToGlobal(Offset.zero);
        final Size targetSize = renderBox.size;
        final Size screenSize = MediaQuery.of(overlayContext).size;
        final EdgeInsets mediaPadding = MediaQuery.of(overlayContext).padding;

        const double idealWidth = 280.0;
        const double margin = 12.0;
        const double arrowWidth = 14.0;
        const double corner = 4.0;

        final double tooltipWidth = math.min(idealWidth, screenSize.width - (margin * 2));
        final double targetCenterX = targetPos.dx + (targetSize.width / 2);

        // Clamping orizzontale: assicura che il tooltip stia sempre interamente nello schermo
        final double rawLeft = targetCenterX - (tooltipWidth / 2);
        final double maxLeft = math.max(margin, screenSize.width - tooltipWidth - margin);
        final double clampedLeft = rawLeft.clamp(margin, maxLeft);

        // Calcolo della posizione della freccia in coordinate locali del tooltip
        final double localTargetX = targetCenterX - clampedLeft;
        final double minArrowX = corner + (arrowWidth / 2) + 2.0;
        final double maxArrowX = tooltipWidth - corner - (arrowWidth / 2) - 2.0;
        final double arrowX = localTargetX.clamp(minArrowX, math.max(minArrowX, maxArrowX));

        // Determinazione verticale: se sopra non c'è abbastanza spazio (< 130px), mostralo sotto
        final double spaceAbove = targetPos.dy - mediaPadding.top;
        final bool showBelow = spaceAbove < 130.0;

        final double maxAvailableHeight = showBelow
            ? (screenSize.height - (targetPos.dy + targetSize.height + 4) - mediaPadding.bottom - margin)
            : (spaceAbove - 8.0);

        return Positioned(
          left: clampedLeft,
          top: showBelow ? (targetPos.dy + targetSize.height + 4) : null,
          bottom: !showBelow ? (screenSize.height - targetPos.dy + 4) : null,
          width: tooltipWidth,
          child: Material(
            type: MaterialType.transparency,
            child: MouseRegion(
              onEnter: (_) {
                _hideTimer?.cancel();
                _isBubbleHovered = true;
                if (mounted) setState(() {});
              },
              onExit: (_) {
                _isBubbleHovered = false;
                if (mounted) setState(() {});
                _scheduleHide();
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: math.max(60.0, maxAvailableHeight),
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: _CyberBubbleWidget(
                    title: widget.title,
                    message: widget.message,
                    tag: widget.tag,
                    accent: widget.resolvedAccent,
                    arrowX: arrowX,
                    pointingUp: showBelow,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void deactivate() {
    _hideTimer?.cancel();
    _hideOverlay();
    super.deactivate();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isHighlighted = _isTargetHovered || _isBubbleHovered;

    return MouseRegion(
      cursor: SystemMouseCursors.help,
      onEnter: (_) {
        _hideTimer?.cancel();
        _isTargetHovered = true;
        setState(() {});
        _showOverlay();
      },
      onExit: (_) {
        _isTargetHovered = false;
        setState(() {});
        _scheduleHide();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_overlayEntry != null) {
            _hideOverlay();
            _isTargetHovered = false;
            _isBubbleHovered = false;
            setState(() {});
          } else {
            _showOverlay();
            _isTargetHovered = true;
            setState(() {});
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isHighlighted ? widget.resolvedAccent.withValues(alpha: 0.25) : CprPalette.surfaceSunken,
            border: Border.all(
              color: isHighlighted ? widget.resolvedAccent : widget.resolvedAccent.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: isHighlighted
                ? <BoxShadow>[
                    BoxShadow(
                      color: widget.resolvedAccent.withValues(alpha: 0.45),
                      blurRadius: 7,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '?',
            style: CprType.label.copyWith(
              fontSize: widget.size * 0.65,
              fontWeight: FontWeight.bold,
              color: isHighlighted ? CprPalette.ink : widget.accent,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Disegna la vignetta con freccia puntata verso il badge '?'
class _CyberBubbleWidget extends StatelessWidget {
  const _CyberBubbleWidget({
    required this.title,
    required this.message,
    this.tag,
    required this.accent,
    required this.arrowX,
    required this.pointingUp,
  });

  final String title;
  final String message;
  final String? tag;
  final Color accent;
  final double arrowX;
  final bool pointingUp;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(
        accent: accent,
        arrowX: arrowX,
        pointingUp: pointingUp,
      ),
      child: Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: pointingUp ? 18 : 10,
          bottom: pointingUp ? 10 : 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: CprType.label.copyWith(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: accent,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                if (tag != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    color: accent.withValues(alpha: 0.15),
                    child: Text(
                      tag!.toUpperCase(),
                      style: CprType.label.copyWith(
                        fontSize: 8,
                        color: accent,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: CprType.caption.copyWith(
                color: CprPalette.ink,
                fontSize: 11,
                height: 1.35,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Painter per la bolla con freccia puntata verso il '?'
class _BubblePainter extends CustomPainter {
  const _BubblePainter({
    required this.accent,
    required this.arrowX,
    required this.pointingUp,
  });

  final Color accent;
  final double arrowX;
  final bool pointingUp;

  @override
  void paint(Canvas canvas, Size size) {
    const double arrowHeight = 8.0;
    const double arrowWidth = 14.0;
    const double corner = 4.0;

    final Path path = Path();

    if (!pointingUp) {
      // Freccia puntata verso il basso
      final double rectBottom = size.height - arrowHeight;
      path
        ..moveTo(corner, 0)
        ..lineTo(size.width - corner, 0)
        ..lineTo(size.width, corner)
        ..lineTo(size.width, rectBottom - corner)
        ..lineTo(size.width - corner, rectBottom)
        ..lineTo(arrowX + (arrowWidth / 2), rectBottom)
        ..lineTo(arrowX, size.height)
        ..lineTo(arrowX - (arrowWidth / 2), rectBottom)
        ..lineTo(corner, rectBottom)
        ..lineTo(0, rectBottom - corner)
        ..lineTo(0, corner)
        ..close();
    } else {
      // Freccia puntata verso l'alto
      const double rectTop = arrowHeight;
      path
        ..moveTo(corner, rectTop)
        ..lineTo(arrowX - (arrowWidth / 2), rectTop)
        ..lineTo(arrowX, 0)
        ..lineTo(arrowX + (arrowWidth / 2), rectTop)
        ..lineTo(size.width - corner, rectTop)
        ..lineTo(size.width, rectTop + corner)
        ..lineTo(size.width, size.height - corner)
        ..lineTo(size.width - corner, size.height)
        ..lineTo(corner, size.height)
        ..lineTo(0, size.height - corner)
        ..lineTo(0, rectTop + corner)
        ..close();
    }

    // Bagliore/ombra cyberpunk
    final Paint shadowPaint = Paint()
      ..color = accent.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8);
    canvas.drawPath(path, shadowPaint);

    // Sfondo solido scuro cyberpunk
    final Paint fillPaint = Paint()
      ..color = CprPalette.surfaceRaised
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Bordo neon accent
    final Paint borderPaint = Paint()
      ..color = accent
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) =>
      oldDelegate.accent != accent ||
      oldDelegate.arrowX != arrowX ||
      oldDelegate.pointingUp != pointingUp;
}
