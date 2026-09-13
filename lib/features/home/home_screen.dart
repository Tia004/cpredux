import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../data/document_library.dart';
import '../../data/migrator.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../domain/sheet.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/drop_zone.dart';
import '../../widgets/entrance.dart';
import '../../widgets/inputs.dart';
import '../../widgets/menu.dart';
import '../../widgets/tech_button.dart';
import '../compare/compare_picker.dart';
import '../files/file_browser.dart';
import '../sheet/sheet_wizard.dart';

/// Schermata iniziale: creare, aprire, convertire, partecipare.
///
/// E' un widget con stato per una ragione sola: l'elenco dei documenti esistenti
/// si rilegge entrando, e leggere il disco durante il disegno significherebbe
/// farlo a ogni ricostruzione.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Dopo il primo fotogramma: `notifyListeners` durante la costruzione
    // dell'albero e' un errore, e la lettura del disco deve comunque avvenire
    // quando la schermata esiste gia'.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppScope.of(context).refreshDocumentLibrary();
    });
  }

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

class _Actions extends StatefulWidget {
  const _Actions({required this.state});

  final AppState state;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  AppState get state => widget.state;

  /// True mentre un flusso con dialogo e' in corso.
  ///
  /// Serve alla zona di rilascio: coperta da un dialogo continuerebbe a
  /// ricevere i rilasci, e un file lasciato sopra la finestra di conversione
  /// finirebbe sulla zona sotto, che l'utente non sta guardando.
  bool _busy = false;

  // --- Creazione e apertura ------------------------------------------------

  Future<void> _newDocument(BuildContext context, {required bool sheet}) async {
    SheetSetup? setup;
    if (sheet) {
      // Mostra il wizard: l'utente puo' personalizzare la scheda prima di crearla.
      setup = await showSheetWizard(context);
      if (setup == null || !context.mounted) return;
    }

    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.save,
      title: sheet ? 'Dove salvare la scheda' : 'Nuova campagna',
      extensions: <String>[CpreduxFile.extension],
      initialDirectory: AppPaths.documentsDir().path,
      suggestedName: sheet ? (setup?.name ?? 'Nuova scheda') : 'Nuova campagna',
      description: sheet ? 'Scegli dove salvare "${setup?.name}"' : 'Scegli dove salvare il documento',
    );
    if (path == null || !context.mounted) return;

