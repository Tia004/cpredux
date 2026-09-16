import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design/palette.dart';
import '../design/typography.dart';
import '../domain/catalog_item.dart';
import '../domain/enums.dart';
import '../domain/items.dart';
import '../domain/rules.dart';
import '../domain/skills.dart';
import 'dice_3d_table.dart';
import 'tech_button.dart';

/// Modalità operativa per il lancio di dadi interattivo in stile gestionale Cyberpunk.
enum RollMode {
  skill,
  attack,
  damage,
}

/// Dialog modale con visualizzatore 3D, fisica di rotazione, calcolo danni e ablazione.
Future<void> showCombatOrSkillRollDialog(
  BuildContext context, {
  required String title,
  required DiceType die,
  required int count,
  int modifier = 0,
  String modifierLabel = '',
  Skill? skill,
  WeaponData? weapon,
  ResolvedItem? item,
  VoidCallback? onAmmoChanged,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.85),
    builder: (BuildContext ctx) => _CombatRollDialogContent(
      title: title,
      initialDie: die,
      initialCount: count,
      initialModifier: modifier,
      modifierLabel: modifierLabel,
      skill: skill,
      weapon: weapon,
      item: item,
      onAmmoChanged: onAmmoChanged,
    ),
  );
}

class _CombatRollDialogContent extends StatefulWidget {
  const _CombatRollDialogContent({
    required this.title,
    required this.initialDie,
    required this.initialCount,
    required this.initialModifier,
    required this.modifierLabel,
    this.skill,
    this.weapon,
    this.item,
    this.onAmmoChanged,
  });

  final String title;
  final DiceType initialDie;
  final int initialCount;
  final int initialModifier;
  final String modifierLabel;
  final Skill? skill;
  final WeaponData? weapon;
  final ResolvedItem? item;
  final VoidCallback? onAmmoChanged;

  @override
  State<_CombatRollDialogContent> createState() => _CombatRollDialogContentState();
}

class _CombatRollDialogContentState extends State<_CombatRollDialogContent> {
  final math.Random _rng = math.Random();

  late DiceType _currentDie;
  late int _diceCount;
  late int _modifier;
  late String _currentTitle;
  late String _modLabel;
  bool _isDamageRoll = false;

  late DiceRoll _roll;
  int _revealKey = 0;

  // Calcolo impatto danno
  int _targetSp = 11;
  bool _showImpactCalc = false;

  @override
  void initState() {
    super.initState();
    _currentDie = widget.initialDie;
    _diceCount = widget.initialCount;
    _modifier = widget.initialModifier;
    _currentTitle = widget.title;
    _modLabel = widget.modifierLabel;
    _performRoll();
  }

  void _performRoll() {
    setState(() {
      if (_diceCount == 1) {
        _roll = rollDie(
          _currentDie,
          label: _currentTitle,
          modifier: _modifier,
          random: _rng,
        );
      } else {
        _roll = rollDice(
          _currentDie,
          _diceCount,
          label: _currentTitle,
          modifier: _modifier,
          random: _rng,
        );
      }
      _revealKey++;
    });
  }

  void _switchToDamageRoll() {
    final String dmg = widget.weapon?.damage ?? '2d6';
    // Estrai conteggio dadi da stringhe come "3d6", "4d6"
    final RegExp match = RegExp(r'(\d+)d(\d+)', caseSensitive: false);
    final RegExpMatch? m = match.firstMatch(dmg);
    int count = 3;
    DiceType die = DiceType.d6;
    if (m != null) {
      count = int.tryParse(m.group(1) ?? '3') ?? 3;
      final int faces = int.tryParse(m.group(2) ?? '6') ?? 6;
      die = faces == 10 ? DiceType.d10 : DiceType.d6;
    }

    setState(() {
      _isDamageRoll = true;
      _currentDie = die;
      _diceCount = count;
      _modifier = 0;
      _modLabel = '';
      _currentTitle = 'DANNO: ${widget.item?.name ?? 'Arma'} ($dmg)';
      _showImpactCalc = true;
      _performRoll();
    });
  }

  void _fireAmmo(AppState state, int count) {
    final ResolvedItem? it = widget.item;
    if (it == null) return;
    state.mutate((s) {
      final int idx = s.inventory.indexWhere((e) => e.id == it.entry.id);
      if (idx >= 0) {
        final current = s.inventory[idx].currentAmmo;
        s.inventory[idx].currentAmmo = math.max(0, current - count);
      }
    });
    widget.onAmmoChanged?.call();
    setState(() {});
  }

