import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../domain/modifiers.dart';
import '../../domain/sheet.dart';
import '../../domain/skills.dart';
import '../../domain/stats.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/dice_roll_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

/// Statistiche e abilita'.
///
/// Due livelli distinti e sempre visibili separatamente: il **valore base**,
/// che l'utente modifica, e il **valore calcolato**, che somma i modificatori
/// di cyberware, effetti e correzioni manuali. Tenerli separati non e' un
/// dettaglio implementativo: quando il master chiede "come fai ad avere 17?",
/// la risposta deve essere leggibile a schermo, non ricostruibile a mente.
class StatsTab extends StatefulWidget {
  const StatsTab({super.key});

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  bool? _isLockedOverride;

  bool _isStatsLocked(CharacterSheet sheet) {
    if (_isLockedOverride != null) return _isLockedOverride!;
    // Durante la prima creazione della scheda (prima del primo salvataggio / senza IP storici),
    // le caratteristiche sono liberamente modificabili. Una volta salvata o con avanzamenti,
    // sono bloccate e richiedono la pressione della matitina con conferma.
    final bool isBrandNew = sheet.identity.totalImprovementPoints == 0 &&
        sheet.meta.createdAt.isNotEmpty &&
        sheet.meta.createdAt == sheet.meta.updatedAt;
    return !isBrandNew;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet!;
    final totals = state.totals!;
    final bool locked = _isStatsLocked(sheet);

    final Widget statsCol = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ChamferPanel(
          title: 'Caratteristiche',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _PointTracker(sheet: sheet),
              const SizedBox(width: 8),
              if (locked)
                Tooltip(
                  message: 'Modifica caratteristiche base (richiede conferma)',
                  child: InkResponse(
                    onTap: () async {
                      final bool ok = await showTechConfirm(
                        context,
                        title: 'MODIFICA CARATTERISTICHE BASE',
                        message:
                            'I punti caratteristica (INT, RIF, DES, TEC, CAR, VOL, FOR, VEL, FIS, EMP) '
                            'sono definiti alla creazione della scheda e aumentano solo avanzando '
                            'di livello con i Punti Miglioramento (IP).\n\n'
                            'Vuoi sbloccare la modifica manuale delle caratteristiche?',
                        confirmLabel: 'SBLOCCA MODIFICA',
                      );
                      if (ok && mounted) {
                        setState(() => _isLockedOverride = false);
                      }
                    },
                    radius: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: CprPalette.surfaceSunken,
                        border: Border.all(color: CprPalette.yellow.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.edit_outlined, size: 12, color: CprPalette.yellow),
                          const SizedBox(width: 4),
                          Text(
                            'MODIFICA',
                            style: CprType.label.copyWith(
                              fontSize: 9.5,
                              color: CprPalette.yellow,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Tooltip(
                  message: 'Blocca modifiche caratteristiche base',
                  child: InkResponse(
                    onTap: () => setState(() => _isLockedOverride = true),
                    radius: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: CprPalette.surfaceSunken,
                        border: Border.all(color: CprPalette.cyan.withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.lock_open, size: 12, color: CprPalette.cyan),
                          const SizedBox(width: 4),
                          Text(
                            'SBLOCCATO',
                            style: CprType.label.copyWith(
                              fontSize: 9.5,
                              color: CprPalette.cyan,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          child: Column(
            children: <Widget>[
              for (final Stat stat in Stat.values)
                _StatRow(
                  stat: stat,
                  base: sheet.statBase[stat] ?? 1,
                  calculated: totals.statValue(stat),
                  onChanged: locked ? null : (int v) => state.mutate((s) => s.statBase[stat] = v),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ManualModifiersPanel(state: state),
        const SizedBox(height: 16),
        _ProficienciesPanel(state: state),
      ],
    );

    final Widget skillsCol = ChamferPanel(
      title: 'Abilita',
      trailing: SizedBox(
        width: 220,
        child: TechField(
          label: '',
          value: _query,
          hint: 'Cerca fra le abilita…',
          onChanged: (String v) => setState(() => _query = v.toLowerCase()),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final SkillCategory category in SkillCategory.values)
            ..._categorySection(category, state),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          final bool twoColumns = c.maxWidth >= 980;
          if (!twoColumns) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                statsCol,
                const SizedBox(height: 16),
                skillsCol,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 5, child: statsCol),
              const SizedBox(width: 16),
              Expanded(flex: 6, child: skillsCol),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _categorySection(SkillCategory category, AppState state) {
    final List<Skill> all = Skill.byCategory[category] ?? <Skill>[];
    final List<Skill> visible = _query.isEmpty
        ? all
        : all.where((Skill s) => s.name.toLowerCase().contains(_query)).toList();
    if (visible.isEmpty) return const <Widget>[];

    final sheet = state.sheet!;
    final totals = state.totals!;

    return <Widget>[
      const SizedBox(height: 14),
      Row(
        children: <Widget>[
          Container(width: 3, height: 11, color: CprPalette.inkFaint),
          const SizedBox(width: 8),
          Text(
            category.label.toUpperCase(),
            style: CprType.label.copyWith(color: CprPalette.inkMuted, fontSize: 10),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: CprPalette.hairline)),
        ],
      ),
      const SizedBox(height: 6),
      for (final Skill skill in visible)
        _SkillRow(
          skill: skill,
          base: sheet.skillLevels[skill] ?? 0,
          calculated: totals.skillValue(skill),
          checkTotal: totals.skillCheck(skill),
          statValue: totals.statValue(skill.stat),
          onChanged: (int v) => state.mutate((s) => s.skillLevels[skill] = v),
        ),
    ];
  }
}

class _PointTracker extends StatelessWidget {
  const _PointTracker({required this.sheet});

  final CharacterSheet sheet;

  @override
  Widget build(BuildContext context) {
    final int spent = sheet.statBase.values.fold(0, (int a, int b) => a + b);
    final int remaining = 62 - spent;
    final Color color = spent == 62
        ? CprPalette.success
        : (spent > 62 ? CprPalette.danger : CprPalette.yellow);

    return Tooltip(
      message: 'Regola Cyberpunk RED: distribuisci 62 punti tra le 10 caratteristiche (da 2 a 8 per ciascuna a inizio gioco). Modifica i valori con + e -.',
      waitDuration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: CprPalette.veil(color, 0.12),
          border: Border.all(color: color, width: 1),
        ),
        child: Text(
          'PUNTI SPESI: $spent / 62 (${remaining >= 0 ? "$remaining rimasti" : "${-remaining} in eccesso"})',
          style: CprType.label.copyWith(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.stat,
    required this.base,
    required this.calculated,
    required this.onChanged,
  });

  final Stat stat;
  final int base;
  final int calculated;
  final ValueChanged<int>? onChanged;

  static const Map<Stat, String> _statDescriptions = <Stat, String>{
    Stat.intelligence: 'INTELLIGENZA (INT): Capacità logica, percezione, calcolo e deduzione. Fondamentale per Netrunner, Tech e detective.',
    Stat.reflexes: 'RIFLESSI (RIF): Prontezza neuromuscolare, tiro con armi a distanza e guida. Con RIF 8+ puoi schivare i proiettili a vista!',
    Stat.dexterity: 'DESTREZZA (DES): Coordinazione atletica, arti marziali, combattimento in mischia e furtività.',
    Stat.technique: 'TECNICA (TEC): Abilità manuale, riparazioni, cybertecnologia, pronto soccorso e manomissione.',
    Stat.cool: 'CARISMA / COOL (CAR): Presenza scenica, fascino, persuasione e sangue freddo. Chiave per Rockerboy e Fixer.',
    Stat.willpower: 'VOLONTÀ (VOL): Coraggio, determinazione e concentrazione. Insieme a FIS determina i Punti Vita (PV).',
    Stat.luck: 'FORTUNA (FOR): Punti spendibili per aggiungere +1 a qualsiasi tiro (si ricaricano a inizio sessione).',
    Stat.movement: 'VELOCITÀ (VEL): Distanza di corsa e movimento sul campo di battaglia in metri per turno.',
    Stat.body: 'FISICO (FIS): Robustezza e massa muscolare. Determina i PV, la soglia ferita grave e il carico trasportabile.',
    Stat.empathy: 'EMPATIA (EMP): Rapporto con gli altri ed equilibrio emotivo. Ogni punto vale 10 punti di Umanità iniziale.',
  };

  @override
  Widget build(BuildContext context) {
    final int delta = calculated - base;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 130,
            child: Tooltip(
              message: _statDescriptions[stat] ?? stat.label,
              waitDuration: const Duration(milliseconds: 150),
              child: Text(
                stat.label,
                overflow: TextOverflow.ellipsis,
                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13),
              ),
            ),
          ),
          Expanded(child: _StatSegments(value: calculated, base: base)),
          const SizedBox(width: 12),
          _MiniStepper(value: base, onChanged: onChanged, min: 1, max: Stat.max),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              '$calculated',
              textAlign: TextAlign.right,
              style: CprType.numeralSmall.copyWith(
                fontSize: 16,
                color: delta > 0
                    ? CprPalette.cyan
                    : delta < 0
                        ? CprPalette.danger
                        : CprPalette.ink,
              ),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              delta == 0 ? '' : '${delta > 0 ? '+' : ''}$delta',
              textAlign: TextAlign.right,
              style: CprType.label.copyWith(
                fontSize: 9.5,
                color: delta > 0 ? CprPalette.cyan : CprPalette.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra a segmenti con il valore base evidenziato e i modificatori in un
/// colore diverso: si vede a colpo d'occhio quanta parte del totale viene
/// dal personaggio e quanta dagli impianti.
class _StatSegments extends StatelessWidget {
  const _StatSegments({required this.value, required this.base});

  final int value;
  final int base;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: Row(
        children: List<Widget>.generate(Stat.max, (int i) {
          final bool fromBase = i < base;
          final bool fromModifier = i >= base && i < value;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == Stat.max - 1 ? 0 : 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fromBase
                      ? CprPalette.yellow
                      : fromModifier
                          ? CprPalette.cyan
                          : CprPalette.surfaceRaised,
                  border: Border.all(
                    color: fromBase || fromModifier
                        ? CprPalette.veil(CprPalette.ink, 0.25)
                        : CprPalette.hairline,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.skill,
    required this.base,
    required this.calculated,
    required this.checkTotal,
    required this.statValue,
    required this.onChanged,
  });

  final Skill skill;
  final int base;
  final int calculated;
  final int checkTotal;
  final int statValue;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final int delta = calculated - base;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 54,
            child: Text(
              skill.stat.short,
              style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
            ),
          ),
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Tooltip(
                    message: '${skill.name}: Abilità legata a ${skill.stat.label.toUpperCase()}. Tiro = 1d10 + Base ($base) + Stat ($statValue) = Base $checkTotal.',
                    waitDuration: const Duration(milliseconds: 250),
                    child: Text(
                      skill.name,
                      overflow: TextOverflow.ellipsis,
                      style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13),
                    ),
                  ),
                ),
                if (skill.isDoubleCost) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Costo doppio in creazione',
                    child: Text('x2', style: CprType.label.copyWith(fontSize: 9, color: CprPalette.magenta)),
                  ),
                ],
                if (skill.isEssential) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Abilita essenziale: parte da 2',
                    child: Icon(Icons.bolt, size: 12, color: CprPalette.veil(CprPalette.yellow, 0.7)),
                  ),
                ],
                if (skill.isMaster) ...<Widget>[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Si specializza in competenze',
                    child: Icon(Icons.account_tree_outlined, size: 12, color: CprPalette.veil(CprPalette.cyan, 0.8)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _MiniStepper(value: base, onChanged: onChanged, min: 0, max: 10),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              '$calculated',
              textAlign: TextAlign.right,
              style: CprType.numeralSmall.copyWith(
                fontSize: 14,
                color: delta > 0
                    ? CprPalette.cyan
                    : delta < 0
                        ? CprPalette.danger
                        : CprPalette.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: 'Tira 1d10 + ${skill.stat.short} ($statValue) + abilita ($calculated)',
            child: InkWell(
              borderRadius: BorderRadius.circular(3),
              onTap: () {
                showCombatOrSkillRollDialog(
                  context,
                  title: 'Prova: ${skill.name}',
                  die: DiceType.d10,
                  count: 1,
                  modifier: checkTotal,
                  modifierLabel: '${skill.stat.short} + ${skill.name}',
                  skill: skill,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.yellow, 0.08),
                  border: Border.all(color: CprPalette.veil(CprPalette.yellow, 0.4)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.casino_outlined, size: 12, color: CprPalette.yellow),
                    const SizedBox(width: 4),
                    Text(
                      '$checkTotal',
                      textAlign: TextAlign.right,
                      style: CprType.numeralSmall.copyWith(color: CprPalette.yellow, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stepper compatto, senza etichetta, per le righe di tabella.
class _MiniStepper extends StatelessWidget {
  const _MiniStepper({
    required this.value,
    required this.onChanged,
    required this.min,
    required this.max,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    final bool isEditable = onChanged != null;
    return Container(
      decoration: BoxDecoration(
        color: isEditable ? Colors.transparent : CprPalette.surfaceSunken,
        border: Border.all(
          color: isEditable ? CprPalette.hairline : CprPalette.hairline.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _MiniButton(
            icon: Icons.remove,
            enabled: isEditable && value > min,
            onTap: () => onChanged?.call((value - 1).clamp(min, max)),
          ),
          SizedBox(
            width: 26,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: CprType.numeralSmall.copyWith(
                fontSize: 12,
                color: isEditable ? CprPalette.ink : CprPalette.inkMuted,
              ),
            ),
          ),
          _MiniButton(
            icon: Icons.add,
            enabled: isEditable && value < max,
            onTap: () => onChanged?.call((value + 1).clamp(min, max)),
          ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 22,
          height: 24,
          child: Icon(
            icon,
            size: 11,
            color: enabled ? CprPalette.inkMuted : CprPalette.veil(CprPalette.inkFaint, 0.4),
          ),
        ),
      ),
    );
  }
}

/// Correzioni manuali a caratteristiche e abilita'.
class _ManualModifiersPanel extends StatelessWidget {
  const _ManualModifiersPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sheet = state.sheet!;
    final int total = sheet.statModifiers.length + sheet.skillModifiers.length;

    return ChamferPanel(
      title: 'Correzioni manuali',
      accent: CprPalette.cyan,
      trailing: TechButton(
        label: 'Aggiungi',
        icon: Icons.add,
        variant: TechButtonVariant.ghost,
        compact: true,
        onPressed: () => _addModifier(context),
      ),
      child: total == 0
          ? const TechWell(
              child: Text(
                'Nessuna correzione manuale.\n'
                'I bonus di cyberware ed effetti vengono applicati automaticamente: '
                'qui vanno solo quelli che decidi tu (droghe, equipaggiamento speciale, '
                'concessioni del master).',
                style: TextStyle(color: CprPalette.inkFaint, height: 1.5, fontSize: 12),
              ),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < sheet.statModifiers.length; i++)
                  _ModifierRow(
                    label: sheet.statModifiers[i].target.label,
                    value: sheet.statModifiers[i].value,
                    active: sheet.statModifiers[i].isActive,
                    onToggle: (bool v) => state.mutate((s) => s.statModifiers[i].isActive = v),
                    onValue: (int v) => state.mutate((s) => s.statModifiers[i].value = v),
                    onRemove: () => state.mutate((s) => s.statModifiers.removeAt(i)),
                  ),
                for (int i = 0; i < sheet.skillModifiers.length; i++)
                  _ModifierRow(
                    label: sheet.skillModifiers[i].skill?.name ?? 'Abilita sconosciuta',
                    value: sheet.skillModifiers[i].value,
                    active: sheet.skillModifiers[i].isActive,
                    onToggle: (bool v) => state.mutate((s) => s.skillModifiers[i].isActive = v),
                    onValue: (int v) => state.mutate((s) => s.skillModifiers[i].value = v),
                    onRemove: () => state.mutate((s) => s.skillModifiers.removeAt(i)),
                  ),
              ],
            ),
    );
  }

  Future<void> _addModifier(BuildContext context) async {
    final _ModifierDraft? draft = await showDialog<_ModifierDraft>(
      context: context,
      builder: (BuildContext context) => const _AddModifierDialog(),
    );
    if (draft == null) return;

    state.mutate((s) {
      final Stat? stat = draft.stat;
      final Skill? skill = draft.skill;
      if (stat != null) {
        s.statModifiers.add(StatModifier(target: stat, value: draft.value));
      } else if (skill != null) {
        s.skillModifiers.add(SkillModifier(skillId: skill.id, value: draft.value));
      }
    });
  }
}

class _ModifierRow extends StatelessWidget {
  const _ModifierRow({
    required this.label,
    required this.value,
    required this.active,
    required this.onToggle,
    required this.onValue,
    required this.onRemove,
  });

  final String label;
  final int value;
  final bool active;
  final ValueChanged<bool> onToggle;
  final ValueChanged<int> onValue;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: CprType.body.copyWith(
                color: active ? CprPalette.ink : CprPalette.inkFaint,
                fontSize: 13,
              ),
            ),
          ),
          TechSegmented<bool>(
            value: active,
            items: const <bool>[true, false],
            labelOf: (bool v) => v ? 'Attiva' : 'Spenta',
            accent: CprPalette.cyan,
            onChanged: onToggle,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: TechField(
              label: '',
              value: '$value',
              numeric: true,
              onChanged: (String v) => onValue(int.tryParse(v) ?? 0),
            ),
          ),
          const SizedBox(width: 6),
          TechButton(
            label: '',
            icon: Icons.delete_outline,
            variant: TechButtonVariant.danger,
            compact: true,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}

class _ModifierDraft {
  const _ModifierDraft({this.stat, this.skill, required this.value});

  final Stat? stat;
  final Skill? skill;
  final int value;
}

class _AddModifierDialog extends StatefulWidget {
  const _AddModifierDialog();

  @override
  State<_AddModifierDialog> createState() => _AddModifierDialogState();
}

class _AddModifierDialogState extends State<_AddModifierDialog> {
  bool _isStat = true;
  Stat _stat = Stat.intelligence;
  Skill _skill = Skill.perception;
  int _value = 1;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CprPalette.surface,
      shape: const RoundedRectangleBorder(),
      child: SizedBox(
        width: 460,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('NUOVA CORREZIONE', style: CprType.label.copyWith(color: CprPalette.yellow)),
              const SizedBox(height: 16),
              TechSegmented<bool>(
                value: _isStat,
                items: const <bool>[true, false],
                labelOf: (bool v) => v ? 'Caratteristica' : 'Abilita',
                accent: CprPalette.cyan,
                onChanged: (bool v) => setState(() => _isStat = v),
              ),
              const SizedBox(height: 14),
              if (_isStat)
                TechDropdown<Stat>(
                  label: 'Caratteristica',
                  value: _stat,
                  items: Stat.values,
                  labelOf: (Stat s) => s.label,
                  onChanged: (Stat s) => setState(() => _stat = s),
                )
              else
                TechDropdown<Skill>(
                  label: 'Abilita',
                  value: _skill,
                  items: Skill.values,
                  labelOf: (Skill s) => s.name,
                  onChanged: (Skill s) => setState(() => _skill = s),
                ),
              const SizedBox(height: 14),
              TechNumberStepper(
                label: 'Valore della correzione',
                value: _value,
                min: -10,
                max: 10,
                accent: CprPalette.cyan,
                onChanged: (int v) => setState(() => _value = v),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TechButton(
                    label: 'Annulla',
                    variant: TechButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: 'Aggiungi',
                    variant: TechButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(
                      _ModifierDraft(
                        stat: _isStat ? _stat : null,
                        skill: _isStat ? null : _skill,
                        value: _value,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gestione delle competenze (specializzazioni delle abilita' master).
class _ProficienciesPanel extends StatelessWidget {
  const _ProficienciesPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sheet = state.sheet!;

    return ChamferPanel(
      title: 'Competenze',
      accent: CprPalette.cyan,
      trailing: TechButton(
        label: 'Nuova competenza',
        icon: Icons.add,
        variant: TechButtonVariant.ghost,
        compact: true,
        onPressed: () => _add(context),
      ),
      child: sheet.proficiencies.isEmpty
          ? const TechWell(
              child: Text(
                'Nessuna competenza.\n'
                'Musica, Linguaggio, Scienza e Conoscenza della Zona funzionano per '
                'specializzazioni: "Chitarra", "Giapponese", "Farmacologia", "Watson".',
                style: TextStyle(color: CprPalette.inkFaint, height: 1.5, fontSize: 12),
              ),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < sheet.proficiencies.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 150,
                          child: Text(
                            sheet.proficiencies[i].masterSkill?.name ?? 'Abilita sconosciuta',
                            style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                          ),
                        ),
                        Expanded(
                          child: TechField(
                            label: '',
                            value: sheet.proficiencies[i].name,
                            hint: 'Nome della competenza',
                            onChanged: (String v) =>
                                state.mutate((s) => s.proficiencies[i].name = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 110,
                          child: TechNumberStepper(
                            label: '',
                            value: sheet.proficiencies[i].level,
                            max: 10,
                            compact: true,
                            accent: CprPalette.cyan,
                            onChanged: (int v) =>
                                state.mutate((s) => s.proficiencies[i].level = v),
                          ),
                        ),
                        const SizedBox(width: 6),
                        TechButton(
                          label: '',
                          icon: Icons.delete_outline,
                          variant: TechButtonVariant.danger,
                          compact: true,
                          onPressed: () => state.mutate((s) => s.proficiencies.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _add(BuildContext context) async {
    final _ProficiencyDraft? draft = await showDialog<_ProficiencyDraft>(
      context: context,
      builder: (BuildContext context) => const _AddProficiencyDialog(),
    );
    if (draft == null) return;

    state.mutate((s) {
      s.proficiencies.add(
        Proficiency(
          id: 'prof-${DateTime.now().microsecondsSinceEpoch}',
          masterSkillId: draft.master.id,
          name: draft.name,
        ),
      );
    });
  }
}

class _ProficiencyDraft {
  const _ProficiencyDraft({required this.master, required this.name});

  final Skill master;
  final String name;
}

class _AddProficiencyDialog extends StatefulWidget {
  const _AddProficiencyDialog();

  @override
  State<_AddProficiencyDialog> createState() => _AddProficiencyDialogState();
}

class _AddProficiencyDialogState extends State<_AddProficiencyDialog> {
  Skill _master = Skill.masterSkills.first;
  String _name = '';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CprPalette.surface,
      shape: const RoundedRectangleBorder(),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text('NUOVA COMPETENZA', style: CprType.label.copyWith(color: CprPalette.cyan)),
              const SizedBox(height: 16),
              TechDropdown<Skill>(
                label: 'Abilita master',
                value: _master,
                items: Skill.masterSkills,
                labelOf: (Skill s) => s.name,
                accent: CprPalette.cyan,
                onChanged: (Skill s) => setState(() => _master = s),
              ),
              const SizedBox(height: 14),
              TechField(
                label: 'Specializzazione',
                value: _name,
                hint: 'Es. Chitarra, Giapponese, Farmacologia',
                accent: CprPalette.cyan,
                onChanged: (String v) => setState(() => _name = v),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TechButton(
                    label: 'Annulla',
                    variant: TechButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: 'Aggiungi',
                    variant: TechButtonVariant.primary,
                    onPressed: _name.trim().isEmpty
                        ? null
                        : () => Navigator.of(context).pop(
                              _ProficiencyDraft(master: _master, name: _name.trim()),
                            ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