    final String name = sheet && setup != null ? setup.name : p.basenameWithoutExtension(path);
    try {
      if (sheet && setup != null) {
        final SheetIdentity identity = SheetIdentity(
          tag: setup.tag,
          playerName: setup.playerName,
          role: setup.role,
          roleAbility: setup.roleAbility,
          roleRank: setup.roleRank,
          aliases: setup.aliases,
          reputation: setup.reputation,
          gameDate: setup.gameDate,
        );
        await state.createSheet(
          name: name,
          directory: p.dirname(path),
          identity: identity,
          statBase: setup.statBase,
        );
      } else if (sheet) {
        await state.createSheet(name: name, directory: p.dirname(path));
      } else {
        await state.createCampaign(name: name, directory: p.dirname(path));
      }
    } catch (e) {
      if (!context.mounted) return;
      await _reportError(context, 'Creazione non riuscita', e);
    }
  }

  Future<void> _browse(BuildContext context) async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Apri documento',
      extensions: <String>[CpreduxFile.extension],
      initialDirectory: AppPaths.documentsDir().path,
      description: 'Schede e campagne',
    );
    if (path == null || !context.mounted) return;
    await _open(context, path);
  }

  Future<void> _open(BuildContext context, String path) async {
    setState(() => _busy = true);
    try {
      await state.openDocument(path);
    } catch (e) {
      if (!context.mounted) return;
      await _reportError(context, 'Apertura non riuscita', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reportError(BuildContext context, String title, Object error) async {
    await showTechMessage(
      context,
      title: title,
      message: error is CpreduxException ? error.message : 'Si e\' verificato un errore.',
      detail: error is CpreduxException ? error.detail : error.toString(),
      isError: true,
    );
  }

  // --- Conversione ---------------------------------------------------------

  /// Converte una scheda del vecchio formato, mostrando **prima** l'anteprima.
  ///
  /// L'ordine conta: prima si analizza e si mostra cosa verra' convertito e
  /// dove finira', poi si scrive. Chiedere conferma su qualcosa che non si e'
  /// ancora visto non e' una conferma, e' una scommessa.
  Future<void> _convertLegacy(BuildContext context, String legacyPath) async {
    setState(() => _busy = true);
    try {
      final MigrationReport report = state.analyseLegacySheet(legacyPath);
      if (!context.mounted) return;

      final MigrationTarget? target = await showMigrationPreview(
        context,
        report: report,
        fileName: p.basename(legacyPath),
        outputPathOf: (MigrationTarget t) => state.migrationOutputPath(legacyPath, t),
      );
      if (target == null || !context.mounted) return;

      final MigrationReport result = state.migrateLegacySheet(legacyPath, target: target);
      if (!context.mounted) return;
      await showMigrationReport(context, result);
    } catch (e) {
      if (!context.mounted) return;
      await _reportError(context, 'Conversione non riuscita', e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Confronta due schede già salvate.
  ///
  /// Le schede vengono lette **senza aprirle**: un confronto e' una lettura, e
  /// aprire un documento al posto dell'utente vorrebbe dire sostituirgli quello
  /// che sta guardando per rispondere a una domanda che non ha fatto.
  Future<void> _compareDocuments(BuildContext context) async {
    final Comparison? comparison = await showComparePicker(context, state: state);
    if (comparison == null || !context.mounted) return;
    state.openComparison(comparison);
  }

  Future<void> _pickLegacy(BuildContext context) async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Converti scheda vecchia',
      extensions: <String>['cpred_sheet'],
      initialDirectory: AppPaths.documentsDir().path,
      description: 'Vecchie schede Java (.cpred_sheet)',
    );
    if (path == null || !context.mounted) return;
    await _convertLegacy(context, path);
  }

  void _onDropped(BuildContext context, List<String> paths) {
    if (paths.length > 1) {
      showTechMessage(
        context,
        title: 'Una per volta',
        message: 'Ho convertito solo "${p.basename(paths.first)}".\n\n'
            'Le altre ${paths.length - 1} schede non sono state toccate: trascinale '
            'una alla volta, cosi\' puoi controllare cosa e\' stato riconosciuto in '
            'ognuna.',
      );
    }
    _convertLegacy(context, paths.first);
  }

  // --- Partecipazione a una campagna ---------------------------------------

  /// Apre la scheda scelta e si collega al tavolo di un master.
  ///
  /// La sequenza e' obbligata: `joinSession` ha bisogno di una scheda aperta,
  /// perche' e' la scheda a dire *chi* si sta portando al tavolo. Per questo il
  /// dialogo chiede prima il personaggio e poi l'indirizzo.
  Future<void> _joinCampaign(BuildContext context) async {
    final bool? joined = await showDialog<bool>(
      context: context,
      barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.75),
      builder: (BuildContext context) => _JoinCampaignDialog(state: state),
    );
    if (joined != true || !context.mounted) return;
    state.goToSheet(landing: SheetLanding.session);
  }

  // --- Costruzione ---------------------------------------------------------

  List<MenuEntry> _sheetEntries(BuildContext context) {
    final List<DocumentEntry> sheets = state.documentsOfKind(DocumentKind.sheet);
    return <MenuEntry>[
      for (final DocumentEntry sheet in sheets)
        MenuEntry(
          label: sheet.name,
          description: sheet.missing
              ? 'File non trovato'
              : '${sheet.folder}${sheet.savedLabel.isEmpty ? '' : '  ·  ${sheet.savedLabel}'}',
          icon: sheet.missing
              ? Icons.error_outline
              : (sheet.readable ? Icons.description_outlined : Icons.warning_amber_rounded),
          accent: sheet.missing || !sheet.readable ? CprPalette.warning : CprPalette.yellow,
          trailing: sheet.missing ? 'MANCA' : null,
          onTap: () => _open(context, sheet.path),
        ),
      MenuEntry(
        label: 'Sfoglia i file…',
        description: 'Apri una scheda da un\'altra cartella',
        icon: Icons.folder_open,
        accent: CprPalette.inkMuted,
        onTap: () => _browse(context),
      ),
    ];
  }

  List<MenuEntry> _campaignEntries(BuildContext context) {
    final List<DocumentEntry> campaigns = state.documentsOfKind(DocumentKind.campaign);
    return <MenuEntry>[
      for (final DocumentEntry campaign in campaigns)
        MenuEntry(
          label: campaign.name,
          description: campaign.missing
              ? 'File non trovato'
              : '${campaign.folder}${campaign.savedLabel.isEmpty ? '' : '  ·  ${campaign.savedLabel}'}',
          icon: campaign.missing ? Icons.error_outline : Icons.group_work_outlined,
          accent: campaign.missing ? CprPalette.warning : CprPalette.cyan,
          trailing: campaign.missing ? 'MANCA' : null,
          onTap: () => _open(context, campaign.path),
        ),
      MenuEntry(
        label: 'Sfoglia i file…',
        description: 'Apri una campagna da un\'altra cartella',
        icon: Icons.folder_open,
        accent: CprPalette.inkMuted,
        onTap: () => _browse(context),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final int sheets = state.documentsOfKind(DocumentKind.sheet).length;
    final int campaigns = state.documentsOfKind(DocumentKind.campaign).length;

    return ChamferPanel(
      title: 'Cosa vuoi fare',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          MenuRow(
            label: 'Nuova scheda',
            description: 'Crea un personaggio da zero',
            icon: Icons.person_add_alt,
            accent: CprPalette.yellow,
            primary: true,
            onTap: () => _newDocument(context, sheet: true),
          ),
          const SizedBox(height: 8),
          ExpandableMenuRow(
            label: 'Apri scheda',
            description: sheets == 0
                ? 'Riprendi un personaggio esistente'
                : '$sheets ${sheets == 1 ? 'scheda trovata' : 'schede trovate'}',
            icon: Icons.folder_open,
            accent: CprPalette.yellow,
            entries: _sheetEntries(context),
            emptyMessage: 'Nessuna scheda trovata. Nel menu\' qui sotto puoi cercarla '
                'in un\'altra cartella.',
            enable: !_busy,
          ),
          const SizedBox(height: 8),
          ExpandableMenuRow(
            label: 'Crea o partecipa a una campagna',
            description: 'Apri un tavolo da master, oppure entra in quello di un altro',
            icon: Icons.groups_2_outlined,
            accent: CprPalette.cyan,
            enable: !_busy,
            entries: <MenuEntry>[
              MenuEntry(
                label: 'Crea una nuova campagna',
                description: 'Apri un tavolo e invita i giocatori',
                icon: Icons.add_circle_outline,
                accent: CprPalette.cyan,
                onTap: () => _newDocument(context, sheet: false),
              ),
              MenuEntry(
                label: 'Partecipa a una campagna',
                description: 'Collegati al tavolo di un master con il tuo personaggio',
                icon: Icons.login,
                accent: CprPalette.success,
                onTap: () => _joinCampaign(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MenuRow(
            label: 'Confronta due schede',
            description: sheets < 2
                ? 'Metti due schede una accanto all\'altra e vedi cosa e\' cambiato'
                : 'Due schede a confronto: aggiunto, tolto, cambiato',
            icon: Icons.difference_outlined,
            accent: CprPalette.info,
            onTap: () => _compareDocuments(context),
          ),
          const SizedBox(height: 8),
          ExpandableMenuRow(
            label: 'Apri campagna',
            description: campaigns == 0
                ? 'Riprendi un tavolo in corso'
                : '$campaigns ${campaigns == 1 ? 'campagna trovata' : 'campagne trovate'}',
            icon: Icons.group_work_outlined,
            accent: CprPalette.cyan,
            entries: _campaignEntries(context),
            emptyMessage: 'Nessuna campagna trovata. Nel menu\' qui sotto puoi cercarla '
                'in un\'altra cartella.',
            enable: !_busy,
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 14),
          DropZone(
            enable: !_busy,
            extensions: const <String>['cpred_sheet'],
            label: 'Rilascia qui',
            hint: 'scheda del vecchio programma (.cpred_sheet)',
            accent: CprPalette.magenta,
            onDropped: (List<String> paths) => _onDropped(context, paths),
            onRejected: (String reason) => showTechMessage(
              context,
              title: 'Questo file non va bene',
              message: reason,
              isError: true,
            ),
            child: MenuRow(
              label: 'Converti scheda vecchia',
              description: 'Trascina qui una .cpred_sheet, oppure clicca per sceglierla',
              icon: Icons.auto_fix_high,
              accent: CprPalette.magenta,
              onTap: () => _pickLegacy(context),
            ),
          ),
          const SizedBox(height: 8),
          MenuRow(
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

/// Dialogo di partecipazione a un tavolo.
///
/// Fa due cose che l'utente pensa come una sola — "vado al tavolo di Marco" —
/// ma che il programma deve fare in ordine: aprire la scheda che si porta, e
/// collegarsi. Chiedere l'indirizzo senza dire *con chi* si sta andando al
/// tavolo sarebbe una domanda a cui non si puo' rispondere.
class _JoinCampaignDialog extends StatefulWidget {
  const _JoinCampaignDialog({required this.state});

  final AppState state;

  @override
  State<_JoinCampaignDialog> createState() => _JoinCampaignDialogState();
}

class _JoinCampaignDialogState extends State<_JoinCampaignDialog> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _port = TextEditingController(text: '21099');
  final TextEditingController _password = TextEditingController();

  DocumentEntry? _sheet;
  bool _connecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final List<DocumentEntry> sheets =
        widget.state.documentsOfKind(DocumentKind.sheet).where((DocumentEntry s) => s.readable).toList();
    if (sheets.isNotEmpty) _sheet = sheets.first;
  }

  @override
  void dispose() {
    _address.dispose();
    _port.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Aspetta l'esito del collegamento.
  ///
  /// `joinSession` ritorna quando il socket e' aperto, non quando il master ha
  /// risposto: senza aspettare, il dialogo si chiuderebbe dichiarando un
  /// successo che non e' ancora successo — ed e' esattamente il difetto appena
  /// corretto in `isJoined`.
  Future<String?> _awaitOutcome() async {
    final AppState state = widget.state;
    for (int i = 0; i < 80; i++) {
      if (state.isJoined) return null;
      final String? error = state.sessionError;
      if (error != null) return error;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return 'Il master non ha risposto in tempo. Controlla indirizzo e porta.';
  }

  Future<void> _connect() async {
    final DocumentEntry? sheet = _sheet;
    final int? port = int.tryParse(_port.text.trim());

    if (sheet == null) {
      setState(() => _error = 'Scegli con quale personaggio andare al tavolo.');
      return;
    }
    if (_address.text.trim().isEmpty || port == null) {
      setState(() => _error = 'Inserisci indirizzo e porta del tavolo.');
      return;
    }

    setState(() {
      _connecting = true;
      _error = null;
    });

    final AppState state = widget.state;
    try {
      await state.openDocument(sheet.path);
      await state.joinSession(
        address: _address.text.trim(),
        port: port,
        password: _password.text,
      );
      final String? failure = await _awaitOutcome();
      if (!mounted) return;

      if (failure != null) {
        setState(() {
          _connecting = false;
          _error = failure;
        });
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _error = e is CpreduxException ? e.message : 'Collegamento non riuscito: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<DocumentEntry> sheets = widget.state
        .documentsOfKind(DocumentKind.sheet)
        .where((DocumentEntry s) => s.readable)
        .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ChamferPanel(
          title: 'Partecipa a una campagna',
          accent: CprPalette.success,
          cut: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Il master ti ha dato un indirizzo e una porta. Scegli il personaggio con '
                'cui entri: al tavolo porti la sua scheda, e da quel momento il master puo\' '
                'vederne e modificarne i valori.',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              if (sheets.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: CprPalette.veil(CprPalette.warning, 0.12),
                  child: Text(
                    'Non c\'e\' nessuna scheda da portare al tavolo. Crea prima un '
                    'personaggio, poi torna qui.',
                    style: CprType.caption.copyWith(color: CprPalette.ink),
                  ),
                )
              else
                TechDropdown<DocumentEntry>(
                  label: 'Personaggio',
                  value: _sheet ?? sheets.first,
                  items: sheets,
                  labelOf: (DocumentEntry s) => s.name,
                  accent: CprPalette.success,
                  onChanged: (DocumentEntry s) => setState(() => _sheet = s),
                ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: TechField(
                      label: 'Indirizzo del master',
                      value: _address.text,
                      hint: '192.168.1.20',
                      accent: CprPalette.success,
                      onChanged: (String v) => _address.text = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: TechField(
                      label: 'Porta',
                      value: _port.text,
                      numeric: true,
                      accent: CprPalette.success,
                      onChanged: (String v) => _port.text = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TechField(
                      label: 'Password',
                      value: _password.text,
                      hint: 'solo se richiesta',
                      accent: CprPalette.success,
                      onChanged: (String v) => _password.text = v,
                    ),
                  ),
                ],
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  color: CprPalette.veil(CprPalette.danger, 0.12),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded, size: 14, color: CprPalette.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: CprType.caption.copyWith(color: CprPalette.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TechButton(
                    label: 'Annulla',
                    variant: TechButtonVariant.ghost,
                    onPressed: _connecting ? null : () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: _connecting ? 'Collegamento…' : 'Collega',
                    icon: Icons.login,
                    variant: TechButtonVariant.primary,
                    onPressed: _connecting || sheets.isEmpty ? null : _connect,
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