  void _reloadAmmo(AppState state) {
    final ResolvedItem? it = widget.item;
    final WeaponData? w = widget.weapon;
    if (it == null || w == null) return;
    state.mutate((s) {
      final int idx = s.inventory.indexWhere((e) => e.id == it.entry.id);
      if (idx >= 0) {
        s.inventory[idx].currentAmmo = w.maxAmmo;
      }
    });
    widget.onAmmoChanged?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final bool isCriticalHit = _roll.isCritical;
    final bool isFumble = _roll.isFumble;

    // Regola CP Red su dadi danno: 2 o più 6 provocano Ferita Grave (+5 bonus PF)
    final int sixesCount = _isDamageRoll
        ? _roll.individualResults.where((r) => r == 6).length
        : 0;
    final bool hasCritInjury = sixesCount >= 2;

    // Calcolo impatto su armatura bersaglio
    final int rawDamage = _roll.result;
    final int penetratingDamage = math.max(0, rawDamage - _targetSp);
    final bool armorPenetrated = rawDamage > _targetSp;
    final int totalDamageToTarget = penetratingDamage + (hasCritInjury ? 5 : 0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 680,
        decoration: BoxDecoration(
          color: CprPalette.surfaceRaised,
          border: Border.all(
            color: isCriticalHit || hasCritInjury
                ? CprPalette.cyan
                : isFumble
                    ? CprPalette.danger
                    : CprPalette.hairline,
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: (isCriticalHit || hasCritInjury
                      ? CprPalette.cyan
                      : isFumble
                          ? CprPalette.danger
                          : CprPalette.voidBlack)
                  .withValues(alpha: 0.35),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Intestazione Cyberpunk
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                border: Border(bottom: BorderSide(color: CprPalette.hairline)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    _isDamageRoll ? Icons.local_fire_department : Icons.sports_kabaddi,
                    color: _isDamageRoll ? CprPalette.danger : CprPalette.cyan,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _currentTitle.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: CprType.label.copyWith(
                        color: CprPalette.ink,
                        letterSpacing: 1.4,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: 18, color: CprPalette.inkFaint),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Tavolo da gioco 3D con dadi
            Padding(
              padding: const EdgeInsets.all(12),
              child: Dice3DTable(
                die: _currentDie,
                results: _roll.individualResults,
                total: _roll.total,
                label: _currentTitle,
                modifier: _modifier,
                isCritical: isCriticalHit,
                isFumble: isFumble,
                revealKey: _revealKey,
                tableHeight: 250,
              ),
            ),

            // Banner Critico / Fumble / Ferita Grave
            if (isCriticalHit)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.cyan, 0.15),
                  border: Border.all(color: CprPalette.cyan),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.auto_awesome, color: CprPalette.cyan, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'CRITICO NATURALE! (10 sul D10) — Esplosione di dado!',
                      style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 11),
                    ),
                  ],
                ),
              ),

            if (isFumble)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.danger, 0.15),
                  border: Border.all(color: CprPalette.danger),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded, color: CprPalette.danger, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'FALLIMENTO CRITICO! (1 sul D10) — Possibile inceppamento!',
                      style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 11),
                    ),
                  ],
                ),
              ),

            if (hasCritInjury)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.magenta, 0.2),
                  border: Border.all(color: CprPalette.magenta),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.coronavirus_outlined, color: CprPalette.magenta, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'FERITA GRAVE INFLITTA! (Almeno due 6) → Bersaglio subisce +5 PF e un Trauma Critico!',
                        style: CprType.label.copyWith(color: CprPalette.magenta, fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ),

            // Dettaglio punteggi
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: <Widget>[
                  Text(
                    'Dettaglio: ',
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                  ),
                  Text(
                    _diceCount == 1
                        ? '${_currentDie.label} [${_roll.result}]'
                        : '$_diceCount${_currentDie.label} [${_roll.individualResults.join(', ')}] = ${_roll.result}',
                    style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12),
                  ),
                  if (_modifier != 0) ...<Widget>[
                    Text(
                      ' ${_modifier > 0 ? '+' : '-'} ${_modifier.abs()} ($_modLabel)',
                      style: CprType.body.copyWith(color: CprPalette.yellow, fontSize: 12),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'TOTALE: ',
                    style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 11),
                  ),
                  Text(
                    '${_roll.total}',
                    style: CprType.numeral.copyWith(
                      color: isCriticalHit ? CprPalette.cyan : isFumble ? CprPalette.danger : CprPalette.yellow,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Pannello calcolatore impatto danno (se tiro di danno)
            if (_showImpactCalc) ...<Widget>[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CprPalette.surfaceSunken,
                  border: Border.all(color: CprPalette.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'CALCOLO IMPATTO SU ARMATURA (SP):',
                          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                        ),
                        const Spacer(),
                        Text(
                          'SP Bersaglio:',
                          style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                        ),
                        const SizedBox(width: 6),
                        _SpStepper(
                          sp: _targetSp,
                          onChanged: (int val) => setState(() => _targetSp = val),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        Icon(
                          armorPenetrated ? Icons.check_circle_outline : Icons.shield_outlined,
                          size: 15,
                          color: armorPenetrated ? CprPalette.danger : CprPalette.cyan,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            armorPenetrated
                                ? 'ARMATURA PENETRATA! Il danno supera SP $_targetSp. L\'armatura si abla di 1 SP (nuovo SP: ${_targetSp - 1}).'
                                : 'COLPO DEVIATO: Il danno ($rawDamage) non supera SP $_targetSp. Nessun danno ai PF o ablazione.',
                            style: CprType.caption.copyWith(
                              color: armorPenetrated ? CprPalette.danger : CprPalette.cyan,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                        if (armorPenetrated) ...<Widget>[
                          const SizedBox(width: 8),
                          Text(
                            'PF DANNO: $totalDamageToTarget',
                            style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Gestione munizioni (se arma)
            if (widget.weapon != null && widget.item != null) ...<Widget>[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CprPalette.surfaceSunken,
                  border: Border.all(color: CprPalette.hairline),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.format_list_numbered, size: 14, color: CprPalette.inkFaint),
                    const SizedBox(width: 8),
                    Text(
                      'Munizioni:',
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.item!.entry.currentAmmo} / ${widget.weapon!.maxAmmo}',
                      style: CprType.numeralSmall.copyWith(
                        color: widget.item!.entry.currentAmmo == 0 ? CprPalette.danger : CprPalette.cyan,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    TechButton(
                      label: '-1 Colpo',
                      icon: Icons.flash_on,
                      compact: true,
                      variant: TechButtonVariant.ghost,
                      onPressed: widget.item!.entry.currentAmmo > 0
                          ? () => _fireAmmo(state, 1)
                          : null,
                    ),
                    if (widget.weapon!.rof > 1) ...<Widget>[
                      const SizedBox(width: 6),
                      TechButton(
                        label: 'Raffica (-${widget.weapon!.rof})',
                        icon: Icons.double_arrow,
                        compact: true,
                        variant: TechButtonVariant.ghost,
                        onPressed: widget.item!.entry.currentAmmo >= widget.weapon!.rof
                            ? () => _fireAmmo(state, widget.weapon!.rof)
                            : null,
                      ),
                    ],
                    const SizedBox(width: 6),
                    TechButton(
                      label: 'Ricarica',
                      icon: Icons.sync,
                      compact: true,
                      variant: TechButtonVariant.ghost,
                      onPressed: () => _reloadAmmo(state),
                    ),
                  ],
                ),
              ),
            ],

            // Bottoni di controllo
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: <Widget>[
                  TechButton(
                    label: 'Ritira dado',
                    icon: Icons.refresh,
                    variant: TechButtonVariant.ghost,
                    onPressed: _performRoll,
                  ),
                  const SizedBox(width: 10),
                  if (!_isDamageRoll && widget.weapon != null) ...<Widget>[
                    TechButton(
                      label: 'Tira Danno (${widget.weapon!.damage.isNotEmpty ? widget.weapon!.damage : '3d6'})',
                      icon: Icons.local_fire_department,
                      variant: TechButtonVariant.primary,
                      onPressed: _switchToDamageRoll,
                    ),
                  ],
                  const Spacer(),
                  TechButton(
                    label: 'Condividi al Tavolo',
                    icon: Icons.wifi,
                    variant: TechButtonVariant.ghost,
                    compact: true,
                    onPressed: () {
                      state.sendRollToSession(
                        label: _currentTitle,
                        detail: _diceCount == 1
                            ? '1${_currentDie.label} + $_modifier'
                            : '$_diceCount${_currentDie.label}',
                        total: _roll.total,
                        isCritical: isCriticalHit,
                        isFumble: isFumble,
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tiro inviato alla sessione: $_currentTitle -> ${_roll.total}'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  TechButton(
                    label: 'Chiudi',
                    variant: TechButtonVariant.ghost,
                    compact: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpStepper extends StatelessWidget {
  const _SpStepper({required this.sp, required this.onChanged});

  final int sp;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          InkWell(
            onTap: () => onChanged(math.max(0, sp - 1)),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('-', style: TextStyle(color: CprPalette.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$sp', style: CprType.numeralSmall.copyWith(color: CprPalette.yellow, fontSize: 13)),
          ),
          InkWell(
            onTap: () => onChanged(sp + 1),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('+', style: TextStyle(color: CprPalette.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
