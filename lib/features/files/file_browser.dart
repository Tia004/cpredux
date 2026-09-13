import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../data/app_paths.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../../widgets/tech_background.dart';

enum FileBrowserMode { open, save }

/// Apre il browser dei file dell'applicazione.
///
/// Restituisce il percorso scelto, oppure `null` se l'utente annulla.
Future<String?> showFileBrowser(
  BuildContext context, {
  required FileBrowserMode mode,
  required String title,
  List<String> extensions = const <String>[],
  String? initialDirectory,
  String suggestedName = '',
  String? description,

  /// Mostra il comando "tutti i file".
  ///
  /// Serve dove il filtro e' un'indicazione e non una regola: per un ritratto
  /// si parte mostrando le immagini, ma dire "no" a un `.heic` o a un formato
  /// che non abbiamo previsto sarebbe una limitazione arbitraria dell'utente.
  bool showAllFilesToggle = false,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.75),
    builder: (BuildContext context) => _FileBrowserDialog(
      mode: mode,
      title: title,
      extensions: extensions,
      initialDirectory: initialDirectory,
      suggestedName: suggestedName,
      description: description,
      showAllFilesToggle: showAllFilesToggle,
    ),
  );
}

class _FileBrowserDialog extends StatefulWidget {
  const _FileBrowserDialog({
    required this.mode,
    required this.title,
    required this.extensions,
    required this.initialDirectory,
    required this.suggestedName,
    required this.description,
    required this.showAllFilesToggle,
  });

  final FileBrowserMode mode;
  final String title;
  final List<String> extensions;
  final String? initialDirectory;
  final String suggestedName;
  final String? description;
  final bool showAllFilesToggle;

  @override
  State<_FileBrowserDialog> createState() => _FileBrowserDialogState();
}

class _FileBrowserDialogState extends State<_FileBrowserDialog> {
  late Directory _directory;
  String? _selectedFile;
  String? _error;
  late String _fileName = widget.suggestedName;

  @override
  void initState() {
    super.initState();
    _directory = _resolveInitialDirectory();
    _load();
  }

  Directory _resolveInitialDirectory() {
    final String? initial = widget.initialDirectory;
    if (initial != null && Directory(initial).existsSync()) return Directory(initial);
    return AppPaths.documentsDir();
  }

  bool _showAllFiles = false;

  bool _matchesFilter(String fileName) {
    if (widget.extensions.isEmpty || _showAllFiles) return true;
    final String ext = p.extension(fileName).replaceFirst('.', '').toLowerCase();
    return widget.extensions.contains(ext);
  }

  List<Directory> _subdirectories = <Directory>[];
  List<File> _files = <File>[];

