import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/sheet_diff.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/entrance.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

/// Confronto fianco a fianco fra due schede.
///
/// La forma della schermata e' la funzione: due colonne **allineate riga per
/// riga**, cosi' l'occhio scorre in verticale e trova la differenza invece di
/// cercarla. L'alternativa — due schede una sotto l'altra, o un elenco di
/// "prima: X, dopo: Y" — costringe a ricostruire a mente il confronto, che e'
/// esattamente il lavoro che il programma deve risparmiare.
///
/// Tre scelte che si vedono:
///
/// * **il codice colore dice cosa e' successo**, non quanto e' importante: un
///   valore tolto e' rosso, uno aggiunto e' verde, e le due colonne di una riga
///   che e' cambiata portano i due colori insieme;
/// * **la vista parte dalle differenze**, perche' e' quello che si sta
///   cercando; "tutto" e' a un clic, e serve a confermare che una cosa *non* e'
///   cambiata — che e' una domanda legittima e diversa;
/// * **le sezioni si chiudono**, perche' "Abilita" sono 68 righe e in mezzo a
///   quelle la differenza che interessa si perde.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  /// True mostra solo le righe che differiscono. E' il default perche' e' il
  /// motivo per cui si apre un confronto.
  bool _onlyDifferences = true;

  /// Le sezioni chiuse a mano (o chiuse perche' non contengono differenze).
  final Set<String> _collapsed = <String>{};

  void _setOnlyDifferences(bool value, SheetDiff diff) {
    setState(() {
      _onlyDifferences = value;
      _collapsed
        ..clear()
        // In "tutto" le sezioni senza differenze partono chiuse: servono a
        // confermare che li' non e' cambiato niente, e per dirlo basta il
        // titolo con il suo conteggio.
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
          onlyDifferences: _onlyDifferences,
          onOnlyDifferences: (bool v) => _setOnlyDifferences(v, diff),
          onSwap: state.swapComparison,
          onBack: state.closeComparison,
        ),
        Expanded(
          child: SingleChildScrollView(
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
    required this.onlyDifferences,
    required this.onOnlyDifferences,
    required this.onSwap,
    required this.onBack,
  });

  final bool onlyDifferences;
  final ValueChanged<bool> onOnlyDifferences;
  final VoidCallback onSwap;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Container(width: 4, height: 20, color: CprPalette.info),
          const SizedBox(width: 10),
          Text(
            'CONFRONTO',
            style: CprType.label.copyWith(fontSize: 13, letterSpacing: 2.4, color: CprPalette.ink),
          ),
          const Spacer(),
          TechSegmented<bool>(
            value: onlyDifferences,
            items: const <bool>[true, false],
            labelOf: (bool v) => v ? 'Solo differenze' : 'Tutto',
            accent: CprPalette.info,
            onChanged: onOnlyDifferences,
          ),
          const SizedBox(width: 12),
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
