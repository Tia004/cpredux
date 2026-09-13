import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../domain/rules.dart';
import '../../domain/skills.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

/// Un tiro finito, come lo mostra il registro.
class RollRecord {
  RollRecord({
    required this.label,
    required this.detail,
    required this.total,
    this.isCritical = false,
    this.isFumble = false,
    required this.at,
  });

  final String label;
  final String detail;
  final int total;
  final bool isCritical;
  final bool isFumble;
  final DateTime at;
}

/// Il tiro di dadi.
///
/// Due cose contano qui, e non sono i dadi: il **risultato grande** e il
/// **registro**. In sessione si tira decine di volte e il master chiede "quanto
/// hai fatto?" due secondi dopo: se il numero precedente e' sparito, il tiro va
/// rifatto. Per questo il risultato resta a schermo finche' non ne arriva un
/// altro, e il registro tiene gli ultimi tiri con ora e dettaglio.
class DiceTab extends StatefulWidget {
  const DiceTab({super.key});

  @override
  State<DiceTab> createState() => _DiceTabState();
}

class _DiceTabState extends State<DiceTab> {
  final math.Random _rng = math.Random();
  final List<RollRecord> _history = <RollRecord>[];

  DiceType _die = DiceType.d10;
  int _count = 1;
  int _modifier = 0;

  RollRecord? _last;
  int _reveal = 0;

  void _rollFree() {
    final DiceRoll roll = _count == 1
        ? rollDie(_die, modifier: _modifier, random: _rng)
        : rollDice(_die, _count, modifier: _modifier, random: _rng);

    final String label = _count == 1 ? _die.label : '$_count${_die.label}';
    final String detail = _modifier == 0
        ? label
        : '$label ${_modifier > 0 ? '+' : '-'} ${_modifier.abs()}';

    setState(() {
      _last = RollRecord(
        label: label,
        detail: detail,
        total: roll.total,
        isCritical: roll.isCritical,
        isFumble: roll.isFumble,
        at: DateTime.now(),
      );
      _history.insert(0, _last!);
      if (_history.length > 40) _history.removeLast();
      // Il contatore serve a far ripartire l'animazione di rivelazione: senza,
      // due tiri con lo stesso totale non farebbero ricomparire nulla e
      // sembrerebbe che il secondo tiro non sia avvenuto.
      _reveal++;
    });
  }

