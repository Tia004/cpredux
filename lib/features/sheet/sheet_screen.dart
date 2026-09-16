import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../domain/sheet.dart';
import '../../net/cloud_sync_service.dart';
import '../../widgets/tech_button.dart';
import '../map/map_section.dart';
import 'tab_character.dart';
import 'tab_cyberware.dart';
import 'tab_dice.dart';
import 'tab_effects.dart';
import 'tab_inventory.dart';
import 'tab_session.dart';
import 'tab_sheet_settings.dart';
import 'tab_stats.dart';
import 'tab_text.dart';

/// Le sezioni della scheda.
///
/// La navigazione e' una barra verticale e non una fila di tab orizzontali:
/// con tredici sezioni i tab orizzontali diventano stretti e illeggibili, e
/// costringono a scorrere lateralmente. In verticale ci stanno tutte, con il
/// nome per esteso, e la sezione attiva si legge subito.
enum SheetSection {
  character('Personaggio', Icons.badge_outlined),
  stats('Statistiche e abilita', Icons.insights_outlined),
  inventory('Inventario', Icons.inventory_2_outlined),
  equipment('Equipaggiamento', Icons.shield_outlined),
  cyberware('Cyberware', Icons.memory_outlined),
  effects('Effetti', Icons.warning_amber_outlined),
  session('Sessione', Icons.hub_outlined),
  map('Mappa', Icons.map_outlined),
  notes('Note', Icons.sticky_note_2_outlined),
  background('Background', Icons.auto_stories_outlined),
  description('Descrizione fisica', Icons.face_outlined),
  dice('Dadi', Icons.casino_outlined),
  settings('Impostazioni scheda', Icons.tune_outlined);

  const SheetSection(this.label, this.icon);

  final String label;
  final IconData icon;

  Color get accent {
    switch (this) {
      case SheetSection.character:
      case SheetSection.stats:
      case SheetSection.dice:
        return CprPalette.yellow;
      case SheetSection.inventory:
      case SheetSection.equipment:
        return CprPalette.cyan;
      case SheetSection.cyberware:
      case SheetSection.effects:
        return CprPalette.magenta;
      case SheetSection.session:
        return CprPalette.success;
      case SheetSection.map:
        return CprPalette.info;
      case SheetSection.notes:
      case SheetSection.background:
      case SheetSection.description:
        return CprPalette.inkMuted;
      case SheetSection.settings:
        return CprPalette.inkFaint;
    }
  }
}

class SheetScreen extends StatefulWidget {
  const SheetScreen({super.key});

  @override
  State<SheetScreen> createState() => _SheetScreenState();
}

class _SheetScreenState extends State<SheetScreen> {
  SheetSection _section = SheetSection.character;
  SheetLanding _appliedLanding = SheetLanding.start;

  /// Applica la sezione di atterraggio richiesta **prima del disegno**.
  ///
  /// `didChangeDependencies` e' l'ultimo punto in cui si puo' leggere lo stato
  /// dell'applicazione senza dover chiamare `setState`: assegnare qui la sezione
  /// significa aprirsi direttamente sulla chat del tavolo invece di mostrare
  /// "Personaggio" per un fotogramma e poi saltare altrove.
  ///
  /// La richiesta si azzera dopo il fotogramma e non subito, perche' il valore
  /// viene letto *qui*: azzerarlo durante la lettura lo cancellerebbe prima che
  /// un secondo ascoltatore possa vederlo, e in questo caso l'ascoltatore e' la
  /// schermata stessa quando viene ricostruita.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final AppState state = AppScope.of(context);
    final SheetLanding landing = state.sheetLandingRequest;
    if (landing == _appliedLanding) return;

