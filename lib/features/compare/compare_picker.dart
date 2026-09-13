import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../data/document_library.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';

/// Sceglie le due schede da confrontare.
///
/// Due modi di arrivarci, che sono due domande diverse:
///
/// * **due file** — "che differenza c'e' fra queste due schede?";
/// * **la scheda aperta contro un file** — "cosa e' cambiato da quando ho
///   salvato quella copia?". In questo caso un lato e' gia' deciso (e' la
///   scheda che si sta guardando, con le sue modifiche non ancora salvate) e si
///   sceglie solo l'altro.
///
/// La lettura avviene **alla conferma** e non alla scelta: se un file non si
/// apre, l'errore compare dentro questo dialogo, dove l'utente sta ancora
/// decidendo, invece di far cadere la schermata che si apre dopo.
Future<Comparison?> showComparePicker(
  BuildContext context, {
  required AppState state,
  ComparisonSide? openSheet,
}) {
  return showDialog<Comparison>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.75),
    builder: (BuildContext context) => _ComparePicker(state: state, openSheet: openSheet),
  );
}

class _ComparePicker extends StatefulWidget {
  const _ComparePicker({required this.state, this.openSheet});

  final AppState state;

  /// La scheda aperta, se il confronto parte da li'.
  final ComparisonSide? openSheet;

  @override
  State<_ComparePicker> createState() => _ComparePickerState();
}

class _ComparePickerState extends State<_ComparePicker> {
  String? _leftPath;
  String? _rightPath;
  String? _error;
  bool _reading = false;

  bool get _singleChoice => widget.openSheet != null;

  /// La scelta e' gia' sensata appena si apre: due schede diverse se ci sono,
  /// altrimenti quella che c'e'. Prefillare non decide niente — la conferma e'
  /// un pulsante a parte — e risparmia due tendine a chi ha due schede sole.
  @override
  void initState() {
    super.initState();
    final List<DocumentEntry> sheets = _sheets();

    // Confrontare la scheda con il file da cui viene e' una domanda legittima
    // (quando ha modifiche non salvate e' anzi la piu' utile), ma non e' una
    // buona **precompilazione**: senza modifiche darebbe zero differenze, cioe'
    // la risposta giusta alla domanda sbagliata. Quindi si parte da un'altra
    // scheda, se c'e'.
    final List<DocumentEntry> preferred = _singleChoice
        ? sheets.where((DocumentEntry d) => d.path != widget.openSheet!.path).toList()
        : sheets;

    if (preferred.isNotEmpty) _leftPath = preferred.first.path;
    if (!_singleChoice && sheets.length > 1) {
      _rightPath = sheets[1].path == _leftPath ? null : sheets[1].path;
    }
  }

  /// True quando la copia scelta e' il file da cui viene la scheda aperta.
  bool get _sameAsOpen =>
      _singleChoice && _leftPath != null && _leftPath == widget.openSheet!.path;

  List<DocumentEntry> _sheets() => widget.state
      .documentsOfKind(DocumentKind.sheet)
      .where((DocumentEntry d) => d.readable)
      .toList();