  void _rollSkill(AppState state, Skill skill, SheetTotals totals) {
    final DiceRoll roll = rollSkillCheck(state.sheet!, skill, random: _rng);
    setState(() {
      _last = RollRecord(
        label: skill.name,
        detail: '1d10 + ${totals.statValue(skill.stat)} (${skill.stat.short})'
            ' + ${totals.skillValue(skill)}',
        total: roll.total,
        isCritical: roll.isCritical,
        isFumble: roll.isFumble,
        at: DateTime.now(),
      );
      _history.insert(0, _last!);
      if (_history.length > 40) _history.removeLast();
      _reveal++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet;
    final totals = state.totals;
    if (sheet == null || totals == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1060),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Widget left = Column(
                children: <Widget>[
                  _ResultPanel(last: _last, reveal: _reveal),
                  const SizedBox(height: 14),
                  _RollerPanel(
                    die: _die,
                    count: _count,
                    modifier: _modifier,
                    onDie: (DiceType d) => setState(() => _die = d),
                    onCount: (int v) => setState(() => _count = v),
                    onModifier: (int v) => setState(() => _modifier = v),
                    onRoll: _rollFree,
                  ),
                ],
              );
              final Widget right = Column(
                children: <Widget>[
                  _SkillPanel(
                    totals: totals,
                    onRoll: (Skill s) => _rollSkill(state, s, totals),
                  ),
                  const SizedBox(height: 14),
                  _HistoryPanel(history: _history, onClear: () => setState(() => _history.clear())),
                ],
              );

              if (c.maxWidth < 940) {
                return Column(children: <Widget>[left, const SizedBox(height: 14), right]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: left),
                  const SizedBox(width: 14),
                  Expanded(flex: 6, child: right),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Il risultato, in grande.
class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.last, required this.reveal});

  final RollRecord? last;
  final int reveal;

  @override
  Widget build(BuildContext context) {
    final RollRecord? roll = last;
    final Color accent = roll == null
        ? CprPalette.inkFaint
        : roll.isCritical
            ? CprPalette.success
            : roll.isFumble
                ? CprPalette.danger
                : CprPalette.yellow;

    return ChamferPanel(
      title: 'Ultimo tiro',
      accent: accent,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 128,
            child: Center(
              child: roll == null
                  ? Text(
                      'Nessun tiro',
                      style: CprType.body.copyWith(color: CprPalette.inkFaint),
                    )
                  : TweenAnimationBuilder<double>(
                      key: ValueKey<int>(reveal),
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: CprMotion.slow,
                      curve: CprMotion.enter,
                      builder: (BuildContext context, double t, Widget? child) {
                        return Opacity(
                          opacity: t.clamp(0, 1),
                          child: Transform.scale(
                            // Parte da 0.82 e "assesta": un numero che nasce
                            // fermo sembra un'etichetta, uno che si assesta
                            // sembra il risultato di qualcosa che e' successo.
                            scale: 0.82 + (0.18 * t),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            '${roll.total}',
                            style: CprType.display.copyWith(fontSize: 72, color: accent),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            roll.detail.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: CprType.label.copyWith(color: CprPalette.inkMuted),
                          ),
                          if (roll.isCritical || roll.isFumble) ...<Widget>[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              color: CprPalette.veil(accent, 0.16),
                              child: Text(
                                roll.isCritical ? 'CRITICO' : 'FALLIMENTO CRITICO',
                                style: CprType.label.copyWith(color: accent, fontSize: 10),
                              ),
                            ),
                          ],
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

class _RollerPanel extends StatelessWidget {
  const _RollerPanel({
    required this.die,
    required this.count,
    required this.modifier,
    required this.onDie,
    required this.onCount,
    required this.onModifier,
    required this.onRoll,
  });

  final DiceType die;
  final int count;
  final int modifier;
  final ValueChanged<DiceType> onDie;
  final ValueChanged<int> onCount;
  final ValueChanged<int> onModifier;
  final VoidCallback onRoll;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Tira',
      accent: CprPalette.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final DiceType d in DiceType.values)
                _DieChip(
                  label: d.label,
                  selected: d == die,
                  onTap: () => onDie(d),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TechNumberStepper(
                  label: 'Numero di dadi',
                  value: count,
                  min: 1,
                  max: 20,
                  accent: CprPalette.yellow,
                  onChanged: onCount,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Modificatore',
                  value: modifier,
                  min: -30,
                  max: 30,
                  accent: CprPalette.cyan,
                  onChanged: onModifier,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TechButton(
            label: 'Tira  ${count > 1 ? '$count${die.label}' : die.label}'
                '${modifier == 0 ? '' : modifier > 0 ? ' + $modifier' : ' - ${modifier.abs()}'}',
            icon: Icons.casino_outlined,
            variant: TechButtonVariant.primary,
            onPressed: onRoll,
          ),
        ],
      ),
    );
  }
}

class _DieChip extends StatelessWidget {
  const _DieChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          width: 54,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? CprPalette.veil(CprPalette.yellow, 0.14)
                : CprPalette.surfaceSunken,
            border: Border.all(color: selected ? CprPalette.yellow : CprPalette.hairline),
          ),
          child: Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(
              fontSize: 10.5,
              color: selected ? CprPalette.yellow : CprPalette.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiro di abilita': la parte che fa risparmiare davvero tempo al tavolo.
///
/// Il modificatore non e' chiesto all'utente: viene preso dai totali della
/// scheda, perche' e' esattamente il numero che le persone sbagliano a sommare
/// quando hanno fretta. Il dettaglio sotto il risultato mostra la scomposizione
/// (caratteristica + abilita'), cosi' il master puo' verificarla se vuole.
class _SkillPanel extends StatefulWidget {
  const _SkillPanel({required this.totals, required this.onRoll});

  final SheetTotals totals;
  final void Function(Skill) onRoll;

  @override
  State<_SkillPanel> createState() => _SkillPanelState();
}

class _SkillPanelState extends State<_SkillPanel> {
  String _query = '';
  SkillCategory? _category;

  @override
  Widget build(BuildContext context) {
    final List<Skill> filtered = Skill.values.where((Skill s) {
      if (_category != null && s.category != _category) return false;
      if (_query.isEmpty) return true;
      return s.name.toLowerCase().contains(_query.toLowerCase());
    }).toList();

    return ChamferPanel(
      title: 'Tiro di abilita',
      accent: CprPalette.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TechField(
            label: '',
            value: _query,
            hint: 'Cerca abilita',
            accent: CprPalette.cyan,
            onChanged: (String v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: <Widget>[
              _CategoryChip(
                label: 'Tutte',
                selected: _category == null,
                onTap: () => setState(() => _category = null),
              ),
              for (final SkillCategory c in SkillCategory.values)
                _CategoryChip(
                  label: c.label,
                  selected: _category == c,
                  onTap: () => setState(() => _category = c),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (BuildContext context, int i) {
                final Skill skill = filtered[i];
                final int total = widget.totals.skillCheck(skill);
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => widget.onRoll(skill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              skill.name,
                              overflow: TextOverflow.ellipsis,
                              style: CprType.body.copyWith(fontSize: 13),
                            ),
                          ),
                          Text(
                            skill.stat.short,
                            style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            color: CprPalette.veil(CprPalette.cyan, 0.12),
                            child: Text(
                              '+$total',
                              style: CprType.numeralSmall.copyWith(color: CprPalette.cyan),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.casino_outlined, size: 14, color: CprPalette.inkFaint),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          color: selected ? CprPalette.veil(CprPalette.cyan, 0.14) : CprPalette.surfaceSunken,
          child: Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(
              fontSize: 9,
              color: selected ? CprPalette.cyan : CprPalette.inkFaint,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.history, required this.onClear});

  final List<RollRecord> history;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Registro dei tiri',
      accent: CprPalette.inkMuted,
      trailing: history.isEmpty
          ? null
          : TechButton(
              label: 'Pulisci',
              icon: Icons.delete_sweep_outlined,
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: onClear,
            ),
      child: history.isEmpty
          ? Text(                            "I tiri della sessione compaiono qui, dal piu' recente.",
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: history.length,
                itemBuilder: (BuildContext context, int i) {
                  final RollRecord r = history[i];
                  final Color color = r.isCritical
                      ? CprPalette.success
                      : r.isFumble
                          ? CprPalette.danger
                          : CprPalette.ink;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${r.total}',
                            style: CprType.numeralSmall.copyWith(color: color, fontSize: 15),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${r.label} · ${r.detail}',
                            overflow: TextOverflow.ellipsis,
                            style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                          ),
                        ),
                        Text(
                          _time(r.at),
                          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  static String _time(DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }
}