  void _load() {
    final List<Directory> dirs = <Directory>[];
    final List<File> files = <File>[];

    try {
      for (final FileSystemEntity entity in _directory.listSync(followLinks: false)) {
        final String name = p.basename(entity.path);
        // Le cartelle e i file che iniziano con "." sono quasi sempre rumore
        // di sistema: nasconderli tiene pulito un elenco che altrimenti
        // diventa illeggibile nella cartella home.
        if (name.startsWith('.')) continue;
        if (entity is Directory) {
          dirs.add(entity);
        } else if (entity is File && _matchesFilter(name)) {
          files.add(entity);
        }
      }
      dirs.sort((Directory a, Directory b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      files.sort((File a, File b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      _error = null;
    } on FileSystemException catch (e) {
      // Cartelle non accessibili sono la norma (foto, libreria, altri utenti):
      // si mostra il motivo invece di far esplodere la schermata.
      _error = 'Cartella non accessibile: ${e.osError?.message ?? e.message}';
    }

    setState(() {
      _subdirectories = dirs;
      _files = files;
      _selectedFile = null;
    });
  }

  void _enter(Directory directory) {
    setState(() => _directory = directory);
    _load();
  }

  void _goUp() {
    final Directory parent = _directory.parent;
    if (parent.path != _directory.path) {
      setState(() => _directory = parent);
      _load();
    }
  }

  bool get _canConfirm {
    if (widget.mode == FileBrowserMode.save) return _fileName.trim().isNotEmpty;
    return _selectedFile != null;
  }

  String get _resultPath {
    if (widget.mode == FileBrowserMode.save) {
      final String name = _fileName.trim();
      final String withExtension = widget.extensions.isEmpty || _matchesFilter(name)
          ? name
          : '$name.${widget.extensions.first}';
      return p.join(_directory.path, withExtension);
    }
    return _selectedFile ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940, maxHeight: 640),
        child: SizedBox(
          width: 940,
          height: 640,
          child: TechBackground(
            gridSize: 28,
            showVignette: false,
            child: CustomPaint(
              painter: _panelPainter(),
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Column(
                  children: <Widget>[
                    _header(),
                    _breadcrumb(),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          _places(),
                          const VerticalDivider(width: 1, color: CprPalette.hairline),
                          Expanded(child: _listing()),
                        ],
                      ),
                    ),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  _PanelPainter _panelPainter() => _PanelPainter();

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Container(width: 3, height: 16, color: CprPalette.yellow),
          const SizedBox(width: 10),
          Text(widget.title.toUpperCase(), style: CprType.label.copyWith(fontSize: 12.5, color: CprPalette.ink)),
          if (widget.description != null) ...<Widget>[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.description!,
                overflow: TextOverflow.ellipsis,
                style: CprType.caption.copyWith(color: CprPalette.inkFaint),
              ),
            ),
          ] else
            const Spacer(),
          TechButton(
            label: '',
            icon: Icons.close,
            variant: TechButtonVariant.ghost,
            compact: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _breadcrumb() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          TechButton(
            label: '',
            icon: Icons.arrow_upward,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: 'Cartella superiore',
            onPressed: _goUp,
          ),
          const SizedBox(width: 8),
          if (widget.showAllFilesToggle && widget.extensions.isNotEmpty) ...<Widget>[
            TechButton(
              label: 'Tutti i file',
              icon: _showAllFiles ? Icons.filter_alt_off : Icons.filter_alt,
              variant: _showAllFiles ? TechButtonVariant.secondary : TechButtonVariant.ghost,
              compact: true,
              tooltip: _showAllFiles
                  ? 'Mostra solo ${widget.extensions.map((String e) => ".$e").join(", ")}'
                  : 'Mostra tutti i tipi di file',
              onPressed: () {
                setState(() => _showAllFiles = !_showAllFiles);
                _load();
              },
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              _directory.path,
              overflow: TextOverflow.ellipsis,
              style: CprType.caption.copyWith(
                color: CprPalette.inkMuted,
                fontFamilyFallback: CprType.monoFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _places() {
    final List<(String, Directory, IconData)> places = <(String, Directory, IconData)>[
      ('Documenti', AppPaths.documentsDir(), Icons.description_outlined),
      ('Cartella app', AppPaths.dataDir(), Icons.apps),
      ('Home', Directory(Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '/'), Icons.home_outlined),
    ];

    return SizedBox(
      width: 200,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        children: <Widget>[
          for (final (String name, Directory dir, IconData icon) in places)
            _PlaceTile(
              name: name,
              icon: icon,
              selected: dir.path == _directory.path,
              onTap: () => _enter(dir),
            ),
        ],
      ),
    );
  }

  Widget _listing() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: CprType.body.copyWith(color: CprPalette.warning),
          ),
        ),
      );
    }

    if (_subdirectories.isEmpty && _files.isEmpty) {
      return Center(
        child: Text(
          widget.mode == FileBrowserMode.open && widget.extensions.isNotEmpty
              ? 'Nessun file ${widget.extensions.map((String e) => ".$e").join(", ")} in questa cartella.'
              : 'Cartella vuota.',
          style: CprType.body.copyWith(color: CprPalette.inkFaint),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _subdirectories.length + _files.length,
      itemBuilder: (BuildContext context, int index) {
        if (index < _subdirectories.length) {
          final Directory dir = _subdirectories[index];
          return _EntryTile(
            name: p.basename(dir.path),
            icon: Icons.folder_outlined,
            selected: false,
            onTap: () => _enter(dir),
          );
        }
        final File file = _files[index - _subdirectories.length];
        final String name = p.basename(file.path);
        // In modalita' salvataggio si clicca un nome per riusarlo, non per
        // sovrascrivere: selezionare un file esistente copia il nome nel campo.
        final bool selected = widget.mode == FileBrowserMode.open
            ? _selectedFile == file.path
            : _fileName == name;
        return _EntryTile(
          name: name,
          icon: Icons.insert_drive_file_outlined,
          selected: selected,
          trailing: _fileSize(file),
          onTap: () {
            if (widget.mode == FileBrowserMode.open) {
              setState(() => _selectedFile = file.path);
            } else {
              setState(() => _fileName = p.basenameWithoutExtension(name));
            }
          },
          onDoubleTap: widget.mode == FileBrowserMode.open
              ? () => Navigator.of(context).pop(file.path)
              : null,
        );
      },
    );
  }

  String _fileSize(File file) {
    try {
      final int bytes = file.lengthSync();
      if (bytes < 1024) return '$bytes B';
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '';
    }
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: widget.mode == FileBrowserMode.save
                ? TechField(
                    label: 'Nome del file',
                    value: _fileName,
                    hint: 'La mia scheda',
                    onChanged: (String v) => setState(() => _fileName = v),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('FILE SELEZIONATO', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
                      const SizedBox(height: 6),
                      Text(
                        _selectedFile == null ? 'Nessuno' : p.basename(_selectedFile!),
                        style: CprType.body.copyWith(
                          color: _selectedFile == null ? CprPalette.inkFaint : CprPalette.ink,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 16),
          TechButton(
            label: 'Annulla',
            variant: TechButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          TechButton(
            label: widget.mode == FileBrowserMode.save ? 'Crea' : 'Apri',
            icon: widget.mode == FileBrowserMode.save ? Icons.add : Icons.folder_open,
            variant: TechButtonVariant.primary,
            onPressed: _canConfirm ? () => Navigator.of(context).pop(_resultPath) : null,
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          margin: const EdgeInsets.only(bottom: 3),
          color: selected ? CprPalette.veil(CprPalette.yellow, 0.10) : null,
          child: Row(
            children: <Widget>[
              Icon(icon, size: 15, color: selected ? CprPalette.yellow : CprPalette.inkMuted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: CprType.caption.copyWith(
                    color: selected ? CprPalette.yellow : CprPalette.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.name,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.onDoubleTap,
    this.trailing,
  });

  final String name;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: selected ? CprPalette.veil(CprPalette.yellow, 0.12) : null,
          child: Row(
            children: <Widget>[
              Icon(icon, size: 15, color: selected ? CprPalette.yellow : CprPalette.inkFaint),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: CprType.body.copyWith(
                    color: selected ? CprPalette.yellow : CprPalette.ink,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PanelPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = CprPalette.surface);
    canvas.drawRect(
      rect,
      Paint()
        ..color = CprPalette.hairlineBright
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) => false;
}