  Future<void> _browse(bool left) async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Scegli una scheda',
      extensions: <String>[CpreduxFile.extension],
      initialDirectory: AppPaths.documentsDir().path,
      description: 'Schede (.cpredux)',
      // Le copie di sicurezza si chiamano `Nome.cpredux.backup` e non hanno
      // l'estensione del formato: senza questo interruttore la versione di
      // ieri non sarebbe scegliibile, cioe' proprio quella che serve.
      showAllFilesToggle: true,
    );
    if (path == null) return;
    setState(() {
      if (left) {
        _leftPath = path;
      } else {
        _rightPath = path;
      }
      _error = null;
    });
  }

  void _confirm() {
    final String? left = _leftPath;
    final String? right = _rightPath;

    if (left == null) {
      setState(() => _error = 'Scegli la prima scheda da confrontare.');
      return;
    }
    if (!_singleChoice && right == null) {
      setState(() => _error = 'Scegli anche la seconda scheda.');
      return;
    }
    if (!_singleChoice && right != null && left == right) {
      // Un file confrontato con se stesso da' zero differenze, che si legge
      // come "non e' cambiato niente" — una risposta giusta alla domanda
      // sbagliata.
      setState(() => _error = 'Le due scelte puntano allo stesso file: scegli due documenti diversi.');
      return;
    }

    setState(() {
      _reading = true;
      _error = null;
    });

    try {
      if (_singleChoice) {
        final ComparisonSide file = widget.state.readSheetSide(left);
        Navigator.of(context).pop(
          Comparison(before: file, after: widget.openSheet!),
        );
        return;
      }

      final ComparisonSide before = widget.state.readSheetSide(left);
      final ComparisonSide after = widget.state.readSheetSide(right!);
      Navigator.of(context).pop(Comparison(before: before, after: after));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _reading = false;
        _error = e is CpreduxException ? e.message : 'Non e\' stato possibile leggere il documento.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DocumentEntry> sheets = _sheets();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ChamferPanel(
          title: _singleChoice ? 'Confronta con una versione' : 'Confronta due schede',
          accent: CprPalette.info,
          cut: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                _singleChoice
                    ? 'Questa scheda ha modifiche non salvate? Il confronto usa quello che vedi '
                        'adesso, non quello che c\'e\' su disco: scegli la copia da mettere accanto.'
                    : 'Due schede, riga per riga: cosa e\' stato aggiunto, tolto o cambiato.',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.5),
              ),
              const SizedBox(height: 18),
              if (sheets.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: CprPalette.veil(CprPalette.warning, 0.12),
                    child: Text(
                      'Non c\'e\' nessuna scheda nell\'elenco: servono documenti salvati, e si '
                      'scegliono con "Sfoglia i file".',
                      style: CprType.caption.copyWith(color: CprPalette.ink),
                    ),
                  ),
                ),
              _SideSlot(
                label: _singleChoice ? 'La copia da confrontare' : 'Prima',
                accent: _singleChoice ? CprPalette.success : CprPalette.danger,
                path: _leftPath,
                sheets: sheets,
                onBrowse: () => _browse(true),
                onPicked: (String path) => setState(() {
                  _leftPath = path;
                  _error = null;
                }),
              ),
              const SizedBox(height: 14),
              if (_singleChoice)
                // La scheda aperta non si scegle: e' quello che si sta
                // guardando. Qui si dichiara *cosa* e' e se ha modifiche non
                // ancora salvate, che e' l'unica cosa che l'utente non puo'
                // vedere da solo.
                _SideSlot(
                  label: 'Questa scheda, adesso',
                  accent: CprPalette.info,
                  path: null,
                  sheets: const <DocumentEntry>[],
                  fixedName: widget.openSheet!.label,
                  fixedNote: widget.openSheet!.dirty
                      ? 'con modifiche non ancora salvate'
                      : 'come e\' sul disco',
                  onBrowse: () {},
                  onPicked: (_) {},
                )
              else
                _SideSlot(
                  label: 'Dopo',
                  accent: CprPalette.success,
                  path: _rightPath,
                  sheets: sheets,
                  onBrowse: () => _browse(false),
                  onPicked: (String path) => setState(() {
                    _rightPath = path;
                    _error = null;
                  }),
                ),
              if (_sameAsOpen) ...<Widget>[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.info_outline, size: 14, color: CprPalette.info),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Hai scelto il file da cui viene questa scheda: si vedranno solo le '
                        'differenze non ancora salvate.',
                        style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ],
              if (_error != null) ...<Widget>[
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Icon(Icons.warning_amber_rounded, size: 14, color: CprPalette.danger),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _error!,
                        style: CprType.caption.copyWith(color: CprPalette.ink),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TechButton(
                    label: 'Annulla',
                    variant: TechButtonVariant.ghost,
                    onPressed: _reading ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: _reading ? 'Leggo…' : 'Confronta',
                    icon: Icons.difference_outlined,
                    variant: TechButtonVariant.primary,
                    onPressed: _reading ? null : _confirm,
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

/// Un lato del confronto nel dialogo: la tendina dei documenti e "Sfoglia".
class _SideSlot extends StatelessWidget {
  const _SideSlot({
    required this.label,
    required this.accent,
    required this.path,
    required this.sheets,
    required this.onBrowse,
    required this.onPicked,
    this.fixedName,
    this.fixedNote,
  });

  final String label;
  final Color accent;
  final String? path;
  final List<DocumentEntry> sheets;
  final VoidCallback onBrowse;
  final ValueChanged<String> onPicked;
  final String? fixedName;
  final String? fixedNote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: CprPalette.veil(accent, 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(width: 3, height: 12, color: accent),
              const SizedBox(width: 8),
              Text(label.toUpperCase(), style: CprType.label.copyWith(color: accent)),
            ],
          ),
          const SizedBox(height: 10),
          if (fixedName != null) ...<Widget>[
            Text(fixedName!, style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13)),
            if (fixedNote != null) ...<Widget>[
              const SizedBox(height: 3),
              Text(
                fixedNote!,
                style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
              ),
            ],
          ],
          if (fixedName == null) ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: sheets.isEmpty
                      ? Text(
                          'Nessuna scheda nell\'elenco',
                          style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                        )
                      : TechDropdown<DocumentEntry>(
                          label: 'Documento',
                          value: _selected(sheets),
                          items: sheets,
                          labelOf: (DocumentEntry d) => d.name,
                          accent: accent,
                          onChanged: (DocumentEntry d) => onPicked(d.path),
                        ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 17),
                  child: TechButton(
                    label: 'Sfoglia…',
                    icon: Icons.folder_open,
                    variant: TechButtonVariant.ghost,
                    compact: true,
                    onPressed: onBrowse,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Il percorso per esteso: due schede possono chiamarsi allo stesso
            // modo in cartelle diverse, e la tendina mostra solo il nome.
            Text(
              path == null ? 'Nessun file scelto' : '${p.basename(path!)}  ·  ${p.dirname(path!)}',
              overflow: TextOverflow.ellipsis,
              style: CprType.caption.copyWith(
                color: path == null ? CprPalette.inkFaint : CprPalette.inkMuted,
                fontSize: 10.5,
                fontFamilyFallback: CprType.monoFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }

  DocumentEntry _selected(List<DocumentEntry> sheets) {
    for (final DocumentEntry entry in sheets) {
      if (entry.path == path) return entry;
    }
    return sheets.first;
  }
}