    _appliedLanding = landing;
    switch (landing) {
      case SheetLanding.start:
        break;
      case SheetLanding.session:
        _section = SheetSection.session;
      case SheetLanding.map:
        _section = SheetSection.map;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) state.clearSheetLanding();
    });
  }

  Widget _sectionWidget() {
    switch (_section) {
      case SheetSection.character:
        return const CharacterTab();
      case SheetSection.stats:
        return const StatsTab();
      case SheetSection.inventory:
        return const InventoryTab();
      case SheetSection.equipment:
        return const EquipmentTab();
      case SheetSection.cyberware:
        return const CyberwareTab();
      case SheetSection.effects:
        return const EffectsTab();
      case SheetSection.session:
        return const SessionTab();
      // Il giocatore non decide la mappa del tavolo: qui puo' guardarla e
      // proporre dei segni. E' la stessa sezione con i permessi di chi gioca,
      // non una seconda schermata da tenere allineata.
      case SheetSection.map:
        return const MapSection(asGameMaster: false);
      case SheetSection.notes:
        return const NotesTab();
      case SheetSection.background:
        return const BackgroundTab();
      case SheetSection.description:
        return const DescriptionTab();
      case SheetSection.dice:
        return const DiceTab();
      case SheetSection.settings:
        return const SheetSettingsTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    if (state.sheet == null) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        const _SheetHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _SectionRail(
                current: _section,
                onSelect: (SheetSection s) => setState(() => _section = s),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: CprMotion.normal,
                  switchInCurve: CprMotion.enter,
                  switchOutCurve: CprMotion.exit,
                  transitionBuilder: (Widget child, Animation<double> animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.012, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<SheetSection>(_section),
                    child: _sectionWidget(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Intestazione della scheda: identita' del documento e stato vitale.
///
/// I punti vita restano visibili in ogni sezione, non solo in "Personaggio":
/// in sessione il master modifica i PV del giocatore mentre questi sta
/// guardando l'inventario, e un'informazione cosi' importante non puo'
/// dipendere da quale schermata hai aperto.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet;
    final totals = state.totals;
    if (sheet == null || totals == null) return const SizedBox.shrink();

    final double hpRatio = totals.maxHitPoints == 0 ? 0 : sheet.identity.currentHp / totals.maxHitPoints;
    final Color hpColor = CprPalette.healthColorFor(hpRatio);
    final bool isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          TechButton(
            label: '',
            icon: Icons.arrow_back,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: 'Torna al menu',
            onPressed: () => state.closeDocument(),
          ),
          const SizedBox(width: 12),
          Container(width: 3, height: 18, color: CprPalette.yellow),
          const SizedBox(width: 9),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: Text(
                    sheet.identity.tag.trim().isNotEmpty ? sheet.identity.tag : sheet.meta.name,
                    overflow: TextOverflow.ellipsis,
                    style: CprType.body.copyWith(color: CprPalette.ink, fontWeight: FontWeight.w600),
                  ),
                ),
                if (sheet.identity.role.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '· ${sheet.identity.role}',
                      overflow: TextOverflow.ellipsis,
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                _SaveIndicator(dirty: state.isDirty, autosave: state.settings.autosave),
                const SizedBox(width: 4),
                _CloudSyncIndicator(sheet: sheet),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _HeaderStat(
            label: 'PV',
            value: '${sheet.identity.currentHp}/${totals.maxHitPoints}',
            color: hpColor,
          ),
          const SizedBox(width: 14),
          _HeaderStat(
            label: 'Umanita',
            value: '${sheet.identity.currentHumanity}/${totals.maxHumanity}',
            color: CprPalette.humanityIntact,
          ),
          if (!isCompact) ...<Widget>[
            const SizedBox(width: 14),
            _HeaderStat(
              label: 'Carico',
              value: '${totals.currentLoad.toStringAsFixed(1)}/${totals.maxLoad.toStringAsFixed(0)}',
              color: totals.loadStatus == LoadStatus.overload
                  ? CprPalette.danger
                  : totals.loadStatus == LoadStatus.heavy
                      ? CprPalette.warning
                      : CprPalette.inkMuted,
            ),
          ],
          const SizedBox(width: 14),
          TechButton(
            label: 'Salva',
            icon: Icons.save_outlined,
            variant: TechButtonVariant.primary,
            compact: true,
            onPressed: () => state.save(),
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 8.5)),
        const SizedBox(height: 1),
        Text(value, style: CprType.numeralSmall.copyWith(color: color, fontSize: 14)),
      ],
    );
  }
}

/// Indicatore dello stato di salvataggio.
///
/// Esiste per una ragione precisa: se l'utente sa che l'app salva da sola,
/// smette di premere Salva e smette anche di preoccuparsi. Ma allora *deve*
/// poter vedere che sta effettivamente salvando, altrimenti la fiducia e' solo
/// una supposizione.
class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.dirty, required this.autosave});

  final bool dirty;
  final bool autosave;

  @override
  Widget build(BuildContext context) {
    final Color color = dirty ? CprPalette.warning : CprPalette.success;
    final String text = dirty
        ? (autosave ? 'Modifiche in corso…' : 'Non salvato')
        : 'Salvato';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedContainer(
          duration: CprMotion.fast,
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(text, style: CprType.label.copyWith(color: color, fontSize: 9.5)),
      ],
    );
  }
}

class _SectionRail extends StatelessWidget {
  const _SectionRail({required this.current, required this.onSelect});

