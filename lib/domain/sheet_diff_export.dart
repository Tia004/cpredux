import 'dart:convert';

import 'sheet_diff.dart';

/// Esportazione di un confronto fra schede in tre formati:
///
/// 1. [toChatSummary]: testo semplice con markup Cyberpunk pronto da incollare
///    in chat (Discord, Telegram, o il tavolo stesso);
/// 2. [toStandaloneHtml]: file HTML autonomo con grafica Cyberpunk completa,
///    apribile offline in qualsiasi browser moderno;
/// 3. [toJsonString]: struttura dati JSON serializzabile e pronta per essere
///    archiviata o riletta.
abstract final class SheetDiffExport {
  /// Genera un riepilogo testuale ottimizzato per la chat.
  static String toChatSummary(SheetDiff diff, {bool onlyDifferences = true}) {
    final StringBuffer buf = StringBuffer();
    buf.writeln('╔═══════════════════════════════════════════════════════════════╗');
    buf.writeln('  CONFRONTO SCHEDE // CYBERPUNK RED');
    buf.writeln('  [PRIMA]: ${diff.beforeLabel}');
    buf.writeln('  [DOPO] : ${diff.afterLabel}');
    if (diff.identical) {
      buf.writeln('  ESITO  : Nessuna differenza rilevata (schede identiche)');
      buf.writeln('╚═══════════════════════════════════════════════════════════════╝');
      return buf.toString();
    }

    buf.writeln('  VARIAZIONI: ${diff.changes} in ${diff.changedGroups} sezioni');
    buf.writeln('╚═══════════════════════════════════════════════════════════════╝');
    buf.writeln();

    final List<DiffGroup> groups = diff.groupsWith(onlyDifferences: onlyDifferences);
    for (final DiffGroup group in groups) {
      buf.writeln('▶ [${group.title.toUpperCase()}] (${group.changes} variazioni)');
      for (final DiffRow row in group.rows) {
        switch (row.state) {
          case DiffState.changed:
            buf.write('  ~ ${row.label}: ${row.before ?? "—"} → ${row.after ?? "—"}');
            if (row.detail != null && row.detail!.isNotEmpty) {
              buf.write(' (${row.detail})');
            }
            buf.writeln();
          case DiffState.added:
            buf.write('  + ${row.label}: ${row.after ?? "—"} [AGGIUNTO]');
            if (row.detail != null && row.detail!.isNotEmpty) {
              buf.write(' (${row.detail})');
            }
            buf.writeln();
          case DiffState.removed:
            buf.write('  - ${row.label}: ${row.before ?? "—"} [RIMOSSO]');
            if (row.detail != null && row.detail!.isNotEmpty) {
              buf.write(' (${row.detail})');
            }
            buf.writeln();
          case DiffState.unchanged:
            if (!onlyDifferences) {
              buf.writeln('    ${row.label}: ${row.after ?? row.before ?? "—"}');
            }
        }
      }
      buf.writeln();
    }

    buf.writeln('— Trasmesso via CPRED Visualizer —');
    return buf.toString();
  }

