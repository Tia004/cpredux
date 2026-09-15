import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/campaign_ai.dart';
import '../../domain/sheet.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

/// Modale di prenotazione per il Servizio Taxi / Trasporti Delamain.
/// Verifica se il giocatore è nella lista nera dell'IA Delamain.
class DelamainRideBookingDialog extends StatefulWidget {
  const DelamainRideBookingDialog({super.key, this.state});

  final AppState? state;

  @override
  State<DelamainRideBookingDialog> createState() => _DelamainRideBookingDialogState();
}

class _DelamainRideBookingDialogState extends State<DelamainRideBookingDialog> {
  String _tier = 'Standard';
  int _fare = 20;
  String _destination = 'Little China (Watson)';
  double _destX = 0.45;
  double _destY = 0.35;
  String _errorMessage = '';

  static const List<Map<String, Object>> _destinations = [
    {'name': 'Little China (Watson)', 'x': 0.45, 'y': 0.35},
    {'name': 'Kabuki (Watson)', 'x': 0.55, 'y': 0.30},
    {'name': 'Corpo Plaza (Centro)', 'x': 0.50, 'y': 0.50},
    {'name': 'The Glen (Heywood)', 'x': 0.48, 'y': 0.65},
    {'name': 'Pacifica Combat Zone', 'x': 0.42, 'y': 0.85},
    {'name': 'Arroyo (Santo Domingo)', 'x': 0.65, 'y': 0.62},
    {'name': 'Badlands Accampamento Nomadi', 'x': 0.85, 'y': 0.80},
  ];

  AppState get _state => widget.state ?? AppScope.of(context);

