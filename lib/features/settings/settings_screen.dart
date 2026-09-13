import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/sheet.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/entrance.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../update/update_panel.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Column(
      children: <Widget>[
        const _TopBar(title: 'Impostazioni'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Entrance(
                      delay: const Duration(milliseconds: 30),
                      child: ChamferPanel(
                        title: 'Gioco e calcolo',
                        child: Column(
                          children: <Widget>[
                            _ToggleRow(
                              label: 'Calcolo automatico del carico',
                              description:
                                  'Somma il peso di oggetti e cyberware e applica le penalita\' a '
                                  'Velocita\' e Destrezza. Disattivandolo il carico resta visibile '
                                  'ma non incide sulle caratteristiche.',
                              value: state.settings.enableLoad,
                              onChanged: (bool v) =>
                                  state.updateSettings((s) => s.enableLoad = v),
                            ),
                            const SizedBox(height: 16),
                            _ToggleRow(
                              label: 'Salvataggio automatico',
                              description:
                                  'Salva sul file circa un secondo dopo l\'ultima modifica. '
                                  'Il vecchio programma salvava sempre: e\' una promessa che gli '
                                  'utenti si aspettano, quindi resta attiva di default.',
                              value: state.settings.autosave,
                              onChanged: (bool v) =>
                                  state.updateSettings((s) => s.autosave = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      delay: const Duration(milliseconds: 80),
                      child: ChamferPanel(
                        title: 'Integrazione',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _ToggleRow(
                              label: 'Discord Rich Presence',
                              description:
                                  'Mostra su Discord che stai usando l\'app, e su quale personaggio. '
                                  'Funziona automaticamente su macOS, Windows e Linux quando Discord e\' aperto.',
                              value: state.settings.enableDiscordRichPresence,
                              onChanged: (bool v) =>
                                  state.updateSettings((s) => s.enableDiscordRichPresence = v),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: state.discord.isConnected
                                        ? CprPalette.success
                                        : (state.settings.enableDiscordRichPresence
                                            ? CprPalette.warning
                                            : CprPalette.inkFaint),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    !state.settings.enableDiscordRichPresence
                                        ? 'Integrazione disattivata.'
                                        : (state.discord.isConnected
                                            ? 'Collegato a Discord: presenza attiva.'
                                            : 'Ricerca client Discord in corso (assicurati che Discord sia aperto)...'),
                                    style: CprType.caption.copyWith(
                                      color: state.discord.isConnected
                                          ? CprPalette.success
                                          : (state.settings.enableDiscordRichPresence
                                              ? CprPalette.warning
                                              : CprPalette.inkFaint),
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                                if (state.settings.enableDiscordRichPresence && !state.discord.isConnected) ...<Widget>[
                                  const SizedBox(width: 8),
                                  TechButton(
                                    label: 'Riprova',
                                    icon: Icons.refresh,
                                    variant: TechButtonVariant.ghost,
                                    compact: true,
                                    onPressed: () => state.refreshPresence(),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      delay: const Duration(milliseconds: 130),
                      child: const ChamferPanel(
                        title: 'Aggiornamenti',
                        child: UpdatePanel(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      delay: const Duration(milliseconds: 160),
                      child: ChamferPanel(
                        title: 'Aspetto',
                        trailing: Text(
                          'in arrivo',
                          style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Il tema chiaro e\' gia\' definito, ma i widget usano ancora i '
                              'colori del tema scuro letti come costanti. Va prima introdotto un '
                              'insieme di token di colore risolti in base al tema: finche\' non e\' '
                              'fatto, esporre l\'interruttore darebbe una schermata illeggibile. '
                              'La scelta e\' deliberata: meglio un\'opzione assente che una rotta.',
                              style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.5),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                _DisabledChip(label: 'Tema scuro', active: true),
                                const SizedBox(width: 8),
                                _DisabledChip(label: 'Tema chiaro', active: false),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      delay: const Duration(milliseconds: 180),
                      child: ChamferPanel(
                        title: 'Dove sono i tuoi file',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _PathRow(label: 'Documenti', path: AppPaths.documentsDir().path),
                            _PathRow(label: 'Dati applicazione', path: AppPaths.dataDir().path),
                            _PathRow(label: 'Configurazione', path: AppPaths.configDir().path),
                            const SizedBox(height: 14),
                            Row(
                              children: <Widget>[
                                TechButton(
                                  label: 'Svuota recenti',
                                  icon: Icons.cleaning_services_outlined,
                                  variant: TechButtonVariant.ghost,
                                  compact: true,
                                  onPressed: state.settings.recentFiles.isEmpty
                                      ? null
                                      : () async {
                                          final bool ok = await showTechConfirm(
                                            context,
                                            title: 'Svuotare i recenti?',
                                            message:
                                                'Verranno rimossi ${state.settings.recentFiles.length} '
                                                'riferimenti dall\'elenco. I file non vengono toccati.',
                                            confirmLabel: 'Svuota',
                                          );
                                          if (ok) {
                                            await state.updateSettings(
                                              (s) => s.recentFiles.clear(),
                                            );
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Entrance(
                      delay: const Duration(milliseconds: 230),
                      child: ChamferPanel(
                        title: 'Formato dei documenti',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            _InfoRow(label: 'Estensione', value: '.${CpreduxFile.extension}'),
                            _InfoRow(label: 'Versione del formato', value: 'v$cpreduxFormatVersion'),
                            _InfoRow(label: 'Contenitore', value: 'SQLite (journal DELETE, file singolo)'),
                            _InfoRow(
                              label: 'Compatibilita\'',
                              value: 'Vecchie .cpred_sheet convertibili automaticamente',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TechButton(
                        label: 'Torna al menu',
                        icon: Icons.arrow_back,
                        variant: TechButtonVariant.secondary,
                        onPressed: state.goHome,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Container(width: 4, height: 20, color: CprPalette.yellow),
          const SizedBox(width: 10),
          Text(
            title.toUpperCase(),
            style: CprType.label.copyWith(fontSize: 13, letterSpacing: 2.4, color: CprPalette.ink),
          ),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
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
              Text(label, style: CprType.body.copyWith(color: CprPalette.ink)),
              const SizedBox(height: 4),
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

class _DisabledChip extends StatelessWidget {
  const _DisabledChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          border: Border.all(color: active ? CprPalette.yellow : CprPalette.hairline),
        ),
        child: Text(
          label.toUpperCase(),
          style: CprType.label.copyWith(
            fontSize: 10,
            color: active ? CprPalette.yellow : CprPalette.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _PathRow extends StatelessWidget {
  const _PathRow({required this.label, required this.path});

  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 150,
            child: Text(
              label.toUpperCase(),
              style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
            ),
          ),
          Expanded(
            child: SelectableText(
              path,
              style: CprType.caption.copyWith(
                color: CprPalette.inkMuted,
                fontFamilyFallback: CprType.monoFamily,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 180,
            child: Text(
              label.toUpperCase(),
              style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
            ),
          ),
          Expanded(child: Text(value, style: CprType.caption.copyWith(color: CprPalette.ink))),
        ],
      ),
    );
  }
}
