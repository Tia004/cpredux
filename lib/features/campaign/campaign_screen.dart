import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../data/cpredux_file.dart';
import '../../data/document_library.dart';
import '../../domain/campaign.dart';
import '../../domain/campaign_combat.dart';
import '../../domain/enums.dart';
import '../../domain/net_architecture.dart';
import '../../domain/rules.dart';
import '../../domain/sheet.dart';
import '../sheet/chat_rich_tools.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/cyber_help_tooltip.dart';
import '../../widgets/dice_3d_table.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/humanity_gauge.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../ai/ai_assistant_drawer.dart';
import '../gm/gm_screen.dart';
import '../map/map_section.dart';
import 'net_architecture_editor.dart';
import 'ai_fleet_section.dart';
import 'cyberpunk_red_suite.dart';
import 'extended_tools.dart';
import 'session_transcriber.dart';
import 'session_summaries_section.dart';

/// Le sezioni del tavolo.
enum CampaignSection {
  players('Giocatori', Icons.groups_2_outlined),
  map('Mappa', Icons.map_outlined),
  netrun('Mappa NET', Icons.hub_outlined),
  table('Tavolo', Icons.forum_outlined),
  sessionSummaries('Riepiloghi Sessioni', Icons.history_edu_outlined),
  aiBots('IA del gioco', Icons.smart_toy_outlined),
  dice('Dadi', Icons.casino_outlined),
  notebook('Quaderno', Icons.menu_book_outlined),
  gmTools('Strumenti GM', Icons.dashboard_customize_outlined, masterOnly: true),
  aiChat('Cyber-Assistente IA', Icons.smart_toy_outlined, masterOnly: true),
  settings('Impostazioni', Icons.tune_outlined);

  const CampaignSection(this.label, this.icon, {this.masterOnly = false});

  final String label;
  final IconData icon;

  /// Se `true` la sezione e' visibile solo al Master della campagna.
  final bool masterOnly;

  Color get accent {
    switch (this) {
      case CampaignSection.players:
      case CampaignSection.netrun:
      case CampaignSection.aiChat:
        return CprPalette.cyan;
      case CampaignSection.map:
        return CprPalette.info;
      case CampaignSection.table:
      case CampaignSection.sessionSummaries:
      case CampaignSection.dice:
        return CprPalette.yellow;
      case CampaignSection.aiBots:
        return CprPalette.magenta;
      case CampaignSection.notebook:
      case CampaignSection.gmTools:
        return CprPalette.violet;
      case CampaignSection.settings:
        return CprPalette.inkFaint;
    }
  }
}

