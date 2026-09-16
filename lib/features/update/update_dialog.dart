import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../net/update_manifest.dart';
import '../../version.dart';
import '../../widgets/tech_button.dart';

/// Cosa ha scelto l'utente davanti a un aggiornamento.
enum UpdateChoice {
  /// Scarica e installa subito.
  installNow,

  /// Salta **questa** versione: verra' riproposto solo il prossimo rilascio.
  skipVersion,

  /// Scarica adesso e installa alla chiusura del programma.
  onClose,
}

/// Chiede cosa fare di un aggiornamento disponibile.
///
/// Tre scelte e non due: "piu' tardi" e' la risposta piu' comune a un
/// aggiornamento, e senza un modo per dirlo l'utente impara a chiudere la
/// finestra senza leggerla. Chiudere senza scegliere non installa nulla — e'
/// l'unica lettura accettabile di un dialogo che chiede il permesso.
Future<UpdateChoice?> showUpdateDialog(
  BuildContext context, {
  required UpdateManifest release,
  required UpdatePlatform platform,
}) {
  return showDialog<UpdateChoice>(
    context: context,
    barrierDismissible: true,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.78),
    builder: (BuildContext context) => _UpdateDialog(release: release, platform: platform),
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release, required this.platform});

  final UpdateManifest release;
  final UpdatePlatform platform;

  /// La dimensione in una forma leggibile, o stringa vuota se il manifesto non
  /// la dichiara: dire "circa 0 MB" e' peggio che non dire niente.
  String get _sizeLabel {
    final int? bytes = release.assets[platform]?.size;
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final String size = _sizeLabel;

    return Dialog(
      backgroundColor: CprPalette.surface,
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: CprPalette.hairline)),
              ),
              child: Row(
                children: <Widget>[
                  Container(width: 3, height: 16, color: CprPalette.success),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AGGIORNAMENTO DISPONIBILE',
                      style: CprType.label.copyWith(
                        color: CprPalette.success,
                        fontSize: 12,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: <Widget>[
                      Text(
                        'Versione ${release.version}',
                        style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'hai la $appVersion',
                        style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (release.notes.isEmpty)
                    Text(
                      'Nessuna nota di rilascio.',
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                    )
                  else
                    for (final String note in release.notes.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(width: 4, height: 4, color: CprPalette.cyan),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                note,
                                style: CprType.caption.copyWith(
                                  color: CprPalette.inkMuted,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 10),
                  Text(
                    size.isEmpty
                        ? 'Pacchetto per ${platform.label}.'
                        : 'Pacchetto per ${platform.label} · $size',
                    style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: CprPalette.hairline)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TechButton(
                    label: 'Aggiorna adesso',
                    icon: Icons.download,
                    variant: TechButtonVariant.primary,
                    onPressed: () => Navigator.of(context).pop(UpdateChoice.installNow),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TechButton(
                          label: 'Alla chiusura',
                          icon: Icons.schedule,
                          variant: TechButtonVariant.secondary,
                          compact: true,
                          onPressed: () => Navigator.of(context).pop(UpdateChoice.onClose),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TechButton(
                          label: 'Salta questa versione',
                          icon: Icons.skip_next,
                          variant: TechButtonVariant.ghost,
                          compact: true,
                          onPressed: () => Navigator.of(context).pop(UpdateChoice.skipVersion),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Scaricando adesso l\'aggiornamento si applica alla chiusura senza dover '
                    'aspettare: a quel punto resta solo da sostituire i file, e non serve piu\' '
                    'la rete. Chiudendo questa finestra non si installa nulla.',
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
