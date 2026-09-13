import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/rarity_color.dart';
import '../../design/typography.dart';
import '../../domain/cyberware.dart';
import '../../domain/enums.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/humanity_gauge.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import 'editors.dart';

class CyberwareTab extends StatelessWidget {
  const CyberwareTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet!;
    final totals = state.totals!;

    final Map<CyberwareCategory, List<Cyberware>> grouped =
        <CyberwareCategory, List<Cyberware>>{};
    for (final Cyberware c in sheet.cyberware) {
      grouped.putIfAbsent(c.category, () => <Cyberware>[]).add(c);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Widget gauge = ChamferPanel(
                title: 'Umanita',
                accent: CprPalette.humanityEroded,
                trailing: Text(
                  '${totals.humanityLost} persi',
                  style: CprType.label.copyWith(color: CprPalette.humanityEroded, fontSize: 9.5),
                ),
                child: Center(
                  child: HumanityGauge(
                    current: sheet.identity.currentHumanity,
                    max: totals.maxHumanity,
                    size: 190,
                  ),
                ),
              );

              final Widget summary = ChamferPanel(
                title: 'Riepilogo impianti',
                accent: CprPalette.magenta,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Il cyberware erode l\'Umanita\' in modo permanente. '
                      'Rimuovere un impianto restituisce i suoi bonus alle caratteristiche '
                      'ma non l\'Umanita\' gia\' spesa: e\' una perdita, non un prestito.',
                      style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        _Tile(
                          label: 'Impianti',
                          value: '${sheet.cyberware.length}',
                          accent: CprPalette.magenta,
                        ),
                        const SizedBox(width: 18),
                        _Tile(
                          label: 'Peso totale',
                          value: '${sheet.cyberware.fold<double>(0, (double a, Cyberware c) => a + c.weight).toStringAsFixed(2)} kg',
                          accent: CprPalette.cyan,
                        ),
                        const SizedBox(width: 18),
                        _Tile(
                          label: 'Costo sostenuto',
                          value: '${sheet.cyberware.fold<int>(0, (int a, Cyberware c) => a + c.cost)}',
                          accent: CprPalette.yellow,
                        ),
                      ],
                    ),
                    if (totals.humanityLost > 0) ...<Widget>[
                      const SizedBox(height: 16),
                      _EmpathyWarning(
                        maxEmpathy: totals.maxEmpathy,
                        humanityLost: totals.humanityLost,
                      ),
                    ],
                  ],
                ),
              );

              if (c.maxWidth < 940) {
                return Column(
                  children: <Widget>[gauge, const SizedBox(height: 16), summary],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 4, child: gauge),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: summary),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (sheet.cyberware.isEmpty)
            ChamferPanel(
              title: 'Impianti installati',
              accent: CprPalette.magenta,
              trailing: _AddButton(onPressed: () => _add(context, state)),
              child: const TechWell(
                child: Text(
                  'Nessun impianto installato.\n'
                  'Aggiungi il cyberware del personaggio: ogni impianto porta con se\' '
                  'il costo in Umanita\' e le correzioni a caratteristiche e abilita\', '
                  'che vengono applicate automaticamente ai totali.',
                  style: TextStyle(color: CprPalette.inkFaint, height: 1.5, fontSize: 12),
                ),
              ),
            )
          else
            for (final CyberwareCategory category in CyberwareCategory.values)
              if (grouped.containsKey(category)) ...<Widget>[
                ChamferPanel(
                  title: category.label,
                  accent: CprPalette.magenta,
                  trailing: Text(
                    '${grouped[category]!.length}',
                    style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (final Cyberware item in grouped[category]!)
                        _CyberwareRow(
                          item: item,
                          onEdit: () async {
                            final Cyberware? updated =
                                await showCyberwareEditor(context, existing: item);
                            if (updated != null) {
                              state.mutate((s) {
                                final int index =
                                    s.cyberware.indexWhere((Cyberware c) => c.id == item.id);
                                if (index >= 0) s.cyberware[index] = updated;
                              });
                            }
                          },
                          onDelete: () async {
                            final bool ok = await showTechConfirm(
                              context,
                              title: 'Rimuovere l\'impianto?',
                              message: '${item.name} verra\' rimosso dalla scheda.\n\n'
                                  'Le correzioni alle caratteristiche e alle abilita\' '
                                  'verranno tolte. L\'Umanita\' persa resta persa.',
                              confirmLabel: 'Rimuovi',
                              danger: true,
                            );
                            if (ok) {
                              state.mutate(
                                (s) => s.cyberware.removeWhere((Cyberware c) => c.id == item.id),
                              );
                            }
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
          if (sheet.cyberware.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: _AddButton(onPressed: () => _add(context, state)),
            ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, AppState state) async {
    final Cyberware? item = await showCyberwareEditor(context);
    if (item != null) {
      state.mutate((s) => s.cyberware.add(item));
    }
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TechButton(
      label: 'Installa impianto',
      icon: Icons.add,
      variant: TechButtonVariant.primary,
      compact: true,
      onPressed: onPressed,
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
        const SizedBox(height: 3),
        Text(value, style: CprType.numeral.copyWith(color: accent, fontSize: 19)),
      ],
    );
  }
}

/// Avviso sull'Empatia.
///
/// La regola e' che l'Umanita' persa abbassa il massimo di Empatia, e sotto una
/// certa soglia il personaggio diventa un PNG. Un'app che mostra solo il numero
/// di Umanita' lascia il giocatore a fare il conto a mente proprio mentre la
/// cosa diventa drammatica: qui il conto e' esplicito.
class _EmpathyWarning extends StatelessWidget {
  const _EmpathyWarning({required this.maxEmpathy, required this.humanityLost});

  final int maxEmpathy;
  final int humanityLost;

  @override
  Widget build(BuildContext context) {
    final bool critical = maxEmpathy <= 2;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CprPalette.veil(critical ? CprPalette.danger : CprPalette.warning, 0.10),
        border: Border.all(
          color: CprPalette.veil(critical ? CprPalette.danger : CprPalette.warning, 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            critical ? Icons.dangerous_outlined : Icons.info_outline,
            size: 15,
            color: critical ? CprPalette.danger : CprPalette.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              critical
                  ? 'Empatia massima $maxEmpathy: sotto la soglia di 2 il personaggio perde '
                      'il controllo e diventa un PNG. Il master dovrebbe esserne consapevole ora, '
                      'non quando succede.'
                  : 'Con $humanityLost punti di Umanita\' persi l\'Empatia massima scende a '
                      '$maxEmpathy. Quando raggiunge 0 il personaggio non e\' piu\' giocabile.',
              style: CprType.caption.copyWith(
                color: critical ? CprPalette.danger : CprPalette.ink,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CyberwareRow extends StatefulWidget {
  const _CyberwareRow({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final Cyberware item;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  @override
  State<_CyberwareRow> createState() => _CyberwareRowState();
}

class _CyberwareRowState extends State<_CyberwareRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Cyberware item = widget.item;
    final List<String> effects = <String>[
      for (final dynamic m in item.statModifiers)
        '${m.target.label} ${m.value > 0 ? '+' : ''}${m.value}',
      for (final dynamic m in item.skillModifiers)
        '${m.skill?.name ?? 'Abilita'} ${m.value > 0 ? '+' : ''}${m.value}',
    ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: _hover ? CprPalette.veil(CprPalette.magenta, 0.06) : null,
            border: Border(
              left: BorderSide(color: CprPalette.veil(item.rarity.color, 0.9), width: 3),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                color: CprPalette.surfaceSunken,
                child: item.imagePath != null && File(item.imagePath!).existsSync()
                    ? Image.file(
                        File(item.imagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.memory,
                          size: 15,
                          color: CprPalette.magenta,
                        ),
                      )
                    : const Icon(Icons.memory, size: 15, color: CprPalette.magenta),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13),
                          ),
                        ),
                        if (item.isFoundational) ...<Widget>[
                          const SizedBox(width: 7),
                          Tooltip(
                            message: 'Impianto fondamentale',
                            child: Icon(
                              Icons.lock_outline,
                              size: 11,
                              color: CprPalette.veil(CprPalette.warning, 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.rarity.label,
                      style: CprType.label.copyWith(color: item.rarity.color, fontSize: 8.5),
                    ),
                    if (effects.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        effects.join('  ·  '),
                        style: CprType.caption.copyWith(
                          color: CprPalette.cyan,
                          fontFamilyFallback: CprType.monoFamily,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('UMANITA', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 8)),
                  Text(
                    '-${item.humanityLost}',
                    style: CprType.numeralSmall.copyWith(
                      color: CprPalette.humanityEroded,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('PESO', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 8)),
                  Text(
                    item.weight.toStringAsFixed(1),
                    style: CprType.numeralSmall.copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text('COSTO', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 8)),
                  Text(
                    '${item.cost}',
                    style: CprType.numeralSmall.copyWith(fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              TechButton(
                label: '',
                icon: Icons.delete_outline,
                variant: TechButtonVariant.danger,
                compact: true,
                onPressed: () => widget.onDelete(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
