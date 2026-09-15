import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../data/app_paths.dart';
import '../../data/cpredux_file.dart';
import '../../data/settings_store.dart';
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
                                            ? (state.discord.discordUsername != null
                                                ? 'Collegato a Discord come ${state.discord.discordUsername}: presenza attiva.'
                                                : 'Collegato a Discord: presenza attiva.')
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
                      child: _AppearancePanel(state: state),
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

class _AppearancePanel extends StatefulWidget {
  const _AppearancePanel({required this.state});

  final AppState state;

  @override
  State<_AppearancePanel> createState() => _AppearancePanelState();
}

class _AppearancePanelState extends State<_AppearancePanel> {
  final TextEditingController _hexController = TextEditingController();

  static const List<(String, String, String, Color)> _baseThemes = <(String, String, String, Color)>[
    ('dark', 'Scuro', 'Fondali neri high-tech e superfici graduate', Color(0xFF07080A)),
    ('light', 'Chiaro', 'Superfici luminose tattiche ad alta leggibilita\'', Color(0xFFF1F2F4)),
    ('oled', 'OLED', 'Nero puro #000000 per display OLED e contrasto estremo', Color(0xFF000000)),
  ];

  static const List<(String, String, String, Color, Color)> _subThemes = <(String, String, String, Color, Color)>[
    ('cyberpunk2077', 'Cyberpunk 2077', 'Giallo segnaletico, ciano e magenta', Color(0xFFFCEE0A), Color(0xFF22E6D2)),
    ('cyberpunkRed', 'Cyberpunk RED', 'Rosso cremisi da combattimento e carmine', Color(0xFFE8002D), Color(0xFFFF5E00)),
    ('militech', 'Militech', 'Verde fosforo tattico e verde militare', Color(0xFF00FF66), Color(0xFF3DDC84)),
    ('custom', 'Personalizzato', 'Colore d\'accento a tua scelta', Color(0xFF8B5CF6), Color(0xFFFF2E88)),
  ];

  static const List<Color> _customPresets = <Color>[
    Color(0xFFFCEE0A), // Giallo 2077
    Color(0xFFE8002D), // Cyberpunk Red
    Color(0xFF00FF66), // Militech
    Color(0xFF22E6D2), // Ciano
    Color(0xFFFF2E88), // Magenta
    Color(0xFF8B5CF6), // Violetto
    Color(0xFFFF5E00), // Arancio Neon
    Color(0xFF00D2FF), // Blu Elettrico
    Color(0xFFFFD700), // Oro Cromato
    Color(0xFFFF2A85), // Rosa Tokyo
  ];

  @override
  void initState() {
    super.initState();
    _hexController.text =
        '#${(widget.state.settings.customAccentColorValue & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  void _applyHex(String value) {
    String clean = value.replaceAll('#', '').trim();
    if (clean.length == 6) {
      final int? parsed = int.tryParse(clean, radix: 16);
      if (parsed != null) {
        widget.state.updateSettings((s) => s.customAccentColorValue = 0xFF000000 | parsed);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = widget.state.settings;
    final Color activeAccent = Theme.of(context).colorScheme.primary;

    return ChamferPanel(
      title: 'Tema e Aspetto',
      accent: activeAccent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TEMA BASE',
            style: CprType.label.copyWith(color: activeAccent, fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Imposta lo sfondo e le superfici visive dell\'intera suite.',
            style: CprType.caption.copyWith(color: CprPalette.inkMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final (String id, String title, String desc, Color bg) in _baseThemes)
                _ThemeCard(
                  title: title,
                  subtitle: desc,
                  previewColor: bg,
                  isSelected: settings.baseTheme == id,
                  accent: activeAccent,
                  onTap: () => widget.state.updateSettings((s) => s.baseTheme = id),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'SOTTOTEMA (PALETTE CROMATICA)',
            style: CprType.label.copyWith(color: activeAccent, fontSize: 11, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            'Modifica gli accenti, i bordi e gli stati grafici dei controlli cyberpunk.',
            style: CprType.caption.copyWith(color: CprPalette.inkMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: <Widget>[
              for (final (String id, String title, String desc, Color p, Color s) in _subThemes)
                _ThemeCard(
                  title: title,
                  subtitle: desc,
                  previewColor: id == 'custom' ? Color(settings.customAccentColorValue) : p,
                  secondaryColor: s,
                  isSelected: settings.subTheme == id,
                  accent: activeAccent,
                  onTap: () => widget.state.updateSettings((s) => s.subTheme = id),
                ),
            ],
          ),
          if (settings.subTheme == 'custom') ...<Widget>[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                border: Border.all(color: activeAccent.withValues(alpha: 0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'COLORE D\'ACCENTO PERSONALIZZATO',
                    style: CprType.label.copyWith(color: activeAccent, fontSize: 10, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      for (final Color color in _customPresets)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _hexController.text =
                                  '#${(color.toARGB32() & 0x00FFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
                            });
                            widget.state.updateSettings(
                              (s) => s.customAccentColorValue = color.toARGB32(),
                            );
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: settings.customAccentColorValue == color.toARGB32()
                                    ? Colors.white
                                    : CprPalette.hairlineBright,
                                width: settings.customAccentColorValue == color.toARGB32() ? 2.5 : 1.0,
                              ),
                              boxShadow: settings.customAccentColorValue == color.toARGB32()
                                  ? <BoxShadow>[
                                      BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Color(settings.customAccentColorValue),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 140,
                        child: TechField(
                          label: 'Codice HEX',
                          value: _hexController.text,
                          hint: '#FF0055',
                          onChanged: (String v) => _applyHex(v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.title,
    required this.subtitle,
    required this.previewColor,
    this.secondaryColor,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color previewColor;
  final Color? secondaryColor;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 255,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.12) : CprPalette.surfaceSunken,
          border: Border.all(
            color: isSelected ? accent : CprPalette.hairline,
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: isSelected
              ? <BoxShadow>[
                  BoxShadow(color: accent.withValues(alpha: 0.25), blurRadius: 10),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: previewColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
                  ),
                ),
                if (secondaryColor != null) ...<Widget>[
                  const SizedBox(width: 4),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: secondaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: CprType.label.copyWith(
                      color: isSelected ? accent : CprPalette.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: accent),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 10.5, height: 1.3),
            ),
          ],
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
