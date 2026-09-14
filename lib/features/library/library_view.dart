import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../data/document_library.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../domain/sheet.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/tech_button.dart';

/// Vista della Libreria Schede esclusiva dell'applicazione.
///
/// Permette di gestire, ricercare, aprire in tab e inviare schede e campagne
/// direttamente dall'interno del programma, senza dover ricorrere a file explorer esterni.
class LibraryView extends StatefulWidget {
  const LibraryView({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _categoryFilter = 0; // 0: Tutte, 1: Schede, 2: Campagne

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<DocumentEntry> allDocs = state.documents;
    final String query = _searchCtrl.text.trim().toLowerCase();

    final List<DocumentEntry> filtered = allDocs.where((DocumentEntry doc) {
      if (_categoryFilter == 1 && doc.kind != DocumentKind.sheet) return false;
      if (_categoryFilter == 2 && doc.kind != DocumentKind.campaign) return false;
      if (query.isNotEmpty) {
        final bool matchName = doc.name.toLowerCase().contains(query);
        final bool matchFile = doc.fileName.toLowerCase().contains(query);
        if (!matchName && !matchFile) return false;
      }
      return true;
    }).toList();

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // Header con cartella dedicata
        ChamferPanel(
                accent: CprPalette.yellow,
                cut: 12,
                title: 'LIBRERIA SCHEDE CPRedux',
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  color: CprPalette.veil(CprPalette.yellow, 0.15),
                  child: Text(
                    '${allDocs.length} DOCUMENTI',
                    style: CprType.label.copyWith(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: CprPalette.yellow,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Spazio esclusivo e cartella canonica per le tue schede personaggio e campagne.',
                      style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13.5),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        const Icon(Icons.folder_outlined, size: 14, color: CprPalette.inkMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            AppPaths.sheetsDir().path,
                            style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Barra di ricerca, filtri e creazione rapida
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Cerca per nome personaggio o file…',
                        prefixIcon: const Icon(Icons.search, size: 18, color: CprPalette.inkMuted),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () => setState(() => _searchCtrl.clear()),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  TechButton(
                    label: 'Crea Scheda',
                    icon: Icons.add,
                    variant: TechButtonVariant.primary,
                    compact: true,
                    onPressed: () => state.createSheetInNewTab(),
                  ),
                  const SizedBox(width: 8),
                  TechButton(
                    label: 'Nuova Campagna',
                    icon: Icons.casino_outlined,
                    variant: TechButtonVariant.secondary,
                    compact: true,
                    onPressed: () => _promptNewCampaign(context, state),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filtri categoria
              Row(
                children: <Widget>[
                  _filterButton(label: 'Tutti (${allDocs.length})', index: 0),
                  const SizedBox(width: 8),
                  _filterButton(
                    label: 'Schede (${allDocs.where((DocumentEntry d) => d.kind == DocumentKind.sheet).length})',
                    index: 1,
                  ),
                  const SizedBox(width: 8),
                  _filterButton(
                    label: 'Campagne (${allDocs.where((DocumentEntry d) => d.kind == DocumentKind.campaign).length})',
                    index: 2,
                  ),
                  const Spacer(),
                  TechButton(
                    label: 'Ricarica',
                    icon: Icons.refresh,
                    variant: TechButtonVariant.ghost,
                    compact: true,
                    onPressed: () => state.refreshDocumentLibrary(),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Griglia/Lista delle schede
              if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: CprPalette.surface,
                    border: Border.all(color: CprPalette.hairline),
                  ),
                  child: Column(
                    children: <Widget>[
                      const Icon(Icons.folder_open, size: 36, color: CprPalette.inkFaint),
                      const SizedBox(height: 12),
                      Text(
                        'Nessun documento trovato nella libreria.',
                        style: CprType.body.copyWith(color: CprPalette.inkMuted),
                      ),
                      const SizedBox(height: 8),
                      TechButton(
                        label: 'Crea la tua prima Scheda Personaggio',
                        icon: Icons.add,
                        variant: TechButtonVariant.primary,
                        compact: true,
                        onPressed: () => state.createSheetInNewTab(),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: filtered
                      .map((DocumentEntry entry) => _buildEntryCard(context, state, entry))
                      .toList(),
                ),
            ],
          );

    if (widget.embedded) return content;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: content,
        ),
      ),
    );
  }

  Widget _filterButton({required String label, required int index}) {
    final bool active = _categoryFilter == index;
    return InkWell(
      onTap: () => setState(() => _categoryFilter = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? CprPalette.yellow.withValues(alpha: 0.18) : CprPalette.surfaceSunken,
          border: Border.all(color: active ? CprPalette.yellow : CprPalette.hairline),
        ),
        child: Text(
          label,
          style: CprType.label.copyWith(
            fontSize: 10.5,
            color: active ? CprPalette.yellow : CprPalette.inkMuted,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildEntryCard(BuildContext context, AppState state, DocumentEntry entry) {
    final bool isSheet = entry.kind == DocumentKind.sheet;
    final IconData icon = isSheet ? Icons.person_outline : Icons.casino_outlined;
    final Color accent = isSheet ? CprPalette.cyan : CprPalette.yellow;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CprPalette.surface,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      entry.name,
                      style: CprType.body.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      color: CprPalette.surfaceSunken,
                      child: Text(
                        isSheet ? 'SCHEDA' : 'CAMPAGNA',
                        style: CprType.caption.copyWith(fontSize: 8.5, color: accent, letterSpacing: 0.6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Ultima modifica: ${entry.savedLabel.isNotEmpty ? entry.savedLabel : "Recente"} · ${entry.fileName}',
                  style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TechButton(
            label: 'Apri in nuova Tab',
            icon: Icons.open_in_new,
            variant: TechButtonVariant.primary,
            compact: true,
            onPressed: () => state.openFileInNewTab(entry.path),
          ),
          if (state.isHosting && isSheet) ...<Widget>[
            const SizedBox(width: 8),
            TechButton(
              label: 'Invia a Giocatore',
              icon: Icons.send_outlined,
              variant: TechButtonVariant.secondary,
              compact: true,
              tooltip: 'Invia questa scheda a un giocatore connesso al tavolo',
              onPressed: () => _promptSendToPlayer(context, state, entry),
            ),
          ],
          const SizedBox(width: 8),
          TechButton(
            label: '',
            icon: Icons.delete_outline,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: 'Elimina file',
            onPressed: () => _confirmDeleteFile(context, state, entry),
          ),
        ],
      ),
    );
  }

  Future<void> _promptNewCampaign(BuildContext context, AppState state) async {
    final TextEditingController nameCtrl = TextEditingController(text: 'Night City Chronicles');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: CprPalette.surface,
        title: Text('Crea Nuova Campagna', style: CprType.body.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Inserisci il titolo della campagna da creare nella tua libreria:', style: CprType.caption),
            const SizedBox(height: 12),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nome Campagna')),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Crea')),
        ],
      ),
    );

    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      final Directory dir = AppPaths.sheetsDir();
      await state.createCampaign(name: nameCtrl.text.trim(), directory: dir.path);
    }
  }

  Future<void> _promptSendToPlayer(BuildContext context, AppState state, DocumentEntry entry) async {
    final host = state.host;
    if (host == null || host.players.isEmpty) {
      showTechMessage(context, title: 'Nessun Giocatore', message: 'Nessun giocatore e\' attualmente collegato al tavolo.');
      return;
    }

    try {
      final CpreduxFile file = CpreduxFile.open(entry.path);
      final CharacterSheet sheet;
      try {
        sheet = file.readSheet();
      } finally {
        file.close();
      }

      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: CprPalette.surface,
          title: Text('Invia Scheda a Giocatore', style: CprType.body.copyWith(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: host.players.values.map((p) {
              return ListTile(
                leading: const Icon(Icons.person, color: CprPalette.cyan),
                title: Text(p.characterName.isNotEmpty ? p.characterName : 'Giocatore ${p.id}'),
                subtitle: Text('ID: ${p.id}'),
                trailing: const Icon(Icons.send, size: 16, color: CprPalette.yellow),
                onTap: () {
                  Navigator.of(ctx).pop();
                  state.sendSheetToPlayer(p.id, sheet, reason: 'Scheda inviata dal Master');
                  showTechMessage(
                    context,
                    title: 'Scheda Inviata',
                    message: 'La scheda "${sheet.meta.name}" e\' stata trasmessa a ${p.characterName}.',
                  );
                },
              );
            }).toList(),
          ),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annulla')),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        showTechMessage(context, title: 'Errore Lettura', message: 'Impossibile leggere la scheda: $e');
      }
    }
  }

  Future<void> _confirmDeleteFile(BuildContext context, AppState state, DocumentEntry entry) async {
    final bool ok = await showTechConfirm(
      context,
      title: 'Elimina Documento',
      message: 'Sei sicuro di voler eliminare permanentemente "${entry.name}" dalla tua libreria?\n${entry.path}',
      confirmLabel: 'Elimina',
      danger: true,
    );
    if (ok) {
      try {
        final File f = File(entry.path);
        if (f.existsSync()) f.deleteSync();
        state.refreshDocumentLibrary();
      } catch (e) {
        if (context.mounted) {
          showTechMessage(context, title: 'Errore', message: 'Impossibile eliminare il file: $e');
        }
      }
    }
  }
}
