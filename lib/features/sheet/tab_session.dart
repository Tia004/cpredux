import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/campaign.dart';
import '../../domain/rules.dart';
import '../../domain/skills.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

/// La sessione vista dal giocatore.
///
/// Il giocatore non modifica lo stato degli altri e non modifica nemmeno il
/// proprio *attraverso* la rete: le azioni che hanno un effetto (usare un
/// medkit, riposare) sono **richieste** che il master applica. Il motivo e'
/// pratico oltre che di regolamento: il master e' l'unico che vede tutti i
/// personaggi, quindi deve poter decidere sapendo cosa sta succedendo al
/// tavolo.
class SessionTab extends StatefulWidget {
  const SessionTab({super.key});

  @override
  State<SessionTab> createState() => _SessionTabState();
}

class _SessionTabState extends State<SessionTab> {
  final TextEditingController _address = TextEditingController();
  final TextEditingController _port = TextEditingController(text: '21099');
  final TextEditingController _password = TextEditingController();
  final TextEditingController _chat = TextEditingController();
  final math.Random _rng = math.Random();

  bool _connecting = false;
  String? _localError;

  @override
  void dispose() {
    _address.dispose();
    _port.dispose();
    _password.dispose();
    _chat.dispose();
    super.dispose();
  }

  Future<void> _connect(AppState state) async {
    final int? port = int.tryParse(_port.text.trim());
    if (_address.text.trim().isEmpty || port == null) {
      setState(() => _localError = 'Inserisci indirizzo e porta del tavolo.');
      return;
    }
    setState(() {
      _connecting = true;
      _localError = null;
    });
    await state.joinSession(
      address: _address.text.trim(),
      port: port,
      password: _password.text,
    );
    if (!mounted) return;
    setState(() => _connecting = false);
  }

