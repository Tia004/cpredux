import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/entrance.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';

/// Schermata iniziale: creare, aprire, convertire.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Entrance(delay: const Duration(milliseconds: 30), child: const _Hero()),
              const SizedBox(height: 22),
              Entrance(
                delay: const Duration(milliseconds: 90),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    // Sotto i 980 px le due colonne diventano una: e' la
                    // larghezza a cui i pulsanti inizierebbero a troncarsi.
                    final bool twoColumns = c.maxWidth >= 980;
                    final Widget actions = _Actions(state: state);
                    final Widget recent = _Recent(state: state);
                    if (!twoColumns) {
                      return Column(
                        children: <Widget>[actions, const SizedBox(height: 16), recent],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 3, child: actions),
                        const SizedBox(width: 16),
                        Expanded(flex: 4, child: recent),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              Entrance(delay: const Duration(milliseconds: 150), child: const _Footer()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        // Il logo e' disegnato con testo e barre invece che caricato come
        // immagine: cosi' resta nitido a qualunque risoluzione e scala con la
        // tipografia dell'app senza dover spedire piu' versioni dell'asset.
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(width: 6, height: 34, color: CprPalette.yellow),
                const SizedBox(width: 12),
                Text(
                  'CPRED',
                  style: CprType.display.copyWith(
                    fontSize: 46,
                    letterSpacing: 2,
                    color: CprPalette.ink,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'VISUALIZER',
                    style: CprType.label.copyWith(
                      fontSize: 15,
                      letterSpacing: 5,
                      color: CprPalette.yellow,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Schede e campagne di Cyberpunk RED, senza fare i conti a mano.',
              style: CprType.body.copyWith(color: CprPalette.inkMuted),
            ),
          ],
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final AppState state;

  Future<void> _newDocument(BuildContext context, {required bool sheet}) async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.save,
      title: sheet ? 'Nuova scheda' : 'Nuova campagna',
      extensions: <String>[CpreduxFile.extension],
      initialDirectory: AppPaths.documentsDir().path,
      suggestedName: sheet ? 'Nuova scheda' : 'Nuova campagna',
      description: 'Scegli dove salvare il documento',
    );
    if (path == null || !context.mounted) return;

    final String name = p.basenameWithoutExtension(path);
    try {
      if (sheet) {
        await state.createSheet(name: name, directory: p.dirname(path));
      } else {
        await state.createCampaign(name: name, directory: p.dirname(path));
      }
    } catch (e) {
      if (!context.mounted) return;
      await showTechMessage(
        context,
        title: 'Creazione non riuscita',
        message: e is CpreduxException ? e.message : 'Si e\' verificato un errore.',
        detail: e is CpreduxException ? e.detail : e.toString(),
        isError: true,
      );
    }
  }

  Future<void> _openDocument(BuildContext context) async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Apri documento',
      extensions: <String>[CpreduxFile.extension],
      initialDirectory: AppPaths.documentsDir().path,
      description: 'Schede e campagne',
    );
    if (path == null || !context.mounted) return;

    try {
      await state.openDocument(path);
    } catch (e) {
      if (!context.mounted) return;
      await showTechMessage(
        context,
        title: 'Apertura non riuscita',
        message: e is CpreduxException ? e.message : 'Si e\' verificato un errore.',
        detail: e is CpreduxException ? e.detail : e.toString(),
        isError: true,
      );
    }
  }

  /// Converte una scheda del vecchio formato, mostrando **prima** l'anteprima.
  ///
  /// L'ordine conta: prima si analizza e si mostra cosa verra' convertito, poi
  /// si chiede conferma, poi si scrive. Chiedere conferma su qualcosa che non
  /// si e' ancora visto non e' una conferma, e' una scommessa.
  Future<void> _convertLegacy(BuildContext context) async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Converti scheda vecchia',
      extensions: <String>['cpred_sheet'],
      initialDirectory: AppPaths.documentsDir().path,
      description: 'Vecchie schede Java (.cpred_sheet)',
    );
    if (path == null || !context.mounted) return;

    try {
      final report = state.analyseLegacySheet(path);
      if (!context.mounted) return;

      final bool confirmed = await showTechConfirm(
        context,
        title: 'Confermi la conversione?',
        message: 'Verranno convertiti ${report.totalElements} elementi'
            '${report.hasWarnings ? ', con ${report.warnings.length} avvertenze' : ''}.\n\n'
            'La scheda originale non viene toccata: verra\' creato un nuovo file .cpredux '
            'e ne verra\' fatto un backup.',
        confirmLabel: 'Converti',
      );
      if (!confirmed || !context.mounted) return;

      final result = state.migrateLegacySheet(path);
      if (!context.mounted) return;
      await showMigrationReport(context, result);
    } catch (e) {
      if (!context.mounted) return;
      await showTechMessage(
        context,
        title: 'Conversione non riuscita',
        message: e is CpreduxException ? e.message : 'Si e\' verificato un errore.',
        detail: e is CpreduxException ? e.detail : e.toString(),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Cosa vuoi fare',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _MenuButton(
            label: 'Nuova scheda',
            description: 'Crea un personaggio da zero',
            icon: Icons.person_add_alt,
            accent: CprPalette.yellow,
            primary: true,
            onTap: () => _newDocument(context, sheet: true),
          ),
          const SizedBox(height: 8),
          _MenuButton(
            label: 'Apri scheda',
            description: 'Riprendi un personaggio esistente',
            icon: Icons.folder_open,
            accent: CprPalette.yellow,
            onTap: () => _openDocument(context),
          ),
          const SizedBox(height: 8),
          _MenuButton(
            label: 'Nuova campagna',
            description: 'Apri un tavolo e invita i giocatori',
            icon: Icons.groups_2_outlined,
            accent: CprPalette.cyan,
            onTap: () => _newDocument(context, sheet: false),
          ),
          const SizedBox(height: 8),
          _MenuButton(
            label: 'Apri campagna',
            description: 'Riprendi un tavolo in corso',
            icon: Icons.group_work_outlined,
            accent: CprPalette.cyan,
            onTap: () => _openDocument(context),
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          _MenuButton(
            label: 'Converti scheda vecchia',
            description: 'Importa una .cpred_sheet del vecchio programma',
            icon: Icons.auto_fix_high,
            accent: CprPalette.magenta,
            onTap: () => _convertLegacy(context),
          ),
          const SizedBox(height: 8),
          _MenuButton(
            label: 'Impostazioni',
            description: 'Tema, carico, salvataggio automatico',
            icon: Icons.settings,
            accent: CprPalette.inkFaint,
            onTap: state.goToSettings,
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hover
                ? (widget.primary
                    ? CprPalette.veil(widget.accent, 0.16)
                    : CprPalette.veil(widget.accent, 0.08))
                : (widget.primary
                    ? CprPalette.veil(widget.accent, 0.08)
                    : Colors.transparent),
            border: Border(
              left: BorderSide(color: widget.accent, width: _hover ? 4 : 2),
            ),
          ),
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
              AnimatedOpacity(
                duration: CprMotion.hover,
                opacity: _hover ? 1 : 0,
                child: Icon(Icons.arrow_forward, size: 15, color: widget.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Recent extends StatelessWidget {
  const _Recent({required this.state});

  final AppState state;

  Future<void> _open(BuildContext context, String path) async {
    if (!File(path).existsSync()) {
      final bool forget = await showTechConfirm(
        context,
        title: 'File non trovato',
        message: 'Il documento non esiste piu\' in questa posizione.\n\n$path\n\n'
            'Vuoi toglierlo dall\'elenco dei recenti?',
        confirmLabel: 'Rimuovi',
        danger: true,
      );
      if (forget) {
        await state.updateSettings((s) => s.forgetFile(path));
      }
      return;
    }

    try {
      await state.openDocument(path);
    } catch (e) {
      if (!context.mounted) return;
      await showTechMessage(
        context,
        title: 'Apertura non riuscita',
        message: e is CpreduxException ? e.message : 'Si e\' verificato un errore.',
        detail: e is CpreduxException ? e.detail : e.toString(),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> recents = state.settings.recentFiles;

    return ChamferPanel(
      title: 'Documenti recenti',
      trailing: Text(
        recents.isEmpty ? '' : '${recents.length}',
        style: CprType.label.copyWith(color: CprPalette.inkFaint),
      ),
      child: recents.isEmpty
          ? const TechWell(
              child: Text(
                'Nessun documento aperto di recente.\nCrea una scheda per iniziare.',
                style: TextStyle(color: CprPalette.inkFaint, height: 1.5),
              ),
            )
          : Column(
              children: <Widget>[
                for (final String path in recents)
                  _RecentTile(
                    path: path,
                    onOpen: () => _open(context, path),
                    onForget: () => state.updateSettings((s) => s.forgetFile(path)),
                  ),
              ],
            ),
    );
  }
}

class _RecentTile extends StatefulWidget {
  const _RecentTile({required this.path, required this.onOpen, required this.onForget});

  final String path;
  final VoidCallback onOpen;
  final VoidCallback onForget;

  @override
  State<_RecentTile> createState() => _RecentTileState();
}

class _RecentTileState extends State<_RecentTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bool exists = File(widget.path).existsSync();
    final String name = p.basenameWithoutExtension(widget.path);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          margin: const EdgeInsets.only(bottom: 3),
          color: _hover ? CprPalette.veil(CprPalette.yellow, 0.07) : null,
          child: Row(
            children: <Widget>[
              Icon(
                exists ? Icons.description_outlined : Icons.error_outline,
                size: 15,
                color: exists ? CprPalette.yellow : CprPalette.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: CprType.body.copyWith(
                        color: exists ? CprPalette.ink : CprPalette.inkFaint,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.path,
                      overflow: TextOverflow.ellipsis,
                      style: CprType.caption.copyWith(
                        color: CprPalette.inkFaint,
                        fontSize: 10.5,
                        fontFamilyFallback: CprType.monoFamily,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hover)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onForget,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 13, color: CprPalette.inkFaint),
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

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          'CPRED Visualizer — riscrittura in Flutter',
          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
        ),
        const SizedBox(width: 14),
        Text(
          'Formato .cpredux v1',
          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
        ),
        const Spacer(),
        TechButton(
          label: 'Cartella documenti',
          icon: Icons.folder_outlined,
          variant: TechButtonVariant.ghost,
          compact: true,
          tooltip: AppPaths.documentsDir().path,
          onPressed: () {},
        ),
      ],
    );
  }
}
