import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../net/update_installer.dart';
import '../../net/updater.dart';
import '../../version.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

/// Il pannello "Aggiornamenti" delle impostazioni.
///
/// Sta nelle impostazioni e non in una finestra a se' per un motivo preciso: qui
/// l'utente puo' anche **decidere di non essere aggiornato**, e una decisione
/// deve essere una cosa che si vede e si annulla, non un avviso da chiudere in
/// fretta.
class UpdatePanel extends StatelessWidget {
  const UpdatePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final bool canSelfInstall = SelfInstall.detect() != null;
    final bool busy = state.updateStage == UpdateStage.checking ||
        state.updateStage == UpdateStage.downloading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              canSelfInstall ? Icons.verified_outlined : Icons.construction_outlined,
              size: 14,
              color: canSelfInstall ? CprPalette.inkFaint : CprPalette.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                canSelfInstall
                    ? 'Versione installata: $appVersion'
                    : 'Versione installata: $appVersion — questa copia non si aggiorna da sola',
                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13),
              ),
            ),
          ],
        ),
        if (!canSelfInstall) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            SelfInstall.reasonNotSelfInstallable(),
            style: CprType.caption.copyWith(color: CprPalette.warning, height: 1.5),
          ),
        ],
        const SizedBox(height: 18),
        _UpdateToggle(
          label: 'Controlla gli aggiornamenti all\'avvio',
          description:
              'Chiede un file di poche centinaia di byte e non scarica niente da solo. '
              'Se c\'e\' una versione nuova te lo chiede: non la installa.',
          value: state.settings.autoCheckUpdates,
          onChanged: (bool v) => state.updateSettings((s) => s.autoCheckUpdates = v),
        ),
        const SizedBox(height: 18),
        TechField(
          label: 'Indirizzo del manifesto degli aggiornamenti',
          value: state.settings.updateFeedUrl,
          hint: 'https://…/latest.json',
          accent: CprPalette.cyan,
          enabled: state.settings.autoCheckUpdates,
          onChanged: (String v) => state.updateSettings((s) => s.updateFeedUrl = v.trim()),
        ),
        const SizedBox(height: 14),
        _StatusLine(state: state),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            TechButton(
              label: state.updateStage == UpdateStage.checking ? 'Controllo…' : 'Controlla ora',
              icon: Icons.refresh,
              variant: TechButtonVariant.secondary,
              compact: true,
              onPressed: busy ? null : () => state.checkForUpdates(),
            ),
            if (canSelfInstall && state.availableUpdate != null) ...<Widget>[
              TechButton(
                label: 'Aggiorna adesso',
                icon: Icons.download,
                variant: TechButtonVariant.primary,
                compact: true,
                onPressed: busy ? null : () => _downloadAndSchedule(context, state),
              ),
              TechButton(
                label: 'Alla chiusura',
                icon: Icons.schedule,
                variant: TechButtonVariant.ghost,
                compact: true,
                onPressed: busy ? null : () => _schedule(context, state),
              ),
            ],
          ],
        ),
        if (state.settings.hasPendingUpdate) ...<Widget>[
          const SizedBox(height: 16),
          _Notice(
            icon: Icons.schedule,
            color: CprPalette.cyan,
            text: 'La versione ${state.settings.pendingUpdateVersion} e\' gia\' scaricata e verra\' '
                'applicata alla chiusura del programma, che si riaprira\' da solo per installarla.',
            action: TechButton(
              label: 'Annulla',
              icon: Icons.close,
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: state.cancelScheduledUpdate,
            ),
          ),
        ],
        if (state.installError != null) ...<Widget>[
          const SizedBox(height: 16),
          _Notice(
            icon: Icons.error_outline,
            color: CprPalette.danger,
            text: 'L\'ultimo aggiornamento non e\' riuscito: ${state.installError}',
            action: TechButton(
              label: 'Chiudi',
              icon: Icons.close,
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: state.clearInstallError,
            ),
          ),
        ],
      ],
    );
  }

  /// Dal pannello l'utente ha gia' espresso l'intenzione, quindi non si chiede
  /// di nuovo: si scarica e si rimanda alla chiusura. La scelta a tre opzioni
  /// serve quando l'aggiornamento arriva da solo all'avvio, dove l'utente non ha
  /// chiesto niente e la finestra deve poter essere rifiutata.
  Future<void> _downloadAndSchedule(BuildContext context, AppState state) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.8),
      builder: (BuildContext context) => const _DownloadingDialog(),
    );

    final bool downloaded = await state.downloadUpdate();
    if (!context.mounted) return;
    Navigator.of(context).pop();

    if (!downloaded) {
      await showTechMessage(
        context,
        title: 'Aggiornamento non scaricato',
        message: state.updateError ?? 'Non e\' stato possibile scaricare il pacchetto.',
        isError: true,
      );
      return;
    }

    final bool scheduled = await state.scheduleUpdateOnClose();
    if (!context.mounted || !scheduled) return;
    await showTechMessage(
      context,
      title: 'Aggiornamento pronto',
      message: 'Il pacchetto e\' stato scaricato e verificato, e verra\' applicato alla chiusura '
          'del programma: si riaprira\' da solo per installarlo e poi si chiudera\'.',
    );
  }

  Future<void> _schedule(BuildContext context, AppState state) async {
    final bool ok = await state.scheduleUpdateOnClose();
    if (!context.mounted || ok) return;
    await showTechMessage(
      context,
      title: 'Aggiornamento non scaricato',
      message: state.updateError ?? 'Non e\' stato possibile scaricare il pacchetto.',
      isError: true,
    );
  }
}

