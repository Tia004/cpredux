import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/stats.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_button.dart';

/// I dati raccolti dal wizard di creazione (o modifica) scheda.
class SheetSetup {
  SheetSetup({
    required this.name,
    this.tag = '',
    this.playerName = '',
    this.role = '',
    this.roleAbility = '',
    this.roleRank = '',
    this.aliases = '',
    this.reputation = '',
    this.gameDate = '',
    Map<Stat, int>? statBase,
  }) : statBase = statBase ?? <Stat, int>{for (final Stat s in Stat.values) s: 1};

  String name;
  String tag;
  String playerName;
  String role;
  String roleAbility;
  String roleRank;
  String aliases;
  String reputation;
  String gameDate;
  Map<Stat, int> statBase;
}

/// Apre il wizard di creazione (o modifica) della scheda.
///
/// [existingSetup] != null indica modifica: i campi sono precompilati.
/// Restituisce un [SheetSetup] se l'utente conferma, null se annulla.
Future<SheetSetup?> showSheetWizard(
  BuildContext context, {
  SheetSetup? existingSetup,
  bool editMode = false,
}) {
  return showDialog<SheetSetup>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    barrierDismissible: false,
    builder: (BuildContext context) => _SheetWizard(
      setup: existingSetup ?? SheetSetup(name: ''),
      editMode: editMode,
    ),
  );
}

class _SheetWizard extends StatefulWidget {
  const _SheetWizard({required this.setup, required this.editMode});

  final SheetSetup setup;
  final bool editMode;

  @override
  State<_SheetWizard> createState() => _SheetWizardState();
}

class _SheetWizardState extends State<_SheetWizard> {
  late final SheetSetup _s = SheetSetup(
    name: widget.setup.name,
    tag: widget.setup.tag,
    playerName: widget.setup.playerName,
    role: widget.setup.role,
    roleAbility: widget.setup.roleAbility,
    roleRank: widget.setup.roleRank,
    aliases: widget.setup.aliases,
    reputation: widget.setup.reputation,
    gameDate: widget.setup.gameDate,
    statBase: Map<Stat, int>.from(widget.setup.statBase),
  );

  /// Punti spesi: in CP RED si distribuiscono 62 punti tra le 10 statistiche,
  /// ognuna va da 2 a 8 (tranne Fortuna che va da 2 a 8).
  int get _pointsSpent => _s.statBase.values.fold(0, (int a, int b) => a + b);
  static const int _totalPoints = 62;

