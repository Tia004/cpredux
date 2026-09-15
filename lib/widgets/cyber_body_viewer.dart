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
  surface('Corpo', Icons.person_outline, 'surface'),
  all('Tutti i sistemi', Icons.layers_outlined, 'all'),
  skeleton('Scheletro', Icons.accessibility_new, 'skeleton'),
  muscles('Muscoli', Icons.fitness_center, 'muscles'),
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
  });
  final List<Cyberware> cyberware;
  final String? selectedZone;
  final ValueChanged<String?>? onZoneSelected;
  final ValueChanged<String>? onInstallInZone;
  final double height;
  final AnatomyModel? model;

  @override
  State<CyberBodyViewer> createState() => _CyberBodyViewerState();
}

class _CyberBodyViewerState extends State<CyberBodyViewer> {
  AnatomyModel? _model;
  bool _failed = false;
  BodyScanLayer _layer = BodyScanLayer.surface;
  AnatomyCamera _camera = const AnatomyCamera();
  double _gestureZoom = 1;
  final FocusNode _focus = FocusNode(debugLabel: 'Anatomy 3D camera');
  AnatomyFrame? _frame;
  Size? _frameSize;

  @override
  void initState() {
    super.initState();
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
                const Icon(
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
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        const CustomPaint(painter: _ScannerBackdrop()),
                        if (_frame != null)
                          RepaintBoundary(
                            child: CustomPaint(
                              painter: AnatomyPainter(_frame!),
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
                                  'ANATOMIA / 3D',
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

class _ScannerBackdrop extends CustomPainter {
  const _ScannerBackdrop();
  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[Color(0xFF19343A), Color(0xFF091316)],
          radius: .75,
        ).createShader(bounds),
    );
    final Paint fine = Paint()
      ..color = const Color(0x1438989F)
      ..strokeWidth = .6;
    for (double x = 24; x < size.width; x += 32) {
      for (double y = 24; y < size.height; y += 32) {
        canvas.drawCircle(Offset(x, y), .6, fine);
      }
    }
    final double floor = size.height * .95;
    for (final double fraction in <double>[.23, .32, .41]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width / 2, floor),
          width: size.width * fraction,
          height: size.width * fraction * .16,
        ),
        fine,
      );
    }
    final Paint ticks = Paint()
      ..color = const Color(0x304D898D)
      ..strokeWidth = 1;
    for (double y = 50; y < size.height - 40; y += 20) {
      canvas.drawLine(
        Offset(size.width - 10, y),
        Offset(size.width - (y % 50 == 0 ? 20 : 15), y),
        ticks,
      );
    }
  }

  @override
  bool shouldRepaint(_ScannerBackdrop oldDelegate) => false;
}
