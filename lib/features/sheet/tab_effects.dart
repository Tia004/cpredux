import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/effects.dart';
import '../../domain/enums.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import 'editors.dart';

class EffectsTab extends StatelessWidget {
  const EffectsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet!;
    final List<Effect> active = sheet.effects.where((Effect e) => e.isActive).toList();
    final List<Effect> archived = sheet.effects.where((Effect e) => !e.isActive).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChamferPanel(
            title: 'Effetti attivi',
            accent: CprPalette.magenta,
            trailing: TechButton(
              label: 'Nuovo effetto',
              icon: Icons.add,
              variant: TechButtonVariant.primary,
              compact: true,
              onPressed: () async {
                final Effect? effect = await showEffectEditor(context);
                if (effect != null) {
                  state.mutate((s) => s.effects.add(effect));
                }
              },
            ),
            child: active.isEmpty
                ? const TechWell(
                    child: Text(
                      'Nessun effetto attivo.\n'
                      'Ferite, droghe, malattie e condizioni: ogni effetto attivo incide sui '
                      'Punti Vita, sul carico e sulle caratteristiche, e lo vedi nel totale.',
                      style: TextStyle(color: CprPalette.inkFaint, height: 1.5, fontSize: 12),
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final Effect effect in active)
                        _EffectRow(
                          effect: effect,
                          onToggle: () => state.mutate((s) {
                            s.effects
                                .firstWhere((Effect e) => e.id == effect.id)
                                .isActive = false;
                          }),
                          onEdit: () async {
                            final Effect? updated =
                                await showEffectEditor(context, existing: effect);
                            if (updated != null) {
                              state.mutate((s) {
                                final int index =
                                    s.effects.indexWhere((Effect e) => e.id == effect.id);
                                if (index >= 0) s.effects[index] = updated;
                              });
                            }
                          },
                          onDelete: () => _delete(context, state, effect),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          ChamferPanel(
            title: 'Archivio',
            accent: CprPalette.inkFaint,
            trailing: Text(
              'effetti conclusi, non piu\' attivi',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            ),
            child: archived.isEmpty
                ? const TechWell(
                    child: Text(
                      'Nessun effetto archiviato.\n'
                      'Un effetto che guarisce non viene cancellato: viene disattivato e '
                      'resta qui, cosi\' il master puo\' ricostruire cosa e\' successo.',
                      style: TextStyle(color: CprPalette.inkFaint, height: 1.5, fontSize: 12),
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final Effect effect in archived)
                        _EffectRow(
                          effect: effect,
                          onToggle: () => state.mutate((s) {
                            s.effects
                                .firstWhere((Effect e) => e.id == effect.id)
                                .isActive = true;
                          }),
                          onEdit: () async {
                            final Effect? updated =
                                await showEffectEditor(context, existing: effect);
                            if (updated != null) {
                              state.mutate((s) {
                                final int index =
                                    s.effects.indexWhere((Effect e) => e.id == effect.id);
                                if (index >= 0) s.effects[index] = updated;
                              });
                            }
                          },
                          onDelete: () => _delete(context, state, effect),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(BuildContext context, AppState state, Effect effect) async {
    final bool ok = await showTechConfirm(
      context,
      title: 'Eliminare l\'effetto?',
      message: '${effect.name} verra\' eliminato definitivamente.\n\n'
          'Se e\' solo concluso, disattivalo invece: resta in archivio e il master '
          'puo\' ancora ricostruire cosa e\' successo in sessione.',
      confirmLabel: 'Elimina',
      danger: true,
    );
    if (ok) {
      state.mutate((s) => s.effects.removeWhere((Effect e) => e.id == effect.id));
    }
  }
}

class _EffectRow extends StatefulWidget {
  const _EffectRow({
    required this.effect,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Effect effect;
  final VoidCallback onToggle;
  final Future<void> Function() onEdit;
  final VoidCallback onDelete;

  @override
  State<_EffectRow> createState() => _EffectRowState();
}

class _EffectRowState extends State<_EffectRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Effect effect = widget.effect;
    final List<String> impacts = <String>[
      if (effect.lifeEffect != 0) 'PV ${effect.lifeEffect > 0 ? '+' : ''}${effect.lifeEffect}',
      if (effect.lifePercentEffect != 0)
        'PV ${effect.lifePercentEffect > 0 ? '+' : ''}${effect.lifePercentEffect}%',
      if (effect.loadEffect != 0) 'Carico ${effect.loadEffect > 0 ? '+' : ''}${effect.loadEffect} kg',
      if (effect.loadPercentEffect != 0)
        'Carico ${effect.loadPercentEffect > 0 ? '+' : ''}${effect.loadPercentEffect}%',
      for (final dynamic m in effect.statModifiers)
        '${m.target.label} ${m.value > 0 ? '+' : ''}${m.value}',
      for (final dynamic m in effect.skillModifiers)
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
              left: BorderSide(
                color: effect.isActive ? CprPalette.magenta : CprPalette.hairline,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            effect.name,
                            overflow: TextOverflow.ellipsis,
                            style: CprType.body.copyWith(
                              color: effect.isActive ? CprPalette.ink : CprPalette.inkMuted,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (effect.isLethal == EffectKnowledge.yes) ...<Widget>[
                          const SizedBox(width: 7),
                          Tooltip(
                            message: 'Potenzialmente letale',
                            child: Icon(Icons.dangerous_outlined, size: 12, color: CprPalette.danger),
                          ),
                        ],
                      ],
                    ),
                    if (effect.duration.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        'Durata: ${effect.duration}',
                        style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
                      ),
                    ],
                    if (impacts.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(
                        impacts.join('  ·  '),
                        style: CprType.caption.copyWith(
                          color: CprPalette.magenta,
                          fontFamilyFallback: CprType.monoFamily,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _KnowledgeChip(label: 'Curabile', value: effect.isCurable),
              const SizedBox(width: 6),
              _KnowledgeChip(label: 'Trattabile', value: effect.isTreatable),
              const SizedBox(width: 8),
              TechButton(
                label: effect.isActive ? 'Attivo' : 'Archiviato',
                icon: effect.isActive ? Icons.toggle_on : Icons.toggle_off,
                variant: effect.isActive ? TechButtonVariant.primary : TechButtonVariant.ghost,
                compact: true,
                onPressed: widget.onToggle,
              ),
              const SizedBox(width: 6),
              TechButton(
                label: '',
                icon: Icons.delete_outline,
                variant: TechButtonVariant.danger,
                compact: true,
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostra uno dei tre stati di conoscenza.
///
/// "Sconosciuto" e' reso in modo diverso da "No": confonderli cambierebbe il
/// significato clinico dell'effetto per il master, che e' esattamente
/// l'informazione che sta cercando in questa schermata.
class _KnowledgeChip extends StatelessWidget {
  const _KnowledgeChip({required this.label, required this.value});

  final String label;
  final EffectKnowledge value;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (value) {
      EffectKnowledge.yes => CprPalette.success,
      EffectKnowledge.no => CprPalette.inkFaint,
      EffectKnowledge.unknown => CprPalette.warning,
    };
    final String text = switch (value) {
      EffectKnowledge.yes => 'Si',
      EffectKnowledge.no => 'No',
      EffectKnowledge.unknown => '?',
    };

    return Tooltip(
      message: '$label: ${value.label}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 7.5),
          ),
          const SizedBox(height: 1),
          Container(
            width: 30,
            padding: const EdgeInsets.symmetric(vertical: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: CprPalette.veil(color, 0.6)),
              color: CprPalette.veil(color, 0.08),
            ),
            child: Text(text, style: CprType.label.copyWith(color: color, fontSize: 9)),
          ),
        ],
      ),
    );
  }
}
