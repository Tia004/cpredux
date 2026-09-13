import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Una voce di menu'.
class MenuEntry {
  const MenuEntry({
    required this.label,
    this.description = '',
    this.icon,
    this.accent,
    this.onTap,
    this.trailing,
    this.muted = false,
  });

  final String label;
  final String description;
  final IconData? icon;
  final Color? accent;
  final VoidCallback? onTap;

  /// Numero o data a destra, per le voci di documento.
  final String? trailing;

  /// Voce presente ma non utilizzabile (file che non c'e' piu'), con il motivo
  /// scritto nella descrizione.
  final bool muted;
}

/// Riga di menu': una azione sola.
///
/// La forma e' sempre la stessa in tutta l'applicazione — barra di colore a
/// sinistra, icona, titolo, riga di spiegazione, freccia che compare al
/// passaggio del mouse — perche' il menu' principale e' la prima cosa che si
/// vede, ed e' li' che si impara come si comporta il resto.
class MenuRow extends StatefulWidget {
  const MenuRow({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.primary = false,
    this.trailing,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool primary;
  final Widget? trailing;

  @override
  State<MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<MenuRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return _RowShell(
      accent: widget.accent,
      primary: widget.primary,
      hover: _hover,
      onHover: (bool value) => setState(() => _hover = value),
      onTap: widget.onTap,
      child: Row(
        children: <Widget>[
          Icon(widget.icon, size: 17, color: widget.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.label,
                  style: CprType.body.copyWith(
                    color: CprPalette.ink,
                    fontWeight: _hover ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.description,
                  style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                ),
              ],
            ),
          ),
          if (widget.trailing != null) widget.trailing!,
          AnimatedOpacity(
            duration: CprMotion.hover,
            opacity: _hover ? 1 : 0,
            child: Icon(Icons.arrow_forward, size: 15, color: widget.accent),
          ),
        ],
      ),
    );
  }
}

/// Riga di menu' che si apre su un elenco.
///
/// E' il menu' a tendina dei documenti esistenti: si clicca l'intestazione e si
/// apre la lista, senza cambiare schermata. Sta **dentro** il pannello e non
/// fluttua sopra la finestra, per una ragione pratica: un elenco ancorato al
/// proprio posto non ha bisogno di calcolare dove finisce lo schermo, e su una
/// finestra stretta non si ritrova a meta' fuori.
class ExpandableMenuRow extends StatefulWidget {
  const ExpandableMenuRow({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.entries,
    this.primary = false,
    this.emptyMessage = 'Non c\'e\' niente qui.',
    this.maxBodyHeight = 292,
    this.enable = true,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color accent;
  final List<MenuEntry> entries;
  final bool primary;
  final String emptyMessage;
  final double maxBodyHeight;
  final bool enable;

  @override
  State<ExpandableMenuRow> createState() => _ExpandableMenuRowState();
}

class _ExpandableMenuRowState extends State<ExpandableMenuRow> {
  bool _open = false;
  bool _hover = false;

  void _toggle() {
    if (!widget.enable) return;
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _RowShell(
          accent: widget.accent,
          primary: widget.primary,
          hover: _hover || _open,
          onHover: (bool value) => setState(() => _hover = value),
          onTap: _toggle,
          child: Row(
            children: <Widget>[
              Icon(widget.icon, size: 17, color: widget.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      widget.label,
                      style: CprType.body.copyWith(
                        color: CprPalette.ink,
                        fontWeight: _hover || _open ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.description,
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                    ),
                  ],
                ),
              ),
              if (widget.entries.isNotEmpty) ...<Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  color: CprPalette.veil(widget.accent, 0.14),
                  child: Text(
                    '${widget.entries.length}',
                    style: CprType.numeralSmall.copyWith(color: widget.accent, fontSize: 11),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              // La freccia dice due cose con lo stesso segno: gira quando il
              // menu' e' aperto, e compare quando il mouse e' sopra. Senza il
              // primo non si saprebbe che la riga si apre; senza il secondo non
              // si saprebbe che e' cliccabile.
              AnimatedRotation(
                duration: CprMotion.fast,
                turns: _open ? 0.25 : 0,
                child: AnimatedOpacity(
                  duration: CprMotion.hover,
                  opacity: _hover || _open ? 1 : 0.25,
                  child: Icon(Icons.chevron_right, size: 16, color: widget.accent),
                ),
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: CprMotion.normal,
          curve: CprMotion.enter,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : _Body(
                  entries: widget.entries,
                  emptyMessage: widget.emptyMessage,
                  maxHeight: widget.maxBodyHeight,
                  accent: widget.accent,
                  onPicked: () {
                    // Un menu' che resta aperto dopo la scelta nasconde proprio
                    // la cosa che si e' appena fatta.
                    if (mounted) setState(() => _open = false);
                  },
                ),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.entries,
    required this.emptyMessage,
    required this.maxHeight,
    required this.accent,
    required this.onPicked,
  });

  final List<MenuEntry> entries;
  final String emptyMessage;
  final double maxHeight;
  final Color accent;
  final VoidCallback onPicked;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Text(
          emptyMessage,
          style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.4),
        ),
      );
    }

    final Widget list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final MenuEntry entry in entries)
          _EntryRow(entry: entry, onTap: () {
            entry.onTap?.call();
            onPicked();
          }),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(left: 14, bottom: 4),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border(left: BorderSide(color: CprPalette.veil(accent, 0.45), width: 2)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        // L'elenco scorre da solo quando i documenti sono tanti: una tendina
        // alta quanto la finestra non e' piu' una tendina.
        child: SingleChildScrollView(child: list),
      ),
    );
  }
}

class _EntryRow extends StatefulWidget {
  const _EntryRow({required this.entry, required this.onTap});

  final MenuEntry entry;
  final VoidCallback onTap;

  @override
  State<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends State<_EntryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final MenuEntry entry = widget.entry;
    final Color accent = entry.accent ?? CprPalette.inkMuted;
    final bool enabled = entry.onTap != null && !entry.muted;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: _hover && enabled ? CprPalette.veil(accent, 0.10) : null,
          child: Row(
            children: <Widget>[
              if (entry.icon != null) ...<Widget>[
                Icon(entry.icon, size: 13, color: entry.muted ? CprPalette.inkFaint : accent),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      entry.label,
                      overflow: TextOverflow.ellipsis,
                      style: CprType.caption.copyWith(
                        color: entry.muted ? CprPalette.inkFaint : CprPalette.ink,
                        fontSize: 12.5,
                        fontWeight: _hover && enabled ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    if (entry.description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        entry.description,
                        overflow: TextOverflow.ellipsis,
                        style: CprType.caption.copyWith(
                          color: CprPalette.inkFaint,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (entry.trailing != null)
                Text(
                  entry.trailing!,
                  style: CprType.numeralSmall.copyWith(
                    color: CprPalette.inkFaint,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Guscio comune delle righe: barra di colore, sfondo al passaggio del mouse.
class _RowShell extends StatelessWidget {
  const _RowShell({
    required this.child,
    required this.accent,
    required this.primary,
    required this.hover,
    required this.onHover,
    required this.onTap,
  });

  final Widget child;
  final Color accent;
  final bool primary;
  final bool hover;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: hover
                ? CprPalette.veil(accent, primary ? 0.16 : 0.08)
                : (primary ? CprPalette.veil(accent, 0.08) : Colors.transparent),
            border: Border(left: BorderSide(color: accent, width: hover ? 4 : 2)),
          ),
          child: child,
        ),
      ),
    );
  }
}
