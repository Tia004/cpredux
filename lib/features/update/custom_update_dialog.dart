import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../net/update_manifest.dart';
import '../../net/updater.dart';
import '../../version.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/tech_button.dart';

/// Apre la finestra di dialogo personalizzata per il download e riavvio dell'aggiornamento.
Future<void> showCustomUpdateDownloadDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.82),
    builder: (BuildContext ctx) => const _CustomUpdateDialog(),
  );
}

class _CustomUpdateDialog extends StatefulWidget {
  const _CustomUpdateDialog();

  @override
  State<_CustomUpdateDialog> createState() => _CustomUpdateDialogState();
}

class _CustomUpdateDialogState extends State<_CustomUpdateDialog> {
  bool _downloadStarted = false;
  String _statusMessage = 'Pronto per il download del pacchetto di installazione.';
  int _restartCountdown = 2;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _startDownload(AppState state) async {
    setState(() {
      _downloadStarted = true;
      _statusMessage = 'Connessione ai server di rilascio in corso…';
    });

    final bool ok = await state.downloadUpdate();
    if (!mounted) return;

    if (!ok) {
      setState(() {
        _statusMessage = 'Download non riuscito: ${state.updateError ?? "Errore di rete"}';
      });
      return;
    }

    setState(() {
      _statusMessage = 'Download completato e verificato. Riavvio tra $_restartCountdown s…';
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_restartCountdown <= 1) {
        t.cancel();
        await _applyAndRestart(state);
      } else {
        setState(() {
          _restartCountdown--;
          _statusMessage = 'Download completato. Riavvio tra $_restartCountdown s…';
        });
      }
    });
  }

  Future<void> _applyAndRestart(AppState state) async {
    final bool scheduled = await state.scheduleUpdateOnClose();
    if (!scheduled) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Impossibile pianificare l\'aggiornamento.';
        });
      }
      return;
    }
    await state.startPendingUpdate();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final UpdateManifest? release = state.availableUpdate;
    final double progress = state.updateProgress.clamp(0.0, 1.0);
    final bool isDownloading = state.updateStage == UpdateStage.downloading;
    final bool isReady = state.updateStage == UpdateStage.ready;
    final bool isFailed = state.updateStage == UpdateStage.failed;

    final String targetVersion = release?.version ?? 'Nuova Versione';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: ChamferPanel(
          accent: CprPalette.yellow,
          cut: 14,
          title: 'AGGIORNAMENTO SOFTWARE CPRedux',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: CprPalette.veil(CprPalette.yellow, 0.15),
              border: Border.all(color: CprPalette.yellow, width: 1),
            ),
            child: Text(
              'v$appVersion → v$targetVersion',
              style: CprType.label.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: CprPalette.yellow,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'E\' disponibile un nuovo aggiornamento ufficiale per la suite CPRedux Desktop.',
                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              if (release != null && release.notes.isNotEmpty) ...<Widget>[
                Text(
                  'NOTE DI RILASCIO',
                  style: CprType.label.copyWith(fontSize: 10.5, color: CprPalette.cyan, letterSpacing: 1.2),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CprPalette.surfaceSunken,
                    border: Border.all(color: CprPalette.hairline),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: release.notes
                          .take(6)
                          .map(
                            (String note) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.only(top: 6, right: 8),
                                    color: CprPalette.yellow,
                                  ),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.35),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Barra di Download Personalizzata Cyberpunk
              Text(
                'STATO DOWNLOAD',
                style: CprType.label.copyWith(fontSize: 10, color: CprPalette.inkMuted, letterSpacing: 1),
              ),
              const SizedBox(height: 6),
              _CyberpunkProgressBar(progress: progress, isDownloading: isDownloading, isReady: isReady),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: CprType.caption.copyWith(
                        color: isFailed
                            ? CprPalette.danger
                            : isReady
                                ? CprPalette.success
                                : CprPalette.yellow,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: CprType.label.copyWith(
                      color: CprPalette.yellow,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Azioni
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  if (!isDownloading && !isReady)
                    TechButton(
                      label: 'Chiudi',
                      variant: TechButtonVariant.ghost,
                      compact: true,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  const SizedBox(width: 10),
                  if (!_downloadStarted || isFailed)
                    TechButton(
                      label: isFailed ? 'Riprova Download' : 'Scarica e Riavvia',
                      icon: Icons.download,
                      variant: TechButtonVariant.primary,
                      compact: true,
                      onPressed: () => _startDownload(state),
                    )
                  else if (isReady)
                    TechButton(
                      label: 'Riavvia Ora',
                      icon: Icons.restart_alt,
                      variant: TechButtonVariant.primary,
                      compact: true,
                      onPressed: () => _applyAndRestart(state),
                    )
                  else
                    TechButton(
                      label: 'Download in corso…',
                      icon: Icons.sync,
                      variant: TechButtonVariant.ghost,
                      compact: true,
                      onPressed: null,
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

/// Barra di avanzamento personalizzata Cyberpunk a segmenti e bagliore neon.
class _CyberpunkProgressBar extends StatelessWidget {
  const _CyberpunkProgressBar({
    required this.progress,
    required this.isDownloading,
    required this.isReady,
  });

  final double progress;
  final bool isDownloading;
  final bool isReady;

  @override
  Widget build(BuildContext context) {
    final Color barColor = isReady ? CprPalette.success : CprPalette.yellow;

    return Container(
      height: 18,
      width: double.infinity,
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Stack(
        children: <Widget>[
          // Barra piena
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: CprMotion.fast,
              decoration: BoxDecoration(
                color: barColor.withValues(alpha: 0.85),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: barColor.withValues(alpha: 0.45),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          // Pattern a tratteggio cyberpunk
          Positioned.fill(
            child: CustomPaint(
              painter: _StripedPatternPainter(color: Colors.black.withValues(alpha: 0.35)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StripedPatternPainter extends CustomPainter {
  const _StripedPatternPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;

    const double step = 8.0;
    for (double x = -size.height; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StripedPatternPainter oldDelegate) => false;
}
