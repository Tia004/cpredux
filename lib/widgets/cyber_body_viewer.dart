import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/palette.dart';
import '../design/typography.dart';
import '../domain/cyberware.dart';
import 'anatomy/anatomy_model.dart';
import 'anatomy/anatomy_scene.dart';
import 'tech_button.dart';

enum BodyScanLayer {
  surface('X-Ray', Icons.person_outline, 'surface'),
  all('Tutti i sistemi', Icons.layers_outlined, 'all'),
  skeleton('Scheletro', Icons.accessibility_new, 'skeleton'),
  vascular('Vascolare', Icons.favorite_border, 'vascular'),
  nervous('Nervoso', Icons.bolt, 'nervous'),
  zones('Zone cyber', Icons.grid_view, 'zones');

  const BodyScanLayer(this.label, this.icon, this.id);
  final String label;
  final IconData icon;
  final String id;
}

/// An offline, native 3D scanner. Mesh projection and picking share the same
/// camera, so selections continue to follow the body while orbiting and zooming.
class CyberBodyViewer extends StatefulWidget {
  const CyberBodyViewer({
    super.key,
    required this.cyberware,
    this.selectedZone,
    this.onZoneSelected,
    this.onInstallInZone,
    this.height = 560,
    this.model,
    this.humanity,
    this.maxHumanity,
    this.isCyberpsychotic = false,
  });
  final List<Cyberware> cyberware;
  final String? selectedZone;
  final ValueChanged<String?>? onZoneSelected;
  final ValueChanged<String>? onInstallInZone;
  final double height;
  final AnatomyModel? model;
  final int? humanity;
  final int? maxHumanity;
  final bool isCyberpsychotic;

  @override
  State<CyberBodyViewer> createState() => _CyberBodyViewerState();
}