/// La riga di stato: dice sempre qualcosa, anche quando non c'e' niente da dire.
///
/// Un pannello che dopo "Controlla ora" resta identico fa dubitare che il
/// pulsante funzioni. Uno stato esplicito per ogni fase elimina il dubbio, e
/// distingue "sei aggiornato" da "non ho potuto controllare": sono due cose
/// diverse che una spia spenta confonderebbe.
class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final UpdateStage stage = state.updateStage;
    final (String text, Color color) = switch (stage) {
      UpdateStage.idle => ('Nessun controllo effettuato in questa sessione.', CprPalette.inkFaint),
      UpdateStage.checking => ('Controllo in corso…', CprPalette.cyan),
      UpdateStage.upToDate => ('Nessun aggiornamento disponibile.', CprPalette.success),
      UpdateStage.available => (
          'Disponibile la versione ${state.availableUpdate?.version}.',
          CprPalette.success,
        ),
      UpdateStage.downloading => ('Scaricamento in corso…', CprPalette.cyan),
      UpdateStage.ready => ('Pacchetto scaricato e verificato.', CprPalette.success),
      UpdateStage.failed => (
          state.updateError ?? 'Controllo non riuscito.',
          CprPalette.warning,
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            switch (stage) {
              UpdateStage.checking || UpdateStage.downloading => Icons.sync,
              UpdateStage.upToDate || UpdateStage.available || UpdateStage.ready => Icons.check_circle_outline,
              UpdateStage.failed => Icons.warning_amber_outlined,
              UpdateStage.idle => Icons.info_outline,
            },
            size: 14,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: CprType.caption.copyWith(color: color, height: 1.45)),
        ),
      ],
    );
  }
}

/// La finestra che si vede durante il download.
///
/// Blocca la chiusura con un clic fuori: un download interrotto a meta' produce
/// un archivio troncato, e l'utente non ha modo di sapere se e' stato lui a
/// rompere qualcosa.
class _DownloadingDialog extends StatelessWidget {
  const _DownloadingDialog();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final int percent = (state.updateProgress * 100).round();

    return Dialog(
      backgroundColor: CprPalette.surface,
      insetPadding: const EdgeInsets.all(60),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'SCARICAMENTO',
              style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 11, letterSpacing: 1.6),
            ),
            const SizedBox(height: 6),
            Text(
              state.availableUpdate == null
                  ? ''
                  : 'Versione ${state.availableUpdate!.version}',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 16),
            Stack(
              children: <Widget>[
                Container(height: 10, color: CprPalette.surfaceSunken),
                FractionallySizedBox(
                  widthFactor: state.updateProgress.clamp(0, 1),
                  child: Container(height: 10, color: CprPalette.cyan),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$percent%',
              style: CprType.numeralSmall.copyWith(color: CprPalette.inkMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      color: CprPalette.veil(color, 0.08),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.45),
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(width: 8), action!],
        ],
      ),
    );
  }
}

class _UpdateToggle extends StatelessWidget {
  const _UpdateToggle({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(label, style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13)),
              const SizedBox(height: 5),
              Text(
                description,
                style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        TechSegmented<bool>(
          value: value,
          items: const <bool>[true, false],
          labelOf: (bool v) => v ? 'Attivo' : 'Spento',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
