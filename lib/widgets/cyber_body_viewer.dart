import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/typography.dart';
import '../domain/cyberware.dart';
import 'tech_button.dart';

/// Modalità di visualizzazione dei layer anatomici
enum BodyScanLayer {
  all('Tutti i Sistemi', Icons.layers),
  skeleton('Scheletro', Icons.accessibility),
  vascular('Vascolare', Icons.favorite_border),
  nervous('Nervoso', Icons.bolt),
  zones('Zone Cyber', Icons.grid_view);

  const BodyScanLayer(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Visualizzatore interattivo del corpo umano cyberpunk con 4 layer anatomici:
/// 1. Silhouette corporea
/// 2. Scheletro
/// 3. Sistema vascolare
/// 4. Sistema nervoso
///
/// Dispone di zone corporee interattive con bagliore neon proporzionale
/// al numero di cyberware installati in ciascuna parte del corpo.
class CyberBodyViewer extends StatefulWidget {
  const CyberBodyViewer({
    super.key,
    required this.cyberware,
    this.selectedZone,
    this.onZoneSelected,
    this.onInstallInZone,
    this.height = 420,
  });

  final List<Cyberware> cyberware;
  final String? selectedZone;
  final ValueChanged<String?>? onZoneSelected;
  final void Function(String zoneId)? onInstallInZone;
  final double height;

  @override
  State<CyberBodyViewer> createState() => _CyberBodyViewerState();
}

class _CyberBodyViewerState extends State<CyberBodyViewer> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  BodyScanLayer _activeLayer = BodyScanLayer.all;
  String? _hoveredZone;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Map<String, List<Cyberware>> get _zoneCyberwareMap {
    final Map<String, List<Cyberware>> map = <String, List<Cyberware>>{};
    for (final CyberBodyZone zone in CyberBodyZone.values) {
      map[zone.id] = <Cyberware>[];
    }
    for (final Cyberware c in widget.cyberware) {
      final String z = c.bodyZone.toLowerCase();
      if (map.containsKey(z)) {
        map[z]!.add(c);
      } else {
        map['torso']!.add(c);
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Cyberware>> zoneMap = _zoneCyberwareMap;
    final String? effectiveSelected = widget.selectedZone;
    final CyberBodyZone? selectedZoneObj = effectiveSelected != null
        ? CyberBodyZone.fromId(effectiveSelected)
        : null;

    final List<Cyberware> selectedList = effectiveSelected != null
        ? (zoneMap[effectiveSelected] ?? const <Cyberware>[])
        : const <Cyberware>[];

    final int selectedHumanity = selectedList.fold<int>(0, (int s, Cyberware c) => s + c.humanityLost);

    return Container(
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header / Layer Toolbar
          _buildToolbar(),

          // Main Visualizer Stage (Canvas + Callouts)
          SizedBox(
            height: widget.height,
            child: Stack(
              children: <Widget>[
                // Background Cyber Grid
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CyberGridPainter(),
                  ),
                ),

                // Anatomical Multi-Layer Canvas
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (BuildContext context, _) {
                      return CustomPaint(
                        painter: _BodyAnatomyPainter(
                          activeLayer: _activeLayer,
                          zoneCounts: zoneMap.map((String k, List<Cyberware> v) => MapEntry<String, int>(k, v.length)),
                          selectedZone: effectiveSelected,
                          hoveredZone: _hoveredZone,
                          pulsePhase: _pulseController.value,
                        ),
                      );
                    },
                  ),
                ),

                // Interactive Hit Boxes Overlay
                Positioned.fill(
                  child: LayoutBuilder(
                    builder: (BuildContext context, BoxConstraints constraints) {
                      return _buildHitAreas(constraints.biggest);
                    },
                  ),
                ),

                // Left Callouts
                Positioned(
                  left: 12,
                  top: 12,
                  bottom: 12,
                  child: _buildCalloutsColumn(
                    zones: const <CyberBodyZone>[
                      CyberBodyZone.head,
                      CyberBodyZone.eyes,
                      CyberBodyZone.ears,
                      CyberBodyZone.torso,
                      CyberBodyZone.skin,
                    ],
                    zoneMap: zoneMap,
                    selectedZone: effectiveSelected,
                    alignment: CrossAxisAlignment.start,
                  ),
                ),

                // Right Callouts
                Positioned(
                  right: 12,
                  top: 12,
                  bottom: 12,
                  child: _buildCalloutsColumn(
                    zones: const <CyberBodyZone>[
                      CyberBodyZone.arms,
                      CyberBodyZone.hands,
                      CyberBodyZone.groin,
                      CyberBodyZone.legs,
                    ],
                    zoneMap: zoneMap,
                    selectedZone: effectiveSelected,
                    alignment: CrossAxisAlignment.end,
                  ),
                ),

                // Corner Reticles
                const Positioned(
                  top: 8,
                  left: 8,
                  child: _CornerReticle(isTop: true, isLeft: true),
                ),
                const Positioned(
                  top: 8,
                  right: 8,
                  child: _CornerReticle(isTop: true, isLeft: false),
                ),
                const Positioned(
                  bottom: 8,
                  left: 8,
                  child: _CornerReticle(isTop: false, isLeft: true),
                ),
                const Positioned(
                  bottom: 8,
                  right: 8,
                  child: _CornerReticle(isTop: false, isLeft: false),
                ),
              ],
            ),
          ),

          // Bottom Zone Details & Actions Bar
          if (selectedZoneObj != null)
            _buildSelectionBottomBar(selectedZoneObj, selectedList, selectedHumanity)
          else
            _buildIdleBottomBar(),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CprPalette.surface,
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.biotech, size: 16, color: CprPalette.cyan),
              const SizedBox(width: 8),
              Text(
                'DIAGNOSTICA CORPOREA // BIO-CYBER SCANNER',
                style: CprType.label.copyWith(color: CprPalette.ink, letterSpacing: 1.1, fontSize: 11),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.cyan, 0.15),
                  border: Border.all(color: CprPalette.cyan, width: 0.8),
                ),
                child: Text(
                  'ONLINE',
                  style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 8.5),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: <Widget>[
              for (final BodyScanLayer layer in BodyScanLayer.values)
                InkWell(
                  onTap: () => setState(() => _activeLayer = layer),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _activeLayer == layer
                          ? CprPalette.veil(CprPalette.cyan, 0.2)
                          : CprPalette.surfaceSunken,
                      border: Border.all(
                        color: _activeLayer == layer ? CprPalette.cyan : CprPalette.hairline,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          layer.icon,
                          size: 11,
                          color: _activeLayer == layer ? CprPalette.cyan : CprPalette.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          layer.label.toUpperCase(),
                          style: CprType.label.copyWith(
                            color: _activeLayer == layer ? CprPalette.cyan : CprPalette.inkMuted,
                            fontSize: 8.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalloutsColumn({
    required List<CyberBodyZone> zones,
    required Map<String, List<Cyberware>> zoneMap,
    required String? selectedZone,
    required CrossAxisAlignment alignment,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: alignment,
      children: <Widget>[
        for (final CyberBodyZone zone in zones)
          _buildZoneCalloutItem(
            zone: zone,
            count: (zoneMap[zone.id] ?? const <Cyberware>[]).length,
            isSelected: selectedZone == zone.id,
            isHovered: _hoveredZone == zone.id,
          ),
      ],
    );
  }

  Widget _buildZoneCalloutItem({
    required CyberBodyZone zone,
    required int count,
    required bool isSelected,
    required bool isHovered,
  }) {
    final Color badgeColor = count > 2
        ? CprPalette.magenta
        : count > 0
            ? CprPalette.cyan
            : CprPalette.inkMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hoveredZone = zone.id),
      onExit: (_) => setState(() => _hoveredZone = null),
      child: GestureDetector(
        onTap: () {
          final String? next = widget.selectedZone == zone.id ? null : zone.id;
          widget.onZoneSelected?.call(next);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected
                ? CprPalette.veil(badgeColor, 0.25)
                : isHovered
                    ? CprPalette.veil(badgeColor, 0.12)
                    : CprPalette.surface.withValues(alpha: 0.8),
            border: Border.all(
              color: isSelected
                  ? badgeColor
                  : isHovered
                      ? CprPalette.veil(badgeColor, 0.6)
                      : CprPalette.hairline,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: CprPalette.veil(badgeColor, 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                zone.label.toUpperCase(),
                style: CprType.label.copyWith(
                  color: isSelected || isHovered ? badgeColor : CprPalette.ink,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: count > 0 ? CprPalette.veil(badgeColor, 0.25) : CprPalette.surfaceSunken,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: count > 0 ? badgeColor : CprPalette.hairline,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '$count',
                  style: CprType.numeralSmall.copyWith(
                    color: count > 0 ? badgeColor : CprPalette.inkFaint,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHitAreas(Size size) {
    // Relative coordinates of body zones on the canvas
    final Map<String, Rect> relativeAreas = <String, Rect>{
      'head': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.14), width: 70, height: 55),
      'eyes': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.13), width: 34, height: 16),
      'ears': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.16), width: 56, height: 18),
      'torso': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.35), width: 90, height: 95),
      'arms': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.38), width: 170, height: 90),
      'hands': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.53), width: 190, height: 50),
      'groin': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.50), width: 70, height: 45),
      'legs': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.74), width: 100, height: 140),
      'skin': Rect.fromCenter(center: Offset(size.width * 0.50, size.height * 0.24), width: 120, height: 40),
    };

    return Stack(
      children: <Widget>[
        for (final MapEntry<String, Rect> entry in relativeAreas.entries)
          Positioned.fromRect(
            rect: entry.value,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoveredZone = entry.key),
              onExit: (_) => setState(() => _hoveredZone = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  final String? next = widget.selectedZone == entry.key ? null : entry.key;
                  widget.onZoneSelected?.call(next);
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectionBottomBar(
    CyberBodyZone zone,
    List<Cyberware> items,
    int humanity,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CprPalette.surface,
        border: Border(top: BorderSide(color: CprPalette.hairline)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.cyan, 0.15),
                  border: Border.all(color: CprPalette.cyan),
                ),
                child: const Icon(Icons.my_location, size: 14, color: CprPalette.cyan),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'ZONA: ${zone.label.toUpperCase()}',
                        style: CprType.body.copyWith(
                          color: CprPalette.cyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${items.length} impianti · -$humanity Umanità)',
                        style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 10.5),
                      ),
                    ],
                  ),
                  Text(
                    zone.description,
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TechButton(
                label: 'Installa in ${zone.label}',
                icon: Icons.add,
                variant: TechButtonVariant.primary,
                compact: true,
                onPressed: () => widget.onInstallInZone?.call(zone.id),
              ),
              const SizedBox(width: 8),
              TechButton(
                label: 'Mostra tutti',
                icon: Icons.close,
                variant: TechButtonVariant.secondary,
                compact: true,
                onPressed: () => widget.onZoneSelected?.call(null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdleBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: CprPalette.surface,
        border: Border(top: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.touch_app_outlined, size: 14, color: CprPalette.inkMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Clicca su una zona del corpo anatomico o sulle etichette per filtrare gli impianti o visualizzare la concentrazione di cyberware.',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Disegna la griglia e gli assi di scansione
class _CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint gridPaint = Paint()
      ..color = CprPalette.hairline.withValues(alpha: 0.35)
      ..strokeWidth = 0.5;

    const double step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Assi centrali
    final Paint axisPaint = Paint()
      ..color = CprPalette.cyan.withValues(alpha: 0.20)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), axisPaint);

    // Cerchi olografici di scansione di fondo
    final Paint circlePaint = Paint()
      ..color = CprPalette.cyan.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.45), 110, circlePaint);
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.45), 160, circlePaint);
  }

  @override
  bool shouldRepaint(_CyberGridPainter oldDelegate) => false;
}