  bool get _canConfirm => _s.name.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final String title = widget.editMode ? 'Modifica scheda' : 'Nuova scheda';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 660),
        child: TechBackground(
          gridSize: 26,
          showVignette: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CprPalette.surface,
              border: Border.all(color: CprPalette.yellow.withValues(alpha: 0.55)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // --- Intestazione ---
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CprPalette.hairline)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(width: 3, height: 15, color: CprPalette.yellow),
                      const SizedBox(width: 10),
                      Text(
                        title.toUpperCase(),
                        style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        'Tutti i campi sono facoltativi tranne il nome',
                        style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                      ),
                    ],
                  ),
                ),

                // --- Corpo scrollabile ---
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Sezione: Identita'
                        _SectionLabel('Identita'),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TechField(
                                label: 'Nome della scheda *',
                                value: _s.name,
                                hint: 'Il nome del file',
                                accent: CprPalette.yellow,
                                onChanged: (String v) => setState(() => _s.name = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TechField(
                                label: 'Nome del personaggio',
                                value: _s.tag,
                                hint: 'Come ti chiamano in strada',
                                onChanged: (String v) => setState(() => _s.tag = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TechField(
                                label: 'Giocatore',
                                value: _s.playerName,
                                hint: 'Il tuo nome',
                                onChanged: (String v) => setState(() => _s.playerName = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TechField(
                                label: 'Soprannomi',
                                value: _s.aliases,
                                hint: 'Separati da virgola',
                                onChanged: (String v) => setState(() => _s.aliases = v),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        _SectionLabel('Ruolo'),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              flex: 3,
                              child: _RoleSelector(
                                value: _s.role,
                                onChanged: (String v) => setState(() => _s.role = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: TechField(
                                label: 'Abilita di ruolo',
                                value: _s.roleAbility,
                                onChanged: (String v) => setState(() => _s.roleAbility = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TechField(
                                label: 'Rango',
                                value: _s.roleRank,
                                numeric: true,
                                onChanged: (String v) => setState(() => _s.roleRank = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TechField(
                                label: 'Punti reputazione',
                                value: _s.reputation,
                                onChanged: (String v) => setState(() => _s.reputation = v),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TechField(
                                label: 'Data in gioco',
                                value: _s.gameDate,
                                hint: 'gg/mm/aaaa',
                                onChanged: (String v) => setState(() => _s.gameDate = v),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
                        _SectionLabel('Caratteristiche'),
                        const SizedBox(height: 4),
                        Row(
                          children: <Widget>[
                            Text(
                              'Distribuisci $_pointsSpent / $_totalPoints punti (da 2 a 8 ciascuna)',
                              style: CprType.caption.copyWith(
                                color: _pointsSpent == _totalPoints
                                    ? CprPalette.success
                                    : _pointsSpent > _totalPoints
                                        ? CprPalette.danger
                                        : CprPalette.inkMuted,
                              ),
                            ),
                            const Spacer(),
                            TechButton(
                              label: 'Reset',
                              icon: Icons.restart_alt,
                              variant: TechButtonVariant.ghost,
                              compact: true,
                              onPressed: () => setState(() {
                                for (final Stat s in Stat.values) {
                                  _s.statBase[s] = 1;
                                }
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _StatGrid(
                          statBase: _s.statBase,
                          onChanged: (Stat stat, int value) => setState(() => _s.statBase[stat] = value),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Azioni ---
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: CprPalette.hairline)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TechButton(
                        label: 'Annulla',
                        variant: TechButtonVariant.ghost,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 10),
                      TechButton(
                        label: widget.editMode ? 'Applica' : 'Crea scheda',
                        icon: widget.editMode ? Icons.check : Icons.add,
                        variant: TechButtonVariant.primary,
                        onPressed: _canConfirm ? () => Navigator.of(context).pop(_s) : null,
                      ),
                    ],
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 10.5),
    );
  }
}

/// Selettore di ruolo: pulsanti chip per i 10 ruoli di CP RED.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const List<String> _roles = <String>[
    'Fixer', 'Lawman', 'Media', 'Medtech', 'Netrunner',
    'Nomade', 'Rockerboy', 'Solo', 'Tech', 'Exec',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('RUOLO', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: <Widget>[
            for (final String role in _roles)
              _RoleChip(
                label: role,
                selected: value.toLowerCase() == role.toLowerCase(),
                onTap: () => onChanged(
                  value.toLowerCase() == role.toLowerCase() ? '' : role,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.selected, required this.onTap});

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
          duration: CprMotion.fast,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(CprPalette.yellow, 0.15) : CprPalette.surfaceSunken,
            border: Border.all(
              color: selected ? CprPalette.yellow : CprPalette.hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(
              fontSize: 9.5,
              color: selected ? CprPalette.yellow : CprPalette.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Griglia per le 10 caratteristiche, ciascuna con uno stepper compatto.
class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.statBase, required this.onChanged});

  final Map<Stat, int> statBase;
  final void Function(Stat, int) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final Stat stat in Stat.values)
          SizedBox(
            width: 130,
            child: _StatStepper(
              stat: stat,
              value: statBase[stat] ?? 1,
              onChanged: (int v) => onChanged(stat, v),
            ),
          ),
      ],
    );
  }
}

class _StatStepper extends StatelessWidget {
  const _StatStepper({required this.stat, required this.value, required this.onChanged});

  final Stat stat;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(stat.short, style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 9)),
                Text(stat.label, style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 10)),
              ],
            ),
          ),
          _MiniButton(
            icon: Icons.remove,
            enabled: value > 1,
            onTap: () => onChanged((value - 1).clamp(1, Stat.max)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '$value',
              style: CprType.numeral.copyWith(
                fontSize: 18,
                color: value <= 1 ? CprPalette.inkFaint : CprPalette.ink,
              ),
            ),
          ),
          _MiniButton(
            icon: Icons.add,
            enabled: value < Stat.max,
            onTap: () => onChanged((value + 1).clamp(1, Stat.max)),
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
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: enabled ? CprPalette.veil(CprPalette.yellow, 0.10) : Colors.transparent,
            border: Border.all(color: enabled ? CprPalette.yellow : CprPalette.hairline),
          ),
          child: Icon(icon, size: 13, color: enabled ? CprPalette.yellow : CprPalette.inkFaint),
        ),
      ),
    );
  }
}