/// La schermata del master.
///
/// Il principio che la governa: **il master e' l'autorita'**. Qui il master
/// vede tutti i personaggi del tavolo e puo' modificarli lui stesso — punti
/// vita, umanita', fortuna, ferite, ban. Non e' una scorciatoia: e' il modello
/// di gioco. Il master decide che un colpo e' andato a segno e lo applica,
/// invece di chiedere al giocatore di aggiornare la propria scheda e sperare
/// che lo faccia.
class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  CampaignSection _section = CampaignSection.players;

  Widget _sectionWidget() {
    switch (_section) {
      case CampaignSection.players:
        return const _PlayersSection();
      case CampaignSection.map:
        return const MapSection(asGameMaster: true);
      case CampaignSection.netrun:
        return const _NetrunSection();
      case CampaignSection.table:
        return const _TableSection();
      case CampaignSection.sessionSummaries:
        return const SessionSummariesSection();
      case CampaignSection.aiBots:
        return const AiFleetMasterSection();
      case CampaignSection.dice:
        return const _DiceSection();
      case CampaignSection.notebook:
        return const _NotebookSection();
      case CampaignSection.gmTools:
        return const Padding(
          padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: GmConsole(),
        );
      case CampaignSection.aiChat:
        return const AiAssistantDrawer(isFullWidth: true);
      case CampaignSection.settings:
        return const _SettingsSection();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    if (state.campaign == null) return const SizedBox.shrink();

    return Column(
      children: <Widget>[
        const RepaintBoundary(child: _CampaignHeader()),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              RepaintBoundary(
                child: _CampaignRail(
                  current: _section,
                  onSelect: (CampaignSection s) => setState(() => _section = s),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: CprMotion.normal,
                  switchInCurve: CprMotion.enter,
                  switchOutCurve: CprMotion.exit,
                  child: KeyedSubtree(
                    key: ValueKey<CampaignSection>(_section),
                    child: _sectionWidget(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CampaignHeader extends StatelessWidget {
  const _CampaignHeader();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign campaign = state.campaign!;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  TechButton(
                    label: '',
                    icon: Icons.arrow_back,
                    variant: TechButtonVariant.ghost,
                    compact: true,
                    tooltip: 'Torna al menu',
                    onPressed: state.closeDocument,
                  ),
                  const SizedBox(width: 12),
                  Container(width: 3, height: 18, color: CprPalette.cyan),
                  const SizedBox(width: 9),
                  Text(
                    campaign.meta.name,
                    overflow: TextOverflow.ellipsis,
                    style: CprType.body.copyWith(color: CprPalette.ink, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  _SessionBadge(state: state),
                  const SizedBox(width: 8),
                  CyberHelpTooltip(
                    title: 'Tavolo & Connessione LAN/Web',
                    message: 'Il Master apre il tavolo su una porta TCP (es. :20199 o :21099). I giocatori si collegano inserendo l\'indirizzo o cliccando il link di invito.',
                    tag: 'Rete',
                    accent: CprPalette.cyan,
                  ),
                  const SizedBox(width: 10),
                  _CampaignClockBadge(campaign: campaign, state: state),
                  const SizedBox(width: 14),
                  const SessionMicrophoneIndicator(),
                  const SizedBox(width: 10),
                  if (state.isHosting) ...<Widget>[
                    Text(
                      '${campaign.players.where((CampaignPlayer p) => p.isConnected).length} al tavolo',
                      style: CprType.caption.copyWith(color: CprPalette.cyan),
                    ),
                    const SizedBox(width: 10),
                  TechButton(
                    label: 'Invita',
                    icon: Icons.share_outlined,
                    variant: TechButtonVariant.secondary,
                    compact: true,
                    tooltip: 'Mostra i dettagli di connessione e link di invito per i giocatori',
                    onPressed: () => openInviteDialog(context, state, campaign),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: 'Chiudi tavolo',
                    icon: Icons.stop_circle_outlined,
                    variant: TechButtonVariant.danger,
                    compact: true,
                    onPressed: state.stopHosting,
                  ),
                ] else ...<Widget>[
                  TechButton(
                    label: 'Apri il tavolo',
                    icon: Icons.wifi_tethering,
                    variant: TechButtonVariant.primary,
                    compact: true,
                    tooltip: 'Mette il master in ascolto sulla porta ${campaign.port}',
                    onPressed: () => state.startHosting(),
                  ),
                ],
                const SizedBox(width: 10),
                TechButton(
                  label: 'Salva',
                  icon: Icons.save_outlined,
                  variant: TechButtonVariant.secondary,
                  compact: true,
                  onPressed: () => state.save(),
                ),
              ],
            ),
          ),
        ),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            color: CprPalette.surfaceSunken,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  Text(
                    'STRUMENTI TAVOLO',
                    style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 8.5),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: 'Iniziativa',
                    icon: Icons.format_list_numbered,
                    compact: true,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Ordine di turno e iniziativa per PG e PNG',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const InitiativeTrackerDialog(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TechButton(
                    label: 'Balistica & DV',
                    icon: Icons.straighten,
                    compact: true,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Calcolo DV tiro per arma, distanza in metri e coperture',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const BallisticDvCalculatorDialog(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TechButton(
                    label: 'Incontri NC',
                    icon: Icons.casino,
                    compact: true,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Generatore rapido di agguati, Max-Tac, meteo e gang',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const NightCityEncounterDialog(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TechButton(
                    label: 'Loot Nemici',
                    icon: Icons.inventory_2_outlined,
                    compact: true,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Generatore bottino, chip dati, munizioni e droghe',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const EnemyLootDialog(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TechButton(
                    label: 'Screamsheets',
                    icon: Icons.newspaper_outlined,
                    compact: true,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Bacheca notizie, ingaggi Fixer e voci di corridoio',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const ScreamsheetNewsDialog(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TechButton(
                    label: 'Terapia Umanità',
                    icon: Icons.psychology_outlined,
                    compact: true,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Tracciatore terapia cyberpsicosi, degenza e costi in eddy',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => CyberpsychosisTherapyDialog(state: state),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TechButton(
                    label: 'Debiti Corp',
                    icon: Icons.account_balance_outlined,
                    compact: true,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Registro debiti aziendali con scadenze e interessi',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => const CorporateDebtsDialog(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  if (!state.isSessionLive)
                    TechButton(
                      label: 'Avvia Sessione',
                      icon: Icons.play_arrow_outlined,
                      compact: true,
                      variant: TechButtonVariant.primary,
                      tooltip: 'Avvia la sessione live: attiva il microfono e la registrazione Voice-to-Text',
                      onPressed: () {
                        state.startLiveSession();
                      },
                    )
                  else
                    TechButton(
                      label: 'Termina Sessione & Riepilogo IA',
                      icon: Icons.summarize_outlined,
                      compact: true,
                      variant: TechButtonVariant.danger,
                      tooltip: 'Compila trascrizioni vocali, genera commit con note e riassunto IA',
                      onPressed: () {
                        state.endLiveSession();
                        showDialog<void>(
                          context: context,
                          builder: (_) => EndSessionSummaryDialog(
                            campaign: campaign,
                            initialPlayerSummaries: state.pendingPlayerSummaries.values.toList(),
                            onSaveCommit: (CampaignSessionCommit commit) {
                              state.mutateCampaign((Campaign c) {
                                c.sessionCommits.add(commit);
                              });
                              state.pendingPlayerSummaries.clear();
                              state.appendSessionEvent(
                                description: 'Master: Sessione archiviata: ${commit.title} (ID: ${commit.id})',
                              );
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CampaignClockBadge extends StatelessWidget {
  const _CampaignClockBadge({required this.campaign, required this.state});

  final Campaign campaign;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showCampaignClockDialog(context, state, campaign),
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: CprPalette.veil(CprPalette.cyan, 0.10),
          border: Border.all(color: CprPalette.veil(CprPalette.cyan, 0.35)),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.schedule, size: 12, color: CprPalette.cyan),
            const SizedBox(width: 5),
            Text(
              '${campaign.gameDate} · ${campaign.gameTime}',
              style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 9.5),
            ),
            const SizedBox(width: 4),
            Icon(Icons.edit, size: 9, color: CprPalette.cyan),
          ],
        ),
      ),
    );
  }
}

Future<void> showCampaignClockDialog(BuildContext context, AppState state, Campaign campaign) async {
  final TextEditingController dateCtrl = TextEditingController(text: campaign.gameDate);
  final TextEditingController timeCtrl = TextEditingController(text: campaign.gameTime);

  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) {
          return AlertDialog(
            backgroundColor: CprPalette.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: CprPalette.cyan, width: 1.5),
            ),
            title: Row(
              children: <Widget>[
                Icon(Icons.schedule, color: CprPalette.cyan, size: 22),
                const SizedBox(width: 10),
                Text(
                  'OROLOGIO DI CAMPAGNA',
                  style: CprType.title.copyWith(fontSize: 15, color: CprPalette.cyan),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Data e ora di gioco condivise nel mondo di Cyberpunk RED. '
                    'Ogni evento del registro viene scandito da questo orologio.',
                    style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: dateCtrl,
                          style: CprType.body.copyWith(color: CprPalette.ink),
                          decoration: InputDecoration(
                            labelText: 'Data di gioco (AAAA-MM-GG)',
                            filled: true,
                            fillColor: CprPalette.surfaceSunken,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: CprPalette.hairline)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: timeCtrl,
                          style: CprType.body.copyWith(color: CprPalette.ink),
                          decoration: InputDecoration(
                            labelText: 'Ora (HH:MM)',
                            filled: true,
                            fillColor: CprPalette.surfaceSunken,
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: CprPalette.hairline)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('AVANZAMENTO RAPIDO', style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 9)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      TechButton(
                        label: '+1 Ora',
                        compact: true,
                        variant: TechButtonVariant.ghost,
                        onPressed: () {
                          final List<String> parts = timeCtrl.text.split(':');
                          int h = int.tryParse(parts.first) ?? 12;
                          final int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                          h = (h + 1) % 24;
                          setModalState(() {
                            timeCtrl.text = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                          });
                        },
                      ),
                      TechButton(
                        label: '+6 Ore',
                        compact: true,
                        variant: TechButtonVariant.ghost,
                        onPressed: () {
                          final List<String> parts = timeCtrl.text.split(':');
                          int h = int.tryParse(parts.first) ?? 12;
                          final int m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
                          h = (h + 6) % 24;
                          setModalState(() {
                            timeCtrl.text = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                          });
                        },
                      ),
                      TechButton(
                        label: 'Notte (23:00)',
                        compact: true,
                        variant: TechButtonVariant.ghost,
                        onPressed: () => setModalState(() => timeCtrl.text = '23:00'),
                      ),
                      TechButton(
                        label: 'Alba (06:30)',
                        compact: true,
                        variant: TechButtonVariant.ghost,
                        onPressed: () => setModalState(() => timeCtrl.text = '06:30'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TechButton(
                label: 'Annulla',
                variant: TechButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              TechButton(
                label: 'Applica Tempo',
                variant: TechButtonVariant.primary,
                onPressed: () {
                  state.mutateCampaign((Campaign c) {
                    c.gameDate = dateCtrl.text.trim();
                    c.gameTime = timeCtrl.text.trim();
                  });
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> openInviteDialog(BuildContext context, AppState state, Campaign campaign) async {
  final int port = state.host?.port ?? campaign.port;
  final String code = 'CP-${port.toString().substring(math.max(0, port.toString().length - 4))}';

  // Raccoglie subito gli IP locali conosciuti senza attendere rete esterna
  final List<String> ips = <String>[];
  if (state.localAddresses.isNotEmpty) {
    ips.addAll(state.localAddresses);
  }
  try {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final NetworkInterface iface in interfaces) {
      for (final InternetAddress addr in iface.addresses) {
        if (!addr.isLoopback && !ips.contains(addr.address)) {
          ips.add(addr.address);
        }
      }
    }
  } catch (_) {}
  if (ips.isEmpty) ips.add('127.0.0.1');

  final String primaryIp = ips.first;
  final String link = 'cpred://join?host=$primaryIp&port=$port&code=$code';
  final String shareText = 'Tavolo CPRed aperto!\n'
      '• Codice Stanza: $code\n'
      '• Link Rapido: $link\n'
      '• Connessione Locale: $primaryIp:$port'
      '${campaign.password.isNotEmpty ? "\n• Password: ${campaign.password}" : ""}';

  // Copia immediata negli appunti
  try {
    await Clipboard.setData(ClipboardData(text: shareText));
  } catch (_) {}

  if (!context.mounted) return;

  // Mostra la finestra di dialogo interattiva
  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) => _InviteDialog(
      campaign: campaign,
      port: port,
      state: state,
      initialIps: ips,
    ),
  );
}

/// Dialog Cyberpunk per la condivisione e invito dei giocatori al tavolo.
class _InviteDialog extends StatefulWidget {
  const _InviteDialog({
    required this.campaign,
    required this.port,
    required this.state,
    required this.initialIps,
  });

  final Campaign campaign;
  final int port;
  final AppState state;
  final List<String> initialIps;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  late List<String> _localIps;
  String? _publicIp;
  bool _loadingPublic = true;

  @override
  void initState() {
    super.initState();
    _localIps = List<String>.from(widget.initialIps);
    _fetchPublicIp();
  }

  Future<void> _fetchPublicIp() async {
    try {
      final HttpClient client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1000);
      final HttpClientRequest req = await client.getUrl(Uri.parse('https://api.ipify.org')).timeout(const Duration(milliseconds: 1200));
      final HttpClientResponse res = await req.close().timeout(const Duration(milliseconds: 1200));
      if (res.statusCode == 200) {
        final String ip = (await res.transform(utf8.decoder).join()).trim();
        if (mounted && ip.isNotEmpty) {
          setState(() {
            _publicIp = ip;
            _loadingPublic = false;
          });
          return;
        }
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loadingPublic = false);
    }
  }

  String _fullInviteText() {
    final String primaryIp = _localIps.isNotEmpty ? _localIps.first : '127.0.0.1';
    final String code = 'CP-${widget.port.toString().substring(math.max(0, widget.port.toString().length - 4))}';
    final String link = 'cpred://join?host=$primaryIp&port=${widget.port}&code=$code';
    final String pwd = widget.campaign.password.isNotEmpty ? '\n• Password tavolo: ${widget.campaign.password}' : '';

    return '🎲 TAVOLO CYBERPUNK RED APERTO!\n'
        '• Codice Stanza: $code\n'
        '• Link Diretto: $link\n'
        '• Indirizzo Locale: ${_localIps.map((String ip) => "$ip:${widget.port}").join(" oppure ")}\n'
        '${_publicIp != null ? "• Indirizzo Esterno (Online / VPN): $_publicIp:${widget.port}\n" : ""}'
        '$pwd\n'
        'Apri la scheda del tuo personaggio, vai in "Sessione" e inserisci questi dati per sincronizzarti col master.';
  }

  @override
  Widget build(BuildContext context) {
    final String code = 'CP-${widget.port.toString().substring(math.max(0, widget.port.toString().length - 4))}';
    final String primaryIp = _localIps.isNotEmpty ? _localIps.first : '127.0.0.1';
    final String link = 'cpred://join?host=$primaryIp&port=${widget.port}&code=$code';

    return AlertDialog(
      backgroundColor: CprPalette.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: CprPalette.cyan, width: 1.5),
      ),
      title: Row(
        children: <Widget>[
          Icon(Icons.share, color: CprPalette.cyan, size: 22),
          const SizedBox(width: 10),
          Text(
            'INVITA GIOCATORI AL TAVOLO',
            style: CprType.title.copyWith(fontSize: 15, color: CprPalette.cyan),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.success, 0.12),
                  border: Border.all(color: CprPalette.success),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.check_circle, color: CprPalette.success, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dettagli pronti! Già copiati negli appunti per essere inviati ai giocatori.',
                        style: CprType.caption.copyWith(color: CprPalette.success),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _InviteFieldRow(
                label: 'CODICE STANZA',
                value: code,
                onCopy: () => _copySingle(context, code, 'Codice stanza'),
              ),
              const SizedBox(height: 10),
              _InviteFieldRow(
                label: 'INDIRIZZO LOCALE (STESSO WI-FI / RETE)',
                value: _localIps.map((String ip) => '$ip:${widget.port}').join('  |  '),
                onCopy: () => _copySingle(context, '$primaryIp:${widget.port}', 'Indirizzo locale'),
              ),
              if (_publicIp != null) ...<Widget>[
                const SizedBox(height: 10),
                _InviteFieldRow(
                  label: 'INDIRIZZO PUBBLICO (ESTERNO / ROUTER)',
                  value: '$_publicIp:${widget.port}',
                  onCopy: () => _copySingle(context, '$_publicIp:${widget.port}', 'Indirizzo pubblico'),
                ),
              ] else if (_loadingPublic) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  'Rilevamento IP pubblico in corso...',
                  style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                ),
              ],
              if (widget.campaign.password.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                _InviteFieldRow(
                  label: 'PASSWORD TAVOLO',
                  value: widget.campaign.password,
                  onCopy: () => _copySingle(context, widget.campaign.password, 'Password'),
                ),
              ],
              const SizedBox(height: 10),
              _InviteFieldRow(
                label: 'LINK RAPIDO PER L\'APP',
                value: link,
                onCopy: () => _copySingle(context, link, 'Link rapido'),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TechButton(
          label: 'Chiudi',
          variant: TechButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(),
        ),
        TechButton(
          label: 'Copia tutto il messaggio d\'invito',
          icon: Icons.copy_all,
          variant: TechButtonVariant.primary,
          onPressed: () async {
            final String text = _fullInviteText();
            await Clipboard.setData(ClipboardData(text: text));
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Invito completo copiato negli appunti! Incollalo ai tuoi giocatori.'),
                  backgroundColor: CprPalette.surface,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Future<void> _copySingle(BuildContext context, String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copiato negli appunti!'),
          backgroundColor: CprPalette.surface,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

class _InviteFieldRow extends StatelessWidget {
  const _InviteFieldRow({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.hairline),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: CprType.label.copyWith(fontSize: 8.5, color: CprPalette.inkFaint),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: CprType.body.copyWith(
                    color: CprPalette.cyan,
                    fontFamilyFallback: CprType.monoFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TechButton(
            label: 'Copia',
            icon: Icons.copy,
            variant: TechButtonVariant.ghost,
            compact: true,
            onPressed: onCopy,
          ),
        ],
      ),
    );
  }
}

/// Finestra modale per modificare direttamente il numero di porta senza passare dalle impostazioni.
Future<void> showEditPortDialog(BuildContext context, AppState state, Campaign campaign) async {
  final TextEditingController controller = TextEditingController(text: '${campaign.port}');
  String? error;

  await showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      return StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setModalState) {
          return AlertDialog(
            backgroundColor: CprPalette.surfaceRaised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: CprPalette.yellow, width: 1.5),
            ),
            title: Row(
              children: <Widget>[
                Icon(Icons.settings_ethernet, color: CprPalette.yellow, size: 22),
                const SizedBox(width: 10),
                Text(
                  'MODIFICA PORTA SERVER',
                  style: CprType.title.copyWith(fontSize: 15, color: CprPalette.yellow),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Modifica la porta per il tavolo di gioco. Se il tavolo è già aperto, '
                    'verrà riavviato automaticamente sulla nuova porta.',
                    style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: CprType.body.copyWith(
                      color: CprPalette.ink,
                      fontFamilyFallback: CprType.monoFamily,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Porta server (1024 - 65535)',
                      labelStyle: CprType.label.copyWith(color: CprPalette.yellow),
                      errorText: error,
                      filled: true,
                      fillColor: CprPalette.surfaceSunken,
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: CprPalette.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: CprPalette.yellow),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TechButton(
                label: 'Annulla',
                variant: TechButtonVariant.ghost,
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              TechButton(
                label: 'Applica porta',
                variant: TechButtonVariant.primary,
                onPressed: () async {
                  final int? parsed = int.tryParse(controller.text.trim());
                  if (parsed == null || parsed < 1024 || parsed > 65535) {
                    setModalState(() {
                      error = 'Inserisci un numero di porta valido tra 1024 e 65535';
                    });
                    return;
                  }
                  Navigator.of(ctx).pop();
                  state.mutateCampaign((Campaign c) => c.port = parsed);
                  if (state.isHosting) {
                    await state.stopHosting();
                    await state.startHosting();
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Porta impostata su $parsed${state.isHosting ? " (tavolo riavviato)" : ""}'),
                        backgroundColor: CprPalette.surface,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      );
    },
  );
}

/// Stato del tavolo, con il pallino che pulsa quando la sessione e' aperta.
///
/// Un indicatore testuale ("aperto") non dice se il tavolo *sta ricevendo*:
/// il battito lo dice in un modo che si percepisce con la coda dell'occhio,
/// mentre si sta guardando altro — cosa che un master fa continuamente.
class _SessionBadge extends StatefulWidget {
  const _SessionBadge({required this.state});

  final AppState state;

  @override
  State<_SessionBadge> createState() => _SessionBadgeState();
}

class _SessionBadgeState extends State<_SessionBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    if (widget.state.isHosting) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _SessionBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.isHosting && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.state.isHosting && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hosting = widget.state.isHosting;
    final Color color = hosting ? CprPalette.success : CprPalette.inkFaint;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AnimatedBuilder(
          animation: _pulse,
          builder: (BuildContext context, _) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: hosting
                  ? <BoxShadow>[
                      BoxShadow(
                        color: CprPalette.veil(color, 0.5 * (0.4 + _pulse.value)),
                        blurRadius: 10,
                        spreadRadius: 2 * _pulse.value,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: widget.state.campaign != null
              ? () => showEditPortDialog(context, widget.state, widget.state.campaign!)
              : null,
          borderRadius: BorderRadius.circular(3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  hosting
                      ? 'TAVOLO APERTO · PORTA ${widget.state.host!.port}'
                      : 'TAVOLO CHIUSO · PORTA ${widget.state.campaign?.port ?? 21099}',
                  style: CprType.label.copyWith(color: color, fontSize: 9.5),
                ),
                const SizedBox(width: 4),
                Icon(Icons.edit, size: 10, color: color),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CampaignRail extends StatelessWidget {
  const _CampaignRail({required this.current, required this.onSelect});

  final CampaignSection current;
  final ValueChanged<CampaignSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: CprPalette.hairline)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Builder(
          builder: (BuildContext context) {
            final AppState state = AppScope.of(context);
            // Le sezioni master-only vengono filtrate per i giocatori connessi.
            final List<CampaignSection> visible = CampaignSection.values
                .where((CampaignSection s) => !s.masterOnly || state.isMaster)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final CampaignSection s in visible)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => onSelect(s),
                      child: AnimatedContainer(
                        duration: CprMotion.fast,
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                        margin: const EdgeInsets.only(bottom: 2),
                        color: s == current ? CprPalette.veil(s.accent, 0.10) : null,
                        child: Row(
                          children: <Widget>[
                            Icon(s.icon, size: 15, color: s == current ? s.accent : CprPalette.inkMuted),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.label,
                                overflow: TextOverflow.ellipsis,
                                style: CprType.caption.copyWith(
                                  color: s == current ? s.accent : CprPalette.inkMuted,
                                  fontSize: 12.5,
                                  fontWeight: s == current ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// --- Giocatori --------------------------------------------------------------

class _PlayersSection extends StatelessWidget {
  const _PlayersSection();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign campaign = state.campaign!;

    if (campaign.players.isEmpty) {
      return const _EmptyTavolo();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final CampaignPlayer player in campaign.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PlayerCard(
                campaign: campaign,
                player: player,
                onChanged: state.save,
                onDamage: (int amount) => state.masterDamage(player.id, amount),
                onHeal: (int amount) => state.masterHeal(player.id, amount),
                onRestoreAll: () => state.masterRestoreAll(player.id),
                onRestoreHumanity: (int amount) => state.masterRestoreHumanity(player.id, amount),
                onSetHitPoints: (int value) => state.masterSetHitPoints(player.id, value),
                onToggleBan: () => state.masterSetBanned(player.id, !player.isBanned),
                onRemove: () => state.masterRemovePlayer(player.id),
                onNote: (String note) => state.masterNote(player.id, note),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyTavolo extends StatelessWidget {
  const _EmptyTavolo();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign campaign = state.campaign!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ChamferPanel(
            title: 'Nessun giocatore al tavolo',
            accent: CprPalette.cyan,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        state.isHosting
                            ? 'Il tavolo e\' aperto. Comunica ai giocatori uno di questi indirizzi e la porta:'
                            : 'Apri il tavolo per far collegare i giocatori. Porta configurata:',
                        style: CprType.body.copyWith(color: CprPalette.ink),
                      ),
                    ),
                    InkWell(
                      onTap: () => showEditPortDialog(context, state, campaign),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CprPalette.veil(CprPalette.cyan, 0.12),
                          border: Border.all(color: CprPalette.cyan),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              ':${campaign.port}',
                              style: CprType.label.copyWith(
                                color: CprPalette.cyan,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.edit, size: 12, color: CprPalette.cyan),
                            const SizedBox(width: 5),
                            Text(
                              'Modifica porta',
                              style: CprType.caption.copyWith(color: CprPalette.cyan, fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (state.isHosting && state.localAddresses.isNotEmpty)
                  for (final String address in state.localAddresses)
                    _AddressRow(
                      address: address,
                      port: campaign.port,
                      password: campaign.password,
                      onEditPort: () => showEditPortDialog(context, state, campaign),
                    )
                else
                  _AddressRow(
                    address: state.localAddresses.isEmpty
                        ? '127.0.0.1 (solo questa macchina)'
                        : state.localAddresses.first,
                    port: campaign.port,
                    password: campaign.password,
                    onEditPort: () => showEditPortDialog(context, state, campaign),
                  ),
                const SizedBox(height: 14),
                Text(
                  'Il giocatore apre il suo personaggio, va in "Sessione" e inserisce indirizzo, '
                  'porta e password. Da quel momento i valori del personaggio si sincronizzano '
                  'con questo tavolo, e tu puoi modificarli da qui.',
                  style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.address,
    required this.port,
    required this.password,
    this.onEditPort,
  });

  final String address;
  final int port;
  final String password;
  final VoidCallback? onEditPort;

  @override
  Widget build(BuildContext context) {
    final String fullAddress = '$address:$port';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: CprPalette.surfaceSunken,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                SelectableText(
                  address,
                  style: CprType.body.copyWith(
                    color: CprPalette.cyan,
                    fontFamilyFallback: CprType.monoFamily,
                    fontSize: 13,
                  ),
                ),
                InkWell(
                  onTap: onEditPort,
                  borderRadius: BorderRadius.circular(4),
                  child: Tooltip(
                    message: 'Clicca per modificare direttamente la porta :$port',
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CprPalette.veil(CprPalette.yellow, 0.15),
                        border: Border.all(color: CprPalette.yellow, width: 1.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            ':$port',
                            style: CprType.body.copyWith(
                              color: CprPalette.yellow,
                              fontWeight: FontWeight.bold,
                              fontFamilyFallback: CprType.monoFamily,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.edit, size: 12, color: CprPalette.yellow),
                        ],
                      ),
                    ),
                  ),
                ),
                if (password.isNotEmpty)
                  SelectableText(
                    '  (password: $password)',
                    style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                  ),
              ],
            ),
          ),
          TechButton(
            label: 'Copia',
            icon: Icons.copy_all_outlined,
            variant: TechButtonVariant.ghost,
            compact: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullAddress));
              if (!context.mounted) return;
              await showTechMessage(
                context,
                title: 'Copiato',
                message: 'Indirizzo copiato negli appunti.',
                detail: password.isEmpty ? fullAddress : '$fullAddress (password: $password)',
              );
            },
          ),
        ],
      ),
    );
  }
}

/// La scheda di un giocatore vista dal master.
///
/// I comandi rapidi (danno, cura) stanno in alto perche' sono quelli che si
/// usano durante il combattimento, quando serve applicare un numero in due
/// secondi. I campi estesi (fortuna, ferite, nota) stanno sotto, perche' si
/// toccano una volta a serata.
class _PlayerCard extends StatefulWidget {
  const _PlayerCard({
    required this.campaign,
    required this.player,
    required this.onChanged,
    required this.onDamage,
    required this.onHeal,
    required this.onRestoreAll,
    required this.onRestoreHumanity,
    required this.onSetHitPoints,
    required this.onToggleBan,
    required this.onRemove,
    required this.onNote,
  });

  final Campaign campaign;
  final CampaignPlayer player;
  final VoidCallback onChanged;
  final void Function(int) onDamage;
  final void Function(int) onHeal;
  final VoidCallback onRestoreAll;
  final void Function(int) onRestoreHumanity;
  final void Function(int) onSetHitPoints;
  final VoidCallback onToggleBan;
  final VoidCallback onRemove;
  final void Function(String) onNote;

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  bool _expanded = false;

  static int _current(String value) {
    final List<String> parts = value.split('/');
    return int.tryParse(parts.first.trim()) ?? 0;
  }

  static int _max(String value) {
    final List<String> parts = value.split('/');
    if (parts.length < 2) return _current(value);
    return int.tryParse(parts[1].trim()) ?? _current(value);
  }

  @override
  Widget build(BuildContext context) {
    final CampaignPlayer p = widget.player;
    final int hp = _current(p.hitPoints);
    final int hpMax = _max(p.hitPoints);
    final int humanity = _current(p.humanity);
    final int humanityMax = _max(p.humanity);
    final double hpRatio = hpMax == 0 ? 0 : hp / hpMax;
    final Color hpColor = CprPalette.healthColorFor(hpRatio);

    return ChamferPanel(
      accent: p.isConnected ? CprPalette.success : CprPalette.inkFaint,
      title: p.characterName.isEmpty ? 'Senza nome' : p.characterName,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            color: CprPalette.veil(
              p.isConnected ? CprPalette.success : CprPalette.inkFaint,
              0.14,
            ),
            child: Text(
              p.isConnected ? 'COLLEGATO' : 'OFFLINE',
              style: CprType.label.copyWith(
                fontSize: 8.5,
                color: p.isConnected ? CprPalette.success : CprPalette.inkFaint,
              ),
            ),
          ),
          if (p.isBanned) ...<Widget>[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              color: CprPalette.veil(CprPalette.danger, 0.16),
              child: Text(
                'BANNATO',
                style: CprType.label.copyWith(fontSize: 8.5, color: CprPalette.danger),
              ),
            ),
          ],
          const SizedBox(width: 8),
          TechButton(
            label: '',
            icon: _expanded ? Icons.expand_less : Icons.expand_more,
            variant: TechButtonVariant.ghost,
            compact: true,
            tooltip: _expanded ? 'Nascondi dettagli' : 'Mostra dettagli',
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (p.role.trim().isNotEmpty) ...<Widget>[
                Text(
                  p.role.toUpperCase(),
                  style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 9.5),
                ),
                if (p.roleRank.trim().isNotEmpty)
                  Text(
                    ' · RANGO ${p.roleRank}',
                    style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                  ),
                const SizedBox(width: 10),
              ],
              if (p.playerName.trim().isNotEmpty)
                Text(
                  'giocato da ${p.playerName}',
                  style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
                ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Widget hpTile = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _VitalTile(
                    label: 'Punti vita',
                    value: p.hitPoints.isEmpty ? '—' : '$hp / $hpMax',
                    color: hpColor,
                    ratio: hpRatio,
                  ),
                  const SizedBox(height: 10),
                  const SizedBox(height: 10),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TechNumberStepper(
                          label: 'Imposta PV',
                          value: hp,
                          max: 999,
                          compact: true,
                          accent: hpColor,
                          onChanged: widget.onSetHitPoints,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _Quick(label: 'DANNO 1', color: CprPalette.danger, onTap: () => widget.onDamage(1)),
                      _Quick(label: 'DANNO 5', color: CprPalette.danger, onTap: () => widget.onDamage(5)),
                      _Quick(label: 'DANNO 10', color: CprPalette.danger, onTap: () => widget.onDamage(10)),
                      _Quick(label: 'CURA 5', color: CprPalette.success, onTap: () => widget.onHeal(5)),
                      _Quick(label: 'CURA 20', color: CprPalette.success, onTap: () => widget.onHeal(20)),
                      _Quick(label: 'RIPOSO', color: CprPalette.cyan, onTap: widget.onRestoreAll),
                    ],
                  ),
                ],
              );

              final Widget humanityTile = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: HumanityGauge(
                      current: humanity,
                      max: humanityMax == 0 ? 1 : humanityMax,
                      size: 120,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TechNumberStepper(
                    label: 'Fortuna',
                    value: int.tryParse(p.luck.trim()) ?? 0,
                    max: 999,
                    compact: true,
                    accent: CprPalette.yellow,
                    onChanged: (int v) => AppScope.of(context).masterSetLuck(p.id, v),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      _Quick(
                        label: 'TERAPIA +6',
                        color: CprPalette.humanityIntact,
                        onTap: () => widget.onRestoreHumanity(6),
                      ),
                      _Quick(
                        label: 'CYBER -4',
                        color: CprPalette.humanityEroded,
                        onTap: () => AppScope.of(context).masterRestoreHumanity(
                          p.id,
                          -4,
                          reason: 'Cyberware installato dal master',
                        ),
                      ),
                    ],
                  ),
                ],
              );

              if (c.maxWidth < 820) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[hpTile, const SizedBox(height: 16), humanityTile],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: hpTile),
                  const SizedBox(width: 18),
                  Expanded(flex: 4, child: humanityTile),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: TechField(
                  label: 'Ferite gravi',
                  value: p.severeInjuries,
                  hint: 'Nessuna',
                  accent: CprPalette.warning,
                  onChanged: (String v) => AppScope.of(context).masterAddInjury(p.id, v),
                ),
              ),
              const SizedBox(width: 10),
              TechButton(
                label: 'Guarisci',
                icon: Icons.healing_outlined,
                variant: TechButtonVariant.ghost,
                compact: true,
                onPressed: () => AppScope.of(context).masterClearInjuries(p.id),
              ),
            ],
          ),
          if (_expanded) ...<Widget>[
            const SizedBox(height: 12),
            if (p.reputation.trim().isNotEmpty || p.humanity.trim().isNotEmpty)
              Row(
                children: <Widget>[
                  if (p.reputation.trim().isNotEmpty)
                    Expanded(
                      child: _MiniStat(label: 'Reputazione', value: p.reputation),
                    ),
                  if (p.humanity.trim().isNotEmpty)
                    Expanded(
                      child: _MiniStat(label: 'Umanita', value: p.humanity),
                    ),
                  if (p.empathy.trim().isNotEmpty) Expanded(child: _MiniStat(label: 'Empatia', value: p.empathy)),
                ],
              ),
            const SizedBox(height: 12),
            if (p.addictions.trim().isNotEmpty) ...<Widget>[
              _MiniStat(label: 'Dipendenze', value: p.addictions),
              const SizedBox(height: 10),
            ],
            TechTextArea(
              label: 'Nota del master',
              value: p.notes,
              lines: 3,
              hint: 'Quello che il giocatore non sa…',
              onChanged: widget.onNote,
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text(
                  'ID ${p.id}',
                  style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
                ),
                const Spacer(),
                if (AppScope.of(context).isHosting) ...<Widget>[
                  TechButton(
                    label: 'Invia scheda',
                    icon: Icons.send_outlined,
                    variant: TechButtonVariant.secondary,
                    compact: true,
                    tooltip: 'Invia una scheda aggiornata direttamente a questo giocatore',
                    onPressed: () => _promptSendSheetToPlayer(context, AppScope.of(context), p),
                  ),
                  const SizedBox(width: 8),
                ],
                TechButton(
                  label: p.isBanned ? 'Riammetti' : 'Allontana',
                  icon: p.isBanned ? Icons.lock_open_outlined : Icons.block,
                  variant: p.isBanned ? TechButtonVariant.ghost : TechButtonVariant.danger,
                  compact: true,
                  onPressed: widget.onToggleBan,
                ),
                const SizedBox(width: 8),
                TechButton(
                  label: 'Rimuovi',
                  icon: Icons.delete_outline,
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  tooltip: 'Toglie il personaggio dal tavolo e dal documento',
                  onPressed: widget.onRemove,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _promptSendSheetToPlayer(BuildContext context, AppState state, CampaignPlayer player) async {
    final List<DocumentEntry> sheets = state.documentsOfKind(DocumentKind.sheet);
    if (sheets.isEmpty) {
      showTechMessage(
        context,
        title: 'Nessuna Scheda',
        message: 'Non ci sono schede personaggio salvate nella libreria da inviare al giocatore.',
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: CprPalette.surface,
        title: Text(
          'Invia scheda a ${player.characterName.isNotEmpty ? player.characterName : player.id}',
          style: CprType.body.copyWith(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Seleziona quale scheda inviare dal tuo archivio al giocatore:',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted),
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 280),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: sheets.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext _, int idx) {
                    final DocumentEntry entry = sheets[idx];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.person, color: CprPalette.cyan, size: 20),
                      title: Text(entry.name, style: CprType.body.copyWith(fontSize: 13)),
                      subtitle: Text(entry.fileName, style: CprType.caption.copyWith(fontSize: 10)),
                      trailing: Icon(Icons.send_outlined, size: 16, color: CprPalette.yellow),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        try {
                          final CpreduxFile file = CpreduxFile.open(entry.path);
                          final CharacterSheet s;
                          try {
                            s = file.readSheet();
                          } finally {
                            file.close();
                          }
                          state.sendSheetToPlayer(player.id, s, reason: 'Scheda aggiornata inviata dal Master');
                          showTechMessage(
                            context,
                            title: 'Scheda Inviata',
                            message: 'La scheda "${s.meta.name}" e\' stata inviata a ${player.characterName.isNotEmpty ? player.characterName : player.id}.',
                          );
                        } catch (e) {
                          showTechMessage(
                            context,
                            title: 'Errore',
                            message: 'Impossibile inviare la scheda: $e',
                            isError: true,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annulla'),
          ),
        ],
      ),
    );
  }
}

class _VitalTile extends StatelessWidget {
  const _VitalTile({
    required this.label,
    required this.value,
    required this.color,
    required this.ratio,
  });

  final String label;
  final String value;
  final Color color;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint)),
            const Spacer(),
            Text(value, style: CprType.numeralSmall.copyWith(color: color, fontSize: 20)),
          ],
        ),
        const SizedBox(height: 6),
        _Bar(ratio: ratio, color: color),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.ratio, required this.color});

  final double ratio;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: ratio.clamp(0, 1)),
        duration: CprMotion.normal,
        curve: CprMotion.enter,
        builder: (BuildContext context, double value, _) => Stack(
          children: <Widget>[
            Container(color: CprPalette.surfaceSunken),
            FractionallySizedBox(
              widthFactor: value,
              child: Container(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: CprPalette.veil(color, 0.10),
            border: Border.all(color: CprPalette.veil(color, 0.45)),
          ),
          child: Text(label, style: CprType.label.copyWith(color: color, fontSize: 9.5)),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
        const SizedBox(height: 3),
        Text(value, style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12.5)),
      ],
    );
  }
}

// --- Tavolo (chat + log) ----------------------------------------------------

class _TableSection extends StatefulWidget {
  const _TableSection();

  @override
  State<_TableSection> createState() => _TableSectionState();
}

class _TableSectionState extends State<_TableSection> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _activeChannel = 'TAVOLO'; // 'TAVOLO' oppure nome del giocatore / gruppo
  final Set<String> _openChannels = <String>{};
  final Set<String> _selectedPlayersForGroup = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _syncSecretTabsFromEvents(List<SessionEvent> events) {
    for (final SessionEvent e in events) {
      if (e.isWhisper) {
        if (e.delta.isNotEmpty && e.delta != 'MASTER') {
          _openChannels.add(e.delta);
        }
        if (e.whisperTo.isNotEmpty) {
          _openChannels.add(e.whisperTo);
        }
      }
    }
  }

  List<SessionEvent> _getFilteredEvents(List<SessionEvent> allEvents) {
    if (_activeChannel == 'TAVOLO') {
      return allEvents.where((SessionEvent e) => !e.isWhisper).toList();
    }
    final List<String> targets = _activeChannel
        .split(',')
        .map((String s) => s.trim().toLowerCase())
        .where((String s) => s.isNotEmpty)
        .toList();

    return allEvents.where((SessionEvent e) {
      if (!e.isWhisper) return false;
      final List<String> eTargets = e.whisperTargets.map((String s) => s.toLowerCase()).toList();
      final String sender = e.delta.toLowerCase();
      final String pid = e.playerId.toLowerCase();

      final bool targetMatches = targets.any((String t) => eTargets.contains(t) || e.whisperTo.toLowerCase().contains(t));
      final bool senderMatches = targets.contains(sender) || targets.contains(pid);
      return targetMatches || senderMatches;
    }).toList();
  }

  void _sendMessage(AppState state, {String? gifUrl}) {
    final String text = _controller.text;
    final String clean = text.trim();

    if (clean == '/help') {
      state.masterChat('/help');
      _controller.clear();
      setState(() {});
      return;
    }

    if (clean == '/clear') {
      state.masterChat('/clear');
      _controller.clear();
      setState(() {});
      return;
    }

    if (clean.startsWith('/w ') || clean.startsWith('/whisper ')) {
      final bool isShort = clean.startsWith('/w ');
      final String after = clean.substring(isShort ? 3 : 9).trim();
      String target = '';
      if (after.startsWith('"')) {
        final int end = after.indexOf('"', 1);
        if (end != -1) target = after.substring(1, end).trim();
      } else {
        final int sp = after.indexOf(' ');
        if (sp != -1) target = after.substring(0, sp).trim();
      }
      if (target.isNotEmpty) {
        _openChannels.add(target);
        _activeChannel = target;
      }
      state.masterChat(text, gifUrl: gifUrl);
      _controller.clear();
      setState(() {});
      return;
    }

    if (_activeChannel != 'TAVOLO') {
      state.masterChat(text, whisperTo: _activeChannel, gifUrl: gifUrl);
    } else {
      state.masterChat(text, gifUrl: gifUrl);
    }
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign campaign = state.campaign!;

    _syncSecretTabsFromEvents(state.sessionLog);
    final List<SessionEvent> filtered = _getFilteredEvents(state.sessionLog);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Sinistra: Area Chat Principale + Tab Canali
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Barra schede chat canali segreti
                _ChannelTabBar(
                  activeChannel: _activeChannel,
                  openChannels: _openChannels.toList(),
                  onSelect: (String ch) => setState(() => _activeChannel = ch),
                  onClose: (String ch) {
                    setState(() {
                      _openChannels.remove(ch);
                      if (_activeChannel == ch) _activeChannel = 'TAVOLO';
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Pannello Registro messaggi
                Expanded(
                  child: ChamferPanel(
                    title: _activeChannel == 'TAVOLO'
                        ? 'Registro di sessione · Tavolo'
                        : 'Chat Segreta · Sussurro a [$_activeChannel]',
                    accent: _activeChannel == 'TAVOLO' ? CprPalette.yellow : CprPalette.magenta,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        if (_activeChannel != 'TAVOLO')
                          TechButton(
                            label: 'Torna al Tavolo',
                            icon: Icons.public,
                            variant: TechButtonVariant.ghost,
                            compact: true,
                            onPressed: () => setState(() => _activeChannel = 'TAVOLO'),
                          ),
                        TechButton(
                          label: 'Pulisci',
                          icon: Icons.cleaning_services_outlined,
                          variant: TechButtonVariant.ghost,
                          compact: true,
                          onPressed: () {
                            state.sessionLog.clear();
                            state.clearSessionError();
                          },
                        ),
                      ],
                    ),
                    child: filtered.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _activeChannel == 'TAVOLO'
                                    ? (state.isHosting
                                        ? 'Il tavolo e\' aperto: chat globale, tiri e notifiche compaiono qui.\nDigita /help per i comandi o usa la barra a destra per iniziare un sussurro.'
                                        : 'Apri il tavolo per iniziare la sessione.')
                                    : 'Nessun messaggio segreto con $_activeChannel.\nI messaggi scritti in questa scheda sono visibili solo ai destinatari selezionati.',
                                textAlign: TextAlign.center,
                                style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: filtered.length,
                            itemBuilder: (BuildContext context, int i) =>
                                _LogRow(event: filtered[i]),
                          ),
                  ),
                ),
                if (state.sessionError != null) ...<Widget>[
                  const SizedBox(height: 8),
                  _ErrorBar(message: state.sessionError!, onDismiss: state.clearSessionError),
                ],
                const SizedBox(height: 8),
                // Indicatore canale attivo sopra l'input
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: CprPalette.veil(
                      _activeChannel == 'TAVOLO' ? CprPalette.cyan : CprPalette.magenta,
                      0.12,
                    ),
                    border: Border.all(
                      color: CprPalette.veil(
                        _activeChannel == 'TAVOLO' ? CprPalette.cyan : CprPalette.magenta,
                        0.5,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        _activeChannel == 'TAVOLO' ? Icons.public : Icons.lock,
                        size: 13,
                        color: _activeChannel == 'TAVOLO' ? CprPalette.cyan : CprPalette.magenta,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _activeChannel == 'TAVOLO'
                              ? 'DESTINAZIONE: TUTTO IL TAVOLO (PUBBLICO) · Comandi disponibili: /help, /whisper'
                              : 'DESTINAZIONE: SUSSURRO RISERVATO A [$_activeChannel]',
                          style: CprType.label.copyWith(
                            fontSize: 9.5,
                            color: _activeChannel == 'TAVOLO' ? CprPalette.cyan : CprPalette.magenta,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (_activeChannel != 'TAVOLO')
                        InkWell(
                          onTap: () => setState(() => _activeChannel = 'TAVOLO'),
                          child: Text(
                            '✕ Torna al Tavolo',
                            style: CprType.caption.copyWith(
                              fontSize: 9.5,
                              color: CprPalette.inkMuted,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Barra di input
                Row(
                  children: <Widget>[
                    IconButton(
                      icon: Icon(Icons.emoji_emotions_outlined, color: CprPalette.yellow, size: 20),
                      tooltip: 'Aggiungi emoji Unicode',
                      onPressed: state.isHosting
                          ? () async {
                              final String? emoji = await showCyberEmojiPicker(context);
                              if (emoji != null) {
                                _controller.text = '${_controller.text}$emoji';
                              }
                            }
                          : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.gif_box_outlined, color: CprPalette.cyan, size: 20),
                      tooltip: 'Invia GIF (Tenor / Giphy)',
                      onPressed: state.isHosting
                          ? () async {
                              final String? gifUrl = await showCyberGifPicker(context);
                              if (gifUrl != null) {
                                _sendMessage(state, gifUrl: gifUrl);
                              }
                            }
                          : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.attach_file, color: CprPalette.magenta, size: 20),
                      tooltip: 'Invia file o immagine P2P',
                      onPressed: state.isHosting
                          ? () => pickAndSendAttachment(
                                context,
                                onSend: state.masterSendAttachment,
                              )
                          : null,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TechField(
                        label: '',
                        value: _controller.text,
                        hint: _activeChannel == 'TAVOLO'
                            ? 'Parla al tavolo (/help per comandi, /w <nome> <msg> per sussurri)…'
                            : 'Sussurra segretamente a $_activeChannel…',
                        onChanged: (String v) => _controller.text = v,
                      ),
                    ),
                    const SizedBox(width: 10),
                    TechButton(
                      label: 'Invia',
                      icon: Icons.send,
                      variant: _activeChannel == 'TAVOLO'
                          ? TechButtonVariant.primary
                          : TechButtonVariant.secondary,
                      onPressed: state.isHosting ? () => _sendMessage(state) : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Destra: Barra laterale Giocatori Connessi con Sussurri e Selezione Multipla
          SizedBox(
            width: 270,
            child: _ConnectedPlayersSidebar(
              campaign: campaign,
              state: state,
              selectedPlayers: _selectedPlayersForGroup,
              onToggleSelect: (String name) {
                setState(() {
                  if (_selectedPlayersForGroup.contains(name)) {
                    _selectedPlayersForGroup.remove(name);
                  } else {
                    _selectedPlayersForGroup.add(name);
                  }
                });
              },
              onWhisperToPlayer: (String name) {
                _openChannels.add(name);
                setState(() => _activeChannel = name);
              },
              onCreateGroupSecret: (List<String> names) {
                final String groupKey = names.join(', ');
                _openChannels.add(groupKey);
                setState(() => _activeChannel = groupKey);
              },
              onInvite: () => openInviteDialog(context, state, campaign),
            ),
          ),
        ],
      ),
    );
  }
}

/// Barra a schede per canali di chat (Tavolo e chat segrete con i singoli/gruppi).
class _ChannelTabBar extends StatelessWidget {
  const _ChannelTabBar({
    required this.activeChannel,
    required this.openChannels,
    required this.onSelect,
    required this.onClose,
  });

  final String activeChannel;
  final List<String> openChannels;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          _ChannelTabButton(
            label: 'TAVOLO',
            icon: Icons.public,
            isActive: activeChannel == 'TAVOLO',
            accent: CprPalette.cyan,
            onTap: () => onSelect('TAVOLO'),
          ),
          for (final String ch in openChannels) ...<Widget>[
            const SizedBox(width: 6),
            _ChannelTabButton(
              label: ch,
              icon: Icons.lock,
              isActive: activeChannel == ch,
              accent: CprPalette.magenta,
              onTap: () => onSelect(ch),
              onClose: () => onClose(ch),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelTabButton extends StatelessWidget {
  const _ChannelTabButton({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.accent,
    required this.onTap,
    this.onClose,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? CprPalette.veil(accent, 0.2) : CprPalette.surfaceSunken,
          border: Border.all(
            color: isActive ? accent : CprPalette.hairline,
            width: isActive ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: isActive ? accent : CprPalette.inkMuted),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: CprType.label.copyWith(
                  fontSize: 10,
                  color: isActive ? accent : CprPalette.ink,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (onClose != null) ...<Widget>[
              const SizedBox(width: 6),
              InkWell(
                onTap: onClose,
                child: Icon(
                  Icons.close,
                  size: 13,
                  color: isActive ? accent : CprPalette.inkFaint,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pannello a destra con l'elenco dei giocatori connessi, pulsante whisper e selezione per sussurri multipli.
class _ConnectedPlayersSidebar extends StatelessWidget {
  const _ConnectedPlayersSidebar({
    required this.campaign,
    required this.state,
    required this.selectedPlayers,
    required this.onToggleSelect,
    required this.onWhisperToPlayer,
    required this.onCreateGroupSecret,
    required this.onInvite,
  });

  final Campaign campaign;
  final AppState state;
  final Set<String> selectedPlayers;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<String> onWhisperToPlayer;
  final ValueChanged<List<String>> onCreateGroupSecret;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final List<CampaignPlayer> players = campaign.players;
    final int connectedCount = players.where((CampaignPlayer p) => p.isConnected).length;

    return ChamferPanel(
      title: 'Giocatori ($connectedCount online)',
      accent: CprPalette.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (players.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: <Widget>[
                  Text(
                    'Nessun giocatore registrato.',
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                  ),
                  const SizedBox(height: 12),
                  TechButton(
                    label: 'Invita giocatori',
                    icon: Icons.share,
                    variant: TechButtonVariant.secondary,
                    compact: true,
                    onPressed: onInvite,
                  ),
                ],
              ),
            )
          else ...<Widget>[
            Text(
              'Seleziona per sussurri multipli o usa il lucchetto per una chat segreta privata:',
              style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 8.5),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: players.length,
                itemBuilder: (BuildContext context, int index) {
                  final CampaignPlayer p = players[index];
                  final String charName = p.characterName.trim().isEmpty ? 'Senza Nome' : p.characterName;
                  final bool isSelected = selectedPlayers.contains(charName);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? CprPalette.veil(CprPalette.magenta, 0.12)
                          : CprPalette.surfaceSunken,
                      border: Border.all(
                        color: isSelected ? CprPalette.magenta : CprPalette.hairline,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Row(
                      children: <Widget>[
                        // Checkbox selezione gruppo
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: Checkbox(
                            value: isSelected,
                            activeColor: CprPalette.magenta,
                            onChanged: (_) => onToggleSelect(charName),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Pallino connessione
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: p.isConnected ? CprPalette.success : CprPalette.inkFaint,
                            boxShadow: p.isConnected
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: CprPalette.veil(CprPalette.success, 0.6),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nome personaggio e ruolo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                charName,
                                overflow: TextOverflow.ellipsis,
                                style: CprType.body.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: p.isConnected ? CprPalette.ink : CprPalette.inkMuted,
                                ),
                              ),
                              if (p.playerName.isNotEmpty || p.role.isNotEmpty)
                                Text(
                                  p.playerName.isNotEmpty && p.role.isNotEmpty
                                      ? '${p.playerName} · ${p.role}'
                                      : (p.playerName.isNotEmpty ? p.playerName : p.role),
                                  overflow: TextOverflow.ellipsis,
                                  style: CprType.caption.copyWith(
                                    fontSize: 9.5,
                                    color: CprPalette.inkFaint,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Bottone Whisper rapido
                        IconButton(
                          icon: Icon(Icons.lock_outline, size: 16, color: CprPalette.magenta),
                          tooltip: 'Apri chat segreta con $charName',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => onWhisperToPlayer(charName),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (selectedPlayers.length >= 2) ...<Widget>[
              const SizedBox(height: 8),
              TechButton(
                label: 'Sussurro di gruppo (${selectedPlayers.length})',
                icon: Icons.group,
                variant: TechButtonVariant.primary,
                compact: true,
                onPressed: () => onCreateGroupSecret(selectedPlayers.toList()),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.event});

  final SessionEvent event;

  @override
  Widget build(BuildContext context) {
    final bool isWhisper = event.isWhisper;
    final bool isTransaction = event.isTransaction;
    final bool isAlert = event.isAlert;

    final Color color = isAlert
        ? CprPalette.danger
        : isTransaction
            ? CprPalette.success
            : isWhisper
                ? CprPalette.magenta
                : switch (event.delta) {
                    'MASTER' => CprPalette.yellow,
                    'TU' => CprPalette.inkMuted,
                    'PV -' || 'PV +' => CprPalette.healthFull,
                    _ => CprPalette.ink,
                  };

    final BoxDecoration? itemDeco = isAlert
        ? BoxDecoration(
            color: CprPalette.veil(CprPalette.danger, 0.16),
            border: Border.all(color: CprPalette.veil(CprPalette.danger, 0.5), width: 1.2),
            borderRadius: BorderRadius.circular(3),
          )
        : isTransaction
            ? BoxDecoration(
                color: CprPalette.veil(CprPalette.success, 0.14),
                border: Border.all(color: CprPalette.veil(CprPalette.success, 0.4), width: 1.2),
                borderRadius: BorderRadius.circular(3),
              )
            : isWhisper
                ? BoxDecoration(
                    color: CprPalette.veil(CprPalette.magenta, 0.08),
                    border: Border.all(color: CprPalette.veil(CprPalette.magenta, 0.3)),
                    borderRadius: BorderRadius.circular(3),
                  )
                : null;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: (isAlert || isTransaction || isWhisper)
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : EdgeInsets.zero,
      decoration: itemDeco,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: 62,
                child: Text(
                  _time(event.timestamp),
                  style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
                ),
              ),
              if (isAlert) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: CprPalette.veil(CprPalette.danger, 0.22),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.block, size: 10, color: CprPalette.danger),
                      const SizedBox(width: 4),
                      Text(
                        'BAN / AVVISO',
                        style: CprType.label.copyWith(
                          fontSize: 8.5,
                          color: CprPalette.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isTransaction) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: CprPalette.veil(CprPalette.success, 0.22),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.payments_outlined, size: 10, color: CprPalette.success),
                      const SizedBox(width: 4),
                      Text(
                        'EDDY',
                        style: CprType.label.copyWith(
                          fontSize: 8.5,
                          color: CprPalette.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isWhisper) ...<Widget>[
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: CprPalette.veil(CprPalette.magenta, 0.2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.lock, size: 10, color: CprPalette.magenta),
                      const SizedBox(width: 4),
                      Text(
                        event.whisperTo.isNotEmpty ? 'SUSSURRO A: ${event.whisperTo.toUpperCase()}' : 'SUSSURRO',
                        style: CprType.label.copyWith(
                          fontSize: 8.5,
                          color: CprPalette.magenta,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (!isAlert && !isTransaction && event.delta.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: CprPalette.veil(
                    event.delta == 'MASTER' ? CprPalette.yellow : CprPalette.cyan,
                    0.12,
                  ),
                  child: Text(
                    event.delta.toUpperCase(),
                    style: CprType.label.copyWith(
                      fontSize: 8.5,
                      color: event.delta == 'MASTER' ? CprPalette.yellow : CprPalette.cyan,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  event.description,
                  style: CprType.caption.copyWith(color: color, height: 1.4),
                ),
              ),
            ],
          ),
          if (event.hasGif) ...<Widget>[
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(left: 62),
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 180),
              decoration: BoxDecoration(
                border: Border.all(color: CprPalette.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                event.gifUrl,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Icon(Icons.broken_image, color: CprPalette.inkMuted),
                ),
              ),
            ),
          ],
          if (event.hasAttachment) ...<Widget>[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 62),
              child: event.isImageAttachment
                  ? Container(
                      constraints: const BoxConstraints(maxWidth: 280, maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: CprPalette.cyan),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: <Widget>[
                          Image.memory(
                            base64Decode(event.attachmentData),
                            fit: BoxFit.cover,
                            errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.broken_image, color: CprPalette.inkMuted),
                            ),
                          ),
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: CircleAvatar(
                              backgroundColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
                              radius: 14,
                              child: IconButton(
                                icon: Icon(Icons.download, size: 14, color: CprPalette.cyan),
                                tooltip: 'Salva immagine',
                                padding: EdgeInsets.zero,
                                onPressed: () => saveAttachmentToDisk(
                                  context,
                                  fileName: event.attachmentName,
                                  base64Data: event.attachmentData,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: CprPalette.surfaceRaised,
                        border: Border.all(color: CprPalette.hairline),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.insert_drive_file_outlined, color: CprPalette.cyan, size: 20),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                event.attachmentName,
                                style: CprType.caption.copyWith(
                                  color: CprPalette.ink,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${(event.attachmentSize / 1024).toStringAsFixed(1)} KB',
                                style: CprType.label.copyWith(
                                  color: CprPalette.inkFaint,
                                  fontSize: 8.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          TechButton(
                            label: 'Salva',
                            icon: Icons.download,
                            variant: TechButtonVariant.secondary,
                            compact: true,
                            onPressed: () => saveAttachmentToDisk(
                              context,
                              fileName: event.attachmentName,
                              base64Data: event.attachmentData,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  static String _time(String iso) {
    final DateTime? at = DateTime.tryParse(iso);
    if (at == null) return '';
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}';
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.danger, 0.12),
        border: Border.all(color: CprPalette.veil(CprPalette.danger, 0.5)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded, size: 15, color: CprPalette.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: CprType.caption.copyWith(color: CprPalette.ink)),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close, size: 14, color: CprPalette.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Dadi -------------------------------------------------------------------

class _DiceSection extends StatefulWidget {
  const _DiceSection();

  @override
  State<_DiceSection> createState() => _DiceSectionState();
}

class _DiceSectionState extends State<_DiceSection> {
  final math.Random _rng = math.Random();
  DiceType _die = DiceType.d10;
  int _count = 1;
  int _modifier = 0;
  DiceRoll? _last;
  String _lastLabel = '1D10';
  int _reveal = 0;

  void _roll(AppState state) {
    final DiceRoll roll = _count == 1
        ? rollDie(_die, modifier: _modifier, random: _rng)
        : rollDice(_die, _count, modifier: _modifier, random: _rng);
    final String label = _count == 1 ? _die.label : '$_count${_die.label}';
    final String detail = _modifier == 0
        ? label
        : '$label ${_modifier > 0 ? '+' : '-'} ${_modifier.abs()}';

    setState(() {
      _last = roll;
      _lastLabel = label;
      _reveal++;
    });

    // Il tiro del master va a tutto il tavolo: e' il suo scopo. Nel registro
    // locale resta con l'etichetta MASTER, perche' e' il master a parlare.
    state.masterBroadcastRoll(
      label: label,
      detail: detail,
      total: roll.total,
      isCritical: roll.isCritical,
      isFumble: roll.isFumble,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChamferPanel(
                title: 'Tavolo dei Dadi 3D',
                accent: _last == null
                    ? CprPalette.cyan
                    : (_last!.isCritical
                        ? CprPalette.success
                        : _last!.isFumble
                            ? CprPalette.danger
                            : CprPalette.yellow),
                child: _last == null
                    ? Container(
                        height: 280,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E12),
                          border: Border.all(color: CprPalette.hairline),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Icon(Icons.casino_outlined, size: 48, color: CprPalette.veil(CprPalette.cyan, 0.4)),
                              const SizedBox(height: 12),
                              Text(
                                'TAVOLO DEI DADI 3D PRONTO',
                                style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 11, letterSpacing: 1.0),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Seleziona i dadi e lancia per il tavolo della campagna',
                                style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Dice3DTable(
                        die: _die,
                        results: _last!.individualResults.isEmpty ? <int>[_last!.total] : _last!.individualResults,
                        total: _last!.total,
                        label: _lastLabel,
                        modifier: _modifier,
                        isCritical: _last!.isCritical,
                        isFumble: _last!.isFumble,
                        revealKey: _reveal,
                        tableHeight: 285.0,
                      ),
              ),
              const SizedBox(height: 14),
              ChamferPanel(
                title: 'Tira per il tavolo',
                accent: CprPalette.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final DiceType d in DiceType.values)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => setState(() => _die = d),
                              child: Container(
                                width: 52,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: d == _die
                                      ? CprPalette.veil(CprPalette.yellow, 0.14)
                                      : CprPalette.surfaceSunken,
                                  border: Border.all(
                                    color: d == _die ? CprPalette.yellow : CprPalette.hairline,
                                  ),
                                ),
                                child: Text(
                                  d.label.toUpperCase(),
                                  style: CprType.label.copyWith(
                                    fontSize: 10,
                                    color: d == _die ? CprPalette.yellow : CprPalette.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechNumberStepper(
                            label: 'Dadi',
                            value: _count,
                            min: 1,
                            max: 20,
                            accent: CprPalette.yellow,
                            onChanged: (int v) => setState(() => _count = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechNumberStepper(
                            label: 'Modificatore',
                            value: _modifier,
                            min: -30,
                            max: 30,
                            accent: CprPalette.cyan,
                            onChanged: (int v) => setState(() => _modifier = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TechButton(
                      label: 'Tira e annuncia al tavolo',
                      icon: Icons.campaign_outlined,
                      variant: TechButtonVariant.primary,
                      onPressed: state.isHosting ? () => _roll(state) : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- Quaderno ---------------------------------------------------------------

class _NotebookSection extends StatelessWidget {
  const _NotebookSection();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign campaign = state.campaign!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChamferPanel(
                title: 'Quaderno di campagna',
                accent: CprPalette.violet,
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechField(
                            label: 'Data in gioco',
                            value: campaign.gameDate,
                            hint: '2077, 12 giugno',
                            accent: CprPalette.violet,
                            onChanged: (String v) => state.mutateCampaign((c) => c.gameDate = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: 'Nome della campagna',
                            value: campaign.meta.name,
                            accent: CprPalette.violet,
                            onChanged: (String v) => state.mutateCampaign((c) => c.meta.name = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TechTextArea(
                      label: 'Di cosa parla',
                      value: campaign.description,
                      lines: 6,
                      hint: 'La trama, i fili aperti, chi sta tramando…',
                      onChanged: (String v) => state.mutateCampaign((c) => c.description = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ChamferPanel(
                title: 'Eventi salvati',
                accent: CprPalette.inkMuted,
                trailing: campaign.events.isEmpty
                    ? null
                    : TechButton(
                        label: 'Svuota',
                        icon: Icons.delete_sweep_outlined,
                        variant: TechButtonVariant.ghost,
                        compact: true,
                        onPressed: () async {
                          final bool ok = await showTechConfirm(
                            context,
                            title: 'Svuotare gli eventi?',
                            message: 'Verranno rimossi ${campaign.events.length} eventi dal documento. '
                                'La chat di sessione non e\' salvata, quindi non viene toccata.',
                            confirmLabel: 'Svuota',
                            danger: true,
                          );
                          if (ok) state.mutateCampaign((c) => c.events.clear());
                        },
                      ),
                child: campaign.events.isEmpty
                    ? Text(
                        'Nessun evento salvato. Le modifiche del master finiscono qui.',
                        style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: ListView.builder(
                          itemCount: campaign.events.length,
                          itemBuilder: (BuildContext context, int i) =>
                              _LogRow(event: campaign.events[i]),
                        ),
                      ),
              ),
              const SizedBox(height: 14),
              ChamferPanel(
                title: 'Diario delle Sessioni & Riepiloghi IA (${campaign.sessionCommits.length})',
                accent: CprPalette.yellow,
                trailing: TechButton(
                  label: 'Nuovo Riepilogo Sessione',
                  icon: Icons.add_circle_outline,
                  variant: TechButtonVariant.primary,
                  compact: true,
                  onPressed: () {
                    state.broadcastSessionEnd();
                    showDialog<void>(
                      context: context,
                      builder: (_) => EndSessionSummaryDialog(
                        campaign: campaign,
                        initialPlayerSummaries: state.pendingPlayerSummaries.values.toList(),
                        onSaveCommit: (CampaignSessionCommit commit) {
                          state.mutateCampaign((Campaign c) {
                            c.sessionCommits.add(commit);
                          });
                          state.pendingPlayerSummaries.clear();
                          state.appendSessionEvent(
                            description: 'Master: Sessione archiviata: ${commit.title} (ID: ${commit.id})',
                          );
                        },
                      ),
                    );
                  },
                ),
                child: campaign.sessionCommits.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        child: Column(
                          children: <Widget>[
                            Icon(Icons.history_edu, size: 40, color: CprPalette.veil(CprPalette.yellow, 0.5)),
                            const SizedBox(height: 10),
                            Text(
                              'NESSUNA SESSIONE REGISTRATA NEL DIARIO',
                              style: CprType.label.copyWith(fontSize: 11, color: CprPalette.yellow),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Quando termini una sessione con il pulsante in alto a destra o da qui, '
                              'la trascrizione vocale di ciascun giocatore e il riassunto dell\'IA '
                              'verranno archiviati qui con data, ora e titolo personalizzato.',
                              textAlign: TextAlign.center,
                              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final CampaignSessionCommit commit in campaign.sessionCommits.reversed)
                            _SessionCommitCard(commit: commit),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCommitCard extends StatelessWidget {
  const _SessionCommitCard({required this.commit});

  final CampaignSessionCommit commit;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        border: Border.all(color: CprPalette.yellow.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        collapsedIconColor: CprPalette.yellow,
        iconColor: CprPalette.yellow,
        title: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: CprPalette.yellow.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: CprPalette.yellow),
              ),
              child: Text(
                '#${commit.sessionIndex}',
                style: CprType.label.copyWith(fontSize: 10, color: CprPalette.yellow, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                commit.title,
                style: CprType.title.copyWith(fontSize: 13, color: CprPalette.ink),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.schedule, size: 12, color: CprPalette.cyan),
                  const SizedBox(width: 4),
                  Text(
                    '${commit.date} · ${commit.time}',
                    style: CprType.caption.copyWith(fontSize: 10, color: CprPalette.cyan),
                  ),
                ],
              ),
            ),
          ],
        ),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Riepilogo Principale IA
                if (commit.aiSummary.isNotEmpty) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CprPalette.surfaceSunken,
                      border: Border.all(color: CprPalette.cyan.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.smart_toy_outlined, size: 14, color: CprPalette.cyan),
                            const SizedBox(width: 6),
                            Text(
                              'RIEPILOGO PRINCIPALE DELLA SESSIONE (IA)',
                              style: CprType.label.copyWith(fontSize: 10, color: CprPalette.cyan, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          commit.aiSummary,
                          style: CprType.body.copyWith(fontSize: 11.5, color: CprPalette.ink, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Note del Master
                if (commit.masterNotes.isNotEmpty) ...<Widget>[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CprPalette.surfaceSunken,
                      border: Border.all(color: CprPalette.yellow.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(Icons.edit_note, size: 16, color: CprPalette.yellow),
                            const SizedBox(width: 6),
                            Text(
                              'NOTE PERSONALI DEL MASTER',
                              style: CprType.label.copyWith(fontSize: 10, color: CprPalette.yellow, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          commit.masterNotes,
                          style: CprType.body.copyWith(fontSize: 11.5, color: CprPalette.ink, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Riepiloghi dei Singoli Giocatori
                if (commit.playerSummaries.isNotEmpty) ...<Widget>[
                  Text(
                    'COSA HANNO DETTO E FATTO I GIOCATORI (${commit.playerSummaries.length}):',
                    style: CprType.label.copyWith(fontSize: 10, color: CprPalette.inkMuted, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 6),
                  for (final PlayerSessionSummary player in commit.playerSummaries)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F141A),
                        border: Border.all(color: CprPalette.hairline),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Icon(Icons.person_pin, size: 14, color: CprPalette.cyan),
                              const SizedBox(width: 6),
                              Text(
                                player.playerName.toUpperCase(),
                                style: CprType.label.copyWith(fontSize: 10.5, color: CprPalette.cyan, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            player.aiSummary.isNotEmpty ? player.aiSummary : player.transcript,
                            style: CprType.body.copyWith(fontSize: 11, color: CprPalette.inkMuted, height: 1.35),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                ],

                // Trascrizione integrale
                if (commit.fullTranscript.isNotEmpty)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TechButton(
                      label: 'Copia Trascrizione Integrale',
                      icon: Icons.copy_all_outlined,
                      compact: true,
                      variant: TechButtonVariant.ghost,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: commit.fullTranscript));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Trascrizione integrale copiata negli appunti')),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Sezione NET Architecture per Netrunner e Master -----------------------

class _NetrunSection extends StatelessWidget {
  const _NetrunSection();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign? campaign = state.campaign;
    if (campaign == null) return const SizedBox.shrink();

    final NetArchitecture arch = campaign.netArchitecture ??
        NetArchitecture.defaultArchitecture();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: NetArchitectureEditor(
        architecture: arch,
        isMaster: state.isHosting,
        onChanged: () {
          state.mutateCampaign((Campaign c) {
            c.netArchitecture = arch;
          });
        },
      ),
    );
  }
}

// --- Impostazioni del tavolo -------------------------------------------------

class _SettingsSection extends StatelessWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign campaign = state.campaign!;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChamferPanel(
                title: 'Rete',
                accent: CprPalette.cyan,
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechNumberStepper(
                            label: 'Porta',
                            value: campaign.port,
                            min: 1024,
                            max: 65535,
                            accent: CprPalette.cyan,
                            onChanged: (int v) => state.mutateCampaign((c) => c.port = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: 'Password del tavolo',
                            value: campaign.password,
                            hint: 'Vuoto = tavolo aperto',
                            accent: CprPalette.cyan,
                            onChanged: (String v) => state.mutateCampaign((c) => c.password = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TechField(
                      label: 'Indirizzo da comunicare',
                      value: campaign.advertisedAddress,
                      hint: state.localAddresses.isEmpty
                          ? 'Es. 192.168.1.20'
                          : state.localAddresses.first,
                      accent: CprPalette.cyan,
                      onChanged: (String v) => state.mutateCampaign((c) => c.advertisedAddress = v),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'La porta si applica alla prossima apertura del tavolo. Se il giocatore e\' sulla '
                        'stessa rete basta l\'indirizzo locale; per giocare a distanza serve aprire la porta '
                        'sul router o usare una VPN come Tailscale.',
                        style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ChamferPanel(
                title: 'Accessi',
                accent: CprPalette.danger,
                child: campaign.players.isEmpty
                    ? Text(
                        'Nessun giocatore registrato.',
                        style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                      )
                    : Column(
                        children: <Widget>[
                          for (final CampaignPlayer p in campaign.players)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: <Widget>[
                                  Icon(
                                    p.isConnected ? Icons.link : Icons.link_off,
                                    size: 14,
                                    color: p.isConnected ? CprPalette.success : CprPalette.inkFaint,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      p.characterName.isEmpty ? p.id : p.characterName,
                                      overflow: TextOverflow.ellipsis,
                                      style: CprType.body.copyWith(
                                        color: p.isBanned ? CprPalette.inkFaint : CprPalette.ink,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (p.isBanned)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        'BANNATO',
                                        style: CprType.label.copyWith(
                                          fontSize: 8.5,
                                          color: CprPalette.danger,
                                        ),
                                      ),
                                    ),
                                  TechButton(
                                    label: p.isBanned ? 'Riammetti' : 'Allontana',
                                    variant: TechButtonVariant.ghost,
                                    compact: true,
                                    onPressed: () => state.masterSetBanned(p.id, !p.isBanned),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
