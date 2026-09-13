import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/world_map.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_button.dart';

/// Quello che l'utente ha scritto nel dialogo.
class WaypointDraft {
  const WaypointDraft({
    required this.label,
    required this.note,
    required this.kind,
    required this.visibility,
  });

  final String label;
  final String note;
  final WaypointKind kind;
  final WaypointVisibility visibility;
}

/// Editor di un waypoint.
///
/// La visibilita' si sceglie **qui**, al momento in cui si scrive il segno, e
/// non dopo: e' l'informazione che dice se quella nota puo' uscire da questa
/// macchina, e chiederla in un secondo momento significa che l'utente l'ha gia'
/// scritta pensando a se stesso.
Future<WaypointDraft?> showWaypointDialog(
  BuildContext context, {
  required String title,
  WaypointDraft? initial,
  required bool canChooseVisibility,
  String? positionLabel,
}) {
  return showDialog<WaypointDraft>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => _WaypointDialog(
      title: title,
      initial: initial ??
          const WaypointDraft(
            label: '',
            note: '',
            kind: WaypointKind.location,
            visibility: WaypointVisibility.table,
          ),
      canChooseVisibility: canChooseVisibility,
      positionLabel: positionLabel,
    ),
  );
}

class _WaypointDialog extends StatefulWidget {
  const _WaypointDialog({
    required this.title,
    required this.initial,
    required this.canChooseVisibility,
    required this.positionLabel,
  });

  final String title;
  final WaypointDraft initial;
  final bool canChooseVisibility;
  final String? positionLabel;

  @override
  State<_WaypointDialog> createState() => _WaypointDialogState();
}

class _WaypointDialogState extends State<_WaypointDialog> {
  late final TextEditingController _label = TextEditingController(text: widget.initial.label);
  late final TextEditingController _note = TextEditingController(text: widget.initial.note);
  late WaypointKind _kind = widget.initial.kind;
  late WaypointVisibility _visibility = widget.initial.visibility;
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  void _confirm() {
    final String label = _label.text.trim();
    if (label.isEmpty) {
      // Un waypoint senza nome e' un puntino che fra due ore nessuno sapra'
      // spiegare: l'errore si vede subito, non si scopre dopo.
      setState(() => _error = 'Serve un nome: e\' quello che leggerai fra due settimane.');
      return;
    }
    Navigator.of(context).pop(
      WaypointDraft(label: label, note: _note.text.trim(), kind: _kind, visibility: _visibility),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: TechBackground(
          gridSize: 26,
          showVignette: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CprPalette.surface,
              border: Border.all(color: CprPalette.veil(CprPalette.violet, 0.55)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: CprPalette.hairline)),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(width: 3, height: 15, color: CprPalette.violet),
                      const SizedBox(width: 10),
                      Text(
                        widget.title.toUpperCase(),
                        style: CprType.label.copyWith(color: CprPalette.violet, fontSize: 12),
                      ),
                      const Spacer(),
                      if (widget.positionLabel != null)
                        Text(
                          widget.positionLabel!,
                          style: CprType.numeralSmall.copyWith(
                            color: CprPalette.inkFaint,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TechField(
                          label: 'Nome del segno',
                          value: _label.text,
                          hint: 'Imboscata sotto il ponte',
                          accent: CprPalette.violet,
                          onChanged: (String v) {
                            _label.text = v;
                            if (_error != null) setState(() => _error = null);
                          },
                        ),
                        const SizedBox(height: 14),
                        TechTextArea(
                          label: 'Nota',
                          value: _note.text,
                          hint: 'Cosa c\'e\' qui, chi lo sa, cosa serve per entrarci',
                          lines: 3,
                          accent: CprPalette.violet,
                          onChanged: (String v) => _note.text = v,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'CATEGORIA',
                          style: CprType.label.copyWith(color: CprPalette.inkFaint),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (final WaypointKind k in WaypointKind.values)
                              _KindChip(
                                kind: k,
                                selected: k == _kind,
                                onTap: () => setState(() => _kind = k),
                              ),
                          ],
                        ),
                        if (widget.canChooseVisibility) ...<Widget>[
                          const SizedBox(height: 18),
                          Text(
                            'CHI LO VEDE',
                            style: CprType.label.copyWith(color: CprPalette.inkFaint),
                          ),
                          const SizedBox(height: 8),
                          TechSegmented<WaypointVisibility>(
                            value: _visibility,
                            items: WaypointVisibility.values,
                            labelOf: (WaypointVisibility v) => v.label,
                            accent: CprPalette.violet,
                            onChanged: (WaypointVisibility v) => setState(() => _visibility = v),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _visibility == WaypointVisibility.private
                                ? 'Una posizione privata non viene mai trasmessa: nemmeno al tavolo aperto.'
                                : 'Sara\' visibile a chi e\' al tavolo, e verra\' mandata quando il tavolo e\' aperto.',
                            style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                          ),
                        ],
                        if (_error != null) ...<Widget>[
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              const Icon(Icons.warning_amber_rounded, size: 14, color: CprPalette.danger),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: CprType.caption.copyWith(color: CprPalette.ink),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
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
                        label: 'Salva',
                        icon: Icons.check,
                        variant: TechButtonVariant.primary,
                        onPressed: _confirm,
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

class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.selected, required this.onTap});

  final WaypointKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = _kindColor(kind);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(color, 0.16) : CprPalette.surfaceSunken,
            border: Border.all(
              color: selected ? color : CprPalette.hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(_kindIcon(kind), size: 13, color: selected ? color : CprPalette.inkFaint),
              const SizedBox(width: 8),
              Text(
                kind.label.toUpperCase(),
                style: CprType.label.copyWith(
                  fontSize: 9.5,
                  color: selected ? color : CprPalette.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _kindIcon(WaypointKind kind) => switch (kind) {
      WaypointKind.location => Icons.place_outlined,
      WaypointKind.danger => Icons.warning_amber_rounded,
      WaypointKind.person => Icons.person_outline,
      WaypointKind.job => Icons.work_outline,
      WaypointKind.shop => Icons.storefront_outlined,
      WaypointKind.note => Icons.sticky_note_2_outlined,
    };

Color _kindColor(WaypointKind kind) => switch (kind) {
      WaypointKind.location => CprPalette.cyan,
      WaypointKind.danger => CprPalette.danger,
      WaypointKind.person => CprPalette.violet,
      WaypointKind.job => CprPalette.yellow,
      WaypointKind.shop => CprPalette.success,
      WaypointKind.note => CprPalette.inkMuted,
    };

/// Icona e colore di una categoria, usati anche fuori dal dialogo.
class WaypointKindStyle {
  const WaypointKindStyle._();

  static IconData icon(WaypointKind kind) => _kindIcon(kind);
  static Color color(WaypointKind kind) => _kindColor(kind);
}