/// Disegna i 4 layer anatomici completi: Silhouette, Scheletro, Vascolare, Nervoso + Zone Glow
class _BodyAnatomyPainter extends CustomPainter {
  _BodyAnatomyPainter({
    required this.activeLayer,
    required this.zoneCounts,
    required this.selectedZone,
    required this.hoveredZone,
    required this.pulsePhase,
  });

  final BodyScanLayer activeLayer;
  final Map<String, int> zoneCounts;
  final String? selectedZone;
  final String? hoveredZone;
  final double pulsePhase;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.08;
    // Scale factor to fit anatomical body neatly inside the canvas height
    final double s = (size.height / 420.0).clamp(0.65, 1.4);

    final double pulse = 0.5 + 0.5 * math.sin(pulsePhase * math.pi * 2);

    // 1. Silhouette del corpo umano (Sempre visibile o evidenziata)
    _drawBodySilhouette(canvas, cx, cy, s);

    // 2. Zone Glow dinamico (basato sui cyberware installati)
    _drawZoneGlows(canvas, cx, cy, s, pulse);

    // 3. Layer Scheletro
    if (activeLayer == BodyScanLayer.all || activeLayer == BodyScanLayer.skeleton) {
      _drawSkeleton(canvas, cx, cy, s);
    }

    // 4. Layer Vascolare (Vene & Arterie con sangue sintetico pulsante)
    if (activeLayer == BodyScanLayer.all || activeLayer == BodyScanLayer.vascular) {
      _drawVascular(canvas, cx, cy, s, pulse);
    }