  /// Genera un file HTML autonomo Cyberpunk completo di CSS interno.
  static String toStandaloneHtml(SheetDiff diff) {
    final String timestamp = DateTime.now().toIso8601String().substring(0, 19).replaceAll('T', ' ');

    final StringBuffer html = StringBuffer();
    html.writeln('<!DOCTYPE html>');
    html.writeln('<html lang="it">');
    html.writeln('<head>');
    html.writeln('  <meta charset="UTF-8">');
    html.writeln('  <meta name="viewport" content="width=device-width, initial-scale=1.0">');
    html.writeln('  <title>Confronto Schede: ${htmlEscape(diff.beforeLabel)} vs ${htmlEscape(diff.afterLabel)}</title>');
    html.writeln('  <style>');
    html.writeln('''
      :root {
        --bg-void: #06090e;
        --bg-surface: #0c1118;
        --bg-panel: #111822;
        --border-color: #1e293b;
        --border-active: #334155;
        --text-bright: #f8fafc;
        --text-muted: #94a3b8;
        --text-faint: #475569;
        --neon-cyan: #00f0ff;
        --neon-yellow: #fcee0a;
        --neon-magenta: #ff003c;
        --neon-green: #00ff66;
        --font-mono: 'Consolas', 'JetBrains Mono', 'Menlo', monospace;
      }
      * { box-sizing: border-box; margin: 0; padding: 0; }
      body {
        background-color: var(--bg-void);
        color: var(--text-bright);
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
        line-height: 1.5;
        padding: 2rem 1rem;
      }
      .container {
        max-width: 1080px;
        margin: 0 auto;
      }
      header {
        border: 1px solid var(--border-color);
        border-left: 5px solid var(--neon-cyan);
        background: var(--bg-surface);
        padding: 1.5rem 2rem;
        margin-bottom: 2rem;
        position: relative;
        overflow: hidden;
      }
      header::after {
        content: "NET_DIFF_V1";
        position: absolute;
        top: 10px;
        right: 15px;
        font-family: var(--font-mono);
        font-size: 0.75rem;
        color: var(--text-faint);
        letter-spacing: 2px;
      }
      h1 {
        font-size: 1.5rem;
        letter-spacing: 1px;
        color: var(--neon-cyan);
        text-transform: uppercase;
        margin-bottom: 0.5rem;
      }
      .meta {
        display: flex;
        flex-wrap: wrap;
        gap: 1.5rem;
        font-size: 0.9rem;
        color: var(--text-muted);
        font-family: var(--font-mono);
        margin-top: 1rem;
      }
      .badge {
        display: inline-block;
        padding: 3px 8px;
        font-size: 0.8rem;
        font-weight: bold;
        font-family: var(--font-mono);
        border-radius: 2px;
        text-transform: uppercase;
      }
      .badge-diff { background: rgba(252, 238, 10, 0.15); color: var(--neon-yellow); border: 1px solid var(--neon-yellow); }
      .badge-groups { background: rgba(0, 240, 255, 0.15); color: var(--neon-cyan); border: 1px solid var(--neon-cyan); }
      .filter-bar {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 1.5rem;
        padding: 0.75rem 1rem;
        background: var(--bg-surface);
        border: 1px solid var(--border-color);
      }
      button.cyber-btn {
        background: transparent;
        color: var(--neon-cyan);
        border: 1px solid var(--neon-cyan);
        padding: 6px 14px;
        font-family: var(--font-mono);
        font-size: 0.85rem;
        cursor: pointer;
        transition: all 0.2s ease;
      }
      button.cyber-btn:hover {
        background: var(--neon-cyan);
        color: var(--bg-void);
      }
      .group-card {
        background: var(--bg-surface);
        border: 1px solid var(--border-color);
        margin-bottom: 1.5rem;
      }
      .group-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.75rem 1.25rem;
        background: var(--bg-panel);
        border-bottom: 1px solid var(--border-color);
        border-left: 3px solid var(--neon-yellow);
        font-size: 1.05rem;
        font-weight: 600;
      }
      .group-header.no-change {
        border-left-color: var(--text-faint);
        color: var(--text-muted);
      }
      .diff-table {
        width: 100%;
        border-collapse: collapse;
        font-size: 0.9rem;
      }
      .diff-table th {
        text-align: left;
        padding: 8px 16px;
        background: rgba(255,255,255,0.02);
        color: var(--text-muted);
        font-family: var(--font-mono);
        font-size: 0.8rem;
        border-bottom: 1px solid var(--border-color);
      }
      .diff-table td {
        padding: 10px 16px;
        border-bottom: 1px solid rgba(255,255,255,0.04);
        vertical-align: top;
      }
      .diff-row:hover {
        background: rgba(255,255,255,0.02);
      }
      .row-changed { background: rgba(252, 238, 10, 0.03); }
      .row-added { background: rgba(0, 255, 102, 0.04); }
      .row-removed { background: rgba(255, 0, 60, 0.04); }
      .tag-added { color: var(--neon-green); font-weight: bold; font-family: var(--font-mono); }
      .tag-removed { color: var(--neon-magenta); font-weight: bold; font-family: var(--font-mono); }
      .tag-changed { color: var(--neon-yellow); font-weight: bold; font-family: var(--font-mono); }
      .val-before { color: var(--text-muted); }
      .val-after { color: var(--text-bright); font-weight: 600; }
      .arrow { color: var(--neon-cyan); margin: 0 6px; }
      .row-detail { font-size: 0.8rem; color: var(--text-faint); margin-top: 2px; }
      footer {
        text-align: center;
        margin-top: 3rem;
        color: var(--text-faint);
        font-size: 0.8rem;
        font-family: var(--font-mono);
      }
      @media print {
        body { background: white; color: black; }
        header, .group-card, .filter-bar { border: 1px solid #ccc; background: white; color: black; }
        .filter-bar { display: none; }
      }
    ''');
    html.writeln('  </style>');
    html.writeln('</head>');
    html.writeln('<body>');
    html.writeln('  <div class="container">');
    html.writeln('    <header>');
    html.writeln('      <h1>Confronto Schede // Cyberpunk RED</h1>');
    html.writeln('      <div class="meta">');
    html.writeln('        <div><strong>Prima:</strong> ${htmlEscape(diff.beforeLabel)}</div>');
    html.writeln('        <div><strong>Dopo:</strong> ${htmlEscape(diff.afterLabel)}</div>');
    html.writeln('        <div><strong>Generato:</strong> $timestamp</div>');
    html.writeln('      </div>');
    html.writeln('      <div style="margin-top: 1rem;">');
    html.writeln('        <span class="badge badge-diff">${diff.changes} differenze</span> ');
    html.writeln('        <span class="badge badge-groups">${diff.changedGroups} sezioni modificate</span>');
    html.writeln('      </div>');
    html.writeln('    </header>');

    html.writeln('    <div class="filter-bar">');
    html.writeln('      <span id="filter-status" style="font-family: var(--font-mono); font-size: 0.85rem; color: var(--text-muted);">Visualizzazione completa</span>');
    html.writeln('      <button class="cyber-btn" onclick="toggleOnlyDiffs()">Filtra solo differenze</button>');
    html.writeln('    </div>');

    for (final DiffGroup group in diff.groups) {
      final String groupClass = group.hasChanges ? '' : 'no-change';
      final String dataChanges = group.hasChanges ? 'true' : 'false';
      html.writeln('    <section class="group-card group-section" data-has-changes="$dataChanges">');
      html.writeln('      <div class="group-header $groupClass">');
      html.writeln('        <span>${htmlEscape(group.title)}</span>');
      if (group.hasChanges) {
        html.writeln('        <span class="badge badge-diff">${group.changes} variazioni</span>');
      } else {
        html.writeln('        <span style="font-size: 0.8rem; color: var(--text-faint);">Invariata</span>');
      }
      html.writeln('      </div>');
      html.writeln('      <table class="diff-table">');
      html.writeln('        <thead>');
      html.writeln('          <tr>');
      html.writeln('            <th style="width: 35%;">Elemento</th>');
      html.writeln('            <th style="width: 15%;">Stato</th>');
      html.writeln('            <th style="width: 50%;">Variazione</th>');
      html.writeln('          </tr>');
      html.writeln('        </thead>');
      html.writeln('        <tbody>');
      for (final DiffRow row in group.rows) {
        final String rowClass;
        final String stateTag;
        switch (row.state) {
          case DiffState.added:
            rowClass = 'row-added';
            stateTag = '<span class="tag-added">+ AGGIUNTO</span>';
          case DiffState.removed:
            rowClass = 'row-removed';
            stateTag = '<span class="tag-removed">- RIMOSSO</span>';
          case DiffState.changed:
            rowClass = 'row-changed';
            stateTag = '<span class="tag-changed">~ MODIFICATO</span>';
          case DiffState.unchanged:
            rowClass = 'row-unchanged';
            stateTag = '<span style="color: var(--text-faint);">INVARIATO</span>';
        }

        html.writeln('          <tr class="diff-row $rowClass" data-is-change="${row.isChange}">');
        html.writeln('            <td>');
        html.writeln('              <strong>${htmlEscape(row.label)}</strong>');
        if (row.note != null && row.note!.isNotEmpty) {
          html.writeln('              <div class="row-detail">${htmlEscape(row.note!)}</div>');
        }
        html.writeln('            </td>');
        html.writeln('            <td>$stateTag</td>');
        html.writeln('            <td>');
        if (row.state == DiffState.changed) {
          html.writeln('              <span class="val-before">${htmlEscape(row.before ?? "—")}</span>');
          html.writeln('              <span class="arrow">→</span>');
          html.writeln('              <span class="val-after">${htmlEscape(row.after ?? "—")}</span>');
        } else if (row.state == DiffState.added) {
          html.writeln('              <span class="val-after">${htmlEscape(row.after ?? "—")}</span>');
        } else if (row.state == DiffState.removed) {
          html.writeln('              <span class="val-before">${htmlEscape(row.before ?? "—")}</span>');
        } else {
          html.writeln('              <span style="color: var(--text-muted);">${htmlEscape(row.after ?? row.before ?? "—")}</span>');
        }
        if (row.detail != null && row.detail!.isNotEmpty) {
          html.writeln('              <div class="row-detail">${htmlEscape(row.detail!)}</div>');
        }
        html.writeln('            </td>');
        html.writeln('          </tr>');
      }
      html.writeln('        </tbody>');
      html.writeln('      </table>');
      html.writeln('    </section>');
    }

    html.writeln('    <footer>');
    html.writeln('      Esportato da CPRED Visualizer · Confronto Schede Cyberpunk RED');
    html.writeln('    </footer>');
    html.writeln('  </div>');
    html.writeln('  <script>');
    html.writeln('''
      let onlyDiffs = false;
      function toggleOnlyDiffs() {
        onlyDiffs = !onlyDiffs;
        document.getElementById('filter-status').innerText = onlyDiffs ? "Mostrando solo differenze" : "Visualizzazione completa";
        document.querySelectorAll('.group-section').forEach(sec => {
          if (onlyDiffs && sec.getAttribute('data-has-changes') === 'false') {
            sec.style.display = 'none';
          } else {
            sec.style.display = 'block';
          }
        });
        document.querySelectorAll('.row-unchanged').forEach(r => {
          r.style.display = onlyDiffs ? 'none' : '';
        });
      }
    ''');
    html.writeln('  </script>');
    html.writeln('</body>');
    html.writeln('</html>');
    return html.toString();
  }

  /// Genera una rappresentazione JSON strutturata del confronto.
  static String toJsonString(SheetDiff diff, {bool pretty = true}) {
    final Map<String, Object?> map = <String, Object?>{
      'format': 'cpredux_diff_v1',
      'exportedAt': DateTime.now().toIso8601String(),
      'beforeLabel': diff.beforeLabel,
      'afterLabel': diff.afterLabel,
      'changes': diff.changes,
      'changedGroups': diff.changedGroups,
      'identical': diff.identical,
      'groups': <Map<String, Object?>>[
        for (final DiffGroup g in diff.groups)
          <String, Object?>{
            'title': g.title,
            'changes': g.changes,
            'hasChanges': g.hasChanges,
            'rows': <Map<String, Object?>>[
              for (final DiffRow r in g.rows)
                <String, Object?>{
                  'label': r.label,
                  'before': r.before,
                  'after': r.after,
                  'state': r.state.name,
                  'isChange': r.isChange,
                  if (r.detail != null) 'detail': r.detail,
                  if (r.note != null) 'note': r.note,
                },
            ],
          },
      ],
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(map)
        : jsonEncode(map);
  }

  static String htmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}
