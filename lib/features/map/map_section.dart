import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/gm/gm_rules.dart';
import '../../domain/map_token.dart';
import '../../domain/transport.dart';
import '../../domain/world_map.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';
import 'map_canvas.dart';
import 'night_city_painter.dart';
import 'waypoint_dialog.dart';
import '../campaign/cyberpunk_red_suite.dart';
import '../campaign/enemy_loot_dialog.dart';

/// La mappa di Night City, con i segni del tavolo.
///
/// Cosa e' e cosa non e', detto chiaramente perche' e' una scelta e non una
/// mancanza: e' un **riferimento condiviso**. Non muove i personaggi, non tira
/// dadi, non applica regole di movimento. Serve a sostenere la conversazione —
/// "siamo qui, il bersaglio e' li'" — mentre il tavolo parla. Chi cerca un
/// motore di gioco ha sbagliato sezione.
class MapSection extends StatefulWidget {
  const MapSection({super.key, required this.asGameMaster});

  /// True nella schermata della campagna (il master), false in quella della
  /// scheda (il giocatore). Non e' `state.isHosting`: il master prepara la
  /// mappa anche a tavolo chiuso, ed e' anzi il momento in cui la prepara.
  final bool asGameMaster;

  @override
  State<MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<MapSection> {
  String? _selectedId;
  String _query = '';
  final Set<WaypointKind> _kindFilter = <WaypointKind>{};

  /// Token selezionato sulla mappa. Separato da `_selectedId` perche' una cosa
  /// e' un luogo e una e' una persona: evidenziarli insieme confonderebbe la
  /// card che compare sotto il segno.
  String? _selectedTokenId;

  /// Veicolo selezionato: terzo stato di selezione, e non un riuso di
  /// [_selectedTokenId], perche' la scheda che compare sotto un taxi non dice
  /// "come sta" ma "dove va e chi c'e' a bordo".
  String? _selectedTransportId;

  bool _cornerMode = false;
  int _nextCorner = 0;

  ui.Image? _image;
  String _imagePathLoaded = '';
  String? _imageError;
  bool _loadingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncImage());
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  /// Carica l'immagine importata, se c'e' e se non e' gia' quella in memoria.
  ///
  /// Il caricamento si tiene qui e non nel painter: decodificare un JPEG e' una
  /// operazione asincrona che puo' fallire — file spostato, file corrotto — e
  /// un errore va **mostrato**, non disegnato come una mappa vuota.
  Future<void> _syncImage() async {
    if (!mounted) return;
    final AppState state = AppScope.of(context);
    final String path = state.mapBackground.imagePath;

    if (path == _imagePathLoaded) return;
    _imagePathLoaded = path;

    if (path.isEmpty) {
      // Carica automaticamente la mappa completa di Night City 2077 inclusa nell'app
      setState(() {
        _loadingImage = true;
        _imageError = null;
      });
      try {
        ByteData? data;
        try {
          data = await rootBundle.load('assets/images/Map_Base_Full.png');
        } catch (_) {
          data = await rootBundle.load('assets/images/night_city_full.jpg');
        }
        final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final ui.FrameInfo frame = await codec.getNextFrame();
        if (!mounted) return;
        setState(() {
          _image?.dispose();
          _image = frame.image;
          _loadingImage = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _image?.dispose();
          _image = null;
          _loadingImage = false;
        });
      }
      return;
    }

    setState(() {
      _loadingImage = true;
      _imageError = null;
    });

    try {
      final File file = File(path);
      if (!file.existsSync()) {
        throw const FileSystemException('Il file non esiste piu\'');
      }
      final ui.Codec codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final ui.FrameInfo frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() {
        _image?.dispose();
        _image = frame.image;
        _loadingImage = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _image?.dispose();
        _image = null;
        _imageError = 'Non riesco a leggere l\'immagine: $e';
        _loadingImage = false;
      });
    }
  }

  List<MapWaypoint> _visible(AppState state) {
    final List<MapWaypoint> all = state.mapWaypoints;
    final String query = _query.trim().toLowerCase();

    final List<MapWaypoint> filtered = <MapWaypoint>[
      for (final MapWaypoint w in all)
        if ((query.isEmpty || w.label.toLowerCase().contains(query) || w.note.toLowerCase().contains(query)) &&
            (_kindFilter.isEmpty || _kindFilter.contains(w.kind)))
          w,
    ];

    // Le proposte in cima: sono le uniche che chiedono qualcosa a qualcuno.
    filtered.sort((MapWaypoint a, MapWaypoint b) {
      final int byStatus = (a.status == WaypointStatus.proposed ? 0 : 1).compareTo(
        b.status == WaypointStatus.proposed ? 0 : 1,
      );
      if (byStatus != 0) return byStatus;
      final int byVisibility = (a.visibility == WaypointVisibility.private ? 0 : 1).compareTo(
        b.visibility == WaypointVisibility.private ? 0 : 1,
      );
      if (byVisibility != 0) return byVisibility;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
    return filtered;
  }

  void _showCreateEnemyDialog(AppState state) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => _CreateEnemyDialog(
        onCreate: (MapToken token) {
          state.addTokens(tokens: <MapToken>[token]);
          setState(() {
            _selectedTokenId = token.id;
          });
        },
      ),
    );
  }

  // --- Azioni ---------------------------------------------------------------

  Future<void> _placeWaypoint(AppState state, Offset position) async {
    final WaypointDraft? draft = await showWaypointDialog(
      context,
      title: 'Nuovo waypoint',
      canChooseVisibility: widget.asGameMaster,
      positionLabel: '${position.dx.toStringAsFixed(3)} · ${position.dy.toStringAsFixed(3)}',
    );
    if (draft == null || !mounted) return;

    final MapWaypoint created = state.addWaypoint(
      label: draft.label,
      note: draft.note,
      position: position,
      kind: draft.kind,
      visibility: draft.visibility,
    );
    if (!mounted) return;
    setState(() => _selectedId = created.id);
  }

  Future<void> _editWaypoint(AppState state, MapWaypoint waypoint) async {
    final WaypointDraft? draft = await showWaypointDialog(
      context,
      title: 'Modifica waypoint',
      canChooseVisibility: widget.asGameMaster,
      initial: WaypointDraft(
        label: waypoint.label,
        note: waypoint.note,
        kind: waypoint.kind,
        visibility: waypoint.visibility,
      ),
    );
    if (draft == null || !mounted) return;

    state.updateWaypoint(
      waypoint.id,
      label: draft.label,
      note: draft.note,
      kind: draft.kind,
      visibility: draft.visibility,
    );
  }

  Future<void> _deleteWaypoint(AppState state, MapWaypoint waypoint) async {
    final bool ok = await showTechConfirm(
      context,
      title: 'Rimuovere il waypoint',
      message: waypoint.isShareable && waypoint.status == WaypointStatus.accepted
          ? '"${waypoint.label}" sparira\' anche dalla mappa di chi e\' al tavolo.'
          : '"${waypoint.label}" verra\' rimosso dalla mappa.',
      confirmLabel: 'Rimuovi',
      danger: true,
    );
    if (!ok || !mounted) return;
    state.deleteWaypoint(waypoint.id);
    if (_selectedId == waypoint.id) setState(() => _selectedId = null);
  }

  void _onMapTap(AppState state, Offset position) {
    if (_cornerMode) {
      state.setMapCorner(_nextCorner, position);
      setState(() {
        _nextCorner++;
        if (_nextCorner >= 4) {
          _cornerMode = false;
          _nextCorner = 0;
        }
      });
      return;
    }

    if (state.isPlacingWaypoint) {
      _placeWaypoint(state, position);
      return;
    }

    if (_selectedId != null) setState(() => _selectedId = null);
  }

  Future<void> _importImage(AppState state) async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Scegli una mappa',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp', 'gif'],
      initialDirectory: AppPaths.documentsDir().path,
      description:
          'L\'immagine resta sul tuo computer: il programma non la spedisce a nessuno, '
          'nemmeno a chi gioca al tuo tavolo.',
      showAllFilesToggle: true,
    );
    if (path == null || !mounted) return;
    state.setMapImage(path);
    _imagePathLoaded = '';
    await _syncImage();
    if (!mounted) return;
    // Si entra subito in regolazione angoli: un'immagine appena importata e'
    // quasi sempre da allineare, e lasciarla li' storta significa riguardarla
    // dopo aver notato che i waypoint non corrispondono.
    setState(() {
      _cornerMode = true;
      _nextCorner = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<MapWaypoint> waypoints = _visible(state);
    final MapBackground background = state.mapBackground;

    WidgetsBinding.instance.addPostFrameCallback((_) => _syncImage());

    final Widget map = ChamferPanel(
      title: widget.asGameMaster ? 'Mappa del tavolo' : 'Mappa',
      accent: CprPalette.info,
      trailing: _MapStatus(
        shared: state.sharedWaypoints.length,
        privateCount: state.privateWaypointCount,
        proposals: state.mapProposals.length,
        asGameMaster: widget.asGameMaster,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_imageError != null) ...<Widget>[
            _InlineWarning(
              message: _imageError!,
              onDismiss: () {
                setState(() => _imageError = null);
                state.clearMapImage();
              },
            ),
            const SizedBox(height: 10),
          ],
          if (_cornerMode) ...<Widget>[_CornerHint(next: _nextCorner), const SizedBox(height: 10)],
          MapCanvas(
            style: state.mapStyle,
            waypoints: waypoints,
            tokens: state.mapTokens,
            selectedTokenId: _selectedTokenId,
            transports: state.mapTransports,
            selectedTransportId: _selectedTransportId,
            onTransportTap: (Transport t) {
              if (state.isPlacingWaypoint || _cornerMode) return;
              setState(() {
                _selectedId = null;
                _selectedTokenId = null;
                _selectedTransportId = t.id;
              });
            },
            asGameMaster: widget.asGameMaster,
            placing: state.isPlacingWaypoint || _cornerMode,
            image: _image,
            corners: background.corners,
            imageOpacity: background.opacity,
            selectedId: _selectedId,
            onMapTap: (Offset position) => _onMapTap(state, position),
            onTokenTap: (MapToken t) {
              if (state.isPlacingWaypoint || _cornerMode) return;
              setState(() {
                _selectedId = null;
                _selectedTokenId = t.id;
              });
              showDialog<void>(
                context: context,
                builder: (_) => QuickNpcTokenDialog(token: t),
              );
            },
            onTokenDrag: state.moveToken,
            onWaypointTap: (MapWaypoint w) {
              if (state.isPlacingWaypoint || _cornerMode) return;
              setState(() {
                _selectedId = w.id;
                _selectedTokenId = null;
              });
            },
            onCancelPlacing: () {
              state.cancelPlacingWaypoint();
              setState(() {
                _cornerMode = false;
                _nextCorner = 0;
              });
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(_loadingImage ? Icons.hourglass_top : Icons.info_outline, size: 13, color: CprPalette.inkFaint),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _loadingImage
                      ? 'Carico la mappa importata…'
                      : 'Rotella per ingrandire, trascina per spostarti, clic su un token per '
                            'aprire la sua scheda rapida PNG dal tavolo. Cartografia di Night City '
                            'ad alta risoluzione con overlay tattico.',
                  style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final Widget side = Column(
      children: <Widget>[
        _ControlsPanel(
          state: state,
          asGameMaster: widget.asGameMaster,
          query: _query,
          kindFilter: _kindFilter,
          onQuery: (String v) => setState(() => _query = v),
          onToggleKind: (WaypointKind k) => setState(() {
            if (!_kindFilter.remove(k)) _kindFilter.add(k);
          }),
          onAdd: () {
            state.beginPlacingWaypoint();
            setState(() {
              _cornerMode = false;
              _selectedId = null;
            });
          },
        ),
        const SizedBox(height: 14),
        _WaypointList(
          waypoints: waypoints,
          total: state.mapWaypoints.length,
          asGameMaster: widget.asGameMaster,
          selectedId: _selectedId,
          onSelect: (MapWaypoint w) => setState(() {
            _selectedId = w.id;
            _selectedTokenId = null;
          }),
          onEdit: (MapWaypoint w) => _editWaypoint(state, w),
          onDelete: (MapWaypoint w) => _deleteWaypoint(state, w),
        ),
        const SizedBox(height: 14),
        _TransportList(
          transports: state.mapTransports,
          persisted: state.transportsArePersisted,
          asGameMaster: widget.asGameMaster,
          selectedId: _selectedTransportId,
          mapSpanMeters: state.gmRuleBook.rule(GmRules.transportMapSpan).value,
          timeScale: state.gmRuleBook.rule(GmRules.transportTimeScale).value,
          onSelect: (Transport t) => setState(() {
            _selectedTransportId = t.id;
            _selectedId = null;
            _selectedTokenId = null;
          }),
          onHalt: (Transport t) => state.haltTransport(t.id),
          onResume: (Transport t) => state.resumeTransport(t.id),
          onDelete: (Transport t) => state.removeTransport(t.id),
        ),
        const SizedBox(height: 14),
        _TokenList(
          tokens: state.mapTokens,
          persisted: state.tokensArePersisted,
          selectedId: _selectedTokenId,
          onSelect: (MapToken t) => setState(() {
            _selectedTokenId = t.id;
            _selectedId = null;
            _selectedTransportId = null;
          }),
          onDamage: (MapToken t) => state.damageToken(t.id, 5),
          onHeal: (MapToken t) => state.healToken(t.id, 5),
          onDelete: (MapToken t) => state.removeToken(t.id),
          onClearGroup: state.removeTokenGroup,
          onAddEnemy: widget.asGameMaster ? () => _showCreateEnemyDialog(state) : null,
        ),
        if (widget.asGameMaster) ...<Widget>[
          const SizedBox(height: 14),
          _ProposalsPanel(
            proposals: state.mapProposals,
            onAccept: state.masterAcceptWaypoint,
            onReject: state.masterRejectWaypoint,
          ),
          const SizedBox(height: 14),
          _ImportedMapPanel(
            state: state,
            background: background,
            cornerMode: _cornerMode,
            nextCorner: _nextCorner,
            onImport: () => _importImage(state),
            onToggleCorners: () => setState(() {
              _cornerMode = !_cornerMode;
              _nextCorner = 0;
            }),
          ),
        ],
        const SizedBox(height: 14),
        const _LegendPanel(),
      ],
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget content = constraints.maxWidth < 1080
            ? Column(children: <Widget>[map, const SizedBox(height: 14), side])
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 7, child: map),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: side),
                ],
              );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1500), child: content),
          ),
        );
      },
    );
  }
}

