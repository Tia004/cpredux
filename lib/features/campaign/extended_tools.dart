import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/campaign.dart';
import '../../domain/campaign_combat.dart';
import '../../domain/gm/gm_generators.dart';
import '../../domain/map_token.dart';
import '../ai/ai_assistant_service.dart';
import '../../widgets/tech_button.dart';

// =============================================================================
// 1. GENERATORE DI LOOT E TASCHE DEI NEMICI
// =============================================================================

class EnemyLootDialog extends StatefulWidget {
  const EnemyLootDialog({super.key});

  @override
  State<EnemyLootDialog> createState() => _EnemyLootDialogState();
}

class _EnemyLootDialogState extends State<EnemyLootDialog> {
  String _lootResult = 'Seleziona il rango del nemico e premi "Fruga nelle Tasche".';
  bool _isGenerating = false;

  Future<void> _generateLoot(String rank) async {
    setState(() => _isGenerating = true);
    final int quality = rank.contains('Cyberpsicopatico')
        ? 8
        : rank.contains('Soldato')
            ? 6
            : 4;
    final AiLootResult result = await AiAssistantService.instance.generateLootWithAi(
      prompt: rank,
      quality: quality,
    );
    if (!mounted) return;
    final List<String> items = result.entries.map((LootEntry entry) {
      final String quantity = entry.quantity > 1 ? ' x${entry.quantity}' : '';
      final String note = entry.note.isEmpty ? '' : ' — ${entry.note}';
      return '${entry.name}$quantity$note';
    }).toList();
    setState(() {
      _lootResult = '🔍 RISULTATO FRUGAZIONE ($rank):\n\n'
          '💰 Denaro contante trovato: ${result.eurodollars} Eurodollari (eb)\n'
          '🎒 Oggetti nelle tasche (${result.source}):\n${items.isEmpty ? '  • Nessun oggetto' : items.map((i) => "  • $i").join("\n")}';
      _isGenerating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.yellow, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.yellow.withValues(alpha: 0.25), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.inventory_2_outlined, color: CprPalette.yellow, size: 24),
                const SizedBox(width: 8),
                Text('GENERATORE DI LOOT & TASCHE NEMICI', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Fruga rapidamente addosso ai nemici neutralizzati per scoprire Eurodollari, chip dati, droghe e munizioni.',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                TechButton(
                  label: _isGenerating ? 'GENERAZIONE IA...' : 'Mook da Strada (Boostergang)',
                  icon: Icons.person_outline,
                  variant: TechButtonVariant.secondary,
                  onPressed: _isGenerating ? null : () => _generateLoot('Mook da Strada (Boostergang)'),
                ),
                TechButton(
                  label: 'Soldato Corp (Arasaka)',
                  icon: Icons.shield_outlined,
                  variant: TechButtonVariant.secondary,
                  onPressed: _isGenerating ? null : () => _generateLoot('Soldato Corporativo (Arasaka/Militech)'),
                ),
                TechButton(
                  label: 'Cyberpsicopatico / Boss',
                  icon: Icons.warning_amber_rounded,
                  variant: TechButtonVariant.secondary,
                  onPressed: _isGenerating ? null : () => _generateLoot('Cyberpsicopatico / Boss'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                border: Border.all(color: CprPalette.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_lootResult, style: CprType.body.copyWith(color: CprPalette.ink, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 2. REGISTRO DEBITI E CONTRATTI CORPORATIVI
// =============================================================================

class CorporateDebtsDialog extends StatefulWidget {
  const CorporateDebtsDialog({super.key, this.state});

  final AppState? state;

  @override
  State<CorporateDebtsDialog> createState() => _CorporateDebtsDialogState();
}

class _CorporateDebtsDialogState extends State<CorporateDebtsDialog> {
  final TextEditingController _playerCtrl = TextEditingController(text: 'Tavolo / PG');
  final TextEditingController _creditorCtrl = TextEditingController(text: 'Strozzino Tyger Claws');
  final TextEditingController _amountCtrl = TextEditingController(text: '2000');
  final TextEditingController _interestCtrl = TextEditingController(text: '10'); // % settimanale

  AppState get _state => widget.state ?? AppScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appState = _state;
      final String sheetName = (appState.sheet?.identity.tag.trim().isNotEmpty ?? false)
          ? appState.sheet!.identity.tag.trim()
          : ((appState.sheet?.identity.playerName.trim().isNotEmpty ?? false)
              ? appState.sheet!.identity.playerName.trim()
              : (appState.sheet?.meta.name.trim() ?? ''));
      if (sheetName.isNotEmpty) {
        _playerCtrl.text = sheetName;
      } else if (appState.campaign?.players.isNotEmpty ?? false) {
        _playerCtrl.text = appState.campaign!.players.first.characterName;
      }
    });
  }

  @override
  void dispose() {
    _playerCtrl.dispose();
    _creditorCtrl.dispose();
    _amountCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = _state;
    final String currentSheetName = (appState.sheet?.identity.tag.trim().isNotEmpty ?? false)
        ? appState.sheet!.identity.tag.trim()
        : ((appState.sheet?.identity.playerName.trim().isNotEmpty ?? false)
            ? appState.sheet!.identity.playerName.trim()
            : (appState.sheet?.meta.name.trim() ?? ''));
    final List<String> playerOptions = <String>{
      if (currentSheetName.isNotEmpty) currentSheetName,
      if (appState.campaign != null)
        for (final p in appState.campaign!.players) ...<String>[
          if (p.characterName.trim().isNotEmpty) p.characterName.trim(),
          if (p.playerName.trim().isNotEmpty) p.playerName.trim(),
        ],
    }.toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.danger, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.danger.withValues(alpha: 0.3), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.money_off, color: CprPalette.danger, size: 24),
                const SizedBox(width: 8),
                Text('REGISTRO DEBITI & PRESTITI CORPORATIVI', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Tieni traccia dei prestiti contratti dai singoli giocatori con banche Arasaka o usurai di quartiere. Gli interessi maturano ogni settimana.',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _playerCtrl,
              style: CprType.body.copyWith(color: CprPalette.ink),
              decoration: const InputDecoration(
                labelText: 'Giocatore / Personaggio Debitore',
                filled: true,
                fillColor: CprPalette.surfaceSunken,
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline, size: 20, color: CprPalette.yellow),
              ),
            ),
            if (playerOptions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String opt in playerOptions)
                    InkWell(
                      onTap: () => setState(() => _playerCtrl.text = opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _playerCtrl.text == opt ? CprPalette.yellow : CprPalette.surfaceSunken,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          opt,
                          style: CprType.caption.copyWith(
                            color: _playerCtrl.text == opt ? Colors.black : CprPalette.inkMuted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            TextField(
              controller: _creditorCtrl,
              style: CprType.body.copyWith(color: CprPalette.ink),
              decoration: const InputDecoration(
                labelText: 'Creditore / Usuraio',
                filled: true,
                fillColor: CprPalette.surfaceSunken,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: CprType.body.copyWith(color: CprPalette.ink),
                    decoration: const InputDecoration(
                      labelText: 'Debito Residuo (eb)',
                      filled: true,
                      fillColor: CprPalette.surfaceSunken,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _interestCtrl,
                    keyboardType: TextInputType.number,
                    style: CprType.body.copyWith(color: CprPalette.ink),
                    decoration: const InputDecoration(
                      labelText: 'Interesse Settimanale (%)',
                      filled: true,
                      fillColor: CprPalette.surfaceSunken,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TechButton(
              label: 'Registra Debito nel Quaderno di Sessione',
              icon: Icons.save,
              variant: TechButtonVariant.danger,
              onPressed: () {
                final p = _playerCtrl.text.trim().isEmpty ? 'Tavolo' : _playerCtrl.text.trim();
                final c = _creditorCtrl.text.trim();
                final a = _amountCtrl.text.trim();
                final i = _interestCtrl.text.trim();
                final state = _state;
                if (state.campaign != null) {
                  state.mutateCampaign((Campaign camp) {
                    camp.description += '\n[DEBITO: $p] $c: $a eb (Interesse: $i%/settimana)';
                  });
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. INIZIATIVA CONDIVISA E ORDINE DI TURNO
// =============================================================================

class InitiativeTrackerDialog extends StatefulWidget {
  const InitiativeTrackerDialog({super.key, this.state});

  final AppState? state;

  @override
  State<InitiativeTrackerDialog> createState() => _InitiativeTrackerDialogState();
}

class _InitiativeTrackerDialogState extends State<InitiativeTrackerDialog> {
  AppState get _state => widget.state ?? AppScope.of(context);

  void _rollAllInitiatives() {
    final campaign = _state.campaign;
    if (campaign == null) return;

    final rand = math.Random();
    final List<CombatInitiativeEntry> entries = <CombatInitiativeEntry>[];

    // Giocatori
    for (final p in campaign.players) {
      final roll = (rand.nextInt(10) + 1) + 6; // 1d10 + RIF
      entries.add(CombatInitiativeEntry(
        id: p.id,
        name: p.characterName.isEmpty ? 'Giocatore ${p.id}' : p.characterName,
        initiative: roll,
        isPlayer: true,
        playerId: p.id,
      ));
    }

    // Token nemici sulla mappa
    for (final t in campaign.tokens) {
      if (t.kind == TokenKind.nemico || t.kind == TokenKind.neutrale) {
        final roll = (rand.nextInt(10) + 1) + t.refBonus;
        entries.add(CombatInitiativeEntry(
          id: t.id,
          name: t.name,
          initiative: roll,
          isPlayer: false,
          waypointId: t.id,
          currentHp: t.hp,
          maxHp: t.maxHp,
        ));
      }
    }

    entries.sort((a, b) => b.initiative.compareTo(a.initiative));

    _state.mutateCampaign((Campaign c) {
      c.initiativeOrder.clear();
      c.initiativeOrder.addAll(entries);
      c.currentInitiativeTurnIndex = 0;
      c.combatRound = 1;
    });
    setState(() {});
  }

  void _nextTurn() {
    final campaign = _state.campaign;
    if (campaign == null || campaign.initiativeOrder.isEmpty) return;

    _state.mutateCampaign((Campaign c) {
      int next = c.currentInitiativeTurnIndex + 1;
      if (next >= c.initiativeOrder.length) {
        next = 0;
        c.combatRound += 1;
      }
      c.currentInitiativeTurnIndex = next;
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final campaign = _state.campaign;
    final entries = campaign?.initiativeOrder ?? <CombatInitiativeEntry>[];
    final activeIdx = campaign?.currentInitiativeTurnIndex ?? 0;
    final round = campaign?.combatRound ?? 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.cyan, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.cyan.withValues(alpha: 0.3), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.format_list_numbered, color: CprPalette.cyan, size: 24),
                const SizedBox(width: 8),
                Text('ORDINE DI INIZIATIVA & TURNI (ROUND $round)', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                TechButton(
                  label: 'Tira Iniziativa Tutti (1d10+RIF)',
                  icon: Icons.casino,
                  variant: TechButtonVariant.primary,
                  onPressed: _rollAllInitiatives,
                ),
                const SizedBox(width: 8),
                TechButton(
                  label: 'Prossimo Turno ⏭',
                  icon: Icons.skip_next,
                  variant: TechButtonVariant.secondary,
                  onPressed: _nextTurn,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                border: Border.all(color: CprPalette.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: entries.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nessuna iniziativa attiva.\nPremi "Tira Iniziativa Tutti" per ordinare PG e Token nemici.',
                          textAlign: TextAlign.center,
                          style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: entries.length,
                      itemBuilder: (context, i) {
                        final entry = entries[i];
                        final bool isActive = i == activeIdx;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive ? CprPalette.cyan.withValues(alpha: 0.18) : CprPalette.surfaceRaised,
                            border: Border.all(color: isActive ? CprPalette.cyan : CprPalette.hairline),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isActive ? CprPalette.cyan : CprPalette.surfaceSunken,
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: isActive ? Colors.black : CprPalette.ink,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      entry.name,
                                      style: CprType.body.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isActive ? CprPalette.cyan : CprPalette.ink,
                                      ),
                                    ),
                                    Text(
                                      entry.isPlayer ? 'Giocatore' : 'Token Mappa',
                                      style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Iniziativa: ${entry.initiative}',
                                style: CprType.label.copyWith(
                                  color: isActive ? CprPalette.cyan : CprPalette.inkMuted,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4. GENERATORE DI BACHECA SCREAMSHEET NOTIZIE
// =============================================================================

class ScreamsheetNewsDialog extends StatelessWidget {
  const ScreamsheetNewsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> articles = [
      {
        'title': 'MASSACRO ALLA TORRE ARASAKA: CYBERPSICOPATICO ABBATTUTO DALLA MAX-TAC',
        'sub': 'Tre agenti feriti e danni per 4 milioni di Eurodollari nell\'atrio principale.',
        'tag': 'CRONACA NERA',
      },
      {
        'title': 'DELAMAIN CAB ANNUNCIA LA NUOVA FLOTTA EXCELSIOR CON BLINDATURA MILITEC',
        'sub': 'Tariffe bloccate a 20 eb per i viaggiatori abituali, blacklist attiva contro i vandali.',
        'tag': 'ECONOMIA & TRASPORTI',
      },
      {
        'title': 'PIOGGIA ACIDA SU WATSON: L\'AUTORITÀ SANITARIA CONSIGLIA DI NON USCIRE',
        'sub': 'pH dell\'acqua rilevato a 2.8. Le armature prive di sigillatura subiscono ablazione spontanea.',
        'tag': 'ALLERTA AMBIENTALE',
      },
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 580,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          border: Border.all(color: CprPalette.yellow, width: 2.0),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.yellow.withValues(alpha: 0.35), blurRadius: 20),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('📰', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text('NIGHT CITY SCREAMSHEETS · NOTIZIARIO RETE', style: CprType.title.copyWith(fontSize: 14, color: CprPalette.yellow)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final a in articles) ...<Widget>[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CprPalette.surfaceRaised,
                  border: Border.all(color: CprPalette.hairline),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      color: CprPalette.yellow.withValues(alpha: 0.2),
                      child: Text(a['tag']!, style: CprType.label.copyWith(fontSize: 9, color: CprPalette.yellow)),
                    ),
                    const SizedBox(height: 6),
                    Text(a['title']!, style: CprType.body.copyWith(fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(a['sub']!, style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.3)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
