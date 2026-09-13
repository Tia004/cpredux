import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Zona che accetta file trascinati **dal sistema operativo**.
///
/// Perche' serve una libreria nativa: `DragTarget` di Flutter funziona solo fra
/// widget della stessa applicazione. Il trascinamento dal Finder, da Esplora
/// risorse o dal file manager di Linux arriva come evento della piattaforma, e
/// non c'e' modo di riceverlo da `dart:io`.
///
/// Il comportamento visivo e' quello che ci si aspetta da qualunque
/// applicazione desktop: mentre il file e' sopra la zona, la zona **lo dice**
/// (bordo acceso, testo che cambia, alone), perche' un'area che accetta un
/// rilascio senza segnalarlo lascia l'utente a indovinare.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.child,
    required this.onDropped,
    this.extensions = const <String>[],
    this.label = 'Rilascia qui',
    this.hint,
    this.accent,
    this.onRejected,
    this.enable = true,
    this.padding = EdgeInsets.zero,
    this.cut = 10,
  });

  final Widget child;

  /// Chiamato con i percorsi dei file trascinati che passano il filtro.
  final ValueChanged<List<String>> onDropped;

  /// Estensioni accettate, senza punto. Vuoto = tutte.
  final List<String> extensions;

  /// Testo mostrato durante il trascinamento.
  final String label;

  /// Riga secondaria, per dire cosa si sta aspettando.
  final String? hint;

  final Color? accent;

  /// Chiamato quando il rilascio non va bene (estensione non ammessa, cartella).
  /// Serve a spiegare *perche'* non e' successo niente: un rilascio ignorato in
  /// silenzio sembra un difetto del programma.
  final void Function(String reason)? onRejected;

  /// Va messo a false quando davanti c'e' un dialogo.
  ///
  /// La libreria avverte che una zona coperta continua a ricevere i rilasci:
  /// senza questo, un file lasciato sul dialogo di conversione finirebbe
  /// comunque sulla zona sotto, che l'utente non sta guardando.
  final bool enable;

  final EdgeInsets padding;
  final double cut;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _hovering = false;

  bool _accepts(DropItem item) {
    if (item is DropItemDirectory) return false;
    if (widget.extensions.isEmpty) return true;
    final String extension = p.extension(item.path).replaceFirst('.', '').toLowerCase();
    return widget.extensions.contains(extension);
  }

  void _onDone(DropDoneDetails details) {
    setState(() => _hovering = false);

    final List<DropItem> items = details.files;
    if (items.isEmpty) return;

    final List<DropItem> directories = <DropItem>[
      for (final DropItem i in items)
        if (i is DropItemDirectory) i,
    ];
    if (directories.isNotEmpty) {
      widget.onRejected?.call('Hai lasciato una cartella: serve il file della scheda.');
      return;
    }

    final List<String> accepted = <String>[
      for (final DropItem i in items)
        if (_accepts(i)) i.path,
    ];
    if (accepted.isEmpty) {
      final String expected = widget.extensions.map((String e) => '.$e').join(', ');
      widget.onRejected?.call(
        'Questo file non e\' nel formato giusto: serve $expected\n'
        '${items.first.name}',
      );
      return;
    }

    widget.onDropped(accepted);
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? CprPalette.magenta;

    return DropTarget(
      enable: widget.enable,
      // Il DropTarget dell'applicazione resta agganciato anche quando e'
      // coperto: `enable: false` mentre un dialogo e' aperto e' l'unico modo per
      // non far arrivare il rilascio a una zona che non si sta guardando.
      onDragEntered: (_) => setState(() => _hovering = true),
      onDragExited: (_) => setState(() => _hovering = false),
      onDragDone: _onDone,
      child: AnimatedContainer(
        duration: CprMotion.fast,
        curve: CprMotion.enter,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: _hovering ? CprPalette.veil(accent, 0.14) : Colors.transparent,
          border: Border.all(
            color: _hovering ? accent : Colors.transparent,
            width: _hovering ? 1.6 : 1,
          ),
        ),
        child: Stack(
          children: <Widget>[
            widget.child,
            // L'avviso sta sopra il contenuto invece di sostituirlo: la riga
            // che si sta puntando deve restare riconoscibile, altrimenti si
            // perde il riferimento di *dove* si sta lasciando il file.
            if (_hovering)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    alignment: Alignment.center,
                    color: CprPalette.veil(CprPalette.voidBlack, 0.78),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.file_download_outlined, size: 15, color: accent),
                            const SizedBox(width: 8),
                            Text(
                              widget.label.toUpperCase(),
                              style: CprType.label.copyWith(color: accent, fontSize: 11),
                            ),
                          ],
                        ),
                        if (widget.hint != null) ...<Widget>[
                          const SizedBox(height: 5),
                          Text(
                            widget.hint!,
                            style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