/// Stato della mappa in una riga: quante posizioni vede il tavolo e quante no.
class _MapStatus extends StatelessWidget {
  const _MapStatus({
    required this.shared,
    required this.privateCount,
    required this.proposals,
    required this.asGameMaster,
  });

  final int shared;
  final int privateCount;
  final int proposals;
  final bool asGameMaster;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        if (proposals > 0)
          _Pill(
            text: '$proposals ${proposals == 1 ? 'proposta' : 'proposte'}',
            color: CprPalette.warning,
            icon: Icons.hourglass_top,
          ),
        _Pill(text: '$shared al tavolo', color: CprPalette.cyan, icon: Icons.people_outline),
        if (asGameMaster && privateCount > 0)
          _Pill(
            text: '$privateCount ${privateCount == 1 ? 'privato' : 'privati'}',
            color: CprPalette.inkMuted,
            icon: Icons.lock_outline,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      color: CprPalette.veil(color, 0.12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 6),
          Text(text, style: CprType.label.copyWith(color: color, fontSize: 9)),
        ],
      ),
    );
  }
}

class _ControlsPanel extends StatelessWidget {
  const _ControlsPanel({
    required this.state,
    required this.asGameMaster,
    required this.query,
    required this.kindFilter,
    required this.onQuery,
    required this.onToggleKind,
    required this.onAdd,
  });

