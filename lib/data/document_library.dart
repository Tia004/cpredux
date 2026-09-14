import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/enums.dart';
import 'app_paths.dart';
import 'cpredux_file.dart';

/// Un documento trovato sul disco.
///
/// `kind` viene letto **dal contenuto** e non dal nome del file: entrambi i tipi
/// usano `.cpredux`, e fidarsi del nome significherebbe elencare una campagna
/// ridenominata fra le schede. E' la stessa regola dell'apertura, applicata
/// all'elenco.
class DocumentEntry {
  const DocumentEntry({
    required this.path,
    required this.name,
    required this.kind,
    required this.modified,
    this.updatedAt = '',
    this.readable = true,
  });

  final String path;
  final String name;
  final DocumentKind kind;

  /// Data di modifica del file, per ordinare l'elenco.
  final DateTime modified;

  /// Quando il documento dice di essere stato aggiornato l'ultima volta.
  final String updatedAt;

  /// False se il file c'e' ma non si apre (corrotto, di un'altra versione,
  /// non e' un `.cpredux`). Compare lo stesso, segnato: un documento che
  /// sparisce dall'elenco senza spiegazione fa credere di averlo perso.
  final bool readable;

  String get fileName => p.basename(path);
  String get folder => p.dirname(path);

  /// True se il file non esiste piu' (un recente che punta nel vuoto).
  bool get missing => !File(path).existsSync();

  String get savedLabel => updatedAt.isEmpty ? '' : _pretty(updatedAt);

  static String _pretty(String iso) {
    final DateTime? parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final DateTime local = parsed.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
  }
}

/// L'elenco dei documenti che esistono davvero.
///
/// Serve ai menu' "Apri scheda" e "Apri campagna": senza, l'unico modo di
/// riprendere un personaggio e' ricordarsi in che cartella l'hai salvato e
/// ritrovarlo a mano ogni volta.
///
/// Le fonti sono due e si completano: i **documenti recenti** (che coprono i
/// file salvati ovunque) e la **cartella dell'app**, esplorata in profondita'
/// limitata. La seconda esiste perche' un recente puo' essere stato tolto
/// dall'elenco, mentre il file e' ancora li'.
abstract final class DocumentLibrary {
  /// Quanti documenti si esaminano al massimo per cartella.
  ///
  /// Ogni voce costa l'apertura di un database: senza un tetto, una cartella
  /// con migliaia di file bloccherebbe l'interfaccia per un elenco che nessuno
  /// legge fino in fondo.
  static const int maxEntriesPerFolder = 40;

  /// Quanti file si esaminano in tutto.
  static const int maxFiles = 240;

  /// Quante **cartelle** si visitano in tutto.
  ///
  /// Limitarle solo in profondita' non basta: basta una cartella con qualche
  /// migliaio di sottocartelle perche' l'esplorazione duri minuti, e questa
  /// funzione gira entrando nel menu' principale. Il limite e' su tutti i
  /// documenti trovati, quindi non cambia nulla per chi tiene le schede in una
  /// cartella sola — che e' il caso normale.
  static const int maxDirectories = 120;

  /// Quante sottocartelle si scendono.
  static const int maxDepth = 3;

  static List<DocumentEntry> scan({
    List<String> extraPaths = const <String>[],
    bool includeAppFolder = true,
    DocumentKind? kind,
  }) {
    final Map<String, DocumentEntry> found = <String, DocumentEntry>{};

    // 1. I percorsi noti (recenti), che possono stare ovunque.
    for (final String path in extraPaths) {
      final DocumentEntry entry = _describe(path);
      if (kind == null || entry.kind == kind) found[entry.path] = entry;
    }

    // 2. Le cartelle dell'app (%APPDATA% / Library / .local/share) e i documenti utente.
    if (includeAppFolder) {
      final Set<String> scannedRoots = <String>{};
      final List<Directory> roots = <Directory>[
        AppPaths.sheetsDir(),
        AppPaths.dataDir(),
        AppPaths.documentsDir(),
      ];
      for (final Directory root in roots) {
        if (!scannedRoots.add(root.path)) continue;
        for (final File file in _walk(root)) {
          final DocumentEntry entry = _describe(file.path);
          if (kind != null && entry.kind != kind) continue;
          found[entry.path] = entry;
        }
      }
    }

    final List<DocumentEntry> list = found.values.toList()
      ..sort((DocumentEntry a, DocumentEntry b) {
        // Prima i documenti leggibili, poi i piu' recenti: un file rotto non
        // deve stare in cima all'elenco solo perche' e' stato toccato ieri.
        if (a.readable != b.readable) return a.readable ? -1 : 1;
        final int byDate = b.modified.compareTo(a.modified);
        if (byDate != 0) return byDate;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    return list;
  }

  static List<File> _walk(Directory root) {
    if (!root.existsSync()) return const <File>[];

    final List<File> files = <File>[];
    final List<Directory> pending = <Directory>[root];
    final int rootDepth = p.split(root.path).length;
    int visitedDirectories = 0;

    while (pending.isNotEmpty) {
      if (files.length >= maxFiles || visitedDirectories >= maxDirectories) break;
      visitedDirectories++;

      final Directory current = pending.removeLast();
      final int currentDepth = p.split(current.path).length - rootDepth;

      List<FileSystemEntity> children;
      try {
        children = current.listSync(followLinks: false);
      } on FileSystemException {
        // Cartella senza permessi o sparita fra il listino e l'apertura: si
        // salta, perche' un elenco incompleto serve ancora, un'eccezione no.
        continue;
      }

      int taken = 0;
      for (final FileSystemEntity child in children) {
        if (child is Directory) {
          if (currentDepth < maxDepth && !p.basename(child.path).startsWith('.')) {
            pending.add(child);
          }
          continue;
        }
        if (child is! File) continue;
        if (p.extension(child.path).toLowerCase() != '.${CpreduxFile.extension}') continue;
        if (taken >= maxEntriesPerFolder || files.length >= maxFiles) break;
        taken++;
        files.add(child);
      }
    }
    return files;
  }

  /// Descrive un file leggendone il contenuto.
  ///
  /// Non lancia mai: un documento illeggibile e' un dato che l'elenco deve
  /// poter mostrare, non un errore che deve fermare tutto.
  static DocumentEntry _describe(String path) {
    final File file = File(path);
    final String fallbackName = p.basenameWithoutExtension(path);

    if (!file.existsSync()) {
      return DocumentEntry(
        path: path,
        name: fallbackName,
        kind: DocumentKind.sheet,
        modified: DateTime.fromMillisecondsSinceEpoch(0),
        readable: false,
      );
    }

    DateTime modified;
    try {
      modified = file.lastModifiedSync();
    } catch (_) {
      modified = DateTime.fromMillisecondsSinceEpoch(0);
    }

    try {
      final CpreduxFile doc = CpreduxFile.open(path);
      try {
        final DocumentSummary summary = doc.summary();
        return DocumentEntry(
          path: path,
          name: summary.name.isEmpty ? fallbackName : summary.name,
          kind: summary.kind,
          modified: modified,
          updatedAt: summary.updatedAt,
        );
      } finally {
        doc.close();
      }
    } catch (_) {
      return DocumentEntry(
        path: path,
        name: fallbackName,
        kind: DocumentKind.sheet,
        modified: modified,
        readable: false,
      );
    }
  }
}