  final SheetSection current;
  final ValueChanged<SheetSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: CprPalette.hairline)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final SheetSection section in SheetSection.values)
              _RailItem(
                section: section,
                selected: section == current,
                onTap: () => onSelect(section),
              ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatefulWidget {
  const _RailItem({required this.section, required this.selected, required this.onTap});

  final SheetSection section;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailItem> createState() => _RailItemState();
}

class _RailItemState extends State<_RailItem> with SingleTickerProviderStateMixin {
  late final AnimationController _hover;

  @override
  void initState() {
    super.initState();
    _hover = AnimationController(vsync: this, duration: CprMotion.hover);
  }

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.selected;
    final Color color = active ? widget.section.accent : CprPalette.inkMuted;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hover.forward(),
      onExit: (_) => _hover.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hover,
          builder: (BuildContext context, _) => Stack(
            children: <Widget>[
              AnimatedContainer(
                duration: CprMotion.fast,
                curve: CprMotion.enter,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                margin: const EdgeInsets.only(bottom: 2),
                color: active
                    ? CprPalette.veil(widget.section.accent, 0.10)
                    : CprPalette.veil(CprPalette.ink, 0.03 * _hover.value),
                child: Row(
                  children: <Widget>[
                    Icon(widget.section.icon, size: 15, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.section.label,
                        overflow: TextOverflow.ellipsis,
                        style: CprType.caption.copyWith(
                          color: color,
                          fontSize: 12.5,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 2,
                child: AnimatedContainer(
                  duration: CprMotion.fast,
                  width: active ? 2.5 : 0,
                  color: widget.section.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CloudSyncIndicator extends StatelessWidget {
  const _CloudSyncIndicator({required this.sheet});

  final CharacterSheet sheet;

  Future<void> _openCloudModal(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final CloudSyncService cloud = CloudSyncService.instance;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return ListenableBuilder(
          listenable: cloud,
          builder: (BuildContext context, _) {
            final bool auth = cloud.isAuthenticated;
            return AlertDialog(
              backgroundColor: CprPalette.surface,
              shape: BeveledRectangleBorder(
                side: BorderSide(color: CprPalette.cyan, width: 1.2),
              ),
              title: Row(
                children: <Widget>[
                  Icon(Icons.cloud_outlined, color: CprPalette.cyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'SINCRONIZZAZIONE CLOUD (GRATUITA)',
                    style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 11),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (auth) ...<Widget>[
                    Text(
                      'Account collegato: ${cloud.currentUser!.email}',
                      style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cloud.syncState == SheetSyncState.synced
                          ? 'Stato: Sincronizzato sul Cloud'
                          : 'Stato: Sincronizzazione in corso...',
                      style: CprType.caption.copyWith(color: CprPalette.success),
                    ),
                    const SizedBox(height: 14),
                    TechButton(
                      label: 'Salva scheda sul Cloud ora',
                      icon: Icons.cloud_upload_outlined,
                      variant: TechButtonVariant.primary,
                      onPressed: () async {
                        await cloud.saveSheetToCloud(sheet);
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                    ),
                    const SizedBox(height: 8),
                    TechButton(
                      label: 'Disconnetti account',
                      icon: Icons.logout,
                      variant: TechButtonVariant.ghost,
                      compact: true,
                      onPressed: () async {
                        await cloud.signOut();
                      },
                    ),
                  ] else ...<Widget>[
                    Text(
                      'Salva le tue schede direttamente sul cloud in modo 100% gratuito con Google (Firebase Spark).\n\n'
                      'Nessun costo, sincronizzazione immediata tra dispositivi.',
                      style: CprType.body.copyWith(color: CprPalette.ink, height: 1.4, fontSize: 12.5),
                    ),
                    const SizedBox(height: 14),
                    TechButton(
                      label: 'Configura Cloud Google',
                      icon: Icons.cloud_sync_outlined,
                      variant: TechButtonVariant.primary,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        state.openCloud();
                      },
                    ),
                  ],
                ],
              ),
              actions: <Widget>[
                TechButton(
                  label: 'Chiudi',
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: CloudSyncService.instance,
      builder: (BuildContext context, _) {
        final CloudSyncService cloud = CloudSyncService.instance;
        final bool auth = cloud.isAuthenticated;

        return TechButton(
          label: auth ? 'Cloud' : '',
          icon: auth ? Icons.cloud_done_outlined : Icons.cloud_queue_outlined,
          variant: TechButtonVariant.ghost,
          compact: true,
          tooltip: auth ? 'Sincronizzato: ${cloud.currentUser!.email}' : 'Accedi con Google (Cloud gratuito)',
          onPressed: () => _openCloudModal(context),
        );
      },
    );
  }
}