  final AppState state;
  final bool asGameMaster;
  final String query;
  final Set<WaypointKind> kindFilter;
  final ValueChanged<String> onQuery;
  final ValueChanged<WaypointKind> onToggleKind;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Segni sulla mappa',
      accent: CprPalette.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  asGameMaster
                      ? 'L\'aspetto della mappa vale per tutto il tavolo.'
                      : 'Chi decide la mappa e\' il master: qui puoi proporgli dei segni.',
                  style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (asGameMaster)
            TechSegmented<MapStyle>(
              value: state.mapStyle,
              items: MapStyle.values,
              labelOf: (MapStyle s) => s.label,
              accent: CprPalette.info,
              onChanged: state.setMapStyle,
            )
          else
            Row(
              children: <Widget>[
                Icon(Icons.visibility_outlined, size: 13, color: CprPalette.inkFaint),
                const SizedBox(width: 8),
                Text(
                  'Aspetto: ${state.mapStyle.label.toUpperCase()}',
                  style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                ),
              ],
            ),
          const SizedBox(height: 14),
          TechButton(
            label: state.isPlacingWaypoint ? 'Clicca sulla mappa…' : 'Aggiungi un waypoint',
            icon: state.isPlacingWaypoint ? Icons.gps_fixed : Icons.add_location_alt_outlined,
            variant: state.isPlacingWaypoint ? TechButtonVariant.primary : TechButtonVariant.secondary,
            expand: true,
            onPressed: state.isPlacingWaypoint ? state.cancelPlacingWaypoint : onAdd,
          ),
          if (state.isPlacingWaypoint) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Clicca un punto sulla mappa. Esc per annullare.',
              style: CprType.caption.copyWith(color: CprPalette.yellow),
            ),
          ],
          const SizedBox(height: 16),
          TechField(label: 'Cerca', value: query, hint: 'nome o nota', accent: CprPalette.info, onChanged: onQuery),
          const SizedBox(height: 14),
          Text('CATEGORIE', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              for (final WaypointKind k in WaypointKind.values)
                _FilterChip(kind: k, selected: kindFilter.contains(k), onTap: () => onToggleKind(k)),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.kind, required this.selected, required this.onTap});

  final WaypointKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = WaypointKindStyle.color(kind);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(color, 0.16) : CprPalette.surfaceSunken,
            border: Border.all(color: selected ? color : CprPalette.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(WaypointKindStyle.icon(kind), size: 12, color: selected ? color : CprPalette.inkFaint),
              const SizedBox(width: 7),
              Text(
                kind.label.toUpperCase(),
                style: CprType.label.copyWith(fontSize: 9, color: selected ? color : CprPalette.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chi c'e' sulla mappa, con i comandi che servono mentre si gioca.
///
/// Sta qui e non nella console del Master perche' appartiene alla mappa: un
/// segnaposto che si puo' disegnare ma non ferire e' una decorazione, e il
/// momento in cui serve ferirlo e' esattamente quello in cui si sta guardando
/// la mappa e non un'altra schermata.
class _TokenList extends StatelessWidget {
  const _TokenList({
    required this.tokens,
    required this.persisted,
    required this.selectedId,
    required this.onSelect,
    required this.onDamage,
    required this.onHeal,
    required this.onDelete,
    required this.onClearGroup,
    this.onAddEnemy,
  });

  final List<MapToken> tokens;

  /// Se i token finiranno nel documento della campagna.
  final bool persisted;
  final String? selectedId;
  final ValueChanged<MapToken> onSelect;
  final ValueChanged<MapToken> onDamage;
  final ValueChanged<MapToken> onHeal;
  final ValueChanged<MapToken> onDelete;
  final ValueChanged<String> onClearGroup;
  final VoidCallback? onAddEnemy;

  @override
  Widget build(BuildContext context) {
    final List<String> groups = <String>[];
    for (final MapToken t in tokens) {
      if (t.groupId.isNotEmpty && !groups.contains(t.groupId)) groups.add(t.groupId);
    }

    return ChamferPanel(
      title: 'Token sulla mappa',
      accent: CprPalette.danger,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onAddEnemy != null) ...<Widget>[
            TechButton(
              label: '+ Nemico',
              icon: Icons.person_add_alt_1_outlined,
              compact: true,
              variant: TechButtonVariant.primary,
              onPressed: onAddEnemy,
            ),
            const SizedBox(width: 8),
          ],
          Text('${tokens.length}', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (tokens.isEmpty)
            Text(
              'Nessuno sulla mappa. Il generatore di incontri della console del Master li manda '
              'qui già pronti.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            )
          else ...<Widget>[
            if (!persisted)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Senza una campagna aperta questi token non vengono salvati: chiudendo l\'app '
                  'si perdono.',
                  style: CprType.caption.copyWith(color: CprPalette.warning, fontSize: 11),
                ),
              ),
            for (final MapToken t in tokens)
              _TokenRow(
                token: t,
                selected: t.id == selectedId,
                onSelect: () => onSelect(t),
                onDamage: () => onDamage(t),
                onHeal: () => onHeal(t),
                onDelete: () => onDelete(t),
              ),
            if (groups.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text('GRUPPI', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
              const SizedBox(height: 6),
              for (final String group in groups)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${tokens.where((MapToken t) => t.groupId == group).length} token',
                        style: CprType.caption,
                      ),
                    ),
                    TechButton(
                      label: 'Togli gruppo',
                      icon: Icons.delete_sweep_outlined,
                      compact: true,
                      tooltip: 'Rimuove dalla mappa tutti i token di questo gruppo',
                      onPressed: () => onClearGroup(group),
                    ),
                  ],
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// I veicoli in strada, con i comandi del Master.
///
/// Perche' una lista e non solo il segno sulla mappa: un taxi che si muove e'
/// visibile, ma **quanto manca all'arrivo** e **chi c'e' a bordo** sono numeri,
/// e i numeri non si leggono da un'icona di otto pixel. La lista e' il posto in
/// cui il Master guarda prima di decidere se scatenare qualcosa.
class _TransportList extends StatelessWidget {
  const _TransportList({
    required this.transports,
    required this.persisted,
    required this.asGameMaster,
    required this.selectedId,
    required this.mapSpanMeters,
    required this.timeScale,
    required this.onSelect,
    required this.onHalt,
    required this.onResume,
    required this.onDelete,
  });

  final List<Transport> transports;
  final bool persisted;
  final bool asGameMaster;
  final String? selectedId;
  final double mapSpanMeters;
  final double timeScale;
  final ValueChanged<Transport> onSelect;
  final ValueChanged<Transport> onHalt;
  final ValueChanged<Transport> onResume;
  final ValueChanged<Transport> onDelete;

  @override
  Widget build(BuildContext context) {
    if (transports.isEmpty) return const SizedBox.shrink();

    return ChamferPanel(
      title: 'In strada',
      accent: CprPalette.info,
      trailing: Text('${transports.length}', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (!persisted)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Senza una campagna aperta i veicoli non vengono salvati: chiudendo l\'app si perdono.',
                style: CprType.caption.copyWith(color: CprPalette.warning, fontSize: 11),
              ),
            ),
          for (final Transport t in transports)
            _TransportRow(
              transport: t,
              selected: t.id == selectedId,
              asGameMaster: asGameMaster,
              eta: t.eta(mapSpanMeters, timeScale: timeScale),
              onSelect: () => onSelect(t),
              onHalt: () => onHalt(t),
              onResume: () => onResume(t),
              onDelete: () => onDelete(t),
            ),
        ],
      ),
    );
  }
}

class _TransportRow extends StatelessWidget {
  const _TransportRow({
    required this.transport,
    required this.selected,
    required this.asGameMaster,
    required this.eta,
    required this.onSelect,
    required this.onHalt,
    required this.onResume,
    required this.onDelete,
  });

  final Transport transport;
  final bool selected;
  final bool asGameMaster;
  final Duration? eta;
  final VoidCallback onSelect;
  final VoidCallback onHalt;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color accent = NightCityPainter.transportColor(transport);
    final String etaText = eta == null
        ? (transport.status == TransportStatus.arrivato ? 'arrivato' : 'fermo')
        : '${eta!.inSeconds < 60 ? '${eta!.inSeconds}s' : '${(eta!.inSeconds / 60).round()} min'} all\'arrivo';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(accent, 0.10) : CprPalette.surfaceSunken,
            border: Border.all(color: selected ? CprPalette.veil(accent, 0.6) : CprPalette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(transportStatusIcon(transport), size: 13, color: accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      transport.name,
                      overflow: TextOverflow.ellipsis,
                      style: CprType.body.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ),
                  Text(etaText, style: CprType.caption.copyWith(color: accent, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${transport.mode.label} · ${transport.statLine}',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
              ),
              const SizedBox(height: 2),
              Text(
                transport.routeLine,
                style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
              ),
              if (asGameMaster) ...<Widget>[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    if (transport.status == TransportStatus.fermo)
                      TechButton(
                        label: 'Rilascia',
                        icon: Icons.play_arrow,
                        compact: true,
                        tooltip: 'Lo fa ripartire subito, senza aspettare la scadenza',
                        onPressed: onResume,
                      )
                    else if (transport.status == TransportStatus.inViaggio)
                      TechButton(
                        label: 'Ferma',
                        icon: Icons.pause,
                        compact: true,
                        tooltip: 'Lo ferma dove si trova',
                        onPressed: onHalt,
                      ),
                    TechButton(
                      label: 'Togli',
                      icon: Icons.close,
                      compact: true,
                      tooltip: 'Toglie il veicolo dalla mappa',
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// L'icona di un veicolo in base a cosa sta facendo.
///
/// Lo stato prima del modo: a un tavolo la domanda e' "si sta muovendo?", e
/// "che mezzo e'" viene dopo. Un taxi fermo e una moto ferma pongono la stessa
/// domanda.
IconData transportStatusIcon(Transport t) => switch (t.status) {
  TransportStatus.arrivato => Icons.flag_outlined,
  TransportStatus.fermo => Icons.report_gmailerrorred_outlined,
  TransportStatus.inViaggio => switch (t.mode) {
    TransportMode.taxi => Icons.local_taxi_outlined,
    TransportMode.groundcar => Icons.directions_car_outlined,
    TransportMode.moto => Icons.two_wheeler_outlined,
    TransportMode.aerodyne => Icons.flight_outlined,
    TransportMode.maglev => Icons.train_outlined,
  },
};

class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.token,
    required this.selected,
    required this.onSelect,
    required this.onDamage,
    required this.onHeal,
    required this.onDelete,
  });

  final MapToken token;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onDamage;
  final VoidCallback onHeal;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color color = NightCityPainter.tokenColor(token.kind);
    final Color health = NightCityPainter.tokenHealthColor(token);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(color, 0.12) : CprPalette.surfaceSunken,
            border: Border(left: BorderSide(color: health, width: 3)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(child: Text(token.name, style: CprType.caption)),
                        const SizedBox(width: 6),
                        if (token.isDown)
                          Text('A TERRA', style: CprType.label.copyWith(fontSize: 9, color: CprPalette.healthFlatline)),
                      ],
                    ),
                    if (token.statLine.isNotEmpty)
                      Text(token.statLine, style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11)),
                  ],
                ),
              ),
              Tooltip(
                message: 'Scheda rapida PNG',
                child: TechButton(
                  label: '',
                  icon: Icons.badge_outlined,
                  compact: true,
                  variant: TechButtonVariant.secondary,
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => QuickNpcTokenDialog(token: token),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: '5 danni',
                child: TechButton(label: '', icon: Icons.remove, compact: true, onPressed: onDamage),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: '5 Punti Vita indietro',
                child: TechButton(label: '', icon: Icons.add, compact: true, onPressed: onHeal),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Togli dalla mappa',
                child: TechButton(label: '', icon: Icons.close, compact: true, onPressed: onDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaypointList extends StatelessWidget {
  const _WaypointList({
    required this.waypoints,
    required this.total,
    required this.asGameMaster,
    required this.selectedId,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MapWaypoint> waypoints;
  final int total;
  final bool asGameMaster;
  final String? selectedId;
  final ValueChanged<MapWaypoint> onSelect;
  final ValueChanged<MapWaypoint> onEdit;
  final ValueChanged<MapWaypoint> onDelete;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: total == 0 ? 'Nessun segno' : 'Elenco ($total)',
      accent: CprPalette.violet,
      child: total == 0
          ? Text(
              'Non c\'e\' ancora niente sulla mappa. Aggiungi un waypoint e clicca il punto: '
              'un nome, una categoria, e se il tavolo deve vederlo.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
            )
          : waypoints.isEmpty
          ? Text('Nessun segno corrisponde al filtro.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
          : Column(
              children: <Widget>[
                for (final MapWaypoint w in waypoints)
                  _WaypointRow(
                    waypoint: w,
                    selected: w.id == selectedId,
                    // Un giocatore puo' toccare solo le proprie proposte:
                    // un waypoint gia' condiviso e' sulla mappa di tutti, e
                    // modificarlo da li' cambierebbe quello che il master
                    // sta descrivendo.
                    canEdit: asGameMaster || w.status == WaypointStatus.proposed,
                    onSelect: () => onSelect(w),
                    onEdit: () => onEdit(w),
                    onDelete: () => onDelete(w),
                  ),
              ],
            ),
    );
  }
}

class _WaypointRow extends StatelessWidget {
  const _WaypointRow({
    required this.waypoint,
    required this.selected,
    required this.canEdit,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final MapWaypoint waypoint;
  final bool selected;
  final bool canEdit;
  final VoidCallback onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Color color = WaypointKindStyle.color(waypoint.kind);
    final bool pending = waypoint.status == WaypointStatus.proposed;
    final bool hidden = waypoint.visibility == WaypointVisibility.private;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSelect,
        child: AnimatedContainer(
          duration: CprMotion.fast,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(color, 0.12) : CprPalette.surfaceSunken,
            border: Border(
              left: BorderSide(color: selected ? color : CprPalette.hairline, width: selected ? 2.5 : 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(WaypointKindStyle.icon(waypoint.kind), size: 14, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            waypoint.label,
                            overflow: TextOverflow.ellipsis,
                            style: CprType.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: CprPalette.ink,
                            ),
                          ),
                        ),
                        if (hidden) ...<Widget>[
                          const SizedBox(width: 7),
                          _Badge(text: 'PRIVATO', color: CprPalette.inkMuted, icon: Icons.lock_outline),
                        ],
                        if (pending) ...<Widget>[
                          const SizedBox(width: 7),
                          const _Badge(text: 'IN ATTESA', color: CprPalette.warning, icon: Icons.hourglass_top),
                        ],
                      ],
                    ),
                    if (waypoint.note.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        waypoint.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      <String>[
                        waypoint.kind.label,
                        if (waypoint.authorName.trim().isNotEmpty) waypoint.authorName,
                        '${waypoint.x.toStringAsFixed(2)} · ${waypoint.y.toStringAsFixed(2)}',
                      ].join('  ·  '),
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (canEdit)
                TechButton(
                  label: '',
                  icon: Icons.edit_outlined,
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  tooltip: 'Modifica',
                  onPressed: onEdit,
                )
              else
                const SizedBox(width: 30),
              const SizedBox(width: 4),
              TechButton(
                label: '',
                icon: Icons.delete_outline,
                variant: TechButtonVariant.ghost,
                compact: true,
                tooltip: canEdit ? 'Rimuovi' : 'Solo il master puo\' rimuoverlo',
                onPressed: canEdit ? onDelete : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color, required this.icon});

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      color: CprPalette.veil(color, 0.14),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 9, color: color),
          const SizedBox(width: 4),
          Text(text, style: CprType.label.copyWith(color: color, fontSize: 8)),
        ],
      ),
    );
  }
}

