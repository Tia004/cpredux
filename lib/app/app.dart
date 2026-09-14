import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/theme.dart';
import '../design/typography.dart';
import '../features/campaign/campaign_screen.dart';
import '../features/cloud/cloud_space_view.dart';
import '../features/compare/compare_screen.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/sheet/sheet_screen.dart';
import '../features/update/update_dialog.dart';
import '../data/catalog.dart';
import '../net/update_manifest.dart';
import '../widgets/browser_tab_bar.dart';
import '../widgets/dialogs.dart';
import '../widgets/tech_background.dart';
import '../widgets/window_title_bar.dart';
import 'app_state.dart';
import 'startup.dart';

class CpredApp extends StatefulWidget {
  const CpredApp({super.key, this.catalog, this.startup = const StartupRequest()});

  /// Catalogo oggetti da usare. Nullo significa "nessun catalogo": gli oggetti
  /// risultano tutti personalizzati, che e' lo stato corretto per i test che
  /// non ne hanno bisogno.
  final ItemCatalog? catalog;

  /// Come e' stato avviato il programma. L'avvio normale e' il default, cosi'
  /// un test che costruisce l'app non deve sapere niente di aggiornamenti.
  final StartupRequest startup;

  @override
  State<CpredApp> createState() => _CpredAppState();
}

class _CpredAppState extends State<CpredApp> with WidgetsBindingObserver {
  late final AppState _state = AppState(catalog: widget.catalog);

  /// Serve a mostrare il dialogo dell'aggiornamento: all'avvio non c'e' ancora
  /// nessun `BuildContext` sotto il `Navigator` dell'applicazione, e il
  /// controllo degli aggiornamenti parte con l'avvio.
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _afterStartup());
  }

  /// La presenza parte dal menu principale e non da "sconosciuto": apri l'app
  /// e su Discord si legge cosa stai facendo, che e' il senso della funzione.
  ///
  /// Il controllo degli aggiornamenti viene **dopo**, e non blocca: l'utente
  /// puo' iniziare a lavorare mentre la risposta arriva.
  Future<void> _afterStartup() async {
    _state.consumePendingUpdateOutcome();
    _state.startDiscordPresenceLoop();
    await _state.refreshPresence();

    if (widget.startup.mode == StartupMode.justUpdated) {
      await _state.confirmUpdateApplied();
      final BuildContext? after = _navigatorKey.currentContext;
      if (after != null && after.mounted) {
        await showTechMessage(
          after,
          title: 'Aggiornato',
          message: 'Il programma e\' stato aggiornato alla versione ${widget.startup.version ?? ''} '
              'ed e\' di nuovo in funzione.',
        );
      }
      return;
    }

    if (widget.startup.initialFilePath != null) {
      await _state.openFileInNewTab(widget.startup.initialFilePath!);
    }

    if (!_state.settings.autoCheckUpdates) return;
    await _state.checkForUpdates(silent: true);
    if (_state.updateWorthAsking) await _askAboutUpdate();
  }

  /// Chiede cosa fare di un aggiornamento trovato all'avvio.
  ///
  /// Chiudere la finestra senza scegliere **non** installa nulla: un dialogo
  /// che chiede il permesso e nel dubbio aggiorna lo stesso non sta chiedendo
  /// il permesso.
  Future<void> _askAboutUpdate() async {
    final UpdateManifest? release = _state.availableUpdate;
    if (release == null) return;

    final BuildContext? context = _navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final UpdateChoice? choice = await showUpdateDialog(
      context,
      release: release,
      platform: _state.updatePlatform,
    );
    if (choice == null) return;

    switch (choice) {
      case UpdateChoice.skipVersion:
        await _state.skipAvailableUpdate();

      case UpdateChoice.onClose:
        await _state.scheduleUpdateOnClose();

      case UpdateChoice.installNow:
        // "Adesso" significa adesso: si scarica, si avvia l'aggiornatore e si
        // esce. L'utente non deve aspettare la prossima chiusura per una cosa
        // che ha appena autorizzato.
        if (!await _state.downloadUpdate()) return;
        if (!await _state.scheduleUpdateOnClose()) return;
        await _state.startPendingUpdate();
        _requestExit();
    }
  }

  /// Chiude la finestra.
  ///
  /// Su macOS, Windows e Linux l'uscita passa da qui, quindi e' l'unico punto in
  /// cui si puo' avviare l'aggiornamento rimandato **prima** che il processo
  /// sparisca: l'aggiornatore deve essere avviato mentre l'applicazione e'
  /// ancora in piedi, altrimenti non esisterebbe nessuno a lanciarlo.
  @override
  Future<AppExitResponse> didRequestAppExit() async {
    // Salvataggio prima di tutto: un aggiornamento non deve mai costare il
    // lavoro non ancora scritto su disco.
    _state.save(notify: false);

    if (_state.settings.hasPendingUpdate) {
      await _state.startPendingUpdate();
    }
    return AppExitResponse.exit;
  }

  /// Esce subito, senza ripassare dal ciclo di chiusura della finestra.
  ///
  /// Non si usa `handleRequestAppExit` di proposito: richiamerebbe
  /// `didRequestAppExit`, che avvierebbe l'aggiornatore una seconda volta. Due
  /// copie che installano lo stesso aggiornamento insieme sono il modo piu'
  /// rapido per lasciare un'installazione a meta'.
  void _requestExit() {
    _state.save(notify: false);
    exit(0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        title: 'CPRedux Desktop',
        debugShowCheckedModeBanner: false,
        theme: CprTheme.dark(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: CprPalette.hairline),
          ),
          child: TechBackground(
            child: Column(
              children: <Widget>[
                const WindowTitleBar(),
                const BrowserTabBar(),
                if (state.errorMessage != null) _ErrorBar(message: state.errorMessage!),
            Expanded(
              child: AnimatedSwitcher(
                duration: CprMotion.slow,
                switchInCurve: CprMotion.enter,
                switchOutCurve: CprMotion.exit,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.015),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey<AppScreen>(state.screen),
                  child: _screenFor(state.screen),
                ),
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _screenFor(AppScreen screen) {
    switch (screen) {
      case AppScreen.home:
        return const HomeScreen();
      case AppScreen.sheet:
        return const SheetScreen();
      case AppScreen.campaign:
        return const CampaignScreen();
      case AppScreen.settings:
        return const SettingsScreen();
      case AppScreen.compare:
        return const CompareScreen();
      case AppScreen.cloud:
        return const CloudSpaceView();
    }
  }
}

/// Barra d'errore persistente.
///
/// Un errore di salvataggio non va mostrato come un avviso che scompare: se il
/// salvataggio automatico fallisce, l'utente deve continuare a vedere che il
/// suo lavoro *non* sta andando su disco, finche' non risolve.
class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.danger, 0.16),
        border: const Border(bottom: BorderSide(color: CprPalette.danger)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, size: 16, color: CprPalette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: CprType.caption.copyWith(color: CprPalette.ink),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: state.clearError,
              child: const Icon(Icons.close, size: 15, color: CprPalette.danger),
            ),
          ),
        ],
      ),
    );
  }
}
