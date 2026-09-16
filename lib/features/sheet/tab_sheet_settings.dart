import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../compare/compare_picker.dart';
import '../files/file_browser.dart';

/// Impostazioni della scheda.
///
/// Qui stanno le cose che riguardano il **documento** e non il personaggio: come
/// si chiama, quanto denaro ha, qual e' il suo identificativo di sessione, e le
/// operazioni che si fanno raramente e che per questo non devono stare in mezzo
/// ai campi che si toccano a ogni sessione.
class SheetSettingsTab extends StatefulWidget {
  const SheetSettingsTab({super.key});

  @override
  State<SheetSettingsTab> createState() => _SheetSettingsTabState();
}

class _SheetSettingsTabState extends State<SheetSettingsTab> {
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
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChamferPanel(
                title: 'Documento',
                accent: CprPalette.yellow,
                child: Column(
                  children: <Widget>[
                    TechField(
                      label: 'Nome del documento',
                      value: sheet.meta.name,
                      hint: 'Il mio personaggio',
                      onChanged: (String v) => state.mutate((s) => s.meta.name = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Expanded(
                          child: TechField(
                            label: 'Identificativo scheda',
                            value: sheet.meta.id,
                            enabled: false,
                            onChanged: (_) {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        TechButton(
                          label: 'Rigenera',
                          icon: Icons.refresh,
                          variant: TechButtonVariant.ghost,
                          tooltip: 'Nuovo identificativo per questa scheda',
                          onPressed: () => _regenerateId(state),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _Hint(
                      "Il nome cambia solo il titolo della scheda: il file mantiene il nome con cui "
                      "e' stato creato, cosi' i collegamenti gia' condivisi con il master restano validi.",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ChamferPanel(
                title: 'Economia e contatti',
                accent: CprPalette.success,
                child: Column(
                  children: <Widget>[
                    TechNumberStepper(
                      label: 'Eurodollari',
                      value: sheet.eurobucks,
                      min: 0,
                      max: 9999999,
                      accent: CprPalette.success,
                      onChanged: (int v) => state.mutate((s) => s.eurobucks = v),
                    ),
                    const SizedBox(height: 12),
                    TechTextArea(
                      label: 'Vecchie conoscenze',
                      value: sheet.oldConnections,
                      lines: 4,
                      hint: 'Chi conosci, chi ti deve un favore, chi ti evita…',
                      onChanged: (String v) => state.mutate((s) => s.oldConnections = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ChamferPanel(
                title: 'Manutenzione',
                accent: CprPalette.inkMuted,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ActionRow(
                      title: 'Apri la cartella del documento',
                      description: state.documentPath == null
                          ? 'Nessun file su disco'
                          : p.dirname(state.documentPath!),
                      icon: Icons.folder_open,
                      enabled: state.documentPath != null,
                      onPressed: () => _openFolder(state),
                    ),
                    _ActionRow(
                      title: 'Esporta una copia',
                      description: "Salva una copia .cpredux in un'altra posizione",
                      icon: Icons.save_alt,
                      onPressed: () => _exportCopy(state),
                    ),
                    _ActionRow(
                      title: 'Confronta con un\'altra versione',
                      description: 'Metti questa scheda accanto a una copia salvata, e vedi cosa e\' cambiato',
                      icon: Icons.difference_outlined,
                      onPressed: () => _compareWith(state),
                    ),
                    _ActionRow(
                      title: 'Cartella dei documenti',
                      description: AppPaths.documentsDir().path,
                      icon: Icons.folder_special_outlined,
                      onPressed: () => _revealDirectory(AppPaths.documentsDir()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _StatisticsPanel(state: state),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _regenerateId(AppState state) async {
    final bool confirmed = await showTechConfirm(
      context,
      title: "Rigenerare l'identificativo?",
      message: 'Il master riconosce questa scheda dal suo identificativo. Cambiandolo, '
          "il tavolo non la colleghera' piu' alla sessione in corso.",
      confirmLabel: 'Rigenera',
    );
    if (!confirmed) return;
    state.mutate(
      (s) => s.meta.id = 'sheet-${DateTime.now().microsecondsSinceEpoch}',
    );
  }

  /// Confronta la scheda aperta con una copia salvata.
  ///
  /// Il lato "adesso" e' la scheda **in memoria**, con le modifiche non ancora
  /// salvate: e' l'unica versione che l'utente non puo' vedere altrove, ed e'
  /// esattamente quella che si vuole confrontare quando ci si chiede "cosa ho
  /// cambiato?". Il dialogo lo dichiara.
  Future<void> _compareWith(AppState state) async {
    final ComparisonSide? open = state.sideOfOpenSheet();
    if (open == null) return;

    final Comparison? comparison =
        await showComparePicker(context, state: state, openSheet: open);
    if (comparison == null || !mounted) return;
    state.openComparison(comparison);
  }

  Future<void> _openFolder(AppState state) async {
    final String? path = state.documentPath;
    if (path == null) return;
    await _revealDirectory(Directory(p.dirname(path)));
  }

  Future<void> _exportCopy(AppState state) async {
    final String? path = state.documentPath;
    if (path == null) return;
    // Si salva prima: esportare una copia che non contiene le ultime modifiche
    // sarebbe la versione peggiore di questa funzione.
    state.save();

    final String? destination = await showFileBrowser(
      context,
      mode: FileBrowserMode.save,
      title: 'Esporta una copia',
      extensions: <String>[CpreduxFile.extension],
      initialDirectory: AppPaths.documentsDir().path,
      suggestedName: '${p.basenameWithoutExtension(path)} (copia)',
      description: 'Copia della scheda',
    );
    if (destination == null || !mounted) return;

    try {
      final File copy = File(destination);
      if (copy.existsSync() && copy.lengthSync() > 0) {
        throw const FileSystemException("Esiste gia' un file con questo nome.");
      }
      await File(path).copy(destination);
      if (!mounted) return;
      await showTechMessage(
        context,
        title: 'Copia creata',
        message: "La copia e' stata salvata.",
        detail: destination,
      );
    } catch (e) {
      if (!mounted) return;
      await showTechMessage(
        context,
        title: 'Esportazione non riuscita',
        message: "Non e' stato possibile scrivere la copia.",
        detail: e.toString(),
        isError: true,
      );
    }
  }
}

/// Apre la cartella nel gestore file di sistema.
///
/// Non c'e' un plugin: si lancia il comando del sistema operativo, che e' anche
/// l'unico modo per avere l'esperienza *nativa* che ci si aspetta (Finder su
/// macOS, Esplora file su Windows, quello che l'utente usa su Linux).
Future<void> _revealDirectory(Directory directory) async {
  final String path = directory.path;
  try {
    if (Platform.isMacOS) {
      await Process.run('open', <String>[path]);
    } else if (Platform.isWindows) {
      await Process.run('explorer', <String>[path]);
    } else {
      await Process.run('xdg-open', <String>[path]);
    }
  } on ProcessException {
    // Se il comando non e' disponibile non si interrompe nulla: la cartella e'
    // comunque mostrata nel pannello, quindi l'utente ha l'informazione.
  }
}

class _ActionRow extends StatefulWidget {
  const _ActionRow({
    required this.title,
    required this.description,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color color = widget.enabled ? CprPalette.ink : CprPalette.inkFaint;

    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          margin: const EdgeInsets.only(bottom: 4),
          color: _hover && widget.enabled ? CprPalette.veil(CprPalette.yellow, 0.06) : null,
          child: Row(
            children: <Widget>[
              Icon(widget.icon, size: 16, color: widget.enabled ? CprPalette.yellow : CprPalette.inkFaint),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(widget.title, style: CprType.body.copyWith(color: color, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      overflow: TextOverflow.ellipsis,
                      style: CprType.caption.copyWith(
                        color: CprPalette.inkFaint,
                        fontSize: 11,
                        fontFamilyFallback: CprType.monoFamily,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward, size: 14, color: CprPalette.inkFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.info_outline, size: 13, color: CprPalette.inkFaint),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.45),
          ),
        ),
      ],
    );
  }
}

/// Riepilogo numerico della scheda.
///
/// Non serve a giocare, serve a *fidarsi*: dopo una conversione da un vecchio
/// file, e' il posto in cui si verifica in cinque secondi che i numeri
/// corrispondano a quelli che si ricordano.
class _StatisticsPanel extends StatelessWidget {
  const _StatisticsPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sheet = state.sheet!;
    final totals = state.totals!;

    return ChamferPanel(
      title: 'Riepilogo',
      accent: CprPalette.inkFaint,
      child: Wrap(
        spacing: 26,
        runSpacing: 14,
        children: <Widget>[
          _Stat(label: 'Modificatori manuali', value: '${sheet.statModifiers.length}'),
          _Stat(label: 'Modificatori abilita', value: '${sheet.skillModifiers.length}'),
          _Stat(label: 'Competenze', value: '${sheet.proficiencies.length}'),
          _Stat(label: 'Oggetti', value: '${sheet.inventory.length}'),
          _Stat(label: 'Impianti', value: '${sheet.cyberware.length}'),
          _Stat(label: 'Effetti', value: '${sheet.effects.length}'),
          _Stat(label: 'Note', value: '${sheet.notes.length}'),
          _Stat(label: 'PV massimi', value: '${totals.maxHitPoints}'),
          _Stat(label: 'Umanita massima', value: '${totals.maxHumanity}'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(value, style: CprType.numeralSmall.copyWith(color: CprPalette.ink, fontSize: 17)),
        const SizedBox(height: 3),
        Text(
          label.toUpperCase(),
          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
        ),
      ],
    );
  }
}