/// Le proposte dei giocatori in attesa di una decisione.
class _ProposalsPanel extends StatelessWidget {
  const _ProposalsPanel({required this.proposals, required this.onAccept, required this.onReject});

  final List<MapWaypoint> proposals;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Proposte dei giocatori',
      accent: CprPalette.warning,
      glow: proposals.isNotEmpty,
      child: proposals.isEmpty
          ? Text(
              'Nessuna proposta in attesa. Quando un giocatore mette un segno, arriva qui e '
              'resta suo finche\' non lo condividi: cosi\' nessuno scrive sulla mappa che '
              'stai descrivendo.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final MapWaypoint w in proposals)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                      color: CprPalette.surfaceSunken,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(WaypointKindStyle.icon(w.kind), size: 13, color: WaypointKindStyle.color(w.kind)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  w.label,
                                  style: CprType.body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
                                ),
                              ),
                              Text(w.authorName, style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
                            ],
                          ),
                          if (w.note.trim().isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(w.note, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
                          ],
                          const SizedBox(height: 9),
                          Row(
                            children: <Widget>[
                              TechButton(
                                label: 'Condividi',
                                icon: Icons.check,
                                variant: TechButtonVariant.primary,
                                compact: true,
                                onPressed: () => onAccept(w.id),
                              ),
                              const SizedBox(width: 8),
                              TechButton(
                                label: 'Rifiuta',
                                icon: Icons.close,
                                variant: TechButtonVariant.danger,
                                compact: true,
                                onPressed: () => onReject(w.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// La mappa importata dal master: immagine, trasparenza, angoli.
class _ImportedMapPanel extends StatelessWidget {
  const _ImportedMapPanel({
    required this.state,
    required this.background,
    required this.cornerMode,
    required this.nextCorner,
    required this.onImport,
    required this.onToggleCorners,
  });

  final AppState state;
  final MapBackground background;
  final bool cornerMode;
  final int nextCorner;
  final VoidCallback onImport;
  final VoidCallback onToggleCorners;

  static const List<String> _cornerNames = <String>[
    'alto a sinistra',
    'alto a destra',
    'basso a destra',
    'basso a sinistra',
  ];

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Mappa importata',
      accent: CprPalette.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!background.hasImage) ...<Widget>[
            Text(
              'Vuoi usare una mappa tua — comprata, scansionata o disegnata? Importala e '
              'allineala con quattro angoli: i waypoint useranno lo stesso sistema di '
              'riferimento, quindi restano al loro posto anche ingrandendo.',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            TechButton(
              label: 'Importa un\'immagine',
              icon: Icons.add_photo_alternate_outlined,
              variant: TechButtonVariant.secondary,
              expand: true,
              onPressed: onImport,
            ),
          ] else ...<Widget>[
            Text(
              p.basename(background.imagePath),
              style: CprType.caption.copyWith(color: CprPalette.ink, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Il file resta sul tuo computer: non viene spedito al tavolo. Chi gioca vede la '
              'geometria disegnata dal programma.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.4),
            ),
            const SizedBox(height: 12),
            Text('TRASPARENZA', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: CprPalette.info,
                inactiveTrackColor: CprPalette.hairline,
                thumbColor: CprPalette.info,
                overlayColor: CprPalette.veil(CprPalette.info, 0.14),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              ),
              child: Slider(value: background.opacity, onChanged: state.setMapImageOpacity),
            ),
            const SizedBox(height: 4),
            Text(
              'Serve a far parlare la geometria sotto l\'immagine, o a spegnere i colori '
              'troppo accesi di una foto.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            ),
            const SizedBox(height: 12),
            if (cornerMode)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                color: CprPalette.veil(CprPalette.info, 0.12),
                child: Text(
                  'Clicca l\'angolo ${_cornerNames[nextCorner.clamp(0, 3)]} dell\'immagine '
                  '(${nextCorner.clamp(0, 3) + 1} di 4).',
                  style: CprType.caption.copyWith(color: CprPalette.info),
                ),
              )
            else
              Text(
                'Gli angoli sono nell\'ordine in cui li clicchi: alto sinistra, alto destra, '
                'basso destra, basso sinistra.',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.4),
              ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TechButton(
                    label: cornerMode ? 'Annulla angoli' : 'Sistema gli angoli',
                    icon: Icons.crop_free,
                    variant: cornerMode ? TechButtonVariant.primary : TechButtonVariant.secondary,
                    onPressed: onToggleCorners,
                  ),
                ),
                const SizedBox(width: 8),
                TechButton(
                  label: '',
                  icon: Icons.restart_alt,
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  tooltip: 'Angoli pieni',
                  onPressed: state.resetMapCorners,
                ),
              ],
            ),
            const SizedBox(height: 10),
            TechButton(
              label: 'Rimuovi la mappa importata',
              icon: Icons.delete_outline,
              variant: TechButtonVariant.danger,
              compact: true,
              onPressed: state.clearMapImage,
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendPanel extends StatelessWidget {
  const _LegendPanel();

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Legenda',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: <Widget>[
              for (final WaypointKind k in WaypointKind.values)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(WaypointKindStyle.icon(k), size: 12, color: WaypointKindStyle.color(k)),
                    const SizedBox(width: 6),
                    Text(k.label, style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(Icons.lock_outline, size: 12, color: CprPalette.inkMuted),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Privato: non lascia questa macchina. Nemmeno a tavolo aperto.',
                  style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CornerHint extends StatelessWidget {
  const _CornerHint({required this.next});

  final int next;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: CprPalette.veil(CprPalette.info, 0.12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.crop_free, size: 14, color: CprPalette.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Clicca i quattro angoli dell\'immagine (${next.clamp(0, 3) + 1} di 4), '
              'nell\'ordine che leggi nel pannello a lato.',
              style: CprType.caption.copyWith(color: CprPalette.info),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineWarning extends StatelessWidget {
  const _InlineWarning({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: CprPalette.veil(CprPalette.warning, 0.12),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, size: 14, color: CprPalette.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: CprType.caption.copyWith(color: CprPalette.ink)),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 14, color: CprPalette.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateEnemyDialog extends StatefulWidget {
  const _CreateEnemyDialog({required this.onCreate});

  final ValueChanged<MapToken> onCreate;

  @override
  State<_CreateEnemyDialog> createState() => _CreateEnemyDialogState();
}

class _CreateEnemyDialogState extends State<_CreateEnemyDialog> {
  final TextEditingController _nameCtrl = TextEditingController(text: 'Scagnozzo Boostergang');
  final TextEditingController _roleCtrl = TextEditingController(text: 'Scagnozzo');
  final TextEditingController _hpCtrl = TextEditingController(text: '30');
  final TextEditingController _spCtrl = TextEditingController(text: '7');
  final TextEditingController _weaponCtrl = TextEditingController(text: 'Pistola Pesante');
  final TextEditingController _damageCtrl = TextEditingController(text: '3d6');
  final TextEditingController _lootCtrl = TextEditingController(text: 'Munizioni x20, Chip dati');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _hpCtrl.dispose();
    _spCtrl.dispose();
    _weaponCtrl.dispose();
    _damageCtrl.dispose();
    _lootCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final String name = _nameCtrl.text.trim().isEmpty ? 'Nemico' : _nameCtrl.text.trim();
    final int hp = int.tryParse(_hpCtrl.text.trim()) ?? 30;
    final int sp = int.tryParse(_spCtrl.text.trim()) ?? 7;

    final MapToken token = MapToken(
      id: 'enemy_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      role: _roleCtrl.text.trim(),
      kind: TokenKind.nemico,
      hp: hp,
      maxHp: hp,
      sp: sp,
      combat: 12,
      defense: 12,
      weaponName: _weaponCtrl.text.trim(),
      damage: _damageCtrl.text.trim(),
      loot: _lootCtrl.text.trim(),
      x: 0.5,
      y: 0.5,
    );
    widget.onCreate(token);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.danger, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.danger.withValues(alpha: 0.25), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.person_add_alt_1_outlined, color: CprPalette.danger, size: 20),
                const SizedBox(width: 8),
                Text('CREA NUOVO NEMICO SULLA MAPPA', style: CprType.title.copyWith(color: CprPalette.danger, fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TechField(label: 'Nome Nemico', controller: _nameCtrl),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TechField(label: 'Ruolo / Archetipo', controller: _roleCtrl),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(child: TechField(label: 'Punti Vita (PV)', controller: _hpCtrl)),
                const SizedBox(width: 8),
                Expanded(child: TechField(label: 'Armatura (SP)', controller: _spCtrl)),
                const SizedBox(width: 8),
                Expanded(child: TechField(label: 'Arma', controller: _weaponCtrl)),
                const SizedBox(width: 8),
                Expanded(child: TechField(label: 'Danno', controller: _damageCtrl)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Expanded(
                  child: TechField(label: 'Bottino / Loot', controller: _lootCtrl),
                ),
                const SizedBox(width: 8),
                TechButton(
                  label: 'Generatore Loot',
                  icon: Icons.auto_awesome,
                  variant: TechButtonVariant.primary,
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => EnemyLootDialog(
                        initialEnemyName: _nameCtrl.text.trim().isNotEmpty
                            ? _nameCtrl.text.trim()
                            : _roleCtrl.text.trim(),
                        initialLoot: _lootCtrl.text.trim(),
                        onApply: (String compiled) {
                          setState(() => _lootCtrl.text = compiled);
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TechButton(
                  label: 'Annulla',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 10),
                TechButton(
                  label: 'Posiziona sulla Mappa',
                  icon: Icons.add_location_alt_outlined,
                  variant: TechButtonVariant.danger,
                  onPressed: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
