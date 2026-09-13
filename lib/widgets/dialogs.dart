import 'package:flutter/material.dart';

import '../data/migrator.dart';
import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';
import 'tech_button.dart';
import 'tech_background.dart';

/// Mostra un messaggio all'utente.
///
/// Sostituisce gli alert di sistema, che su macOS, Windows e Linux hanno tre
/// aspetti diversi e non si possono tematizzare: in un'app che fa dell'identita'
/// visiva il suo punto di forza, una finestra di sistema grigia nel mezzo e' una
/// rottura evidente.
Future<void> showTechMessage(
  BuildContext context, {
  required String title,
  required String message,
  String? detail,
  bool isError = false,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => _TechDialog(
      title: title,
      accent: isError ? CprPalette.danger : CprPalette.yellow,
      body: <Widget>[
        Text(message, style: CprType.body.copyWith(color: CprPalette.ink)),
        if (detail != null) ...<Widget>[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            color: CprPalette.surfaceSunken,
            child: Text(
              detail,
              style: CprType.caption.copyWith(
                color: CprPalette.inkMuted,
                fontFamilyFallback: CprType.monoFamily,
              ),
            ),
          ),
        ],
      ],
      actions: <Widget>[
        TechButton(
          label: 'Chiudi',
          variant: TechButtonVariant.secondary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

/// Chiede conferma prima di un'azione che non si puo' annullare.
Future<bool> showTechConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Conferma',
  bool danger = false,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => _TechDialog(
      title: title,
      accent: danger ? CprPalette.danger : CprPalette.yellow,
      body: <Widget>[
        Text(message, style: CprType.body.copyWith(color: CprPalette.ink)),
      ],
      actions: <Widget>[
        TechButton(
          label: 'Annulla',
          variant: TechButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        TechButton(
          label: confirmLabel,
          variant: danger ? TechButtonVariant.danger : TechButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// La pagina della conversione: cosa e' stato riconosciuto, dove finira' il
/// file, e il pulsante per convertire.
///
/// Restituisce la destinazione scelta, oppure `null` se si annulla. E' una
/// schermata sola e non due passaggi separati ("confermi?" e poi "dove lo
/// metto?") perche' sono la stessa decisione: si guarda cosa e' stato
/// riconosciuto e si decide se e dove tenerlo.
Future<MigrationTarget?> showMigrationPreview(
  BuildContext context, {
  required MigrationReport report,
  required String fileName,
  required String Function(MigrationTarget) outputPathOf,
  MigrationTarget initial = MigrationTarget.appData,
}) {
  return showDialog<MigrationTarget>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => _MigrationPreview(
      report: report,
      fileName: fileName,
      outputPathOf: outputPathOf,
      initial: initial,
    ),
  );
}

class _MigrationPreview extends StatefulWidget {
  const _MigrationPreview({
    required this.report,
    required this.fileName,
    required this.outputPathOf,
    required this.initial,
  });

  final MigrationReport report;
  final String fileName;
  final String Function(MigrationTarget) outputPathOf;
  final MigrationTarget initial;

  @override
  State<_MigrationPreview> createState() => _MigrationPreviewState();
}

class _MigrationPreviewState extends State<_MigrationPreview> {
  late MigrationTarget _target = widget.initial;

  @override
  Widget build(BuildContext context) {
    final MigrationReport report = widget.report;

    return _TechDialog(
      title: 'Converti la scheda',
      accent: report.hasWarnings ? CprPalette.warning : CprPalette.magenta,
      width: 600,
      body: <Widget>[
        Text(
          widget.fileName,
          style: CprType.body.copyWith(color: CprPalette.ink, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          report.hasWarnings
              ? 'Riconosciuti ${report.totalElements} elementi, con ${report.warnings.length} '
                  'cose da controllare.'
              : 'Riconosciuti ${report.totalElements} elementi, nessuna perdita.',
          style: CprType.caption.copyWith(color: CprPalette.inkMuted),
        ),
        if (report.counts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text('COSA E\' STATO RICONOSCIUTO', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final MapEntry<String, int> entry in report.counts.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  color: CprPalette.surfaceSunken,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('${entry.value}', style: CprType.numeralSmall.copyWith(color: CprPalette.magenta)),
                      const SizedBox(width: 6),
                      Text(
                        entry.key.toUpperCase(),
                        style: CprType.label.copyWith(color: CprPalette.inkMuted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (report.notes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 16),
          Text('DA CONTROLLARE', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
          const SizedBox(height: 8),
          for (final MigrationNote note in report.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Icon(
                      note.isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      size: 13,
                      color: note.isWarning ? CprPalette.warning : CprPalette.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.message,
                      style: CprType.caption.copyWith(
                        color: note.isWarning ? CprPalette.ink : CprPalette.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        const SizedBox(height: 18),
        Text('DOVE SALVARLA', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
        const SizedBox(height: 8),
        for (final MigrationTarget target in MigrationTarget.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TargetOption(
              target: target,
              selected: target == _target,
              path: widget.outputPathOf(target),
              onTap: () => setState(() => _target = target),
            ),
          ),
        const SizedBox(height: 4),
        Row(
          children: <Widget>[
            const Icon(Icons.shield_outlined, size: 13, color: CprPalette.success),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'La scheda vecchia non viene toccata: resta dov\'e\' com\'e\'.',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint),
              ),
            ),
          ],
        ),
      ],
      actions: <Widget>[
        TechButton(
          label: 'Annulla',
          variant: TechButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        TechButton(
          label: 'Converti',
          icon: Icons.auto_fix_high,
          variant: TechButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(_target),
        ),
      ],
    );
  }
}

/// Una delle due destinazioni possibili, con il percorso che ne risulterebbe.
class _TargetOption extends StatelessWidget {
  const _TargetOption({
    required this.target,
    required this.selected,
    required this.path,
    required this.onTap,
  });

  final MigrationTarget target;
  final bool selected;
  final String path;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CprMotion.fast,
          padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(CprPalette.magenta, 0.10) : CprPalette.surfaceSunken,
            border: Border.all(
              color: selected ? CprPalette.magenta : CprPalette.hairline,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  size: 14,
                  color: selected ? CprPalette.magenta : CprPalette.inkFaint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      target.label,
                      style: CprType.body.copyWith(
                        fontSize: 13,
                        color: selected ? CprPalette.ink : CprPalette.inkMuted,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      target.description,
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      path,
                      style: CprType.caption.copyWith(
                        fontSize: 10.5,
                        color: CprPalette.inkMuted,
                        fontFamilyFallback: CprType.monoFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mostra il resoconto di una conversione da vecchio formato.
///
/// Il resoconto e' il punto in cui l'utente decide se fidarsi della
/// conversione: per questo elenca cosa e' passato e cosa no, invece di dire
/// semplicemente "fatto". Una conversione che nasconde le perdite e' peggio di
/// una che fallisce, perche' l'utente se ne accorge troppo tardi.
Future<void> showMigrationReport(BuildContext context, MigrationReport report) {
  return showDialog<void>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => _TechDialog(
      title: 'Conversione completata',
      accent: report.hasWarnings ? CprPalette.warning : CprPalette.success,
      width: 560,
      body: <Widget>[
        Text(
          report.hasWarnings
              ? 'La scheda e\' stata convertita, con alcune avvertenze da controllare.'
              : 'La scheda e\' stata convertita senza perdite.',
          style: CprType.body.copyWith(color: CprPalette.ink),
        ),
        const SizedBox(height: 16),
        if (report.counts.isNotEmpty) ...<Widget>[
          Text('ELEMENTI CONVERTITI', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final MapEntry<String, int> entry in report.counts.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  color: CprPalette.surfaceSunken,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${entry.value}',
                        style: CprType.numeralSmall.copyWith(color: CprPalette.yellow),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.key.toUpperCase(),
                        style: CprType.label.copyWith(color: CprPalette.inkMuted, fontSize: 9.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (report.notes.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          Text('RESOCONTO', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
          const SizedBox(height: 8),
          for (final MigrationNote note in report.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      note.isWarning ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      size: 13,
                      color: note.isWarning ? CprPalette.warning : CprPalette.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.message,
                      style: CprType.caption.copyWith(
                        color: note.isWarning ? CprPalette.ink : CprPalette.inkMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (report.imageDirectory != null || report.backupPath != null) ...<Widget>[
          const SizedBox(height: 14),
          Text('FILE', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
          const SizedBox(height: 8),
          if (report.outputPath != null) _pathRow('Nuova scheda', report.outputPath!),
          if (report.imageDirectory != null) _pathRow('Immagini estratte', report.imageDirectory!),
          if (report.backupPath != null) _pathRow('Backup originale', report.backupPath!),
        ],
      ],
      actions: <Widget>[
        TechButton(
          label: 'Apri la scheda',
          variant: TechButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}

Widget _pathRow(String label, String path) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 130,
          child: Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5)),
        ),
        Expanded(
          child: Text(
            path,
            style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontFamilyFallback: CprType.monoFamily, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

class _TechDialog extends StatelessWidget {
  const _TechDialog({
    required this.title,
    required this.accent,
    required this.body,
    required this.actions,
    this.width = 480,
  });

  final String title;
  final Color accent;
  final List<Widget> body;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width),
        child: TechBackground(
          gridSize: 26,
          showVignette: false,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CprPalette.surface,
              border: Border.all(color: accent.withValues(alpha: 0.55)),
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
                      Container(width: 3, height: 15, color: accent),
                      const SizedBox(width: 10),
                      Text(title.toUpperCase(), style: CprType.label.copyWith(color: accent, fontSize: 12)),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: body,
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
                      for (int i = 0; i < actions.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(width: 10),
                        actions[i],
                      ],
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
