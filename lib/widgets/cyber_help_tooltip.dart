import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/typography.dart';

/// Un badge con punto interrogativo '?' hoverabile che fa apparire un fumetto (speech bubble)
/// con una freccia direzionale che punta direttamente verso il '?'.
class CyberHelpTooltip extends StatefulWidget {
  const CyberHelpTooltip({
    super.key,
    required this.title,
    required this.message,
    this.tag,
    this.accent = CprPalette.cyan,
    this.size = 16.0,
  });

  final String title;
  final String message;
  final String? tag;
  final Color accent;
  final double size;

  @override
  State<CyberHelpTooltip> createState() => _CyberHelpTooltipState();
}

class _CyberHelpTooltipState extends State<CyberHelpTooltip> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  bool _isHovered = false;

  void _showOverlay() {
    if (_overlayEntry != null) return;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          width: 280,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: const Offset(0, -6),
            targetAnchor: Alignment.topCenter,
            followerAnchor: Alignment.bottomCenter,
            child: Material(
              type: MaterialType.transparency,
              child: MouseRegion(
                onEnter: (_) => setState(() => _isHovered = true),
                onExit: (_) {
                  setState(() => _isHovered = false);
                  _hideOverlay();
                },
                child: _CyberBubbleWidget(
                  title: widget.title,
                  message: widget.message,
                  tag: widget.tag,
                  accent: widget.accent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        onEnter: (_) {
          setState(() => _isHovered = true);
          _showOverlay();
        },
        onExit: (_) {
          Future<void>.delayed(const Duration(milliseconds: 50), () {
            if (mounted && !_isHovered) {
              _hideOverlay();
            }
          });
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _showOverlay();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered ? widget.accent.withValues(alpha: 0.25) : CprPalette.surfaceSunken,
              border: Border.all(
                color: _isHovered ? widget.accent : widget.accent.withValues(alpha: 0.5),
                width: 1.2,
              ),
              boxShadow: _isHovered
                  ? <BoxShadow>[
                      BoxShadow(
                        color: widget.accent.withValues(alpha: 0.4),
                        blurRadius: 6,
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
                color: _isHovered ? CprPalette.ink : widget.accent,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Disegna la vignetta con freccia puntata in basso verso il badge '?'
class _CyberBubbleWidget extends StatelessWidget {
  const _CyberBubbleWidget({
    required this.title,
    required this.message,
    this.tag,
    required this.accent,
  });

  final String title;
  final String message;
  final String? tag;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BubblePainter(accent: accent),
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 18),
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

/// Painter per la bolla con freccia puntata verso il centro inferiore
class _BubblePainter extends CustomPainter {
  const _BubblePainter({required this.accent});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final double arrowHeight = 8.0;
    final double arrowWidth = 14.0;
    final double rectBottom = size.height - arrowHeight;
    final double centerX = size.width / 2;

    final Path path = Path()
      ..moveTo(4, 0)
      ..lineTo(size.width - 4, 0)
      ..lineTo(size.width, 4)
      ..lineTo(size.width, rectBottom - 4)
      ..lineTo(size.width - 4, rectBottom)
      // Freccia puntata verso il basso verso il '?'
      ..lineTo(centerX + arrowWidth / 2, rectBottom)
      ..lineTo(centerX, size.height)
      ..lineTo(centerX - arrowWidth / 2, rectBottom)
      ..lineTo(4, rectBottom)
      ..lineTo(0, rectBottom - 4)
      ..lineTo(0, 4)
      ..close();

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
  bool shouldRepaint(covariant _BubblePainter oldDelegate) => oldDelegate.accent != accent;
}