  void _rollSkill(AppState state, Skill skill) {
    final SheetTotals totals = state.totals!;
    final DiceRoll roll = rollSkillCheck(state.sheet!, skill, random: _rng);
    state.sendRollToSession(
      label: skill.name,
      detail: '1d10 + ${totals.statValue(skill.stat)} + ${totals.skillValue(skill)}',
      total: roll.total,
      isCritical: roll.isCritical,
      isFumble: roll.isFumble,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    if (state.sheet == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _StatusPanel(
                state: state,
                address: _address,
                port: _port,
                password: _password,
                connecting: _connecting,
                localError: _localError,
                onConnect: () => _connect(state),
                onLeave: () async {
                  await state.leaveSession();
                  setState(() {});
                },
              ),
              if (state.isJoined) ...<Widget>[
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints c) {
                    final Widget chat = _ChatPanel(
                      state: state,
                      controller: _chat,
                      onSend: () {
                        state.sendChat(_chat.text);
                        _chat.clear();
                        setState(() {});
                      },
                    );
                    final Widget side = Column(
                      children: <Widget>[
                        _RequestsPanel(state: state),
                        const SizedBox(height: 14),
                        _RollPanel(
                          onRoll: (Skill s) => _rollSkill(state, s),
                        ),
                        const SizedBox(height: 14),
                        _TablePlayersPanel(players: state.remotePlayers),
                      ],
                    );

                    if (c.maxWidth < 900) {
                      return Column(children: <Widget>[chat, const SizedBox(height: 14), side]);
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 6, child: chat),
                        const SizedBox(width: 14),
                        Expanded(flex: 5, child: side),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.state,
    required this.address,
    required this.port,
    required this.password,
    required this.connecting,
    required this.localError,
    required this.onConnect,
    required this.onLeave,
  });

  final AppState state;
  final TextEditingController address;
  final TextEditingController port;
  final TextEditingController password;
  final bool connecting;
  final String? localError;
  final VoidCallback onConnect;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final bool joined = state.isJoined;
    final Color accent = joined ? CprPalette.success : CprPalette.cyan;

    return ChamferPanel(
      title: joined ? 'Collegato al tavolo' : 'Collegati a un tavolo',
      accent: accent,
      trailing: joined
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              color: CprPalette.veil(CprPalette.success, 0.14),
              child: Text(
                'IN SESSIONE',
                style: CprType.label.copyWith(color: CprPalette.success, fontSize: 8.5),
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (joined)
            Row(
              children: <Widget>[
                const Icon(Icons.hub_outlined, size: 16, color: CprPalette.success),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.client!.campaignName.isEmpty
                        ? 'Tavolo attivo'
                        : 'Tavolo: ${state.client!.campaignName}',
                    style: CprType.body.copyWith(color: CprPalette.ink),
                  ),
                ),
                TechButton(
                  label: 'Abbandona',
                  icon: Icons.link_off,
                  variant: TechButtonVariant.danger,
                  compact: true,
                  onPressed: onLeave,
                ),
              ],
            )
          else ...<Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  flex: 5,
                  child: TechField(
                    label: 'Indirizzo del master',
                    value: address.text,
                    hint: '192.168.1.20',
                    accent: CprPalette.cyan,
                    onChanged: (String v) => address.text = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: TechField(
                    label: 'Porta',
                    value: port.text,
                    numeric: true,
                    accent: CprPalette.cyan,
                    onChanged: (String v) => port.text = v,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: TechField(
                    label: 'Password',
                    value: password.text,
                    hint: 'solo se richiesta',
                    accent: CprPalette.cyan,
                    onChanged: (String v) => password.text = v,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                TechButton(
                  label: connecting ? 'Collegamento…' : 'Collegati',
                  icon: Icons.link,
                  variant: TechButtonVariant.primary,
                  onPressed: connecting ? null : onConnect,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Indirizzo e porta li comunica il master: sono mostrati nella sua sezione '
                    '"Giocatori" con il comando Copia.',
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                  ),
                ),
              ],
            ),
          ],
          if (localError != null || state.sessionError != null) ...<Widget>[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              color: CprPalette.veil(CprPalette.danger, 0.12),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.warning_amber_rounded, size: 15, color: CprPalette.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      localError ?? state.sessionError!,
                      style: CprType.caption.copyWith(color: CprPalette.ink),
                    ),
                  ),
                  if (localError == null)
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: state.clearSessionError,
                        child: const Icon(Icons.close, size: 14, color: CprPalette.danger),
                      ),
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

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.state,
    required this.controller,
    required this.onSend,
  });

  final AppState state;
  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Tavolo',
      accent: CprPalette.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            height: 300,
            child: state.sessionLog.isEmpty
                ? Center(
                    child: Text(
                      'Ancora nessun messaggio.',
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                    ),
                  )
                : ListView.builder(
                    itemCount: state.sessionLog.length,
                    itemBuilder: (BuildContext context, int i) {
                      final SessionEvent event = state.sessionLog[i];
                      final bool mine = event.delta == 'TU';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (event.delta.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                color: CprPalette.veil(
                                  event.delta == 'MASTER'
                                      ? CprPalette.yellow
                                      : mine
                                          ? CprPalette.inkFaint
                                          : CprPalette.cyan,
                                  0.12,
                                ),
                                child: Text(
                                  event.delta.toUpperCase(),
                                  style: CprType.label.copyWith(
                                    fontSize: 8.5,
                                    color: event.delta == 'MASTER'
                                        ? CprPalette.yellow
                                        : mine
                                            ? CprPalette.inkMuted
                                            : CprPalette.cyan,
                                  ),
                                ),
                              ),
                            Expanded(
                              child: Text(
                                event.description,
                                style: CprType.caption.copyWith(
                                  color: CprPalette.ink,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TechField(
                  label: '',
                  value: controller.text,
                  hint: 'Scrivi al tavolo…',
                  onChanged: (String v) => controller.text = v,
                ),
              ),
              const SizedBox(width: 10),
              TechButton(
                label: 'Invia',
                icon: Icons.send,
                variant: TechButtonVariant.primary,
                onPressed: onSend,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Le richieste al master.
///
/// Sono pulsanti invece che testo libero perche' sono le azioni che si fanno
/// durante il combattimento: chiedere "posso usare un medkit?" a parole
/// richiede che il master legga, interpreti e risponda. Un pulsante applica la
/// regola e lascia al master la sola decisione che conta, cioe' se va bene.
class _RequestsPanel extends StatelessWidget {
  const _RequestsPanel({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Richieste',
      accent: CprPalette.humanityIntact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _RequestButton(
                label: 'Usa Medkit (+20 PV)',
                onTap: () => state.requestIntent('medkit', detail: 'Medkit'),
              ),
              _RequestButton(
                label: 'Pronto soccorso (+10 PV)',
                onTap: () => state.requestIntent('firstAid', detail: 'Pronto soccorso'),
              ),
              _RequestButton(
                label: 'Riposo completo',
                onTap: () => state.requestIntent('rest', detail: 'Riposo'),
              ),
              _RequestButton(
                label: 'Terapia (+6 Umanita)',
                onTap: () => state.requestIntent('therapy', detail: 'Terapia'),
              ),
              _RequestButton(
                label: 'Nota al master',
                onTap: () => state.requestIntent('nota', detail: ''),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Il master vede la richiesta e la applica: e\' lui a decidere cosa succede al tavolo.',
            style: CprType.caption.copyWith(color: CprPalette.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _RequestButton extends StatelessWidget {
  const _RequestButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: CprPalette.veil(CprPalette.humanityIntact, 0.08),
            border: Border.all(color: CprPalette.veil(CprPalette.humanityIntact, 0.4)),
          ),
          child: Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(color: CprPalette.humanityIntact, fontSize: 9.5),
          ),
        ),
      ),
    );
  }
}

class _RollPanel extends StatefulWidget {
  const _RollPanel({required this.onRoll});

  final void Function(Skill) onRoll;

  @override
  State<_RollPanel> createState() => _RollPanelState();
}

class _RollPanelState extends State<_RollPanel> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final SheetTotals totals = state.totals!;
    final List<Skill> filtered = Skill.values
        .where((Skill s) => _query.isEmpty || s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return ChamferPanel(
      title: 'Tira e annuncia',
      accent: CprPalette.yellow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TechField(
            label: '',
            value: _query,
            hint: 'Cerca abilita',
            onChanged: (String v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: filtered.length,
              itemBuilder: (BuildContext context, int i) {
                final Skill skill = filtered[i];
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => widget.onRoll(skill),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              skill.name,
                              overflow: TextOverflow.ellipsis,
                              style: CprType.body.copyWith(fontSize: 12.5),
                            ),
                          ),
                          Text(
                            '+${totals.skillCheck(skill)}',
                            style: CprType.numeralSmall.copyWith(color: CprPalette.yellow),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.campaign_outlined, size: 13, color: CprPalette.inkFaint),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TablePlayersPanel extends StatelessWidget {
  const _TablePlayersPanel({required this.players});

  final List<CampaignPlayer> players;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Al tavolo',
      accent: CprPalette.cyan,
      child: players.isEmpty
          ? Text(
              'In attesa che il master invii lo stato del tavolo.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            )
          : Column(
              children: <Widget>[
                for (final CampaignPlayer p in players)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          p.isConnected ? Icons.person : Icons.person_off_outlined,
                          size: 14,
                          color: p.isConnected ? CprPalette.cyan : CprPalette.inkFaint,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.characterName.isEmpty ? 'Senza nome' : p.characterName,
                            overflow: TextOverflow.ellipsis,
                            style: CprType.body.copyWith(fontSize: 12.5),
                          ),
                        ),
                        if (p.hitPoints.isNotEmpty)
                          Text(
                            'PV ${p.hitPoints}',
                            style: CprType.numeralSmall.copyWith(
                              color: CprPalette.healthColorFor(_ratio(p.hitPoints)),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  static double _ratio(String value) {
    final List<String> parts = value.split('/');
    if (parts.length < 2) return 1;
    final int? cur = int.tryParse(parts[0].trim());
    final int? max = int.tryParse(parts[1].trim());
    if (cur == null || max == null || max == 0) return 1;
    return cur / max;
  }
}