  void _bookRide() {
    final state = _state;
    final campaign = state.campaign;
    final sheet = state.sheet;
    if (sheet == null || campaign == null) return;

    // Trova l'IA Delamain
    final delamainBot = campaign.aiBots.firstWhere(
      (b) => b.id.contains('delamain') || b.canBanDelamain,
      orElse: () => campaign.aiBots.first,
    );

    // Controllo Ban
    final playerId = sheet.meta.id;
    if (delamainBot.isPlayerBanned(playerId)) {
      setState(() {
        _errorMessage = '🚫 ACCESSO NEGATO: Sei presente nella lista nera di Delamain. '
            'Le unità di trasporto automatiche rifiutano di rispondere alle tue chiamate!';
      });

      state.appendSessionEvent(
        description: '🚨 [DELAMAIN SERVICE REFUSED] Tentativo di chiamata taxi fallito: il cliente è nella Blacklist di Delamain.',
        delta: 'BAN SERVIZI',
        isAlert: true,
        playerId: playerId,
      );
      return;
    }

    // Controllo Soldi
    if (sheet.eurobucks < _fare) {
      setState(() {
        _errorMessage = '❌ Crediti insufficienti! La corsa costa $_fare eb (tu ne hai ${sheet.eurobucks} eb).';
      });
      return;
    }

    // Pagamento ed Spostamento
    state.mutate((CharacterSheet s) {
      s.eurobucks -= _fare;
      delamainBot.eddieBalance += _fare;

      for (final p in campaign.players) {
        if (p.id == playerId) {
          p.mapX = _destX;
          p.mapY = _destY;
          p.mapDistrict = _destination;
        }
      }
    });

    final charName = sheet.identity.playerName.isEmpty ? 'Passeggero' : sheet.identity.playerName;
    state.appendSessionEvent(
      description: '💰 [TRANSAZIONE DELAMAIN CAB] -$_fare eb versati a Delamain Core AI. $charName è arrivato a destinazione: $_destination ($_tier).',
      delta: '-$_fare EB',
      isTransaction: true,
      playerId: playerId,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _state.sheet;

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
            BoxShadow(color: CprPalette.yellow.withValues(alpha: 0.3), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Text('🚕', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 8),
                Text('DELAMAIN TRANSPORT SERVICE EXCELSIOR', style: CprType.title.copyWith(fontSize: 14, color: CprPalette.yellow)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Portafoglio disponibile: ${sheet?.eurobucks ?? 0} eb',
              style: CprType.caption.copyWith(color: CprPalette.success),
            ),
            const SizedBox(height: 14),

            // Selezione Classe Veicolo
            Text('LIVELLO DEL SERVIZIO:', style: CprType.label.copyWith(fontSize: 10, color: CprPalette.cyan)),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Standard (20 eb)'),
                    selected: _tier == 'Standard',
                    onSelected: (s) => setState(() {
                      _tier = 'Standard';
                      _fare = 20;
                    }),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Combat Cab (50 eb)'),
                    selected: _tier == 'Combat Cab',
                    onSelected: (s) => setState(() {
                      _tier = 'Combat Cab';
                      _fare = 50;
                    }),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('VIP AV-4 (150 eb)'),
                    selected: _tier == 'VIP AV-4',
                    onSelected: (s) => setState(() {
                      _tier = 'VIP AV-4';
                      _fare = 150;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Selezione Destinazione
            Text('DESTINAZIONE SULLA MAPPA:', style: CprType.label.copyWith(fontSize: 10, color: CprPalette.cyan)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _destination,
              dropdownColor: CprPalette.surfaceRaised,
              style: CprType.body.copyWith(color: CprPalette.ink),
              decoration: const InputDecoration(
                filled: true,
                fillColor: CprPalette.surfaceSunken,
                border: OutlineInputBorder(),
              ),
              items: _destinations.map((d) {
                return DropdownMenuItem<String>(
                  value: d['name']! as String,
                  child: Text(d['name']! as String),
                );
              }).toList(),
              onChanged: (val) {
                if (val == null) return;
                final dest = _destinations.firstWhere((d) => d['name'] == val);
                setState(() {
                  _destination = val;
                  _destX = dest['x']! as double;
                  _destY = dest['y']! as double;
                });
              },
            ),
            if (_errorMessage.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.danger, 0.15),
                  border: Border.all(color: CprPalette.danger),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(_errorMessage, style: CprType.caption.copyWith(color: CprPalette.danger, height: 1.3)),
              ),
            ],
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
                  label: 'Chiama Delamain ($_fare eb)',
                  icon: Icons.local_taxi,
                  variant: TechButtonVariant.primary,
                  onPressed: _bookRide,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modale per effettuare una breccia illegale / hackeraggio verso una IA (Delamain o Broker)
/// per sifonare crediti illegali, inviando una proposta al Master.
class IllegalAiHackDialog extends StatefulWidget {
  const IllegalAiHackDialog({super.key, this.state});

  final AppState? state;

  @override
  State<IllegalAiHackDialog> createState() => _IllegalAiHackDialogState();
}

class _IllegalAiHackDialogState extends State<IllegalAiHackDialog> {
  CampaignAiBot? _selectedBot;
  final TextEditingController _amountCtrl = TextEditingController(text: '1000');
  String _statusMsg = '';

  AppState get _state => widget.state ?? AppScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bots = _state.campaign?.aiBots ?? <CampaignAiBot>[];
      if (bots.isNotEmpty && mounted) {
        setState(() {
          _selectedBot = bots.firstWhere((b) => b.canBeHacked, orElse: () => bots.first);
          _amountCtrl.text = _selectedBot!.hackBounty.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _sendHackProposal() {
    final state = _state;
    final campaign = state.campaign;
    final sheet = state.sheet;
    if (_selectedBot == null || campaign == null || sheet == null) return;

    final int roll1d10 = math.Random().nextInt(10) + 1;
    final int interfaceRank = 4; // Rango Interface tipico o bonus INT
    final int totalRoll = roll1d10 + interfaceRank;
    final int amount = int.tryParse(_amountCtrl.text.trim()) ?? _selectedBot!.hackBounty;

    final proposal = PendingAiHack(
      id: 'hack-${DateTime.now().millisecondsSinceEpoch}',
      playerId: sheet.meta.id,
      playerName: sheet.identity.playerName.isEmpty ? 'Netrunner Anonimo' : sheet.identity.playerName,
      botId: _selectedBot!.id,
      botName: _selectedBot!.name,
      requestedEddies: amount,
      dv: _selectedBot!.hackDv,
      rollTotal: totalRoll,
      timestamp: DateTime.now().toIso8601String(),
    );

    state.mutate((CharacterSheet s) {
      campaign.pendingHacks.add(proposal);
    });

    setState(() {
      _statusMsg = '⚡ Payload d\'infiltrazione trasmesso al terminale Master!\n'
          'Tiro Interface: $roll1d10 + $interfaceRank = $totalRoll (DV: ${_selectedBot!.hackDv})\n'
          'In attesa che il Master accetti la fallacia o scateni il Black ICE...';
    });
  }

  @override
  Widget build(BuildContext context) {
    final bots = _state.campaign?.aiBots ?? <CampaignAiBot>[];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.magenta, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.magenta.withValues(alpha: 0.3), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.security, color: CprPalette.magenta, size: 24),
                const SizedBox(width: 8),
                Text('BRECCIA ILLEGALE AI / SIFONE EDDY', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Attacca l\'architettura di rete di un\'IA programmata dal Master. Se il Master autorizza la breccia, '
              'i fondi verranno bonificati istantaneamente sul tuo conto!',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<CampaignAiBot>(
              initialValue: _selectedBot,
              dropdownColor: CprPalette.surfaceRaised,
              style: CprType.body.copyWith(color: CprPalette.ink),
              decoration: const InputDecoration(
                labelText: 'Target IA',
                filled: true,
                fillColor: CprPalette.surfaceSunken,
                border: OutlineInputBorder(),
              ),
              items: bots.map((b) {
                return DropdownMenuItem<CampaignAiBot>(
                  value: b,
                  child: Text('${b.name} (DV ${b.hackDv}) - Sifone Max: ${b.hackBounty} eb'),
                );
              }).toList(),
              onChanged: (b) {
                if (b != null) {
                  setState(() {
                    _selectedBot = b;
                    _amountCtrl.text = b.hackBounty.toString();
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            TechField(
              label: 'Importo da sottrarre (eb)',
              value: _amountCtrl.text,
              numeric: true,
              accent: CprPalette.magenta,
              onChanged: (v) => _amountCtrl.text = v,
            ),
            if (_statusMsg.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.cyan, 0.12),
                  border: Border.all(color: CprPalette.cyan),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(_statusMsg, style: CprType.caption.copyWith(color: CprPalette.cyan, height: 1.4)),
              ),
            ],
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
                  label: 'Lancia Payload Breccia',
                  icon: Icons.bolt,
                  variant: TechButtonVariant.primary,
                  onPressed: _sendHackProposal,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Modale rapida per inviare denaro (Eurodollari) a una IA o a un altro giocatore al tavolo.
class TransferMoneyDialog extends StatefulWidget {
  const TransferMoneyDialog({super.key, this.state});

  final AppState? state;

  @override
  State<TransferMoneyDialog> createState() => _TransferMoneyDialogState();
}

class _TransferMoneyDialogState extends State<TransferMoneyDialog> {
  final TextEditingController _amountCtrl = TextEditingController(text: '100');
  String _selectedRecipient = '';

  AppState get _state => widget.state ?? AppScope.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final campaign = _state.campaign;
      if (campaign != null && campaign.aiBots.isNotEmpty && mounted) {
        setState(() {
          _selectedRecipient = campaign.aiBots.first.name;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _transfer() {
    final state = _state;
    final campaign = state.campaign;
    final sheet = state.sheet;
    if (sheet == null || campaign == null) return;

    final int amount = int.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (amount <= 0 || sheet.eurobucks < amount) return;

    final senderName = sheet.identity.playerName.isEmpty ? 'Giocatore' : sheet.identity.playerName;

    state.mutate((CharacterSheet s) {
      s.eurobucks -= amount;

      // Se destinatario è un'IA, accredita nel suo portafoglio
      for (final bot in campaign.aiBots) {
        if (bot.name == _selectedRecipient) {
          bot.eddieBalance += amount;
          break;
        }
      }
    });

    state.appendSessionEvent(
      description: '💰 [BONIFICO EDDY] $senderName ha inviato $amount eb a $_selectedRecipient!',
      delta: '-$amount EB',
      isTransaction: true,
      playerId: sheet.meta.id,
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final sheet = state.sheet;
    final campaign = state.campaign;

    final List<String> recipients = <String>[
      if (campaign != null) ...campaign.aiBots.map((b) => b.name),
      if (campaign != null) ...campaign.players.map((p) => p.characterName),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.success, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.success.withValues(alpha: 0.3), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.currency_exchange, color: CprPalette.success, size: 24),
                const SizedBox(width: 8),
                Text('TRASFERISCI EURODOLLARI (EDDY)', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Disponibili sul conto: ${sheet?.eurobucks ?? 0} eb',
              style: CprType.caption.copyWith(color: CprPalette.success),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: recipients.contains(_selectedRecipient) ? _selectedRecipient : (recipients.isNotEmpty ? recipients.first : null),
              dropdownColor: CprPalette.surfaceRaised,
              style: CprType.body.copyWith(color: CprPalette.ink),
              decoration: const InputDecoration(
                labelText: 'Destinatario (IA o Giocatore)',
                filled: true,
                fillColor: CprPalette.surfaceSunken,
                border: OutlineInputBorder(),
              ),
              items: recipients.map((r) => DropdownMenuItem<String>(value: r, child: Text(r))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedRecipient = val);
              },
            ),
            const SizedBox(height: 12),
            TechField(
              label: 'Importo (eb)',
              value: _amountCtrl.text,
              numeric: true,
              accent: CprPalette.success,
              onChanged: (v) => _amountCtrl.text = v,
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
                  label: 'Invia Bonifico',
                  icon: Icons.send,
                  variant: TechButtonVariant.primary,
                  onPressed: _transfer,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