    // 5. Layer Nervoso (Midollo, Nervi & Sinapsi fluorescenti)
    if (activeLayer == BodyScanLayer.all || activeLayer == BodyScanLayer.nervous) {
      _drawNervous(canvas, cx, cy, s, pulse);
    }

    // 6. Evidenziazione zona selezionata/hover
    _drawTargetReticles(canvas, cx, cy, s, pulse);
  }

  void _drawBodySilhouette(Canvas canvas, double cx, double cy, double s) {
    final Path body = Path();

    // Testa / Cranio
    body.addOval(Rect.fromCenter(center: Offset(cx, cy + 24 * s), width: 34 * s, height: 44 * s));

    // Collo, Spalle, Torso, Bacino, Gambe, Braccia (Postura anatomica cyberpunk)
    final Path contour = Path();
    contour.moveTo(cx - 7 * s, cy + 44 * s); // Collo sx
    contour.lineTo(cx - 28 * s, cy + 54 * s); // Spalla sx
    contour.lineTo(cx - 52 * s, cy + 100 * s); // Bicipite sx
    contour.lineTo(cx - 70 * s, cy + 155 * s); // Avambraccio sx
    contour.lineTo(cx - 82 * s, cy + 195 * s); // Mano sx
    contour.lineTo(cx - 74 * s, cy + 195 * s);
    contour.lineTo(cx - 60 * s, cy + 155 * s);
    contour.lineTo(cx - 44 * s, cy + 104 * s); // Ascella sx
    contour.lineTo(cx - 30 * s, cy + 120 * s); // Torace sx
    contour.lineTo(cx - 24 * s, cy + 150 * s); // Vita sx
    contour.lineTo(cx - 28 * s, cy + 175 * s); // Anca sx
    contour.lineTo(cx - 26 * s, cy + 240 * s); // Coscia sx
    contour.lineTo(cx - 24 * s, cy + 295 * s); // Ginocchio sx
    contour.lineTo(cx - 20 * s, cy + 355 * s); // Polpaccio sx
    contour.lineTo(cx - 22 * s, cy + 380 * s); // Caviglia / Piede sx
    contour.lineTo(cx - 10 * s, cy + 380 * s);
    contour.lineTo(cx - 8 * s, cy + 345 * s);
    contour.lineTo(cx - 8 * s, cy + 285 * s);
    contour.lineTo(cx - 2 * s, cy + 200 * s); // Cavallo

    // Lato Dx simmetrico
    contour.lineTo(cx + 2 * s, cy + 200 * s);
    contour.lineTo(cx + 8 * s, cy + 285 * s);
    contour.lineTo(cx + 8 * s, cy + 345 * s);
    contour.lineTo(cx + 10 * s, cy + 380 * s);
    contour.lineTo(cx + 22 * s, cy + 380 * s); // Caviglia / Piede dx
    contour.lineTo(cx + 20 * s, cy + 355 * s);
    contour.lineTo(cx + 24 * s, cy + 295 * s); // Ginocchio dx
    contour.lineTo(cx + 26 * s, cy + 240 * s); // Coscia dx
    contour.lineTo(cx + 28 * s, cy + 175 * s); // Anca dx
    contour.lineTo(cx + 24 * s, cy + 150 * s); // Vita dx
    contour.lineTo(cx + 30 * s, cy + 120 * s); // Torace dx
    contour.lineTo(cx + 44 * s, cy + 104 * s); // Ascella dx
    contour.lineTo(cx + 60 * s, cy + 155 * s);
    contour.lineTo(cx + 74 * s, cy + 195 * s);
    contour.lineTo(cx + 82 * s, cy + 195 * s); // Mano dx
    contour.lineTo(cx + 70 * s, cy + 155 * s); // Avambraccio dx
    contour.lineTo(cx + 52 * s, cy + 100 * s); // Bicipite dx
    contour.lineTo(cx + 28 * s, cy + 54 * s); // Spalla dx
    contour.lineTo(cx + 7 * s, cy + 44 * s); // Collo dx
    contour.close();

    // Riempimento base sagoma
    final Paint fill = Paint()
      ..color = CprPalette.surfaceSunken.withValues(alpha: 0.70)
      ..style = PaintingStyle.fill;
    canvas.drawPath(body, fill);
    canvas.drawPath(contour, fill);

    // Contorno neon azzurro scuro
    final Paint stroke = Paint()
      ..color = CprPalette.cyan.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * s;
    canvas.drawPath(body, stroke);
    canvas.drawPath(contour, stroke);
  }

  void _drawZoneGlows(Canvas canvas, double cx, double cy, double s, double pulse) {
    // Coordinate centrali per ciascuna zona anatomica
    final Map<String, Offset> zoneCenters = <String, Offset>{
      'head': Offset(cx, cy + 24 * s),
      'eyes': Offset(cx, cy + 20 * s),
      'ears': Offset(cx, cy + 24 * s),
      'torso': Offset(cx, cy + 115 * s),
      'arms': Offset(cx, cy + 125 * s),
      'hands': Offset(cx, cy + 185 * s),
      'groin': Offset(cx, cy + 185 * s),
      'legs': Offset(cx, cy + 290 * s),
      'skin': Offset(cx, cy + 100 * s),
    };

    final Map<String, double> zoneRadii = <String, double>{
      'head': 24 * s,
      'eyes': 14 * s,
      'ears': 20 * s,
      'torso': 38 * s,
      'arms': 65 * s,
      'hands': 80 * s,
      'groin': 22 * s,
      'legs': 38 * s,
      'skin': 48 * s,
    };

    for (final MapEntry<String, Offset> entry in zoneCenters.entries) {
      final String zId = entry.key;
      final Offset center = entry.value;
      final double baseRadius = zoneRadii[zId] ?? 25 * s;
      final int count = zoneCounts[zId] ?? 0;
      final bool isSelected = selectedZone == zId;
      final bool isHovered = hoveredZone == zId;

      if (count > 0 || isSelected || isHovered) {
        // Colore dinamico: Magenta se sovraccarico (3+), Giallo se 2, Ciano se 1
        final Color glowColor = count >= 3
            ? CprPalette.magenta
            : count == 2
                ? CprPalette.yellow
                : CprPalette.cyan;

        final double glowBlur = (count * 6.0 + 8.0) * s;
        final double glowOpacity = (0.20 + (count * 0.15) + (pulse * 0.12)).clamp(0.2, 0.85);

        // Bagliore sfumato
        final Paint glowPaint = Paint()
          ..color = glowColor.withValues(alpha: isSelected ? 0.9 : glowOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.0 + count * 1.5) * s
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowBlur);

        if (zId == 'arms') {
          // Glow separato su entrambe le braccia
          canvas.drawCircle(Offset(cx - 58 * s, cy + 130 * s), 20 * s, glowPaint);
          canvas.drawCircle(Offset(cx + 58 * s, cy + 130 * s), 20 * s, glowPaint);
        } else if (zId == 'hands') {
          // Glow su entrambe le mani
          canvas.drawCircle(Offset(cx - 76 * s, cy + 185 * s), 16 * s, glowPaint);
          canvas.drawCircle(Offset(cx + 76 * s, cy + 185 * s), 16 * s, glowPaint);
        } else if (zId == 'legs') {
          // Glow su entrambe le gambe
          canvas.drawCircle(Offset(cx - 18 * s, cy + 280 * s), 20 * s, glowPaint);
          canvas.drawCircle(Offset(cx + 18 * s, cy + 280 * s), 20 * s, glowPaint);
        } else {
          canvas.drawCircle(center, baseRadius, glowPaint);
        }

        // Anello luminoso definito se selezionata
        if (isSelected || isHovered) {
          final Paint selectPaint = Paint()
            ..color = glowColor.withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * s;
          canvas.drawCircle(center, baseRadius + 4 * s, selectPaint);
        }
      }
    }
  }

  void _drawSkeleton(Canvas canvas, double cx, double cy, double s) {
    final Paint bonePaint = Paint()
      ..color = CprPalette.ink.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * s;

    final Paint jointPaint = Paint()
      ..color = CprPalette.cyan.withValues(alpha: 0.80)
      ..style = PaintingStyle.fill;

    // Cranio scheletrico
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 24 * s), width: 26 * s, height: 32 * s),
      bonePaint,
    );
    // Orbite oculari
    canvas.drawCircle(Offset(cx - 5 * s, cy + 22 * s), 3 * s, bonePaint);
    canvas.drawCircle(Offset(cx + 5 * s, cy + 22 * s), 3 * s, bonePaint);

    // Colonna vertebrale (vertebre)
    for (int i = 0; i < 11; i++) {
      final double vy = cy + (48 + i * 11) * s;
      canvas.drawLine(Offset(cx - 4 * s, vy), Offset(cx + 4 * s, vy), bonePaint);
    }

    // Clavicole
    canvas.drawLine(Offset(cx - 28 * s, cy + 56 * s), Offset(cx + 28 * s, cy + 56 * s), bonePaint);

    // Gabbia toracica (costole curvate)
    for (int i = 0; i < 5; i++) {
      final double ry = cy + (65 + i * 11) * s;
      final double rw = (14 + i * 2.5) * s;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, ry), width: rw * 2, height: 12 * s),
        math.pi * 0.1,
        math.pi * 0.8,
        false,
        bonePaint,
      );
    }

    // Pelvi / Bacino
    final Path pelvis = Path()
      ..moveTo(cx - 24 * s, cy + 172 * s)
      ..cubicTo(cx - 16 * s, cy + 160 * s, cx + 16 * s, cy + 160 * s, cx + 24 * s, cy + 172 * s)
      ..lineTo(cx + 16 * s, cy + 195 * s)
      ..lineTo(cx - 16 * s, cy + 195 * s)
      ..close();
    canvas.drawPath(pelvis, bonePaint);

    // Ossa Braccia (Omeri, Radio, Ulna)
    // Braccio sx
    canvas.drawLine(Offset(cx - 28 * s, cy + 56 * s), Offset(cx - 52 * s, cy + 104 * s), bonePaint);
    canvas.drawLine(Offset(cx - 52 * s, cy + 104 * s), Offset(cx - 72 * s, cy + 160 * s), bonePaint);
    // Braccio dx
    canvas.drawLine(Offset(cx + 28 * s, cy + 56 * s), Offset(cx + 52 * s, cy + 104 * s), bonePaint);
    canvas.drawLine(Offset(cx + 52 * s, cy + 104 * s), Offset(cx + 72 * s, cy + 160 * s), bonePaint);

    // Ossa Gambe (Femori, Tibie)
    // Gamba sx
    canvas.drawLine(Offset(cx - 18 * s, cy + 195 * s), Offset(cx - 22 * s, cy + 285 * s), bonePaint);
    canvas.drawLine(Offset(cx - 22 * s, cy + 285 * s), Offset(cx - 16 * s, cy + 365 * s), bonePaint);
    // Gamba dx
    canvas.drawLine(Offset(cx + 18 * s, cy + 195 * s), Offset(cx + 22 * s, cy + 285 * s), bonePaint);
    canvas.drawLine(Offset(cx + 22 * s, cy + 285 * s), Offset(cx + 16 * s, cy + 365 * s), bonePaint);

    // Giunti articolari luminosi (Spalle, Gomiti, Fianchi, Ginocchia)
    final List<Offset> joints = <Offset>[
      Offset(cx - 28 * s, cy + 56 * s),
      Offset(cx + 28 * s, cy + 56 * s),
      Offset(cx - 52 * s, cy + 104 * s),
      Offset(cx + 52 * s, cy + 104 * s),
      Offset(cx - 18 * s, cy + 195 * s),
      Offset(cx + 18 * s, cy + 195 * s),
      Offset(cx - 22 * s, cy + 285 * s),
      Offset(cx + 22 * s, cy + 285 * s),
    ];
    for (final Offset j in joints) {
      canvas.drawCircle(j, 2.5 * s, jointPaint);
    }
  }

  void _drawVascular(Canvas canvas, double cx, double cy, double s, double pulse) {
    // Arterie (Rosso/Magenta) e Vene (Ciano/Azzurro)
    final Paint arteryPaint = Paint()
      ..color = CprPalette.danger.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * s;

    final Paint veinPaint = Paint()
      ..color = CprPalette.cyan.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * s;

    // Cuore sintetico
    final Offset heartPos = Offset(cx - 5 * s, cy + 86 * s);
    canvas.drawCircle(
      heartPos,
      4.5 * s,
      Paint()
        ..color = CprPalette.danger
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s),
    );

    // Arteria Aorta discendente & carotidi
    final Path aorta = Path();
    aorta.moveTo(heartPos.dx, heartPos.dy);
    aorta.lineTo(heartPos.dx + 4 * s, heartPos.dy - 12 * s);
    aorta.lineTo(cx, heartPos.dy - 28 * s); // Carotidi collo
    aorta.lineTo(cx, cy + 32 * s); // Cervello
    aorta.moveTo(heartPos.dx, heartPos.dy);
    aorta.lineTo(cx - 2 * s, cy + 180 * s); // Aorta addominale
    canvas.drawPath(aorta, arteryPaint);

    // Vene e arterie braccia
    canvas.drawLine(heartPos, Offset(cx - 52 * s, cy + 104 * s), arteryPaint);
    canvas.drawLine(Offset(cx - 52 * s, cy + 104 * s), Offset(cx - 72 * s, cy + 160 * s), arteryPaint);
    canvas.drawLine(Offset(heartPos.dx + 6 * s, heartPos.dy), Offset(cx + 52 * s, cy + 104 * s), veinPaint);
    canvas.drawLine(Offset(cx + 52 * s, cy + 104 * s), Offset(cx + 72 * s, cy + 160 * s), veinPaint);

    // Vasi femorali arti inferiori
    canvas.drawLine(Offset(cx - 2 * s, cy + 180 * s), Offset(cx - 18 * s, cy + 285 * s), arteryPaint);
    canvas.drawLine(Offset(cx - 18 * s, cy + 285 * s), Offset(cx - 15 * s, cy + 360 * s), arteryPaint);
    canvas.drawLine(Offset(cx + 2 * s, cy + 180 * s), Offset(cx + 18 * s, cy + 285 * s), veinPaint);
    canvas.drawLine(Offset(cx + 18 * s, cy + 285 * s), Offset(cx + 15 * s, cy + 360 * s), veinPaint);

    // Particella pulsante di flusso sanguigno
    final double flowY = cy + (60 + (pulse * 260)) * s;
    canvas.drawCircle(
      Offset(cx - 2 * s, flowY),
      1.8 * s,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 * s),
    );
  }

  void _drawNervous(Canvas canvas, double cx, double cy, double s, double pulse) {
    final Paint nervePaint = Paint()
      ..color = CprPalette.yellow.withValues(alpha: 0.70)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * s;

    // Encefalo / Tronco
    final Path brain = Path();
    brain.addOval(Rect.fromCenter(center: Offset(cx, cy + 22 * s), width: 18 * s, height: 20 * s));
    canvas.drawPath(brain, nervePaint);

    // Midollo spinale
    final Path cord = Path()
      ..moveTo(cx, cy + 32 * s)
      ..lineTo(cx, cy + 175 * s);
    canvas.drawPath(cord, nervePaint);

    // Plesso brachiale verso le mani
    final Path nervesArms = Path();
    nervesArms.moveTo(cx, cy + 60 * s);
    nervesArms.lineTo(cx - 50 * s, cy + 102 * s);
    nervesArms.lineTo(cx - 70 * s, cy + 155 * s);
    nervesArms.lineTo(cx - 78 * s, cy + 185 * s); // Terminazioni palmo sx

    nervesArms.moveTo(cx, cy + 60 * s);
    nervesArms.lineTo(cx + 50 * s, cy + 102 * s);
    nervesArms.lineTo(cx + 70 * s, cy + 155 * s);
    nervesArms.lineTo(cx + 78 * s, cy + 185 * s); // Terminazioni palmo dx
    canvas.drawPath(nervesArms, nervePaint);

    // Nervi sciatici verso piedi
    final Path nervesLegs = Path();
    nervesLegs.moveTo(cx, cy + 175 * s);
    nervesLegs.lineTo(cx - 20 * s, cy + 285 * s);
    nervesLegs.lineTo(cx - 16 * s, cy + 365 * s);

    nervesLegs.moveTo(cx, cy + 175 * s);
    nervesLegs.lineTo(cx + 20 * s, cy + 285 * s);
    nervesLegs.lineTo(cx + 16 * s, cy + 365 * s);
    canvas.drawPath(nervesLegs, nervePaint);

    // Nodi di scarica sinaptica
    final List<Offset> nodes = <Offset>[
      Offset(cx, cy + 22 * s),
      Offset(cx, cy + 60 * s),
      Offset(cx, cy + 115 * s),
      Offset(cx, cy + 175 * s),
      Offset(cx - 78 * s, cy + 185 * s),
      Offset(cx + 78 * s, cy + 185 * s),
    ];

    for (final Offset n in nodes) {
      canvas.drawCircle(
        n,
        2.0 * s,
        Paint()
          ..color = CprPalette.yellow.withValues(alpha: 0.6 + 0.4 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3.0 * s),
      );
    }
  }

  void _drawTargetReticles(Canvas canvas, double cx, double cy, double s, double pulse) {
    if (selectedZone == null && hoveredZone == null) return;
    final String active = (selectedZone ?? hoveredZone)!;

    final Map<String, Offset> targets = <String, Offset>{
      'head': Offset(cx, cy + 24 * s),
      'eyes': Offset(cx, cy + 20 * s),
      'ears': Offset(cx, cy + 24 * s),
      'torso': Offset(cx, cy + 115 * s),
      'arms': Offset(cx - 58 * s, cy + 130 * s),
      'hands': Offset(cx - 76 * s, cy + 185 * s),
      'groin': Offset(cx, cy + 185 * s),
      'legs': Offset(cx - 18 * s, cy + 280 * s),
      'skin': Offset(cx, cy + 100 * s),
    };

    final Offset? target = targets[active];
    if (target == null) return;

    final Paint reticlePaint = Paint()
      ..color = CprPalette.cyan.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * s;

    final double r = 18 * s + pulse * 4 * s;
    canvas.drawCircle(target, r, reticlePaint);

    // Mirino a croce
    canvas.drawLine(Offset(target.dx - r - 6 * s, target.dy), Offset(target.dx - r, target.dy), reticlePaint);
    canvas.drawLine(Offset(target.dx + r, target.dy), Offset(target.dx + r + 6 * s, target.dy), reticlePaint);
    canvas.drawLine(Offset(target.dx, target.dy - r - 6 * s), Offset(target.dx, target.dy - r), reticlePaint);
    canvas.drawLine(Offset(target.dx, target.dy + r), Offset(target.dx, target.dy + r + 6 * s), reticlePaint);
  }

  @override
  bool shouldRepaint(_BodyAnatomyPainter oldDelegate) =>
      oldDelegate.activeLayer != activeLayer ||
      oldDelegate.selectedZone != selectedZone ||
      oldDelegate.hoveredZone != hoveredZone ||
      oldDelegate.pulsePhase != pulsePhase ||
      oldDelegate.zoneCounts != zoneCounts;
}

/// Angoli del visualizzatore in stile HUD
class _CornerReticle extends StatelessWidget {
  const _CornerReticle({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: CustomPaint(
        painter: _ReticlePainter(isTop: isTop, isLeft: isLeft),
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  const _ReticlePainter({required this.isTop, required this.isLeft});

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = CprPalette.cyan.withValues(alpha: 0.6)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final double x = isLeft ? 0 : size.width;
    final double y = isTop ? 0 : size.height;
    final double dx = isLeft ? 10 : -10;
    final double dy = isTop ? 10 : -10;

    final Path path = Path()
      ..moveTo(x, y + dy)
      ..lineTo(x, y)
      ..lineTo(x + dx, y);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_ReticlePainter oldDelegate) => false;
}
