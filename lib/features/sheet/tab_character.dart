import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/catalog_item.dart';
import '../../domain/enums.dart';
import '../../domain/rules.dart';
import '../../domain/sheet.dart';
import '../../domain/stats.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/cyber_gauges.dart';
import '../../widgets/cyber_help_tooltip.dart';
import '../../widgets/health_heart.dart';
import '../../widgets/humanity_gauge.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';

class CharacterTab extends StatelessWidget {
  const CharacterTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet;
    final totals = state.totals;
    if (sheet == null || totals == null) return const SizedBox.shrink();

    final bool isUncompiled =
        sheet.identity.tag.trim().isEmpty || sheet.identity.role.trim().isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CampaignProfileBar(sheet: sheet, state: state),
          if (isUncompiled) ...<Widget>[
            const _EmptySheetGuideBanner(),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final bool twoColumns = c.maxWidth >= 960;
              if (!twoColumns) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const _VitalsPanel(),
                    const SizedBox(height: 16),
                    _DeathSavePanel(bodyStat: totals.statValue(Stat.body)),
                    const SizedBox(height: 16),
                    const _IdentityPanel(),
                    const SizedBox(height: 16),
                    const _QuickArmorPanel(),
                    const SizedBox(height: 16),
                    _ConditionsPanel(sheet: sheet),
                    const SizedBox(height: 16),
                    _DerivedPanel(totals: totals),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _VitalsPanel(),
                        const SizedBox(height: 16),
                        _DeathSavePanel(bodyStat: totals.statValue(Stat.body)),
                        const SizedBox(height: 16),
                        _ConditionsPanel(sheet: sheet),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _IdentityPanel(),
                        const SizedBox(height: 16),
                        const _QuickArmorPanel(),
                        const SizedBox(height: 16),
                        _DerivedPanel(totals: totals),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _VitalsPanel extends StatelessWidget {
  const _VitalsPanel();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet!;
    final totals = state.totals!;
    final identity = sheet.identity;
    final int currentHp = sheet.effectiveHp;
    final int maxLuck = totals.statValue(Stat.luck);
    final int currentLuck = sheet.effectiveLuck.clamp(0, maxLuck > 0 ? maxLuck : 10);

    return ChamferPanel(
      title: 'Stato vitale',
      trailing: const CyberHelpTooltip(
        title: 'Punti Ferita & Umanità',
        message: 'I PV indicano la salute fisica: a metà PV sei Ferito Gravemente (-2 a tutte le azioni). Sotto i 10 punti di Umanità subentra la Cyberpsicosi!',
        tag: 'Regole',
      ),
      accent: CprPalette.healthColorFor(
        totals.maxHitPoints == 0 ? 0 : currentHp / totals.maxHitPoints,
      ),
      child: Column(
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              Tooltip(
                message:
                    'Punti Vita (PV): 10 + 5 × Media(FIS, VOL). A metà PV sei Ferito Gravemente (-2 a tutte le azioni). A 0 PV sei Morente.',
                waitDuration: const Duration(milliseconds: 200),
                child: HealthHeart(
                  current: currentHp,
                  max: totals.maxHitPoints,
                  size: 156,
                ),
              ),
              Tooltip(
                message:
                    'Umanità: Inizia a Empatia × 10. Si riduce installando Cyberware. Sotto i 10 punti rischi la Cyberpsicosi!',
                waitDuration: const Duration(milliseconds: 200),
                child: HumanityGauge(
                  current: identity.currentHumanity,
                  max: totals.maxHumanity,
                  size: 156,
                ),
              ),
              Tooltip(
                message:
                    'Fortuna (LUCK): Spendi punti Fortuna prima di un tiro per aggiungere +1 al risultato per ogni punto speso!',
                waitDuration: const Duration(milliseconds: 200),
                child: LuckClover(
                  current: currentLuck,
                  max: totals.statValue(Stat.luck),
                  size: 156,
                ),
              ),
              Tooltip(
                message:
                    'Empatia (EMP): Misura l\'umanità emotiva e la capacità di relazionarsi con gli altri.',
                waitDuration: const Duration(milliseconds: 200),
                child: EmpathyGauge(
                  current: identity.currentEmpathy,
                  max: totals.maxEmpathy,
                  size: 156,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DamageControls(
            current: currentHp,
            max: totals.maxHitPoints,
            onSet: (int value) => state.mutate((s) => s.effectiveHp = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TechNumberStepper(
                  label: 'Fortuna corrente',
                  value: currentLuck,
                  min: 0,
                  max: maxLuck > 0 ? maxLuck : 10,
                  accent: CprPalette.yellow,
                  onChanged: (int v) =>
                      state.mutate((s) => s.effectiveLuck = v.clamp(0, maxLuck > 0 ? maxLuck : 10)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Empatia corrente',
                  value: identity.currentEmpathy,
                  max: totals.maxEmpathy,
                  accent: CprPalette.humanityIntact,
                  onChanged: (int v) => state.mutate((s) => s.identity.currentEmpathy = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TechNumberStepper(
                  label: 'Umanita corrente',
                  value: identity.currentHumanity,
                  max: totals.maxHumanity,
                  accent: CprPalette.humanityIntact,
                  onChanged: (int v) => state.mutate((s) => s.identity.currentHumanity = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Punti ispirazione',
                  value: identity.inspirationPoints,
                  max: 99,
                  accent: CprPalette.magenta,
                  onChanged: (int v) => state.mutate((s) => s.identity.inspirationPoints = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TechNumberStepper(
                  label: 'Punti miglioramento',
                  value: identity.currentImprovementPoints,
                  max: 999,
                  compact: true,
                  onChanged: (int v) =>
                      state.mutate((s) => s.identity.currentImprovementPoints = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Totale guadagnati',
                  value: identity.totalImprovementPoints,
                  max: 999,
                  compact: true,
                  onChanged: (int v) =>
                      state.mutate((s) => s.identity.totalImprovementPoints = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Controlli di danno e cura rapida.
class _DamageControls extends StatelessWidget {
  const _DamageControls({
    required this.current,
    required this.max,
    required this.onSet,
  });

  final int current;
  final int max;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _QuickButton(
              label: '1 danno',
              color: CprPalette.danger,
              onTap: () => onSet((current - 1).clamp(0, max)),
            ),
            _QuickButton(
              label: '5 danni',
              color: CprPalette.danger,
              onTap: () => onSet((current - 5).clamp(0, max)),
            ),
            _QuickButton(
              label: '10 danni',
              color: CprPalette.danger,
              onTap: () => onSet((current - 10).clamp(0, max)),
            ),
            _QuickButton(
              label: '1 cura',
              color: CprPalette.success,
              onTap: () => onSet((current + 1).clamp(0, max)),
            ),
            _QuickButton(
              label: '5 cura',
              color: CprPalette.success,
              onTap: () => onSet((current + 5).clamp(0, max)),
            ),
            _QuickButton(
              label: 'Riposo completo',
              color: CprPalette.success,
              onTap: () => onSet(max),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: CprPalette.veil(color, 0.55)),
            color: CprPalette.veil(color, 0.08),
          ),
          child: Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(fontSize: 9.5, color: color),
          ),
        ),
      ),
    );
  }
}

/// Pannello Tiro della Morte (Death Save) da regolamento Cyberpunk RED (p. 186).
///
/// A 0 PV il personaggio e' Morente: all'inizio di ogni turno deve tirare 1d10
/// contro il proprio valore di Fisico (BODY). Ogni turno successivo aggiunge +1
/// di penalita'. Con un 10 naturale muore sul colpo.
class _DeathSavePanel extends StatefulWidget {
  const _DeathSavePanel({required this.bodyStat});

  final int bodyStat;

  @override
  State<_DeathSavePanel> createState() => _DeathSavePanelState();
}

class _DeathSavePanelState extends State<_DeathSavePanel> {
  int _deathPenalty = 0;
  String? _rollOutcome;
  bool _survived = true;

  void _rollDeathSave() {
    final DiceRoll roll = rollDie(DiceType.d10, label: 'Tiro della Morte');
    final int effectiveRoll = roll.result + _deathPenalty;
    final bool nat10 = roll.result == 10;
    final bool survived = !nat10 && effectiveRoll < widget.bodyStat;

    setState(() {
      _survived = survived;
      if (nat10) {
        _rollOutcome =
            '10 NATURALE (CRITICO): Il personaggio non regge lo sforzo e soccombe alla morte.';
      } else if (survived) {
        _rollOutcome =
            'SUCCESSO: Tiro [${roll.result}] + Penalità [$_deathPenalty] = $effectiveRoll (< FIS ${widget.bodyStat}). Sei ancora vivo!';
      } else {
        _rollOutcome =
            'FALLITO: Tiro [${roll.result}] + Penalità [$_deathPenalty] = $effectiveRoll (>= FIS ${widget.bodyStat}). Il personaggio spira.';
      }
      _deathPenalty++;
    });
  }

  void _reset() {
    setState(() {
      _deathPenalty = 0;
      _rollOutcome = null;
      _survived = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Tiro della morte (Death save)',
      accent: CprPalette.danger,
      trailing: TechButton(
        label: 'Azzera penalità',
        variant: TechButtonVariant.ghost,
        compact: true,
        onPressed: _reset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Tooltip(
                  message:
                      'Soglia Base del Tiro della Morte: corrisponde al valore di Fisico (BODY). Per sopravvivere a 0 PV devi fare strettamente meno con 1d10 + penalità.',
                  waitDuration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: CprPalette.surfaceRaised,
                      border: Border.all(color: CprPalette.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'SOGLIA MORTE (FISICO)',
                          style: CprType.label.copyWith(fontSize: 9, color: CprPalette.inkFaint),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.bodyStat}',
                          style: CprType.numeral.copyWith(fontSize: 22, color: CprPalette.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Penalità round (+1/turno)',
                  value: _deathPenalty,
                  max: 20,
                  accent: CprPalette.danger,
                  compact: true,
                  onChanged: (int v) => setState(() => _deathPenalty = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TechButton(
              label: 'Lancia tiro della morte (1d10)',
              icon: Icons.casino_outlined,
              variant: TechButtonVariant.danger,
              onPressed: _rollDeathSave,
            ),
          ),
          if (_rollOutcome != null) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: CprPalette.veil(
                  _survived ? CprPalette.success : CprPalette.danger,
                  0.12,
                ),
                border: Border.all(
                  color: _survived ? CprPalette.success : CprPalette.danger,
                  width: 1.2,
                ),
              ),
              child: Text(
                _rollOutcome!,
                style: CprType.body.copyWith(
                  fontSize: 12,
                  color: _survived ? CprPalette.success : CprPalette.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Riepilogo rapido delle armature equipaggiate e relative penalità (da Java FXML).
class _QuickArmorPanel extends StatelessWidget {
  const _QuickArmorPanel();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<ResolvedItem> inventory = state.resolvedInventory;
    final List<ResolvedItem> equippedArmor =
        inventory.where((ResolvedItem i) => i.entry.isEquipped && i.isArmor).toList();

    ResolvedItem? head;
    ResolvedItem? body;
    ResolvedItem? shield;
    int totalPenalty = 0;

    for (final ResolvedItem item in equippedArmor) {
      final armor = item.armor;
      if (armor == null) continue;
      totalPenalty += armor.penalties;
      switch (armor.slot) {
        case ArmorSlot.head:
          head ??= item;
          break;
        case ArmorSlot.body:
          body ??= item;
          break;
        case ArmorSlot.shield:
          shield ??= item;
          break;
      }
    }

    return ChamferPanel(
      title: 'Armatura equipaggiata',
      accent: CprPalette.cyan,
      trailing: totalPenalty > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: CprPalette.danger.withValues(alpha: 0.15),
                border: Border.all(color: CprPalette.danger, width: 1),
              ),
              child: Text(
                'PENALITÀ -$totalPenalty RIF/DES/MOV',
                style: CprType.label.copyWith(
                  fontSize: 9,
                  color: CprPalette.danger,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Text(
              'Nessuna penalità',
              style: CprType.caption.copyWith(color: CprPalette.success, fontSize: 10),
            ),
      child: Column(
        children: <Widget>[
          _ArmorSlotRow(
            slotLabel: 'Testa (SP)',
            item: head,
            icon: Icons.face_retouching_natural_outlined,
          ),
          const Divider(height: 14, color: CprPalette.hairline),
          _ArmorSlotRow(
            slotLabel: 'Corpo (SP)',
            item: body,
            icon: Icons.shield_outlined,
          ),
          const Divider(height: 14, color: CprPalette.hairline),
          _ArmorSlotRow(
            slotLabel: 'Scudo (SP)',
            item: shield,
            icon: Icons.security_outlined,
          ),
        ],
      ),
    );
  }
}

class _ArmorSlotRow extends StatelessWidget {
  const _ArmorSlotRow({
    required this.slotLabel,
    required this.item,
    required this.icon,
  });

  final String slotLabel;
  final ResolvedItem? item;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final int sp = item?.armor?.sp ?? 0;
    final int penalties = item?.armor?.penalties ?? 0;
    final String name = item?.name ?? 'Nessuna armatura';

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: item != null ? CprPalette.cyan : CprPalette.inkFaint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                slotLabel.toUpperCase(),
                style: CprType.label.copyWith(fontSize: 9, color: CprPalette.inkFaint),
              ),
              const SizedBox(height: 1),
              Text(
                name,
                style: CprType.body.copyWith(
                  fontSize: 13,
                  color: item != null ? CprPalette.ink : CprPalette.inkMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (penalties > 0) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: CprPalette.danger, width: 1),
            ),
            child: Text(
              '-$penalties',
              style: CprType.label.copyWith(fontSize: 9, color: CprPalette.danger),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: CprPalette.veil(CprPalette.cyan, 0.1),
            border: Border.all(color: CprPalette.veil(CprPalette.cyan, 0.4)),
          ),
          child: Text(
            'SP $sp',
            style: CprType.numeral.copyWith(
              fontSize: 14,
              color: sp > 0 ? CprPalette.cyan : CprPalette.inkFaint,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel();

  static const List<Map<String, String>> _standardRoles = <Map<String, String>>[
    <String, String>{'role': 'Solo', 'ability': 'Consapevolezza del Combattimento'},
    <String, String>{'role': 'Netrunner', 'ability': 'Interfaccia'},
    <String, String>{'role': 'Tech', 'ability': 'Fabbricazione / Riparazione'},
    <String, String>{'role': 'Medtech', 'ability': 'Medicina'},
    <String, String>{'role': 'Rockerboy', 'ability': 'Impatto Carismatico'},
    <String, String>{'role': 'Fixer', 'ability': 'Mercato Nero / Contatti'},
    <String, String>{'role': 'Media', 'ability': 'Credibilità'},
    <String, String>{'role': 'Lawman', 'ability': 'Backup Legale'},
    <String, String>{'role': 'Exec', 'ability': 'Lavoro di Squadra'},
    <String, String>{'role': 'Nomade', 'ability': 'Moto / Famiglia'},
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet!;
    final identity = sheet.identity;

    return ChamferPanel(
      title: 'Anagrafica & Identità',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _CharacterAvatarThumb(sheet: sheet, state: state),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Tooltip(
                      message:
                          'Il nome da strada (Handle) con cui il tuo personaggio è conosciuto.',
                      waitDuration: const Duration(milliseconds: 200),
                      child: TechField(
                        label: 'Nome del personaggio (Handle)',
                        value: identity.tag,
                        hint: 'Come ti chiamano in strada',
                        onChanged: (String v) => state.mutate((s) => s.identity.tag = v),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Tooltip(
                      message: 'Il tuo nome o nickname reale al tavolo di gioco.',
                      waitDuration: const Duration(milliseconds: 200),
                      child: TechField(
                        label: 'Giocatore',
                        value: identity.playerName,
                        onChanged: (String v) =>
                            state.mutate((s) => s.identity.playerName = v),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Tooltip(
                  message: 'Soprannomi o pseudonimi usati nelle strade di Night City.',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Soprannomi',
                    value: identity.aliases,
                    hint: 'Separati da virgola',
                    onChanged: (String v) => state.mutate((s) => s.identity.aliases = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: 'Anno e data corrente della campagna (es. 2045 o 2077).',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Data in gioco',
                    value: identity.gameDate,
                    hint: 'gg/mm/aaaa',
                    onChanged: (String v) => state.mutate((s) => s.identity.gameDate = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sezione Ruoli (Multiruolo con tag chips e menu a tendina)
          ChamferPanel(
            title: 'Ruoli & Specializzazioni (Multiruolo)',
            accent: CprPalette.yellow,
            trailing: const CyberHelpTooltip(
              title: 'Ruoli & Multiclasse',
              message: 'In Cyberpunk RED puoi combinare più ruoli (es. Solo + Netrunner). Ciascun ruolo conferisce la sua abilità speciale unica.',
              tag: 'Ruoli',
              accent: CprPalette.yellow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    for (final String r in identity.roles)
                      _RoleTag(
                        label: r,
                        onDelete: () => state.mutate((s) => s.identity.removeRole(r)),
                      ),
                    PopupMenuButton<String>(
                      tooltip: 'Seleziona i ruoli del tuo personaggio (scelta multipla)',
                      color: CprPalette.surfaceRaised,
                      elevation: 8,
                      shape: Border.all(color: CprPalette.yellow, width: 1),
                      onSelected: (String role) {
                        state.mutate((s) {
                          if (s.identity.roles.any((r) => r.toLowerCase() == role.toLowerCase())) {
                            s.identity.removeRole(role);
                          } else {
                            s.identity.addRole(role);
                          }
                        });
                      },
                      itemBuilder: (BuildContext ctx) {
                        return <String>[
                          'Solo',
                          'Netrunner',
                          'Tech',
                          'Medtech',
                          'Media',
                          'Rockerboy',
                          'Exec',
                          'Lawman',
                          'Fixer',
                          'Nomad',
                        ].map((String role) {
                          final bool selected = identity.roles.any((r) => r.toLowerCase() == role.toLowerCase());
                          return PopupMenuItem<String>(
                            value: role,
                            child: Row(
                              children: <Widget>[
                                Icon(
                                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                                  size: 16,
                                  color: selected ? CprPalette.yellow : CprPalette.inkMuted,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  role,
                                  style: CprType.body.copyWith(
                                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                    color: selected ? CprPalette.yellow : CprPalette.ink,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CprPalette.surfaceSunken,
                          border: Border.all(color: CprPalette.yellow.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(Icons.add, size: 13, color: CprPalette.yellow),
                            const SizedBox(width: 4),
                            Text(
                              'AGGIUNGI RUOLO',
                              style: CprType.label.copyWith(
                                fontSize: 9.5,
                                color: CprPalette.yellow,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      flex: 3,
                      child: TechField(
                        label: 'Modifica o inserisci ruolo custom',
                        value: identity.role,
                        hint: 'Separati da virgola (es. Solo, Tech)',
                        onChanged: (String v) => state.mutate((s) => s.identity.role = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Tooltip(
                        message: 'Reputazione: quanto sei temuto o rispettato (da 0 per sconosciuto a 10 per leggenda).',
                        waitDuration: const Duration(milliseconds: 200),
                        child: TechField(
                          label: 'Punti reputazione',
                          value: identity.reputation,
                          onChanged: (String v) => state.mutate((s) => s.identity.reputation = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Sezione Abilità di Ruolo (box impilati per ciascuna classe posseduta con rango individuale)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int rIdx = 0; rIdx < identity.roleEntries.length; rIdx++) ...<Widget>[
                _RoleClassCard(
                  index: rIdx,
                  entry: identity.roleEntries[rIdx],
                  canRemove: identity.roleEntries.length > 1,
                  onRemove: () {
                    state.mutate((s) {
                      s.identity.roleEntries.removeAt(rIdx);
                      s.identity.syncRoleFieldsFromEntries();
                    });
                  },
                  onChanged: (RoleEntry updated) {
                    state.mutate((s) {
                      s.identity.roleEntries[rIdx] = updated;
                      s.identity.syncRoleFieldsFromEntries();
                    });
                  },
                  standardRoles: _standardRoles,
                ),
                const SizedBox(height: 12),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TechButton(
                  label: 'Aggiungi Classe / Multiclasse',
                  icon: Icons.add_circle_outline,
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  onPressed: () {
                    state.mutate((s) {
                      s.identity.roleEntries.add(
                        RoleEntry(role: 'Netrunner', ability: 'Interfaccia', rank: 4),
                      );
                      s.identity.syncRoleFieldsFromEntries();
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Miniatura ritratto del personaggio con selezione rapida file (da Java imageViewCharacterImage).
class _CharacterAvatarThumb extends StatelessWidget {
  const _CharacterAvatarThumb({required this.sheet, required this.state});

  final CharacterSheet sheet;
  final AppState state;

  Future<void> _chooseAvatar(BuildContext context) async {
    final String? picked = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Scegli il ritratto del personaggio',
      extensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
      initialDirectory: AppPaths.documentsDir().path,
      showAllFilesToggle: true,
    );
    if (picked == null) return;
    state.mutate((s) => s.physical.imagePath = picked);
  }

  @override
  Widget build(BuildContext context) {
    final String? path = sheet.physical.imagePath;
    final bool hasImage = path != null && path.trim().isNotEmpty && File(path).existsSync();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _chooseAvatar(context),
        child: Tooltip(
          message: 'Clicca per caricare o cambiare il ritratto del personaggio',
          waitDuration: const Duration(milliseconds: 200),
          child: Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: CprPalette.surfaceRaised,
              border: Border.all(
                color: hasImage ? CprPalette.cyan : CprPalette.hairline,
                width: 1.5,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (hasImage)
                  Image.file(File(path), fit: BoxFit.cover)
                else
                  const Center(
                    child: Icon(Icons.person_pin, size: 40, color: CprPalette.inkFaint),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: CprPalette.voidBlack.withValues(alpha: 0.75),
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      'FOTO',
                      textAlign: TextAlign.center,
                      style: CprType.label.copyWith(
                        fontSize: 8,
                        color: hasImage ? CprPalette.cyan : CprPalette.inkFaint,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.label, required this.onDelete});

  final String label;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 4, top: 3, bottom: 3),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.yellow, 0.15),
        border: Border.all(color: CprPalette.yellow, width: 1),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(
              fontSize: 10,
              color: CprPalette.yellow,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: CprPalette.yellow),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleClassCard extends StatelessWidget {
  const _RoleClassCard({
    required this.index,
    required this.entry,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
    required this.standardRoles,
  });

  final int index;
  final RoleEntry entry;
  final bool canRemove;
  final VoidCallback onRemove;
  final ValueChanged<RoleEntry> onChanged;
  final List<Map<String, String>> standardRoles;

  @override
  Widget build(BuildContext context) {
    final String displayTitle =
        entry.role.trim().isEmpty ? 'Nuova Classe #${index + 1}' : entry.role.trim();

    return ChamferPanel(
      title: 'Classe #${index + 1}: $displayTitle',
      accent: CprPalette.yellow,
      trailing: canRemove
          ? IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: CprPalette.danger),
              tooltip: 'Rimuovi questa classe / ruolo',
              onPressed: onRemove,
              splashRadius: 18,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TechField(
                      label: 'Ruolo / Classe',
                      value: entry.role,
                      hint: 'es. Solo, Netrunner, Medtech...',
                      onChanged: (String v) {
                        entry.role = v;
                        onChanged(entry);
                      },
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: standardRoles.map((Map<String, String> item) {
                        final String rName = item['role'] ?? '';
                        final String rAbility = item['ability'] ?? '';
                        final bool isCurrent =
                            entry.role.trim().toLowerCase() == rName.toLowerCase();
                        return InkWell(
                          onTap: () {
                            entry.role = rName;
                            if (entry.ability.trim().isEmpty ||
                                standardRoles.any((r) => r['ability'] == entry.ability)) {
                              entry.ability = rAbility;
                            }
                            onChanged(entry);
                          },
                          borderRadius: BorderRadius.circular(3),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? CprPalette.yellow.withValues(alpha: 0.25)
                                  : CprPalette.surfaceRaised,
                              border: Border.all(
                                color: isCurrent ? CprPalette.yellow : CprPalette.hairline,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              rName,
                              style: CprType.caption.copyWith(
                                fontSize: 9,
                                color: isCurrent ? CprPalette.yellow : CprPalette.inkMuted,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TechNumberStepper(
                  label: 'Rango Ruolo',
                  value: entry.rank,
                  min: 1,
                  max: 10,
                  accent: CprPalette.yellow,
                  onChanged: (int v) {
                    entry.rank = v;
                    onChanged(entry);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TechField(
                  label: 'Abilità di Ruolo Principale',
                  value: entry.ability,
                  hint: 'es. Consapevolezza del Combattimento, Interfaccia...',
                  onChanged: (String v) {
                    entry.ability = v;
                    onChanged(entry);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TechField(
                  label: 'Note / Sotto-abilità / Specializzazioni',
                  value: entry.notes,
                  hint: 'Distribuzione punti, opzioni, subroutine...',
                  onChanged: (String v) {
                    entry.notes = v;
                    onChanged(entry);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}



class _EmptySheetGuideBanner extends StatelessWidget {
  const _EmptySheetGuideBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.yellow, 0.08),
        border: Border.all(color: CprPalette.veil(CprPalette.yellow, 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lightbulb_outline, color: CprPalette.yellow, size: 18),
              const SizedBox(width: 8),
              Text(
                'GUIDA ALLA COMPILAZIONE DELLA SCHEDA',
                style: CprType.label.copyWith(color: CprPalette.yellow, letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Compila il Nome (Handle) del personaggio e clicca sul tuo Ruolo nei pulsanti rapidi sotto.\n'
            '• Apri la sezione "Statistiche e Abilità" nel menu a sinistra per distribuire i 62 punti tra le 10 caratteristiche.\n'
            '• Punti Vita (PV), Umanità, Soglia Ferita Grave e Basi Abilità si calcolano automaticamente in tempo reale!',
            style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DerivedPanel extends StatelessWidget {
  const _DerivedPanel({required this.totals});

  final SheetTotals totals;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Valori calcolati',
      accent: CprPalette.inkFaint,
      trailing: Text(
        'ricalcolati automaticamente',
        style: CprType.caption.copyWith(color: CprPalette.inkFaint),
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 14,
        children: <Widget>[
          _DerivedValue(
            label: 'Punti vita massimi',
            value: '${totals.maxHitPoints}',
            tooltip: 'Formula da manuale: 10 + 5 × Media(FIS, VOL).',
          ),
          _DerivedValue(
            label: 'Soglia ferite gravi',
            value: '${totals.severeInjuriesThreshold}',
            hint: 'oltre questa soglia',
            tooltip: 'A metà dei PV massimi. Sei Ferito Gravemente (-2 a tutte le azioni).',
          ),
          _DerivedValue(
            label: 'Empatia massima',
            value: '${totals.maxEmpathy}',
            tooltip: 'Il valore di Empatia attuale, calcolato come Umanità / 10.',
          ),
          _DerivedValue(
            label: 'Umanita massima',
            value: '${totals.maxHumanity}',
            tooltip: 'Umanità massima iniziale = Empatia base × 10.',
          ),
          _DerivedValue(
            label: 'Umanita persa',
            value: '${totals.humanityLost}',
            danger: totals.humanityLost > 0,
            tooltip:
                'Umanità sottratta a causa di Cyberware installato o traumi psicologici.',
          ),
          _DerivedValue(
            label: 'Carico massimo',
            value: '${totals.maxLoad.toStringAsFixed(1)} kg',
            tooltip: 'Peso trasportabile prima di subire penalità al movimento.',
          ),
          _DerivedValue(
            label: 'Carico attuale',
            value: '${totals.currentLoad.toStringAsFixed(1)} kg',
            tooltip: 'Peso complessivo di inventario ed equipaggiamento.',
          ),
          _DerivedValue(
            label: 'Stato di carico',
            value: totals.loadStatus.label,
            danger: totals.loadStatus == LoadStatus.overload,
            tooltip: 'Stato del carico: Normale, Pesante o Sovraccarico (-2 VEL).',
          ),
        ],
      ),
    );
  }
}

class _DerivedValue extends StatelessWidget {
  const _DerivedValue({
    required this.label,
    required this.value,
    this.hint,
    this.tooltip,
    this.danger = false,
  });

  final String label;
  final String value;
  final String? hint;
  final String? tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: CprType.numeral.copyWith(
            fontSize: 19,
            color: danger ? CprPalette.danger : CprPalette.ink,
          ),
        ),
        if (hint != null)
          Text(hint!, style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10)),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 200),
        child: content,
      );
    }
    return content;
  }
}

class _ConditionsPanel extends StatelessWidget {
  const _ConditionsPanel({required this.sheet});

  final CharacterSheet sheet;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return ChamferPanel(
      title: 'Condizioni',
      accent: CprPalette.warning,
      child: Column(
        children: <Widget>[
          TechTextArea(
            label: 'Ferite gravi',
            value: sheet.activeProfile?.severeInjuries ?? sheet.identity.severeInjuries,
            hint: 'Una per riga: cosa, dove, quanto e\' guarita',
            lines: 3,
            accent: CprPalette.danger,
            onChanged: (String v) => state.mutate((s) {
              if (s.activeProfile != null) {
                s.activeProfile!.severeInjuries = v;
              } else {
                s.identity.severeInjuries = v;
              }
            }),
          ),
          const SizedBox(height: 12),
          TechTextArea(
            label: 'Dipendenze',
            value: sheet.identity.addictions,
            hint: 'Sostanza, grado di dipendenza',
            lines: 3,
            accent: CprPalette.magenta,
            onChanged: (String v) => state.mutate((s) => s.identity.addictions = v),
          ),
        ],
      ),
    );
  }
}

/// Barra di intestazione che permette di passare dalla Scheda Base ai Profili Campagna
/// memorizzati all'interno dello stesso documento .cpredux (senza creare nuovi file).
class _CampaignProfileBar extends StatelessWidget {
  const _CampaignProfileBar({required this.sheet, required this.state});

  final CharacterSheet sheet;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final String? activeId = sheet.activeCampaignProfileId;
    final CampaignSheetProfile? activeProfile = sheet.activeProfile;
    final bool isBase = activeProfile == null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        border: Border.all(
          color: isBase ? CprPalette.hairline : CprPalette.yellow,
          width: isBase ? 1 : 1.2,
        ),
      ),
      child: Wrap(
        runSpacing: 8,
        spacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    isBase ? Icons.person_outline : Icons.casino_outlined,
                    size: 18,
                    color: isBase ? CprPalette.inkMuted : CprPalette.yellow,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'PROFILO:',
                    style: CprType.label.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: isBase ? CprPalette.inkMuted : CprPalette.yellow,
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String?>(
                tooltip: 'Seleziona profilo scheda o versione campagna',
                color: CprPalette.surfaceRaised,
                shape: Border.all(color: CprPalette.yellow),
                onSelected: (String? profileId) {
                  state.mutate((s) => s.selectCampaignProfile(profileId));
                },
                itemBuilder: (BuildContext ctx) => <PopupMenuEntry<String?>>[
                  PopupMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: <Widget>[
                        const Icon(Icons.person, size: 16, color: CprPalette.cyan),
                        const SizedBox(width: 8),
                        Text(
                          'Scheda Base (Originale)',
                          style: CprType.body.copyWith(
                            fontWeight: isBase ? FontWeight.bold : FontWeight.normal,
                            color: isBase ? CprPalette.cyan : CprPalette.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (sheet.campaignProfiles.isNotEmpty) const PopupMenuDivider(),
                  for (final CampaignSheetProfile prof in sheet.campaignProfiles.values)
                    PopupMenuItem<String?>(
                      value: prof.campaignId,
                      child: Row(
                        children: <Widget>[
                          const Icon(Icons.casino_outlined, size: 16, color: CprPalette.yellow),
                          const SizedBox(width: 8),
                          Text(
                            'Campagna: ${prof.campaignName}',
                            style: CprType.body.copyWith(
                              fontWeight: activeId == prof.campaignId ? FontWeight.bold : FontWeight.normal,
                              color: activeId == prof.campaignId ? CprPalette.yellow : CprPalette.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: CprPalette.surfaceSunken,
                    border: Border.all(color: isBase ? CprPalette.hairline : CprPalette.yellow),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        isBase ? 'Scheda Base (Originale)' : 'Campagna: ${activeProfile.campaignName}',
                        style: CprType.body.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: isBase ? CprPalette.ink : CprPalette.yellow,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down, size: 16, color: CprPalette.inkMuted),
                    ],
                  ),
                ),
              ),
              const CyberHelpTooltip(
                title: 'Versioni & Profili Campagna',
                message: 'In Cyberpunk RED puoi associare questa scheda a diverse campagne senza duplicare il file: i PV attuali, punti fortuna e ferite subite vengono salvati separatamente nel profilo della campagna, lasciando la tua Scheda Base intatta.',
                tag: 'Overlay',
                accent: CprPalette.yellow,
              ),
            ],
          ),
          TechButton(
            label: '+ Associa a Campagna',
            icon: Icons.add_circle_outline,
            variant: TechButtonVariant.ghost,
            compact: true,
            onPressed: () => _promptAddCampaignProfile(context, state, sheet),
          ),
        ],
      ),
    );
  }

  Future<void> _promptAddCampaignProfile(BuildContext context, AppState state, CharacterSheet sheet) async {
    final TextEditingController nameCtrl = TextEditingController(text: 'Nuova Campagna 2045');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: CprPalette.surface,
        title: Text('Nuovo Profilo Campagna', style: CprType.body.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Crea un overlay per una campagna specifica. Le modifiche ai PV, munizioni e ferite saranno registrate qui senza toccare la Scheda Base originale:',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome della Campagna')),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
          TechButton(
            label: 'Crea Profilo',
            icon: Icons.check,
            variant: TechButtonVariant.primary,
            compact: true,
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
          ),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final String campName = nameCtrl.text.trim();
      final String campId = 'camp_profile_${DateTime.now().millisecondsSinceEpoch}';
      state.mutate((s) {
        s.getOrCreateProfile(campId, campName);
        s.selectCampaignProfile(campId);
      });
    }
  }
}

