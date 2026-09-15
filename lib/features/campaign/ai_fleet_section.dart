import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/campaign.dart';
import '../../domain/campaign_ai.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

/// Sezione Master per la Gestione e Programmazione di tutte le Intelligenze Artificiali
/// della campagna (Delamain Core, Fixer Algoritmici, Sorveglianza Netwatch).
class AiFleetMasterSection extends StatefulWidget {
  const AiFleetMasterSection({super.key});

  @override
  State<AiFleetMasterSection> createState() => _AiFleetMasterSectionState();
}

class _AiFleetMasterSectionState extends State<AiFleetMasterSection> {
  void _openEditBotDialog(BuildContext context, AppState state, Campaign campaign, CampaignAiBot bot) {
    final nameCtrl = TextEditingController(text: bot.name);
    final roleCtrl = TextEditingController(text: bot.roleDesignation);
    final personalityCtrl = TextEditingController(text: bot.personality);
    final eddieCtrl = TextEditingController(text: bot.eddieBalance.toString());
    final dvCtrl = TextEditingController(text: bot.hackDv.toString());
    final bountyCtrl = TextEditingController(text: bot.hackBounty.toString());
    bool canBan = bot.canBanDelamain;
    bool canHack = bot.canBeHacked;

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDlgState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CprPalette.surface,
              border: Border.all(color: CprPalette.magenta, width: 1.5),
              borderRadius: BorderRadius.circular(4),
              boxShadow: <BoxShadow>[
                BoxShadow(color: CprPalette.magenta.withValues(alpha: 0.3), blurRadius: 18),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(bot.avatar, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 8),
                      Text('PROGRAMMAZIONE IA: ${bot.name}', style: CprType.title.copyWith(fontSize: 14)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TechField(label: 'Nome IA', controller: nameCtrl),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TechField(label: 'Designazione di Ruolo', controller: roleCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TechField(
                    label: 'Personalità & Istruzioni di Sistema (System Prompt)',
                    controller: personalityCtrl,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TechField(label: 'Portafoglio Eddy (eb)', controller: eddieCtrl),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TechField(label: 'DV Intrusione Netrunning', controller: dvCtrl),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TechField(label: 'Taglia Hack (eb)', controller: bountyCtrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    title: const Text('Autorità di Bannare dai Servizi Delamain', style: TextStyle(fontSize: 12)),
                    value: canBan,
                    activeThumbColor: CprPalette.danger,
                    onChanged: (v) => setDlgState(() => canBan = v),
                  ),
                  SwitchListTile(
                    title: const Text('Vulnerabile ad Hackeraggi Illegali dei Giocatori', style: TextStyle(fontSize: 12)),
                    value: canHack,
                    activeThumbColor: CprPalette.yellow,
                    onChanged: (v) => setDlgState(() => canHack = v),
                  ),
                  const SizedBox(height: 14),
                  // Gestione Lista Nera Giocatori
                  Text('LISTA NERA GIOCATORI BANNATI DA QUESTA IA:', style: CprType.label.copyWith(fontSize: 10, color: CprPalette.danger)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      for (final p in campaign.players) ...<Widget>[
                        FilterChip(
                          label: Text(p.characterName.isEmpty ? 'Giocatore ${p.id}' : p.characterName),
                          selected: bot.isPlayerBanned(p.id),
                          selectedColor: CprPalette.danger.withValues(alpha: 0.3),
                          checkmarkColor: CprPalette.danger,
                          onSelected: (selected) {
                            setDlgState(() {
                              bot.setPlayerBanned(p.id, selected);
                            });
                          },
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TechButton(
                        label: 'Annulla',
                        variant: TechButtonVariant.secondary,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      TechButton(
                        label: 'Salva Programmazione',
                        icon: Icons.check,
                        variant: TechButtonVariant.primary,
                        onPressed: () {
                          state.mutate((s) {
                            bot.name = nameCtrl.text.trim();
                            bot.roleDesignation = roleCtrl.text.trim();
                            bot.personality = personalityCtrl.text.trim();
                            bot.eddieBalance = int.tryParse(eddieCtrl.text.trim()) ?? bot.eddieBalance;
                            bot.hackDv = int.tryParse(dvCtrl.text.trim()) ?? bot.hackDv;
                            bot.hackBounty = int.tryParse(bountyCtrl.text.trim()) ?? bot.hackBounty;
                            bot.canBanDelamain = canBan;
                            bot.canBeHacked = canHack;
                          });
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resolveHack(AppState state, Campaign campaign, PendingAiHack hack, bool accept) {
    if (accept) {
      hack.status = 'approved';
      final bot = campaign.aiBots.firstWhere((b) => b.id == hack.botId, orElse: () => campaign.aiBots.first);
      bot.eddieBalance = math.max(0, bot.eddieBalance - hack.requestedEddies);

      final player = campaign.players.firstWhere((p) => p.id == hack.playerId, orElse: () => campaign.players.first);
      player.eurobucks += hack.requestedEddies;

      state.appendSessionEvent(
        description: '💰 [BRECCIA ILLEGALE AUTORIZZATA] ${hack.playerName} ha violato i server di ${hack.botName} (DV ${hack.dv}) e ha sottratto +${hack.requestedEddies} eb!',
        delta: '+${hack.requestedEddies} EB',
        isTransaction: true,
        transactionAmount: hack.requestedEddies,
        senderName: hack.botName,
        recipientName: hack.playerName,
        playerId: hack.playerId,
      );
    } else {
      hack.status = 'rejected';
      final bot = campaign.aiBots.firstWhere((b) => b.id == hack.botId, orElse: () => campaign.aiBots.first);
      bot.setPlayerBanned(hack.playerId, true);

      state.appendSessionEvent(
        description: '🚨 [INTRUSIONE BLOCCATA - BLACK ICE ATTIVO] Il tentativo di breccia di ${hack.playerName} è stato neutralizzato! ${hack.botName} ha bannato permanentemente l\'utente da tutti i servizi e taxi.',
        delta: 'BAN & ALLARME',
        isAlert: true,
        senderName: hack.botName,
        recipientName: hack.playerName,
        playerId: hack.playerId,
      );
    }
    state.mutateCampaign((c) {
      c.pendingHacks.remove(hack);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign? campaign = state.campaign;
    if (campaign == null) return const SizedBox.shrink();

    final pendingHacks = campaign.pendingHacks;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Sezione
          Row(
            children: <Widget>[
              const Icon(Icons.smart_toy_outlined, color: CprPalette.magenta, size: 24),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'INTELLIGENZE ARTIFICIALI & SERVIZI AUTONOMI DI NIGHT CITY',
                    style: CprType.title.copyWith(fontSize: 14, color: CprPalette.magenta),
                  ),
                  Text(
                    'Pannello Master: Programma personalità, assegna portafogli di eddy e gestisci i ban dei servizi.',
                    style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                  ),
                ],
              ),
              const Spacer(),
              TechButton(
                label: 'Crea Nuova IA',
                icon: Icons.add,
                variant: TechButtonVariant.primary,
                onPressed: () {
                  final newBot = CampaignAiBot(
                    id: 'bot-${DateTime.now().millisecondsSinceEpoch}',
                    name: 'Nuova IA Autonoma',
                    avatar: '🤖',
                    personality: 'Sei una IA commerciale di Night City.',
                    eddieBalance: 20000,
                  );
                  state.mutate((s) => campaign.aiBots.add(newBot));
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Avviso Breccia / Hack Pendenti dai Giocatori
          if (pendingHacks.isNotEmpty) ...<Widget>[
            ChamferPanel(
              accent: CprPalette.danger,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(Icons.warning_amber_rounded, color: CprPalette.danger, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'ALLARME BRECCIA NETRUNNING: TENTATIVI DI HACKING ILLEGALE IN CORSO',
                        style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final hack in pendingHacks) ...<Widget>[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CprPalette.surfaceRaised,
                        border: Border.all(color: CprPalette.danger.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Il giocatore ${hack.playerName} sta forzando i protocolli di ${hack.botName} per risucchiare ${hack.requestedEddies} eb (Tiro: ${hack.rollTotal} vs DV ${hack.dv})!',
                              style: CprType.caption.copyWith(color: CprPalette.ink, height: 1.3),
                            ),
                          ),
                          const SizedBox(width: 10),
                          TechButton(
                            label: 'Accetta Fallacia / Trasferisci',
                            icon: Icons.check_circle_outline,
                            variant: TechButtonVariant.primary,
                            onPressed: () => _resolveHack(state, campaign, hack, true),
                          ),
                          const SizedBox(width: 8),
                          TechButton(
                            label: 'Rifiuta & Attiva Black ICE',
                            icon: Icons.block,
                            variant: TechButtonVariant.danger,
                            onPressed: () => _resolveHack(state, campaign, hack, false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Flotta di IA Registrate
          Text('INTELLIGENZE ARTIFICIALI ATTIVE (${campaign.aiBots.length})', style: CprType.label.copyWith(color: CprPalette.cyan)),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 800;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: <Widget>[
                  for (final bot in campaign.aiBots) ...<Widget>[
                    SizedBox(
                      width: isWide ? (constraints.maxWidth - 20) / 2 : constraints.maxWidth,
                      child: ChamferPanel(
                        accent: bot.canBanDelamain ? CprPalette.yellow : CprPalette.cyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(bot.avatar, style: const TextStyle(fontSize: 26)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(bot.name, style: CprType.title.copyWith(fontSize: 14)),
                                      Text(bot.roleDesignation, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: CprPalette.surfaceRaised,
                                    border: Border.all(color: CprPalette.success),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    '${bot.eddieBalance} eb',
                                    style: CprType.label.copyWith(color: CprPalette.success, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              bot.personality,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CprType.caption.copyWith(color: CprPalette.ink, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                if (bot.bannedPlayerIds.isNotEmpty)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    color: CprPalette.veil(CprPalette.danger, 0.2),
                                    child: Text(
                                      '${bot.bannedPlayerIds.length} BANNATI',
                                      style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 8.5),
                                    ),
                                  ),
                                if (bot.canBeHacked)
                                  Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    color: CprPalette.veil(CprPalette.yellow, 0.2),
                                    child: Text(
                                      'HACK DV ${bot.hackDv}',
                                      style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 8.5),
                                    ),
                                  ),
                                const Spacer(),
                                TechButton(
                                  label: 'Modifica Programmazione',
                                  icon: Icons.edit,
                                  variant: TechButtonVariant.secondary,
                                  onPressed: () => _openEditBotDialog(context, state, campaign, bot),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
