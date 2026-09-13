import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/sheet_diff.dart';
import '../../domain/sheet_diff_export.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/entrance.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';

/// Confronto fianco a fianco o in modalita' Chat Cyberpunk fra due schede.
///
/// Permette di visualizzare le differenze riga per riga oppure come un flusso
/// di dialogo cyberpunk tra i due personaggi/agenti, ed esportare il risultato
/// in testo per chat, file .html autonomo e file .json.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  /// True mostra solo le righe che differiscono. E' il default perche' e' il
  /// motivo per cui si apre un confronto.
  bool _onlyDifferences = true;

  /// True attiva la vista chat cyberpunk con dialogo tra personaggi.
  bool _chatView = false;

  /// Le sezioni chiuse a mano (o chiuse perche' non contengono differenze).
  final Set<String> _collapsed = <String>{};

  void _setOnlyDifferences(bool value, SheetDiff diff) {
    setState(() {
      _onlyDifferences = value;
      _collapsed
        ..clear()
        ..addAll(value
            ? const <String>[]
            : <String>[
                for (final DiffGroup group in diff.groups)
                  if (!group.hasChanges) group.title,
              ]);
    });
  }

  void _toggleGroup(String title) {
    setState(() {
      if (!_collapsed.remove(title)) _collapsed.add(title);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Comparison? comparison = state.comparison;

    if (comparison == null) {
      return _EmptyComparison(onBack: state.goHome);
    }

    final SheetDiff diff = SheetDiff.compare(
      before: comparison.before.sheet,
      after: comparison.after.sheet,
      beforeLabel: comparison.before.label,
      afterLabel: comparison.after.label,
      lookup: state.catalogLookup,
    );
    final List<DiffGroup> groups = diff.groupsWith(onlyDifferences: _onlyDifferences);

    return Column(
      children: <Widget>[
        _TopBar(
          chatView: _chatView,
          onChatView: (bool v) => setState(() => _chatView = v),
          onlyDifferences: _onlyDifferences,
          onOnlyDifferences: (bool v) => _setOnlyDifferences(v, diff),
          onSwap: state.swapComparison,
          onBack: state.closeComparison,
          diff: diff,
          comparison: comparison,
        ),
        Expanded(
          child: _chatView
              ? _CyberpunkChatView(
                  diff: diff,
                  before: comparison.before,
                  after: comparison.after,
                  onlyDifferences: _onlyDifferences,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Entrance(
                            child: _Headers(
                              before: comparison.before,
                              after: comparison.after,
                              onSwap: state.swapComparison,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _Summary(diff: diff, shown: groups.length),
                          const SizedBox(height: 16),
                          for (final DiffGroup group in groups) ...<Widget>[
                            _GroupPanel(
                              group: group,
                              beforeLabel: comparison.before.label,
                              afterLabel: comparison.after.label,
                              collapsed: _collapsed.contains(group.title),
                              onToggle: () => _toggleGroup(group.title),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.chatView,
    required this.onChatView,
    required this.onlyDifferences,
    required this.onOnlyDifferences,
    required this.onSwap,
    required this.onBack,
    required this.diff,
    required this.comparison,
  });

  final bool chatView;
  final ValueChanged<bool> onChatView;
  final bool onlyDifferences;
  final ValueChanged<bool> onOnlyDifferences;
  final VoidCallback onSwap;
  final VoidCallback onBack;
  final SheetDiff diff;
  final Comparison comparison;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            Container(width: 4, height: 20, color: CprPalette.info),
            const SizedBox(width: 10),
            Text(
              'CONFRONTO',
              style: CprType.label.copyWith(fontSize: 13, letterSpacing: 2.4, color: CprPalette.ink),
            ),
            const SizedBox(width: 20),
            TechSegmented<bool>(
              value: chatView,
              items: const <bool>[false, true],
              labelOf: (bool v) => v ? 'Chat Cyberpunk' : 'Fianco a fianco',
              accent: CprPalette.info,
              onChanged: onChatView,
            ),
            const SizedBox(width: 10),
            TechSegmented<bool>(
              value: onlyDifferences,
              items: const <bool>[true, false],
              labelOf: (bool v) => v ? 'Solo diff' : 'Tutto',
              accent: CprPalette.info,
              onChanged: onOnlyDifferences,
            ),
            const SizedBox(width: 10),
            _ExportMenu(
              diff: diff,
              beforeLabel: comparison.before.label,
              afterLabel: comparison.after.label,
            ),
            const SizedBox(width: 8),
            TechButton(
              label: 'Inverti',
              icon: Icons.swap_horiz,
              variant: TechButtonVariant.ghost,
              compact: true,
              tooltip: 'Scambia le due schede',
              onPressed: onSwap,
            ),
            const SizedBox(width: 8),
            TechButton(
              label: 'Torna al menu',
              icon: Icons.arrow_back,
              variant: TechButtonVariant.secondary,
              compact: true,
              onPressed: onBack,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportMenu extends StatelessWidget {
  const _ExportMenu({
    required this.diff,
    required this.beforeLabel,
    required this.afterLabel,
  });

  final SheetDiff diff;
  final String beforeLabel;
  final String afterLabel;

  static String _sanitize(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_').toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: CprPalette.surfaceRaised,
      tooltip: 'Esporta confronto (Chat, HTML, JSON)',
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'chat',
          child: Row(
            children: <Widget>[
              const Icon(Icons.chat_bubble_outline, size: 16, color: CprPalette.info),
              const SizedBox(width: 8),
              Text(
                'Copia riepilogo chat',
                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'html',
          child: Row(
            children: <Widget>[
              const Icon(Icons.html, size: 16, color: CprPalette.success),
              const SizedBox(width: 8),
              Text(
                'Esporta file .html autonomo',
                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12),
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'json',
          child: Row(
            children: <Widget>[
              const Icon(Icons.data_object, size: 16, color: CprPalette.warning),
              const SizedBox(width: 8),
              Text(
                'Esporta file .json',
                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
      onSelected: (String action) async {
        if (action == 'chat') {
          final String summary = SheetDiffExport.toChatSummary(diff);
          await Clipboard.setData(ClipboardData(text: summary));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Riepilogo per chat copiato negli appunti.'),
                backgroundColor: CprPalette.success,
              ),
            );
          }
        } else if (action == 'html') {
          final String html = SheetDiffExport.toStandaloneHtml(diff);
          final String suggested = 'confronto_${_sanitize(beforeLabel)}_vs_${_sanitize(afterLabel)}.html';
          final String? path = await showFileBrowser(
            context,
            mode: FileBrowserMode.save,
            title: 'Salva confronto HTML autonomo',
            suggestedName: suggested,
            extensions: const <String>['.html', '.htm'],
          );
          if (path != null) {
            File(path).writeAsStringSync(html);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File HTML salvato: ${p.basename(path)}'),
                  backgroundColor: CprPalette.success,
                ),
              );
            }
          }
        } else if (action == 'json') {
          final String jsonStr = SheetDiffExport.toJsonString(diff);
          final String suggested = 'confronto_${_sanitize(beforeLabel)}_vs_${_sanitize(afterLabel)}.json';
          final String? path = await showFileBrowser(
            context,
            mode: FileBrowserMode.save,
            title: 'Salva confronto JSON',
            suggestedName: suggested,
            extensions: const <String>['.json'],
          );
          if (path != null) {
            File(path).writeAsStringSync(jsonStr);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File JSON salvato: ${p.basename(path)}'),
                  backgroundColor: CprPalette.success,
                ),
              );
            }
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CprPalette.veil(CprPalette.info, 0.1),
          border: Border.all(color: CprPalette.info),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.file_download_outlined, size: 14, color: CprPalette.info),
            const SizedBox(width: 6),
            Text(
              'ESPORTA',
              style: CprType.label.copyWith(color: CprPalette.info, fontSize: 11),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 14, color: CprPalette.info),
          ],
        ),
      ),
    );
  }
}

/// Le due schede, una accanto all'altra, con al centro il comando per
/// invertirle.
class _Headers extends StatelessWidget {
  const _Headers({required this.before, required this.after, required this.onSwap});

  final ComparisonSide before;
  final ComparisonSide after;
  final VoidCallback onSwap;

  @override
  Widget build(BuildContext context) {
    // `center` e non `stretch`: in una pagina che scorre l'altezza non e'
    // limitata, e `stretch` chiederebbe ai figli di riempire un'altezza
    // infinita. Le due schede si allineano al centro l'una dell'altra.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: _SideCard(side: before, role: 'Prima', accent: CprPalette.danger)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(
            child: TechButton(
              label: 'Inverti',
              icon: Icons.swap_horiz,
              variant: TechButtonVariant.ghost,
              compact: true,
              tooltip: 'Scambia prima e dopo',
              onPressed: onSwap,
            ),
          ),
        ),
        Expanded(child: _SideCard(side: after, role: 'Dopo', accent: CprPalette.success)),
      ],
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.side, required this.role, required this.accent});

  final ComparisonSide side;
  final String role;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: role,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            side.label,
            style: CprType.title.copyWith(fontSize: 17, color: CprPalette.ink),
          ),
          const SizedBox(height: 6),
          if (side.path == null)
            Text(
              'Mai salvata su disco',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            )
          else ...<Widget>[
            Text(
              side.fileName,
              style: CprType.caption.copyWith(
                color: CprPalette.inkMuted,
                fontFamilyFallback: CprType.monoFamily,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              side.folder,
              overflow: TextOverflow.ellipsis,
              style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: <Widget>[
              if (side.savedAt.isNotEmpty)
                _Badge(text: 'salvata ${_prettyDate(side.savedAt)}', color: CprPalette.inkFaint),
              // Una scheda aperta e modificata e' una versione che su disco non
              // esiste: dirlo e' la differenza fra un confronto e un malinteso.
              if (side.dirty) _Badge(text: 'modifiche non salvate', color: CprPalette.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: CprPalette.veil(color, 0.12),
      child: Text(
        text.toUpperCase(),
        style: CprType.label.copyWith(color: color, fontSize: 9),
      ),
    );
  }
}

/// La riga di riepilogo: dice quante differenze ci sono **prima** che l'utente
/// le cerchi, cosi' sa se sta guardando la scheda sbagliata.
class _Summary extends StatelessWidget {
  const _Summary({required this.diff, required this.shown});

  final SheetDiff diff;
  final int shown;

  @override
  Widget build(BuildContext context) {
    final bool identical = diff.identical;
    final Color color = identical ? CprPalette.success : CprPalette.warning;

    return Row(
      children: <Widget>[
        Icon(
          identical ? Icons.check_circle_outline : Icons.difference_outlined,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            identical
                ? 'Le due schede sono identiche in tutto quello che si confronta.'
                : '${diff.changes} ${diff.changes == 1 ? 'differenza' : 'differenze'} '
                    'in ${diff.changedGroups} ${diff.changedGroups == 1 ? 'sezione' : 'sezioni'}.',
            style: CprType.body.copyWith(color: color, fontSize: 13),
          ),
        ),
        Text(
          'sezioni mostrate: $shown',
          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
        ),
      ],
    );
  }
}

class _GroupPanel extends StatelessWidget {
  const _GroupPanel({
    required this.group,
    required this.beforeLabel,
    required this.afterLabel,
    required this.collapsed,
    required this.onToggle,
  });

  final DiffGroup group;
  final String beforeLabel;
  final String afterLabel;
  final bool collapsed;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final Color accent =
        group.hasChanges ? CprPalette.warning : CprPalette.inkFaint;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        // Tutta la sezione e' toccabile per chiuderla: dentro una riga non c'e'
        // niente da premere, quindi non si toglie niente a nessuno.
        onTap: onToggle,
        child: ChamferPanel(
          title: group.title,
          accent: group.hasChanges ? accent : null,
          headerSpacing: collapsed ? 0 : 12,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                group.hasChanges ? '${group.changes}' : 'nessuna',
                style: CprType.label.copyWith(
                  color: accent,
                  fontSize: 9.5,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                duration: CprMotion.fast,
                turns: collapsed ? 0 : 0.25,
                child: Icon(Icons.chevron_right, size: 15, color: accent),
              ),
            ],
          ),
          child: collapsed
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _ColumnHeaders(beforeLabel: beforeLabel, afterLabel: afterLabel),
                    for (final DiffRow row in group.rows) _Row(row: row),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Intestazione delle due colonne, ripetuta in ogni sezione.
///
/// Sembra una ripetizione inutile e non lo e': con sezioni lunghe si scorre
/// parecchio, e quando la testata e' uscita dallo schermo non si sa piu' quale
/// colonna sia la scheda di prima e quale quella di adesso.
class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.beforeLabel, required this.afterLabel});

  final String beforeLabel;
  final String afterLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          const SizedBox(width: _labelWidth),
          Expanded(
            child: Text(
              'prima · $beforeLabel',
              overflow: TextOverflow.ellipsis,
              style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 9.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'dopo · $afterLabel',
              overflow: TextOverflow.ellipsis,
              style: CprType.label.copyWith(color: CprPalette.success, fontSize: 9.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Larghezza della colonna delle etichette: fissa, cosi' i valori delle due
/// schede stanno sempre nella stessa posizione da una riga all'altra.
const double _labelWidth = 214;

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final DiffRow row;

  @override
  Widget build(BuildContext context) {
    final DiffState state = row.state;

    final Color background = switch (state) {
      DiffState.unchanged => Colors.transparent,
      DiffState.changed => CprPalette.veil(CprPalette.warning, 0.05),
      DiffState.added => CprPalette.veil(CprPalette.success, 0.06),
      DiffState.removed => CprPalette.veil(CprPalette.danger, 0.06),
    };

    return Container(
      decoration: BoxDecoration(
        color: background,
        border: state == DiffState.unchanged
            ? null
            : Border(left: BorderSide(color: _stateColor(state), width: 2)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: _labelWidth - 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.label,
                  style: CprType.caption.copyWith(
                    color: state == DiffState.unchanged ? CprPalette.inkMuted : CprPalette.ink,
                    fontSize: 12.5,
                  ),
                ),
                if (row.detail != null)
                  Text(
                    row.detail!,
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
                  ),
                if (row.note != null)
                  Text(
                    row.note!,
                    style: CprType.caption.copyWith(color: CprPalette.warning, fontSize: 10.5),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _Cell(
              value: row.before,
              side: _Side.left,
              state: state,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Cell(
              value: row.after,
              side: _Side.right,
              state: state,
            ),
          ),
        ],
      ),
    );
  }

  static Color _stateColor(DiffState state) => switch (state) {
        DiffState.added => CprPalette.success,
        DiffState.removed => CprPalette.danger,
        DiffState.changed => CprPalette.warning,
        DiffState.unchanged => CprPalette.hairline,
      };
}

enum _Side { left, right }

class _Cell extends StatelessWidget {
  const _Cell({required this.value, required this.side, required this.state});

  final String? value;
  final _Side side;
  final DiffState state;

  @override
  Widget build(BuildContext context) {
    // Il segno accompagna il colore: da solo il colore chiede di ricordarsi
    // quale delle due colonne e' quella nuova, e a meta' pagina non ce lo si
    // ricorda piu'.
    final String? mark = switch ((state, side)) {
      (DiffState.added, _Side.right) => '+',
      (DiffState.removed, _Side.left) => '−',
      (DiffState.changed, _Side.left) => '−',
      (DiffState.changed, _Side.right) => '+',
      _ => null,
    };

    final Color color = switch ((state, side)) {
      (DiffState.unchanged, _) => CprPalette.inkMuted,
      (DiffState.added, _Side.right) => CprPalette.success,
      (DiffState.removed, _Side.left) => CprPalette.danger,
      (DiffState.changed, _Side.left) => CprPalette.danger,
      (DiffState.changed, _Side.right) => CprPalette.success,
      // Il lato che non ha il valore: c'e' una riga sola, e questa e' la
      // colonna vuota.
      _ => CprPalette.inkFaint,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 12,
          child: mark == null
              ? null
              : Text(
                  mark,
                  style: CprType.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
        ),
        Expanded(
          child: Text(
            value ?? '—',
            style: CprType.caption.copyWith(
              color: color,
              fontSize: 12.5,
              fontFamilyFallback: CprType.monoFamily,
              height: 1.35,
              decoration: state == DiffState.removed && side == _Side.left
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cosa si vede se si arriva qui senza un confronto aperto.
///
/// Non dovrebbe succedere, e proprio per questo non deve restare una schermata
/// vuota: un riquadro nero senza spiegazione e' indistinguibile da un difetto.
class _EmptyComparison extends StatelessWidget {
  const _EmptyComparison({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: ChamferPanel(
          title: 'Confronto',
          accent: CprPalette.info,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Non c\'e\' nessun confronto aperto.',
                style: CprType.body.copyWith(color: CprPalette.ink),
              ),
              const SizedBox(height: 6),
              Text(
                'Si apre dal menu principale ("Confronta due schede") oppure dalle '
                'impostazioni di una scheda aperta.',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              TechButton(
                label: 'Torna al menu',
                icon: Icons.arrow_back,
                variant: TechButtonVariant.secondary,
                onPressed: onBack,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Data in breve, come nell'elenco dei documenti.
String _prettyDate(String iso) {
  final DateTime? parsed = DateTime.tryParse(iso);
  if (parsed == null) return iso;
  final DateTime local = parsed.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}

/// Visualizzazione del confronto strutturata come una chat cyberpunk con intercettazione
/// tra i due personaggi/agenti sulla rete (Netwatch / Sub-Net feed).
class _CyberpunkChatView extends StatelessWidget {
  const _CyberpunkChatView({
    required this.diff,
    required this.before,
    required this.after,
    required this.onlyDifferences,
  });

  final SheetDiff diff;
  final ComparisonSide before;
  final ComparisonSide after;
  final bool onlyDifferences;

  @override
  Widget build(BuildContext context) {
    final List<DiffGroup> groups = diff.groupsWith(onlyDifferences: onlyDifferences);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Terminal intercept header
              _ChatTerminalHeader(
                beforeName: before.label,
                afterName: after.label,
                changesCount: diff.changes,
                groupsCount: diff.changedGroups,
              ),
              const SizedBox(height: 16),
              if (groups.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: CprPalette.surfaceRaised,
                    border: Border.all(color: CprPalette.success),
                  ),
                  child: Center(
                    child: Text(
                      'NESSUNA DIFFERENZA RILEVATA TRA I DUE PERSONAGGI.',
                      style: CprType.label.copyWith(color: CprPalette.success, letterSpacing: 1.5),
                    ),
                  ),
                )
              else
                for (final DiffGroup group in groups) ...<Widget>[
                  _ChatGroupHeader(title: group.title, changes: group.changes),
                  const SizedBox(height: 10),
                  for (final DiffRow row in group.rows) ...<Widget>[
                    _buildRowChat(row),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 14),
                ],
              // Terminal footer
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: CprPalette.surfaceSunken,
                  border: Border(top: BorderSide(color: CprPalette.hairline)),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CprPalette.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'STREAM DIALOGO COMPLETATO // PACCHETTI SINCRONIZZATI AL 100%',
                      style: CprType.label.copyWith(
                        color: CprPalette.inkMuted,
                        fontSize: 10,
                        letterSpacing: 1.2,
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

  Widget _buildRowChat(DiffRow row) {
    switch (row.state) {
      case DiffState.changed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ChatBubble(
              sender: before.label,
              role: 'ORIGINE [PRIMA]',
              message: '«${row.label}» registrato a: «${row.before ?? 'non presente'}».',
              accent: CprPalette.danger,
              isLeft: true,
            ),
            const SizedBox(height: 6),
            _ChatBubble(
              sender: after.label,
              role: 'DESTINAZIONE [DOPO]',
              message: 'Override confermato: «${row.label}» aggiornato a «${row.after ?? 'non presente'}».'
                  '${row.detail != null ? '\n[Parametri]: ${row.detail}' : ''}'
                  '${row.note != null ? '\n[Nota]: ${row.note}' : ''}',
              accent: CprPalette.success,
              isLeft: false,
            ),
            const SizedBox(height: 4),
            _DeltaPill(
              label: row.label,
              before: row.before,
              after: row.after,
              state: DiffState.changed,
            ),
          ],
        );
      case DiffState.added:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ChatBubble(
              sender: after.label,
              role: 'DESTINAZIONE [DOPO]',
              message: 'Nuovo modulo acquisito: «${row.label}» = «${row.after ?? ''}».'
                  '${row.detail != null ? '\n[Parametri]: ${row.detail}' : ''}',
              accent: CprPalette.success,
              isLeft: false,
            ),
            const SizedBox(height: 4),
            _DeltaPill(
              label: row.label,
              before: null,
              after: row.after,
              state: DiffState.added,
            ),
          ],
        );
      case DiffState.removed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ChatBubble(
              sender: before.label,
              role: 'ORIGINE [PRIMA]',
              message: 'Componente rimosso o disconnesso: «${row.label}» (era «${row.before ?? ''}»). Assente nel profilo bersaglio.',
              accent: CprPalette.danger,
              isLeft: true,
            ),
            const SizedBox(height: 4),
            _DeltaPill(
              label: row.label,
              before: row.before,
              after: null,
              state: DiffState.removed,
            ),
          ],
        );
      case DiffState.unchanged:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: CprPalette.veil(CprPalette.inkMuted, 0.05),
            border: const Border(left: BorderSide(color: CprPalette.hairline, width: 2)),
          ),
          child: Row(
            children: <Widget>[
              Text(
                '[SYNC] ${row.label}:',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Text(
                row.before ?? '—',
                style: CprType.caption.copyWith(
                  color: CprPalette.ink,
                  fontSize: 11,
                  fontFamilyFallback: CprType.monoFamily,
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _ChatTerminalHeader extends StatelessWidget {
  const _ChatTerminalHeader({
    required this.beforeName,
    required this.afterName,
    required this.changesCount,
    required this.groupsCount,
  });

  final String beforeName;
  final String afterName;
  final int changesCount;
  final int groupsCount;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'NETRUNNER INTERCEPT // FEED DIALOGO',
      accent: CprPalette.info,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.hub_outlined, size: 16, color: CprPalette.info),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CANALE INTERCETTAZIONE: 2045-DELTA // CRITTOGRAFIA QUANTISTICA',
                  style: CprType.label.copyWith(
                    color: CprPalette.info,
                    fontSize: 11,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CprPalette.veil(CprPalette.danger, 0.08),
                    border: const Border(left: BorderSide(color: CprPalette.danger, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('AGENTE ALPHA [PRIMA]', style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 9)),
                      Text(beforeName, style: CprType.title.copyWith(color: CprPalette.ink, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.sync_alt, color: CprPalette.warning, size: 20),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CprPalette.veil(CprPalette.success, 0.08),
                    border: const Border(left: BorderSide(color: CprPalette.success, width: 3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('AGENTE BETA [DOPO]', style: CprType.label.copyWith(color: CprPalette.success, fontSize: 9)),
                      Text(afterName, style: CprType.title.copyWith(color: CprPalette.ink, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'ANOMALIE DI STATO: $changesCount variazioni distribuite su $groupsCount settori.',
            style: CprType.caption.copyWith(color: CprPalette.warning, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _ChatGroupHeader extends StatelessWidget {
  const _ChatGroupHeader({required this.title, required this.changes});

  final String title;
  final int changes;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.info, 0.08),
        border: const Border(
          bottom: BorderSide(color: CprPalette.info, width: 1.5),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.dns_outlined, size: 14, color: CprPalette.info),
          const SizedBox(width: 8),
          Text(
            '// SETTORE DATATERM: ${title.toUpperCase()}',
            style: CprType.label.copyWith(
              color: CprPalette.ink,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            color: changes > 0 ? CprPalette.veil(CprPalette.warning, 0.2) : CprPalette.veil(CprPalette.hairline, 0.4),
            child: Text(
              '$changes delta',
              style: CprType.label.copyWith(
                color: changes > 0 ? CprPalette.warning : CprPalette.inkFaint,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.sender,
    required this.role,
    required this.message,
    required this.accent,
    required this.isLeft,
  });

  final String sender;
  final String role;
  final String message;
  final Color accent;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: EdgeInsets.only(
          left: isLeft ? 0 : 40,
          right: isLeft ? 40 : 0,
        ),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: CprPalette.surfaceRaised,
          border: Border(
            left: isLeft ? BorderSide(color: accent, width: 3) : const BorderSide(color: CprPalette.hairline),
            right: !isLeft ? BorderSide(color: accent, width: 3) : const BorderSide(color: CprPalette.hairline),
            top: const BorderSide(color: CprPalette.hairline),
            bottom: const BorderSide(color: CprPalette.hairline),
          ),
        ),
        child: Column(
          crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (isLeft) ...<Widget>[
                  Icon(Icons.radio_button_checked, size: 10, color: accent),
                  const SizedBox(width: 6),
                ],
                Text(
                  '$sender · $role',
                  style: CprType.label.copyWith(
                    color: accent,
                    fontSize: 9.5,
                    letterSpacing: 1.1,
                  ),
                ),
                if (!isLeft) ...<Widget>[
                  const SizedBox(width: 6),
                  Icon(Icons.radio_button_checked, size: 10, color: accent),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: isLeft ? TextAlign.left : TextAlign.right,
              style: CprType.body.copyWith(
                color: CprPalette.ink,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeltaPill extends StatelessWidget {
  const _DeltaPill({
    required this.label,
    required this.before,
    required this.after,
    required this.state,
  });

  final String label;
  final String? before;
  final String? after;
  final DiffState state;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (state) {
      DiffState.changed => CprPalette.warning,
      DiffState.added => CprPalette.success,
      DiffState.removed => CprPalette.danger,
      DiffState.unchanged => CprPalette.inkMuted,
    };

    final String text = switch (state) {
      DiffState.changed => 'DELTA // $label: «${before ?? '—'}» ➔ «${after ?? '—'}»',
      DiffState.added => '+ ACQUISIZIONE // $label = «${after ?? ''}»',
      DiffState.removed => '- RIMOZIONE // $label (precedente: «${before ?? ''}»)',
      DiffState.unchanged => 'SYNC // $label',
    };

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: CprPalette.veil(color, 0.12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
        ),
        child: Text(
          text,
          style: CprType.caption.copyWith(
            color: color,
            fontSize: 10,
            fontFamilyFallback: CprType.monoFamily,
          ),
        ),
      ),
    );
  }
}

