import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/map_token.dart';
import '../../domain/transport.dart';
import '../../domain/world_map.dart';
import '../../widgets/tech_button.dart';
import 'map_geometry.dart';
import 'night_city_painter.dart';

/// La mappa interattiva: si trascina, si ingrandisce, si clicca.
///
/// Il gesto e il disegno usano le stesse funzioni di conversione
/// ([mapToLocal] / [localToMap]) e lo stesso rettangolo, calcolato dalla stessa
/// dimensione. E' la ragione per cui il clic prende sempre il punto che si sta
/// guardando anche dopo tre ingrandimenti e mezzo.
class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.style,
    required this.waypoints,
    required this.asGameMaster,
    required this.placing,
    required this.onWaypointTap,
    required this.onMapTap,
    this.onCancelPlacing,
    this.image,
    this.corners,
    this.imageOpacity = 1,
    this.selectedId,
    this.draft,
    this.maxHeight = 640,
    this.tokens = const <MapToken>[],
    this.selectedTokenId,
    this.onTokenTap,
    this.onTokenDrag,
    this.transports = const <Transport>[],
    this.selectedTransportId,
    this.onTransportTap,
  });

  final MapStyle style;
  final List<MapWaypoint> waypoints;

  /// Chi c'e' sulla mappa. Opzionale: la mappa si disegna anche senza token.
  final List<MapToken> tokens;
  final String? selectedTokenId;
  final ValueChanged<MapToken>? onTokenTap;

  /// Nuova posizione (coordinate mappa 0..1) mentre si trascina un token.
  final void Function(String tokenId, Offset position)? onTokenDrag;

  /// I veicoli in strada. Si **vedono** muovere: la posizione arriva dallo
  /// stato a ogni battito dell'orologio, e il disegno segue.
  final List<Transport> transports;
  final String? selectedTransportId;

  /// Un veicolo e' stato cliccato. Non si trascina: un veicolo in movimento che
  /// si puo' spostare a mano significa che due cose diverse decidono dove si
  /// trova, e quella sbagliata e' sempre quella che si vede.
  final ValueChanged<Transport>? onTransportTap;

  final bool asGameMaster;

  /// True quando il prossimo clic sulla mappa crea un waypoint.
  final bool placing;

  final ValueChanged<MapWaypoint> onWaypointTap;

  /// Posizione in coordinate mappa (0..1) del clic sul vuoto.
  final ValueChanged<Offset> onMapTap;

  /// Chiamato quando si esce dal posizionamento senza mettere nulla (Esc).
  final VoidCallback? onCancelPlacing;

  final ui.Image? image;
  final List<Offset>? corners;
  final double imageOpacity;
  final String? selectedId;
  final Offset? draft;
  final double maxHeight;

  @override
  State<MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<MapCanvas> with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();

  /// La mappa prende il fuoco quando la si clicca.
  ///
  /// Non e' un dettaglio: le scorciatoie da tastiera esistono solo per chi ha
  /// il fuoco, e un autofocus sulla mappa ruberebbe il cursore al campo di
  /// ricerca che sta nella stessa schermata. Si prende il fuoco quando serve,
  /// cioe' quando si sta lavorando sulla mappa.
  final FocusNode _focus = FocusNode();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  String? _hoveredId;
  double _scale = 1;

  /// Token che si sta trascinando adesso, se ce n'e' uno.
  ///
  /// Finche' non e' nullo, lo spostamento della mappa e' spento: altrimenti
  /// spostare il capo dei Tyger Claws farebbe scivolare via anche il quartiere
  /// sotto di lui, che e' la cosa che rende impossibile prenderci la mano.
  String? _draggingTokenId;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _pulse.repeat();
  }

  void _onTransform() {
    final double next = _transform.value.getMaxScaleOnAxis();
    if ((next - _scale).abs() > 0.01 && mounted) {
      setState(() => _scale = next);
    }
  }

  @override
  void didUpdateWidget(covariant MapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Entrando in posizionamento il fuoco va preso subito, altrimenti Esc non
    // arriva a nessuno e l'unica uscita resta cliccare fuori dalla mappa.
    if (widget.placing && !oldWidget.placing) _focus.requestFocus();
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransform);
    _transform.dispose();
    _focus.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final double current = _transform.value.getMaxScaleOnAxis();
    final double target = (current * factor).clamp(1.0, 9.0);
    final double real = target / current;

    final Size size = context.size ?? const Size(600, 600);
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Matrix4 zoom = Matrix4.identity()
      ..translateByDouble(center.dx, center.dy, 0, 1)
      ..scaleByDouble(real, real, 1, 1)
      ..translateByDouble(-center.dx, -center.dy, 0, 1);

    _transform.value = zoom.multiplied(_transform.value);
  }

  void _reset() => _transform.value = Matrix4.identity();

  /// Quale waypoint sta sotto il puntatore.
  ///
  /// La soglia e' in pixel **schermo** e viene divisa per l'ingrandimento:
  /// senza quella divisione, da ingranditi bisognerebbe centrare il segno al
  /// pixel per prenderlo, e da piccoli si prenderebbe quello accanto.
  MapWaypoint? _hitTest(Offset local, Size size) {
    final Rect rect = mapRectIn(size);
    final double threshold = 13 / _scale;

    MapWaypoint? best;
    double bestDistance = double.infinity;
    for (final MapWaypoint w in widget.waypoints) {
      final double d = (mapToLocal(w.position, rect) - local).distance;
      if (d <= threshold && d < bestDistance) {
        best = w;
        bestDistance = d;
      }
    }
    return best;
  }

  /// Quale token sta sotto il puntatore.
  ///
  /// Soglia piu' larga di quella dei waypoint: un token e' un bersaglio piu'
  /// piccolo e si sposta, quindi perdonare qualche pixel in piu' evita il clic
  /// a vuoto proprio mentre si gioca.
  void _onPointerDown(Offset local, Size size) {
    if (widget.placing || widget.onTokenDrag == null) return;
    final MapToken? token = _hitTestToken(local, size);
    if (token == null) return;
    setState(() => _draggingTokenId = token.id);
  }

  void _onPointerMove(Offset local, Size size) {
    final String? id = _draggingTokenId;
    if (id == null || widget.onTokenDrag == null) return;
    final Offset map = localToMap(local, mapRectIn(size));
    // Limitato alla mappa: un token trascinato fuori bordo non si ritrova piu',
    // e "dov'e' finito il capo dei Tyger Claws" non e' una domanda che il
    // Master debba farsi.
    widget.onTokenDrag!(id, Offset(map.dx.clamp(0, 1).toDouble(), map.dy.clamp(0, 1).toDouble()));
  }

  void _endDrag() {
    if (_draggingTokenId == null) return;
    setState(() => _draggingTokenId = null);
  }

  /// Quale veicolo sta sotto il puntatore.
  ///
  /// Soglia piu' larga di tutte le altre: un veicolo e' piccolo, si muove, e
  /// chi lo clicca lo sta facendo **mentre** si muove. Sbagliare bersaglio qui
  /// significa toccare il token che gli viaggia dentro.
  Transport? _hitTestTransport(Offset local, Size size) {
    if (widget.transports.isEmpty) return null;
    final Rect rect = mapRectIn(size);
    final double threshold = 20 / _scale;

    Transport? best;
    double bestDistance = double.infinity;
    for (final Transport t in widget.transports) {
      final double d = (mapToLocal(t.position, rect) - local).distance;
      if (d <= threshold && d < bestDistance) {
        best = t;
        bestDistance = d;
      }
    }
    return best;
  }

  MapToken? _hitTestToken(Offset local, Size size) {
    if (widget.tokens.isEmpty) return null;
    final Rect rect = mapRectIn(size);
    final double threshold = 17 / _scale;

    MapToken? best;
    double bestDistance = double.infinity;
    for (final MapToken t in widget.tokens) {
      final double d = (mapToLocal(t.position, rect) - local).distance;
      if (d <= threshold && d < bestDistance) {
        best = t;
        bestDistance = d;
      }
    }
    return best;
  }

  void _onTapUp(TapUpDetails details, Size size) {
    _focus.requestFocus();
    final Offset local = details.localPosition;
    final Rect rect = mapRectIn(size);

    // In modalita' posizionamento il clic posiziona, sempre: intercettare un
    // waypoint esistente mentre si sta piazzando il prossimo e' il modo piu'
    // rapido per mettere il segno due millimetri fuori posto.
    if (widget.placing) {
      final Offset map = localToMap(local, rect);
      if (isInsideMap(map)) widget.onMapTap(map);
      return;
    }

    // Prima i veicoli, poi i token, poi i waypoint: l'ordine e' quello del
    // disegno, dal piu' alto al piu' basso. Un clic deve prendere quello che si
    // vede, e il contrario farebbe selezionare il segnaposto nascosto dietro a
    // chi ci sta sopra.
    final Transport? vehicle = _hitTestTransport(local, size);
    if (vehicle != null && widget.onTransportTap != null) {
      widget.onTransportTap!(vehicle);
      return;
    }

    final MapToken? token = _hitTestToken(local, size);
    if (token != null && widget.onTokenTap != null) {
      widget.onTokenTap!(token);
      return;
    }

    final MapWaypoint? hit = _hitTest(local, size);
    if (hit != null) {
      widget.onWaypointTap(hit);
      return;
    }

    final Offset map = localToMap(local, rect);
    if (isInsideMap(map)) widget.onMapTap(map);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size size = Size(
          constraints.maxWidth,
          constraints.maxHeight.isFinite ? constraints.maxHeight.clamp(200, widget.maxHeight) : widget.maxHeight,
        );

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            // Esc esce dal posizionamento, + e - ingrandiscono. Sono le tre
            // cose che si fanno di continuo su una mappa.
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (widget.placing) widget.onCancelPlacing?.call();
            },
            const SingleActivator(LogicalKeyboardKey.equal): () => _zoom(1.25),
            const SingleActivator(LogicalKeyboardKey.minus): () => _zoom(0.8),
            const SingleActivator(LogicalKeyboardKey.digit0): _reset,
          },
          child: Focus(
            focusNode: _focus,
            child: MouseRegion(
              cursor: widget.placing
                  ? SystemMouseCursors.precise
                  : (_hoveredId != null ? SystemMouseCursors.click : SystemMouseCursors.grab),
              onHover: (PointerHoverEvent event) {
                final MapWaypoint? hit = _hitTest(event.localPosition, size);
                final String? id = hit?.id;
                if (id != _hoveredId) setState(() => _hoveredId = id);
              },
              onExit: (_) {
                if (_hoveredId != null) setState(() => _hoveredId = null);
              },
              child: ClipRect(
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: Stack(
                    children: <Widget>[
                      InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 9,
                        scaleEnabled:
                            false, // Disabilita lo zoom da scroll del mouse: zoom solo tramite i pulsanti + e -
                        panEnabled: _draggingTokenId == null,
                        // Il trascinamento usa `Listener` e non un riconoscitore
                        // di gesti: `Listener` riceve il puntatore *prima* che
                        // l'arena dei gesti decida, quindi si fa in tempo a
                        // spegnere lo spostamento della mappa prima che
                        // cominci. Con un `onPanUpdate` normale, trascinare un
                        // token farebbe scorrere anche la mappa sotto di lui.
                        child: Listener(
                          onPointerDown: (PointerDownEvent e) => _onPointerDown(e.localPosition, size),
                          onPointerMove: (PointerMoveEvent e) => _onPointerMove(e.localPosition, size),
                          onPointerUp: (_) => _endDrag(),
                          onPointerCancel: (_) => _endDrag(),
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (TapUpDetails d) => _onTapUp(d, size),
                            child: AnimatedBuilder(
                              animation: _pulse,
                              builder: (BuildContext context, _) => CustomPaint(
                                painter: NightCityPainter(
                                  style: widget.style,
                                  image: widget.image,
                                  corners: widget.corners ?? MapBackground.defaultCorners,
                                  imageOpacity: widget.imageOpacity,
                                  waypoints: widget.waypoints,
                                  tokens: widget.tokens,
                                  selectedTokenId: widget.selectedTokenId,
                                  transports: widget.transports,
                                  selectedTransportId: widget.selectedTransportId,
                                  hoveredId: _hoveredId,
                                  selectedId: widget.selectedId,
                                  draft: widget.draft,
                                  scale: _scale,
                                  showLabels: true,
                                  asGameMaster: widget.asGameMaster,
                                  pulse: _pulse,
                                  repaint: _pulse,
                                ),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _ZoomControls(
                          scale: _scale,
                          onZoomIn: () => _zoom(1.35),
                          onZoomOut: () => _zoom(0.74),
                          onReset: _reset,
                        ),
                      ),
                      if (widget.placing)
                        Positioned(
                          left: 10,
                          top: 10,
                          child: _PlacingHint(cancelled: () => widget.onCancelPlacing?.call()),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Comandi di ingrandimento.
///
/// Esistono oltre alla rotella perche' non tutti hanno una rotella: su un
/// touchpad a due dita il gesto funziona, ma con il mouse serve un modo
/// esplicito, e a un tavolo il master sta spesso con una mano sola.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.scale, required this.onZoomIn, required this.onZoomOut, required this.onReset});

  final double scale;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final bool atBase = (scale - 1).abs() < 0.02;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.voidBlack, 0.78),
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TechButton(
            label: '',
            icon: Icons.remove,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: 'Riduci (−)',
            onPressed: atBase ? null : onZoomOut,
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 46,
            child: Text(
              '${scale.toStringAsFixed(1)}×',
              textAlign: TextAlign.center,
              style: CprType.numeralSmall.copyWith(color: atBase ? CprPalette.inkFaint : CprPalette.cyan),
            ),
          ),
          const SizedBox(width: 6),
          TechButton(
            label: '',
            icon: Icons.add,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: 'Ingrandisci (+)',
            onPressed: onZoomIn,
          ),
          const SizedBox(width: 6),
          TechButton(
            label: '',
            icon: Icons.crop_free,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: 'Inquadra tutta la citta (0)',
            onPressed: atBase ? null : onReset,
          ),
        ],
      ),
    );
  }
}

/// Avviso di posizionamento, con il modo per uscirne.
///
/// Senza, dopo aver premuto "Aggiungi waypoint" l'unico modo per non metterlo
/// sarebbe ricaricare la schermata: una modalita' senza uscita visibile e' un
/// difetto, non una scorciatoia.
class _PlacingHint extends StatelessWidget {
  const _PlacingHint({required this.cancelled});

  final VoidCallback cancelled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.yellow, 0.16),
        border: Border.all(color: CprPalette.veil(CprPalette.yellow, 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.gps_fixed, size: 13, color: CprPalette.yellow),
          const SizedBox(width: 8),
          Text(
            'CLICCA SULLA MAPPA PER POSIZIONARE',
            style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 9),
          ),
          const SizedBox(width: 10),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: cancelled,
              child: Text('ESC', style: CprType.label.copyWith(color: CprPalette.inkMuted, fontSize: 9)),
            ),
          ),
        ],
      ),
    );
  }
}
