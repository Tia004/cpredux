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
import '../../domain/enums.dart';
import '../../domain/rules.dart';
import '../../domain/sheet.dart';
import '../sheet/chat_rich_tools.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/humanity_gauge.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../map/map_section.dart';

/// Le sezioni del tavolo.
enum CampaignSection {
  players('Giocatori', Icons.groups_2_outlined, CprPalette.cyan),
  map('Mappa', Icons.map_outlined, CprPalette.info),
  table('Tavolo', Icons.forum_outlined, CprPalette.yellow),
  dice('Dadi', Icons.casino_outlined, CprPalette.yellow),
  notebook('Quaderno', Icons.menu_book_outlined, CprPalette.violet),
  settings('Impostazioni', Icons.tune_outlined, CprPalette.inkFaint);

  const CampaignSection(this.label, this.icon, this.accent);

  final String label;
  final IconData icon;
  final Color accent;
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
      case CampaignSection.table:
        return const _TableSection();
      case CampaignSection.dice:
        return const _DiceSection();
      case CampaignSection.notebook:
        return const _NotebookSection();
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
        const _CampaignHeader(),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CampaignRail(
                current: _section,
                onSelect: (CampaignSection s) => setState(() => _section = s),
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
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
          Flexible(
            child: Text(
              campaign.meta.name,
              overflow: TextOverflow.ellipsis,
              style: CprType.body.copyWith(color: CprPalette.ink, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 14),
          _SessionBadge(state: state),
          const Spacer(),
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
              tooltip: 'Copia il link di invito e i dettagli per far collegare i giocatori via chat',
              onPressed: () => _copyInviteLink(context, state, campaign),
            ),
            const SizedBox(width: 10),
            TechButton(
              label: 'Chiudi tavolo',
              icon: Icons.stop_circle_outlined,
              variant: TechButtonVariant.danger,
              compact: true,
              onPressed: state.stopHosting,
            ),
          ] else
            TechButton(
              label: 'Apri il tavolo',
              icon: Icons.wifi_tethering,
              variant: TechButtonVariant.primary,
              compact: true,
              tooltip: 'Mette il master in ascolto sulla porta ${campaign.port}',
              onPressed: () => state.startHosting(),
            ),
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
    );
  }

  Future<void> _copyInviteLink(BuildContext context, AppState state, Campaign campaign) async {
    final int port = state.host?.port ?? campaign.port;
    String hostIp = '127.0.0.1';

    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final NetworkInterface iface in interfaces) {
        for (final InternetAddress addr in iface.addresses) {
          if (!addr.isLoopback) {
            hostIp = addr.address;
            break;
          }
        }
        if (hostIp != '127.0.0.1') break;
      }
    } catch (_) {}

    String? publicIp;
    try {
      final HttpClient client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1800);
      final HttpClientRequest req = await client.getUrl(Uri.parse('https://api.ipify.org'));
      final HttpClientResponse res = await req.close();
      if (res.statusCode == 200) {
        publicIp = (await res.transform(utf8.decoder).join()).trim();
      }
    } catch (_) {}

    final String effectiveIp = publicIp ?? hostIp;
    final String code = 'CP-${campaign.port.toString().substring(math.max(0, campaign.port.toString().length - 4))}';
    final String link = 'cpred://join?host=$effectiveIp&port=$port&code=$code';

    final String shareText = 'Tavolo CPRed aperto!\n'
        '• Codice Stanza: $code\n'
        '• Link Rapido: $link\n'
        '• Connessione Online / Estero: $effectiveIp:$port\n'
        '• Connessione Locale (Stessa rete): $hostIp:$port';

    await Clipboard.setData(ClipboardData(text: shareText));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link di invito copiato negli appunti! Invialo via chat ai tuoi giocatori.'),
          backgroundColor: CprPalette.surface,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }
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
        Text(
          hosting ? 'TAVOLO APERTO · PORTA ${widget.state.host!.port}' : 'TAVOLO CHIUSO',
          style: CprType.label.copyWith(color: color, fontSize: 9.5),
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
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: CprPalette.hairline)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final CampaignSection s in CampaignSection.values)
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
                Text(
                  state.isHosting
                      ? 'Il tavolo e\' aperto. Comunica ai giocatori uno di questi indirizzi e la porta:'
                      : 'Apri il tavolo per far collegare i giocatori. Porta configurata:',
                  style: CprType.body.copyWith(color: CprPalette.ink),
                ),
                const SizedBox(height: 14),
                if (state.isHosting && state.localAddresses.isNotEmpty)
                  for (final String address in state.localAddresses)
                    _AddressRow(
                      address: address,
                      port: campaign.port,
                      password: campaign.password,
                    )
                else
                  _AddressRow(
                    address: state.localAddresses.isEmpty
                        ? '127.0.0.1 (solo questa macchina)'
                        : state.localAddresses.first,
                    port: campaign.port,
                    password: campaign.password,
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
  const _AddressRow({required this.address, required this.port, required this.password});

  final String address;
  final int port;
  final String password;

  @override
  Widget build(BuildContext context) {
    final String text = password.isEmpty
        ? '$address:$port'
        : '$address:$port  (password: $password)';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      color: CprPalette.surfaceSunken,
      child: Row(
        children: <Widget>[
          Expanded(
            child: SelectableText(
              text,
              style: CprType.body.copyWith(
                color: CprPalette.cyan,
                fontFamilyFallback: CprType.monoFamily,
                fontSize: 13,
              ),
            ),
          ),
          TechButton(
            label: 'Copia',
            icon: Icons.copy_all_outlined,
            variant: TechButtonVariant.ghost,
            compact: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: '$address:$port'));
              if (!context.mounted) return;
              await showTechMessage(
                context,
                title: 'Copiato',
                message: 'Indirizzo copiato negli appunti.',
                detail: password.isEmpty ? text : 'Password del tavolo: $password',
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
                      leading: const Icon(Icons.person, color: CprPalette.cyan, size: 20),
                      title: Text(entry.name, style: CprType.body.copyWith(fontSize: 13)),
                      subtitle: Text(entry.fileName, style: CprType.caption.copyWith(fontSize: 10)),
                      trailing: const Icon(Icons.send_outlined, size: 16, color: CprPalette.yellow),
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign campaign = state.campaign!;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChamferPanel(
                title: 'Registro di sessione',
                accent: CprPalette.yellow,
                trailing: TechButton(
                  label: 'Pulisci',
                  icon: Icons.cleaning_services_outlined,
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  onPressed: () {
                    state.sessionLog.clear();
                    state.clearSessionError();
                  },
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 180, maxHeight: 340),
                  child: state.sessionLog.isEmpty
                      ? Text(
                          state.isHosting
                              ? 'Il tavolo e\' aperto: chat, tiri e modifiche compaiono qui.'
                              : 'Apri il tavolo per iniziare la sessione.',
                          style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                        )
                      : ListView.builder(
                          itemCount: state.sessionLog.length,
                          itemBuilder: (BuildContext context, int i) =>
                              _LogRow(event: state.sessionLog[i]),
                        ),
                ),
              ),
              if (state.sessionError != null) ...<Widget>[
                const SizedBox(height: 10),
                _ErrorBar(message: state.sessionError!, onDismiss: state.clearSessionError),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.emoji_emotions_outlined, color: CprPalette.yellow, size: 20),
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
                    icon: const Icon(Icons.gif_box_outlined, color: CprPalette.cyan, size: 20),
                    tooltip: 'Invia GIF (Tenor / Giphy)',
                    onPressed: state.isHosting
                        ? () async {
                            final String? gifUrl = await showCyberGifPicker(context);
                            if (gifUrl != null) {
                              state.masterChat('', gifUrl: gifUrl);
                            }
                          }
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.attach_file, color: CprPalette.magenta, size: 20),
                    tooltip: 'Invia file o immagine P2P a tutto il tavolo',
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
                      hint: 'Parla al tavolo (supporta Unicode, emoji, GIF)…',
                      onChanged: (String v) => _controller.text = v,
                    ),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: 'Invia',
                    icon: Icons.send,
                    variant: TechButtonVariant.primary,
                    onPressed: state.isHosting
                        ? () {
                            state.masterChat(_controller.text);
                            _controller.clear();
                            setState(() {});
                          }
                        : null,
                  ),
                ],
              ),
              if (campaign.events.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Eventi salvati nella campagna: ${campaign.events.length}',
                  style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.event});

  final SessionEvent event;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (event.delta) {
      'MASTER' => CprPalette.yellow,
      'TU' => CprPalette.inkMuted,
      'PV -' || 'PV +' => CprPalette.healthFull,
      _ => CprPalette.ink,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              if (event.delta.isNotEmpty)
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
                errorBuilder: (BuildContext context, Object error, StackTrace? stack) => const Padding(
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
                            errorBuilder: (BuildContext context, Object error, StackTrace? stack) => const Padding(
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
                                icon: const Icon(Icons.download, size: 14, color: CprPalette.cyan),
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
                          const Icon(Icons.insert_drive_file_outlined, color: CprPalette.cyan, size: 20),
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
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ChamferPanel(
                title: 'Ultimo tiro',
                accent: _last == null
                    ? CprPalette.inkFaint
                    : (_last!.isCritical
                        ? CprPalette.success
                        : _last!.isFumble
                            ? CprPalette.danger
                            : CprPalette.yellow),
                child: SizedBox(
                  height: 110,
                  child: Center(
                    child: _last == null
                        ? Text(
                            'Nessun tiro',
                            style: CprType.body.copyWith(color: CprPalette.inkFaint),
                          )
                        : TweenAnimationBuilder<double>(
                            key: ValueKey<int>(_reveal),
                            tween: Tween<double>(begin: 0, end: 1),
                            duration: CprMotion.slow,
                            curve: CprMotion.enter,
                            builder: (BuildContext context, double t, Widget? child) => Opacity(
                              opacity: t.clamp(0, 1),
                              child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
                            ),
                            child: Text(
                              '${_last!.total}',
                              style: CprType.display.copyWith(
                                fontSize: 68,
                                color: _last!.isCritical
                                    ? CprPalette.success
                                    : _last!.isFumble
                                        ? CprPalette.danger
                                        : CprPalette.yellow,
                              ),
                            ),
                          ),
                  ),
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
            ],
          ),
        ),
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
