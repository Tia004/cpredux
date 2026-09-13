import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/startup.dart';
import '../../data/settings_store.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../net/update_installer.dart';
import '../../version.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_button.dart';

/// La finestra che si apre quando il programma si riavvia per aggiornarsi.
///
/// Perche' una finestra e non uno script di sistema: sostituire l'applicazione
/// in esecuzione e' l'unica operazione di tutto il programma che, sbagliata,
/// lascia l'utente senza niente. Qui la si vede succedere, con gli stessi
/// colori e la stessa tipografia del resto, e se qualcosa non riesce si legge
/// **cosa** non e' riuscito in una frase comprensibile — cosa che un
/// `chmod +x` fallito in uno script non farebbe mai.
class ApplyUpdateApp extends StatefulWidget {
  const ApplyUpdateApp({
    super.key,
    required this.request,
    this.runner,
  });

  final StartupRequest request;

  /// Iniettabile per i test: l'installazione **non** si esegue mai per davvero
  /// dentro una suite di test.
  final ProcessRunner? runner;

  @override
  State<ApplyUpdateApp> createState() => _ApplyUpdateAppState();
}

class _ApplyUpdateAppState extends State<ApplyUpdateApp> {
  final List<String> _done = <String>[];
  String? _current;
  String? _error;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final String archivePath = widget.request.archivePath ?? '';
    final File archive = File(archivePath);

    // Il rinvio si annulla **prima** di installare: se l'installazione fallisse
    // e il rinvio restasse scritto, il programma riproverebbe a ogni avvio, in
    // un ciclo da cui l'utente non esce. L'esito, buono o cattivo, viene
    // registrato e l'applicazione riaperta lo mostra.
    final AppSettings settings = SettingsStore.load();
    final String version =
        widget.request.version ?? settings.pendingUpdateVersion;
    settings.pendingUpdateVersion = '';
    settings.pendingUpdateArchive = '';
    settings.lastUpdateError = '';
    SettingsStore.save(settings);

    final SelfInstall? target = SelfInstall.detect();
    if (target == null) {
      await _fail(SelfInstall.reasonNotSelfInstallable(), version);
      return;
    }
    if (!archive.existsSync()) {
      await _fail('Il pacchetto scaricato non si trova piu\': ${archive.path}', version);
      return;
    }

    setState(() => _current = 'Preparazione');
    final InstallResult result = await applyUpdate(
      target,
      archive,
      runner: widget.runner ?? runProcess,
      onStep: (InstallStep step) {
        if (!mounted) return;
        setState(() {
          if (_current != null) _done.add(_current!);
          _current = step.label;
        });
      },
    );

    if (!result.success) {
      await _fail(result.error ?? 'Installazione non riuscita.', version);
      return;
    }

    setState(() {
      if (_current != null) _done.add(_current!);
      _current = 'Riavvio';
    });

    await _relaunch(target, justUpdatedTo: version);
  }

  Future<void> _fail(String message, String version) async {
    final AppSettings settings = SettingsStore.load();
    settings.lastUpdateError = message;
    SettingsStore.save(settings);

    if (!mounted) return;
    setState(() {
      _error = message;
      _finished = true;
    });

    // Si riapre comunque il programma **vecchio**: un aggiornamento fallito deve
    // lasciare l'utente con l'applicazione che aveva, non senza applicazione.
    final SelfInstall? target = SelfInstall.detect();
    if (target != null) {
      await Future<void>.delayed(const Duration(seconds: 4));
      await relaunch(target);
    }
  }

  Future<void> _relaunch(SelfInstall target, {required String justUpdatedTo}) async {
    // La copia vecchia non esiste piu': su macOS il bundle e' stato sostituito,
    // su Linux l'AppImage. Si rilancia dal percorso nuovo, non da quello che il
    // processo in esecuzione crede di avere.
    final SelfInstall fresh = SelfInstall(
      kind: target.kind,
      path: target.path,
      executable: target.executable,
    );
    await relaunch(fresh, arguments: <String>['--just-updated', justUpdatedTo]);
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CPRED Visualizer — aggiornamento',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: CprPalette.voidBlack,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: TechBackground(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: CprPalette.surface,
                  border: Border.all(color: CprPalette.hairline),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 3,
                          height: 16,
                          color: _error == null ? CprPalette.cyan : CprPalette.danger,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error == null ? 'AGGIORNAMENTO' : 'AGGIORNAMENTO NON RIUSCITO',
                            style: CprType.label.copyWith(
                              color: _error == null ? CprPalette.cyan : CprPalette.danger,
                              fontSize: 12,
                              letterSpacing: 1.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _error == null
                          ? 'Il programma si sta aggiornando e si riaprira\' da solo.'
                          : _error!,
                      style: CprType.body.copyWith(
                        color: _error == null ? CprPalette.ink : CprPalette.danger,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    for (final String step in _done)
                      _StepRow(label: step, state: _StepState.done),
                    if (_current != null) _StepRow(label: _current!, state: _StepState.running),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        'La versione $appVersion resta installata e utilizzabile. '
                        'Puoi riprovare dal pannello Aggiornamenti delle impostazioni.',
                        style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
                      ),
                    ],
                    if (_finished && _error != null) ...<Widget>[
                      const SizedBox(height: 18),
                      TechButton(
                        label: 'Chiudi',
                        variant: TechButtonVariant.secondary,
                        onPressed: () => exit(1),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _StepState { done, running }

class _StepRow extends StatelessWidget {
  const _StepRow({required this.label, required this.state});

  final String label;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final bool done = state == _StepState.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Icon(
            done ? Icons.check : Icons.more_horiz,
            size: 13,
            color: done ? CprPalette.success : CprPalette.cyan,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: CprType.caption.copyWith(
                color: done ? CprPalette.inkMuted : CprPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