class _CyberBodyViewerState extends State<CyberBodyViewer>
    with SingleTickerProviderStateMixin {
  AnatomyModel? _model;
  bool _failed = false;
  BodyScanLayer _layer = BodyScanLayer.surface;
  AnatomyCamera _camera = const AnatomyCamera();
  double _gestureZoom = 1;
  final FocusNode _focus = FocusNode(debugLabel: 'Anatomy 3D camera');
  AnatomyFrame? _frame;
  Size? _frameSize;
  late final AnimationController _anim;

  double get _strainRatio {
    double strain = (widget.cyberware.length / 8.0).clamp(0.0, 1.0);
    if (widget.humanity != null && widget.maxHumanity != null && widget.maxHumanity! > 0) {
      final double lost = (1.0 - widget.humanity! / widget.maxHumanity!).clamp(0.0, 1.0);
      strain = math.max(strain, lost);
    }
    return strain;
  }

  bool get _isPsychotic =>
      widget.isCyberpsychotic || (widget.humanity != null && widget.humanity! < 10);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _model = widget.model;
    if (_model == null) _load();
  }

  Future<void> _load() async {
    try {
      final AnatomyModel model = await AnatomyModel.load();
      if (mounted) {
        setState(() {
          _model = model;
          _failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(CyberBodyViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model && widget.model != null) {
      _model = widget.model;
    }
    _frame = null;
  }

  @override
  void dispose() {
    _anim.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _view(AnatomyCamera camera) => setState(() {
    _camera = camera;
    _frame = null;
  });
  void _select(String? zone) =>
      widget.onZoneSelected?.call(widget.selectedZone == zone ? null : zone);

  Map<String, List<Cyberware>> get _zones {
    final Map<String, List<Cyberware>> result = <String, List<Cyberware>>{
      for (final CyberBodyZone z in CyberBodyZone.values) z.id: <Cyberware>[],
    };
    for (final Cyberware c in widget.cyberware) {
      result[CyberBodyZone.fromId(c.bodyZone).id]!.add(c);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Cyberware>> zones = _zones;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF091316),
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.biotech_outlined,
                  size: 18,
                  color: CprPalette.cyan,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'DIAGNOSTICA CORPOREA // BIO-CYBER SCANNER',
                    style: CprType.label.copyWith(
                      fontSize: 10,
                      color: CprPalette.ink,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ONLINE',
                  style: CprType.label.copyWith(
                    fontSize: 8,
                    color: CprPalette.cyan,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Wrap(
              spacing: 5,
              runSpacing: 6,
              children: <Widget>[
                for (final BodyScanLayer layer in BodyScanLayer.values)
                  Semantics(
                    selected: _layer == layer,
                    button: true,
                    child: Tooltip(
                      message: 'Isola ${layer.label.toLowerCase()}',
                      child: InkWell(
                        onTap: () => setState(() {
                          _layer = layer;
                          _frame = null;
                        }),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: _layer == layer
                                ? CprPalette.cyan.withValues(alpha: .12)
                                : Colors.transparent,
                            border: Border.all(
                              color: _layer == layer
                                  ? CprPalette.cyan
                                  : CprPalette.hairline,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                layer.icon,
                                size: 13,
                                color: _layer == layer
                                    ? CprPalette.cyan
                                    : CprPalette.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                layer.label.toUpperCase(),
                                style: CprType.label.copyWith(
                                  fontSize: 9,
                                  color: _layer == layer
                                      ? CprPalette.cyan
                                      : CprPalette.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool wide = constraints.maxWidth >= 650;
              return Column(
                children: <Widget>[
                  SizedBox(
                    height: widget.height,
                    child: Row(
                      children: <Widget>[
                        if (wide)
                          SizedBox(
                            width: 184,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: 14,
                                      left: 8,
                                    ),
                                    child: Text(
                                      'REGIONI / 12',
                                      style: CprType.label.copyWith(
                                        fontSize: 8,
                                        color: CprPalette.inkFaint,
                                      ),
                                    ),
                                  ),
                                  for (final CyberBodyZone zone
                                      in CyberBodyZone.selectable)
                                    Expanded(
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _zoneButton(
                                          zone,
                                          zones[zone.id]!.length,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        Expanded(child: _viewport(zones)),
                      ],
                    ),
                  ),
                  if (!wide)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          for (final CyberBodyZone zone
                              in CyberBodyZone.selectable)
                            _zoneButton(zone, zones[zone.id]!.length),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if (zones.entries.any(
            (e) =>
                CyberBodyZone.fromId(e.key).hasUnassignedSide &&
                e.value.isNotEmpty,
          ))
            Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: <Widget>[
                  for (final CyberBodyZone zone in CyberBodyZone.values.where(
                    (z) => z.hasUnassignedSide && zones[z.id]!.isNotEmpty,
                  ))
                    _zoneButton(zone, zones[zone.id]!.length),
                ],
              ),
            ),
          _controls(),
          _details(zones),
        ],
      ),
    );
  }

  Widget _zoneButton(CyberBodyZone zone, int count) {
    final bool selected = widget.selectedZone == zone.id;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: () => _select(zone.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? CprPalette.cyan.withValues(alpha: .09)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: selected ? CprPalette.cyan : CprPalette.hairline,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: Text(
                  zone.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CprType.label.copyWith(
                    fontSize: 10,
                    color: selected ? CprPalette.cyan : CprPalette.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count'.padLeft(2, '0'),
                style: CprType.numeralSmall.copyWith(
                  fontSize: 10,
                  color: count > 0 ? CprPalette.cyan : CprPalette.inkFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _viewport(Map<String, List<Cyberware>> zones) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = constraints.biggest;
        if (_model != null && (_frame == null || _frameSize != size)) {
          _frame = AnatomyFrame.project(
            model: _model!,
            size: size,
            camera: _camera,
            layer: _layer.id,
            selectedZone: widget.selectedZone,
            installedZones: zones.entries
                .where(
                  (MapEntry<String, List<Cyberware>> e) => e.value.isNotEmpty,
                )
                .map((e) => e.key)
                .toSet(),
          );
          _frameSize = size;
        }
        return Focus(
          focusNode: _focus,
          onKeyEvent: (FocusNode node, KeyEvent event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            final LogicalKeyboardKey k = event.logicalKey;
            if (k == LogicalKeyboardKey.arrowLeft) {
              _view(_camera.orbit(-10, 0));
            } else if (k == LogicalKeyboardKey.arrowRight) {
              _view(_camera.orbit(10, 0));
            } else if (k == LogicalKeyboardKey.arrowUp) {
              _view(_camera.orbit(0, -10));
            } else if (k == LogicalKeyboardKey.arrowDown) {
              _view(_camera.orbit(0, 10));
            } else if (k == LogicalKeyboardKey.equal ||
                k == LogicalKeyboardKey.add) {
              _view(_camera.magnify(_camera.zoom * 1.15));
            } else if (k == LogicalKeyboardKey.minus ||
                k == LogicalKeyboardKey.numpadSubtract) {
              _view(_camera.magnify(_camera.zoom / 1.15));
            } else if (k == LogicalKeyboardKey.home) {
              _view(const AnatomyCamera());
            } else {
              return KeyEventResult.ignored;
            }
            return KeyEventResult.handled;
          },
          child: Listener(
            onPointerSignal: (PointerSignalEvent event) {
              if (event is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(event, (
                  PointerSignalEvent e,
                ) {
                  _view(
                    _camera.magnify(
                      _camera.zoom * math.exp(-event.scrollDelta.dy * .002),
                    ),
                  );
                });
              }
            },
            child: GestureDetector(
              key: const ValueKey<String>('anatomy-viewport'),
              behavior: HitTestBehavior.opaque,
              onTapUp: (TapUpDetails details) {
                _focus.requestFocus();
                _select(_frame?.pick(details.localPosition));
              },
              onScaleStart: (_) {
                _focus.requestFocus();
                _gestureZoom = _camera.zoom;
              },
              onScaleUpdate: (ScaleUpdateDetails details) {
                final Offset delta = details.focalPointDelta;
                AnatomyCamera camera = _camera;
                if (details.pointerCount > 1 ||
                    HardwareKeyboard.instance.isShiftPressed) {
                  camera = camera.move(delta);
                } else {
                  camera = camera.orbit(delta.dx, delta.dy);
                }
                _view(camera.magnify(_gestureZoom * details.scale));
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Semantics(
                  label: 'Corpo anatomico 3D. Trascina per ruotare, scorri per zoomare. Frecce e tasti più e meno disponibili.',
                  child: AnimatedBuilder(
                    animation: _anim,
                    builder: (BuildContext context, _) {
                      return ClipRect(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            CustomPaint(
                              painter: _CyberSpaceBackdrop(
                                phase: _anim.value,
                                strain: _strainRatio,
                              ),
                            ),
                            if (_frame != null)
                              RepaintBoundary(
                                child: CustomPaint(
                                  painter: AnatomyPainter(_frame!),
                                ),
                              ),
                            if (_frame != null)
                              CustomPaint(
                                painter: _CyberwareNodesPainter(
                                  frame: _frame!,
                                  cyberware: widget.cyberware,
                                  selectedZone: widget.selectedZone,
                                  phase: _anim.value,
                                ),
                              ),
                            if (_isPsychotic &&
                                _frame != null &&
                                _frame!.headCenter != null)
                              CustomPaint(
                                painter: _HeadGlitchPainter(
                                  center: _frame!.headCenter!,
                                  radius: _frame!.headRadius,
                                  phase: _anim.value,
                                ),
                              ),
                            if (_model == null)
                              Center(
                                child: _failed
                                    ? Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          const Text(
                                            'Modello anatomico non disponibile',
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              setState(() => _failed = false);
                                              _load();
                                            },
                                            child: const Text('Riprova'),
                                          ),
                                        ],
                                      )
                                    : const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                              ),
                            Positioned(
                              top: 12,
                              left: 18,
                              child: IgnorePointer(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      'ANATOMIA / 3D SCANNER',
                                      style: CprType.label.copyWith(
                                        color: CprPalette.cyan,
                                        fontSize: 9,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      _layer.label.toUpperCase(),
                                      style: CprType.label.copyWith(
                                        color: CprPalette.inkFaint,
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              right: 14,
                              child: IgnorePointer(
                                child: Text(
                                  'ORBITA 360°  /  ${(_camera.zoom * 100).round()}%',
                                  style: CprType.label.copyWith(
                                    color: CprPalette.inkFaint,
                                    fontSize: 8,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _controls() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: CprPalette.hairline)),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 6,
      children: <Widget>[
        Wrap(
          spacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            TextButton(
              onPressed: () => _view(const AnatomyCamera(yaw: 0)),
              child: const Text('Fronte'),
            ),
            TextButton(
              onPressed: () => _view(const AnatomyCamera(yaw: math.pi / 2)),
              child: const Text('Profilo'),
            ),
            TextButton(
              onPressed: () => _view(const AnatomyCamera(yaw: math.pi)),
              child: const Text('Dorso'),
            ),
            IconButton(
              tooltip: 'Zoom indietro',
              onPressed: () => _view(_camera.magnify(_camera.zoom / 1.2)),
              icon: const Icon(Icons.remove, size: 17),
            ),
            IconButton(
              tooltip: 'Zoom avanti',
              onPressed: () => _view(_camera.magnify(_camera.zoom * 1.2)),
              icon: const Icon(Icons.add, size: 17),
            ),
            IconButton(
              tooltip: 'Ripristina vista',
              onPressed: () => _view(const AnatomyCamera()),
              icon: const Icon(Icons.center_focus_strong, size: 17),
            ),
          ],
        ),
        Text(
          'Trascina: ruota · Rotella: zoom · Shift + trascina: sposta',
          style: CprType.caption.copyWith(
            fontSize: 9,
            color: CprPalette.inkFaint,
          ),
        ),
      ],
    ),
  );

  Widget _details(Map<String, List<Cyberware>> zones) {
    final String? selected = widget.selectedZone;
    final CyberBodyZone? zone = selected == null
        ? null
        : CyberBodyZone.fromId(selected);
    final List<Cyberware> items = zone == null
        ? <Cyberware>[]
        : zones[zone.id]!;
    return Container(
      padding: const EdgeInsets.all(12),
      color: CprPalette.surface,
      child: Wrap(
        spacing: 16,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          if (zone == null)
            Text(
              'Seleziona una parte del corpo per vedere gli impianti.',
              style: CprType.caption.copyWith(
                color: CprPalette.inkMuted,
                fontSize: 11,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'ZONA: ${zone.label.toUpperCase()}',
                  style: CprType.label.copyWith(
                    color: CprPalette.cyan,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${items.length} impianti · ${items.fold<int>(0, (int n, Cyberware c) => n + c.humanityLost)} umanità persa',
                  style: CprType.caption.copyWith(
                    color: CprPalette.inkMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          if (zone != null)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: <Widget>[
                TechButton(
                  label: 'Installa in ${zone.label}',
                  icon: Icons.add,
                  compact: true,
                  onPressed: widget.onInstallInZone == null
                      ? null
                      : () => widget.onInstallInZone!(zone.id),
                ),
                TechButton(
                  label: 'Mostra tutti',
                  icon: Icons.close,
                  compact: true,
                  variant: TechButtonVariant.secondary,
                  onPressed: () => widget.onZoneSelected?.call(null),
                ),
              ],
            ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (BuildContext context) => AlertDialog(
                title: const Text('Modelli anatomici'),
                content: const SingleChildScrollView(
                  child: SelectableText(
                    'Z-Anatomy — The libre 3D atlas of anatomy — CC BY-SA 4.0.\n'
                    'Gauthier Kervyn e collaboratori.\n\n'
                    'BodyParts3D — The Database Center for Life Science — CC BY-SA 2.1 Japan. Kousaku Okubo.\n\n'
                    'Riferimenti del progetto: Brainder / University of Washington; '
                    'Cranial Nerves and Foramina — University of Dundee, CAHID — CC BY 4.0.\n\n'
                    'Geometrie selezionate, semplificate e normalizzate per CPRedux; adattamento CC BY-SA 4.0.\n'
                    'https://github.com/Z-Anatomy/Models-of-human-anatomy\n'
                    'https://creativecommons.org/licenses/by-sa/4.0/\n\n'
                    'Visualizzazione di gioco, non uno strumento clinico.',
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Chiudi'),
                  ),
                ],
              ),
            ),
            child: Text(
              'Crediti anatomia',
              style: CprType.caption.copyWith(
                fontSize: 9,
                color: CprPalette.inkFaint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberSpaceBackdrop extends CustomPainter {
  const _CyberSpaceBackdrop({required this.phase, this.strain = 0.0});
  final double phase;
  final double strain;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    // 1. Spazio profondo cyberpunk (gradiente stellare dal vuoto cosmico)
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0.0, -0.2),
          radius: 1.15,
          colors: <Color>[
            Color(0xFF070B18), // Deep cyber midnight
            Color(0xFF03050B), // Deep void
            Color(0xFF010204), // Obsidian
          ],
          stops: <double>[0.0, 0.65, 1.0],
        ).createShader(bounds),
    );

    // 2. Grandi Nebulose cosmiche cyberpunk con sfumature ciano e magenta/viola
    final Rect cyanNebula = Rect.fromCircle(
      center: Offset(size.width * 0.28, size.height * 0.35),
      radius: size.width * 0.45,
    );
    canvas.drawOval(
      cyanNebula,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0x2E00F0FF),
            Color(0x1500B8D4),
            Colors.transparent,
          ],
          stops: <double>[0.0, 0.45, 1.0],
        ).createShader(cyanNebula)
        ..blendMode = BlendMode.screen,
    );

    final Rect magentaNebula = Rect.fromCircle(
      center: Offset(size.width * 0.72, size.height * 0.65),
      radius: size.width * 0.50,
    );
    canvas.drawOval(
      magentaNebula,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0x28FF007F),
            Color(0x188B00FF),
            Colors.transparent,
          ],
          stops: <double>[0.0, 0.50, 1.0],
        ).createShader(magentaNebula)
        ..blendMode = BlendMode.screen,
    );

    final Rect violetCore = Rect.fromCircle(
      center: Offset(size.width * 0.50, size.height * 0.48),
      radius: size.width * 0.35,
    );
    canvas.drawOval(
      violetCore,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0x1A6A00FF),
            Colors.transparent,
          ],
          stops: <double>[0.0, 1.0],
        ).createShader(violetCore)
        ..blendMode = BlendMode.plus,
    );

    // 3. Campo stellare tridimensionale (stelle fisse ma luccicanti con ciclo temporale)
    final math.Random rng = math.Random(1337);
    final Paint starPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 95; i++) {
      final double sx = rng.nextDouble() * size.width;
      final double sy = rng.nextDouble() * size.height;
      final double baseRadius = 0.6 + rng.nextDouble() * 1.5;
      final double starSpeed = 0.5 + rng.nextDouble() * 1.8;
      final double starOffset = rng.nextDouble() * math.pi * 2;
      final double twinkle = 0.35 + 0.65 * ((math.sin(phase * math.pi * 2 * starSpeed + starOffset) + 1.0) / 2.0);

      final Color starColor = switch (i % 4) {
        0 => const Color(0xFF00F0FF), // Cyber cyan
        1 => const Color(0xFFFF2E88), // Cyber magenta
        2 => const Color(0xFFC4B5FD), // Starlight violet
        _ => const Color(0xFFFFFFFF), // Pure stellar white
      };

      starPaint.color = starColor.withValues(alpha: (twinkle * (0.4 + 0.6 * rng.nextDouble())).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(sx, sy), baseRadius, starPaint);

      // Bagliore a 4 punte per le stelle più luminose
      if (baseRadius > 1.6 && twinkle > 0.7) {
        final Paint spikePaint = Paint()
          ..color = starColor.withValues(alpha: (twinkle * 0.45).clamp(0.0, 1.0))
          ..strokeWidth = 0.7;
        final double arm = 4.0 * twinkle;
        canvas.drawLine(Offset(sx - arm, sy), Offset(sx + arm, sy), spikePaint);
        canvas.drawLine(Offset(sx, sy - arm), Offset(sx, sy + arm), spikePaint);
      }
    }

    // 4. Particelle cosmiche di polvere neon fluttuanti (leggero drift)
    for (int i = 0; i < 30; i++) {
      final double px = (rng.nextDouble() * size.width + phase * 25.0 * (i.isEven ? 1 : -1)) % size.width;
      final double py = (rng.nextDouble() * size.height + phase * 15.0) % size.height;
      final Color pColor = (i % 2 == 0) ? const Color(0x3300F0FF) : const Color(0x33FF007F);
      canvas.drawCircle(
        Offset(px, py),
        0.9,
        Paint()
          ..color = pColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }
  }

  @override
  bool shouldRepaint(_CyberSpaceBackdrop old) => old.phase != phase || old.strain != strain;
}

class _CyberwareNodesPainter extends CustomPainter {
  const _CyberwareNodesPainter({
    required this.frame,
    required this.cyberware,
    required this.selectedZone,
    required this.phase,
  });
  final AnatomyFrame frame;
  final List<Cyberware> cyberware;
  final String? selectedZone;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Map<String, List<Cyberware>> grouped = <String, List<Cyberware>>{};
    for (final Cyberware c in cyberware) {
      grouped.putIfAbsent(CyberBodyZone.fromId(c.bodyZone).id, () => <Cyberware>[]).add(c);
    }

    final double pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);

    for (final MapEntry<String, List<Cyberware>> entry in grouped.entries) {
      final String zoneId = entry.key;
      final Offset? anchor = frame.zoneAnchors[zoneId];
      if (anchor == null) continue;
      if (anchor.dx < 10 || anchor.dx > size.width - 10 || anchor.dy < 10 || anchor.dy > size.height - 10) continue;

      final bool isSelected = selectedZone == zoneId;
      final Color nodeColor = isSelected ? const Color(0xFF00FFFF) : const Color(0xFFFF9900);

      // 1. Alone e cerchio pulsante
      canvas.drawCircle(
        anchor,
        4.0 + pulse * 3.0,
        Paint()
          ..color = nodeColor.withValues(alpha: 0.35 * pulse)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );

      // 2. Nodo centrale
      canvas.drawCircle(
        anchor,
        3.0,
        Paint()..color = nodeColor,
      );

      // 3. Reticolo di targeting se selezionato
      if (isSelected) {
        const double r = 16.0;
        final Paint reticlePaint = Paint()
          ..color = const Color(0xFF00FFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4;
        canvas.drawArc(Rect.fromCircle(center: anchor, radius: r), -0.5, 1.0, false, reticlePaint);
        canvas.drawArc(Rect.fromCircle(center: anchor, radius: r), math.pi - 0.5, 1.0, false, reticlePaint);
      }

      // 4. Linea guida tech verso badge cyberware
      final bool onRight = anchor.dx < size.width / 2;
      final double tagX = onRight ? anchor.dx - 36 : anchor.dx + 36;
      final double tagY = anchor.dy;

      final Path linePath = Path()
        ..moveTo(anchor.dx, anchor.dy)
        ..lineTo(tagX, tagY);
      canvas.drawPath(
        linePath,
        Paint()
          ..color = nodeColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );

      // Disegna l'etichetta [xN]
      final TextSpan span = TextSpan(
        text: 'x${entry.value.length}',
        style: TextStyle(
          color: nodeColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      );
      final TextPainter tp = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tagX - (onRight ? tp.width + 4 : -4), tagY - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_CyberwareNodesPainter old) =>
      old.frame != frame ||
      old.selectedZone != selectedZone ||
      old.phase != phase ||
      old.cyberware.length != cyberware.length;
}

class _HeadGlitchPainter extends CustomPainter {
  const _HeadGlitchPainter({
    required this.center,
    required this.radius,
    required this.phase,
  });
  final Offset center;
  final double radius;
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect headBounds = Rect.fromCircle(center: center, radius: radius * 1.35);
    final math.Random rng = math.Random((phase * 1000).floor());

    canvas.save();
    canvas.clipRect(headBounds);

    // 1. Linee orizzontali di distorsione e jitter
    for (int i = 0; i < 16; i++) {
      final double y = headBounds.top + rng.nextDouble() * headBounds.height;
      final double h = 2.0 + rng.nextDouble() * 5.0;
      final double shift = (rng.nextDouble() - 0.5) * 28.0;

      // Slice con aberrazione cromatica (Rosso a destra, Ciano a sinistra)
      canvas.drawRect(
        Rect.fromLTWH(headBounds.left + shift, y, headBounds.width, h),
        Paint()..color = const Color(0x66FF003C),
      );
      canvas.drawRect(
        Rect.fromLTWH(headBounds.left - shift * 0.7, y, headBounds.width, h),
        Paint()..color = const Color(0x5500F0FF),
      );
    }

    // 2. Neve statica / rumore digitale
    final Paint noisePaint = Paint()..strokeWidth = 1.2;
    for (int i = 0; i < 45; i++) {
      final double nx = headBounds.left + rng.nextDouble() * headBounds.width;
      final double ny = headBounds.top + rng.nextDouble() * headBounds.height;
      final double len = 1.5 + rng.nextDouble() * 6.0;
      final Color c = rng.nextBool()
          ? const Color(0xAAFFFFFF)
          : (rng.nextBool() ? const Color(0xAAFF003C) : const Color(0xAA00F0FF));
      noisePaint.color = c;
      canvas.drawLine(Offset(nx, ny), Offset(nx + len, ny), noisePaint);
    }

    canvas.restore();

    // 3. Ticker di allerta cyberpsicosi sopra la testa
    final TextSpan warningSpan = TextSpan(
      text: '⚠ CYBERPSICOSI ⚠',
      style: TextStyle(
        color: rng.nextBool() ? const Color(0xFFFF003C) : const Color(0xFFFFCC00),
        fontSize: 9,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
        shadows: const <Shadow>[
          Shadow(color: Color(0xFFFF003C), blurRadius: 8),
        ],
      ),
    );
    final TextPainter tp = TextPainter(
      text: warningSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, headBounds.top - 18));
  }

  @override
  bool shouldRepaint(_HeadGlitchPainter old) =>
      old.center != center || old.radius != radius || old.phase != phase;
}
