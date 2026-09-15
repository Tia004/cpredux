import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/map_token.dart';
import '../../domain/sheet.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';

// =============================================================================
// 1. SCHEDA RAPIDA PNG / MOOK PER I TOKEN SULLA MAPPA
// =============================================================================

/// Modale / Drawer per visualizzare e gestire la scheda rapida di un PNG
/// associato a un token sulla mappa, con applicazione del danno e ablazione.
class QuickNpcTokenDialog extends StatefulWidget {
  const QuickNpcTokenDialog({
    super.key,
    required this.token,
    this.onUpdate,
    this.onDelete,
  });

  final MapToken token;
  final ValueChanged<MapToken>? onUpdate;
  final VoidCallback? onDelete;

  @override
  State<QuickNpcTokenDialog> createState() => _QuickNpcTokenDialogState();
}

class _QuickNpcTokenDialogState extends State<QuickNpcTokenDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roleCtrl;
  late final TextEditingController _weaponCtrl;
  late final TextEditingController _damageCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _lootCtrl;
  late int _hp;
  late int _maxHp;
  late int _sp;
  late int _combat;
  late int _defense;
  late int _eurobucks;

  final TextEditingController _dmgInputCtrl = TextEditingController(text: '10');
  String _lastCombatLog = '';

  @override
  void initState() {
    super.initState();
    final t = widget.token;
    _nameCtrl = TextEditingController(text: t.name);
    _roleCtrl = TextEditingController(text: t.role.isEmpty ? t.kind.label : t.role);
    _weaponCtrl = TextEditingController(text: t.weaponName.isEmpty ? 'Pistola Pesante' : t.weaponName);
    _damageCtrl = TextEditingController(text: t.damage.isEmpty ? '3d6' : t.damage);
    _notesCtrl = TextEditingController(text: t.longNotes.isEmpty ? t.note : t.longNotes);
    _lootCtrl = TextEditingController(text: t.loot.isEmpty ? 'Munizioni x20, Chip dati' : t.loot);
    _hp = t.hp > 0 ? t.hp : (t.maxHp > 0 ? t.maxHp : 30);
    _maxHp = t.maxHp > 0 ? t.maxHp : 30;
    _sp = t.sp > 0 ? t.sp : 7;
    _combat = t.combat > 0 ? t.combat : 12;
    _defense = t.defense > 0 ? t.defense : 12;
    _eurobucks = t.eurobucks;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roleCtrl.dispose();
    _weaponCtrl.dispose();
    _damageCtrl.dispose();
    _notesCtrl.dispose();
    _lootCtrl.dispose();
    _dmgInputCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.token.copyWith(
      name: _nameCtrl.text.trim(),
      role: _roleCtrl.text.trim(),
      weaponName: _weaponCtrl.text.trim(),
      damage: _damageCtrl.text.trim(),
      longNotes: _notesCtrl.text.trim(),
      loot: _lootCtrl.text.trim(),
      hp: _hp,
      maxHp: _maxHp,
      sp: _sp,
      combat: _combat,
      defense: _defense,
      eurobucks: _eurobucks,
    );
    if (widget.onUpdate != null) {
      widget.onUpdate!(updated);
    } else {
      AppScope.of(context).updateMapToken(updated);
    }
  }

  void _applyDamage({bool isHead = false}) {
    final int raw = int.tryParse(_dmgInputCtrl.text.trim()) ?? 0;
    if (raw <= 0) return;

    final int effective = raw - _sp;
    if (effective <= 0) {
      setState(() {
        _lastCombatLog = '🛡️ L\'armatura SP $_sp ha assorbito tutti i $raw danni!';
      });
      return;
    }

    final int taken = isHead ? effective * 2 : effective;
    setState(() {
      _hp = (_hp - taken).clamp(0, _maxHp);
      final int oldSp = _sp;
      if (_sp > 0) _sp = (_sp - 1).clamp(0, 99);
      _lastCombatLog = isHead
          ? '💥 COLPO ALLA TESTA! $raw - $oldSp = $effective × 2 = -$taken PV! Armatura SP ridotta a $_sp (Ablazione).'
          : '🩸 Colpo a segno! $raw - $oldSp = -$taken PV! Armatura SP ridotta a $_sp (Ablazione).';
    });
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final Color kindColor = switch (widget.token.kind) {
      TokenKind.nemico => CprPalette.danger,
      TokenKind.alleato => CprPalette.cyan,
      TokenKind.veicolo => CprPalette.yellow,
      TokenKind.neutrale => CprPalette.inkMuted,
    };

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: kindColor, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: kindColor.withValues(alpha: 0.35), blurRadius: 18),
          ],
        ),
        child: Column(
          children: <Widget>[
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: CprPalette.surfaceRaised,
              child: Row(
                children: <Widget>[
                  Icon(Icons.person_pin_circle, color: kindColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'SCHEDA RAPIDA PNG / TOKEN TAVOLO',
                      style: CprType.title.copyWith(fontSize: 14, color: kindColor),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Nome e Ruolo
                    Row(
                      children: <Widget>[
                        Expanded(
                          flex: 2,
                          child: TechField(
                            label: 'Nome Token / PNG',
                            controller: _nameCtrl,
                            onChanged: (_) => _save(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: 'Archetipo / Fazione',
                            controller: _roleCtrl,
                            onChanged: (_) => _save(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Statistiche Rapide Cyberpunk RED
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechNumberStepper(
                            label: 'PV Attuali',
                            value: _hp,
                            max: _maxHp,
                            accent: CprPalette.danger,
                            onChanged: (v) {
                              setState(() => _hp = v);
                              _save();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TechNumberStepper(
                            label: 'PV Massimi',
                            value: _maxHp,
                            max: 150,
                            accent: CprPalette.yellow,
                            onChanged: (v) {
                              setState(() => _maxHp = v);
                              _save();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TechNumberStepper(
                            label: 'Armatura (SP)',
                            value: _sp,
                            max: 25,
                            accent: CprPalette.cyan,
                            onChanged: (v) {
                              setState(() => _sp = v);
                              _save();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechNumberStepper(
                            label: 'Combattimento Base',
                            value: _combat,
                            max: 25,
                            accent: CprPalette.magenta,
                            onChanged: (v) {
                              setState(() => _combat = v);
                              _save();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TechNumberStepper(
                            label: 'Difesa / Evasione',
                            value: _defense,
                            max: 25,
                            accent: CprPalette.info,
                            onChanged: (v) {
                              setState(() => _defense = v);
                              _save();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TechNumberStepper(
                            label: 'Portafoglio (eb)',
                            value: _eurobucks,
                            max: 99999,
                            accent: CprPalette.success,
                            onChanged: (v) {
                              setState(() => _eurobucks = v);
                              _save();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Pannello Risoluzione Danno & Ablazione
                    ChamferPanel(
                      accent: CprPalette.danger,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'APPLICAZIONE DANNO & ABLAZIONE ARMATURA',
                            style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 10),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              SizedBox(
                                width: 100,
                                child: TechField(
                                  label: 'Danno grezzo',
                                  controller: _dmgInputCtrl,
                                ),
                              ),
                              const SizedBox(width: 10),
                              TechButton(
                                label: 'Colpo Corpo',
                                icon: Icons.shield,
                                variant: TechButtonVariant.danger,
                                onPressed: () => _applyDamage(isHead: false),
                              ),
                              const SizedBox(width: 8),
                              TechButton(
                                label: 'Colpo Testa (x2)',
                                icon: Icons.gps_fixed,
                                variant: TechButtonVariant.secondary,
                                onPressed: () => _applyDamage(isHead: true),
                              ),
                            ],
                          ),
                          if (_lastCombatLog.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: CprPalette.surfaceRaised,
                                border: Border.all(color: CprPalette.danger.withValues(alpha: 0.5)),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                _lastCombatLog,
                                style: CprType.caption.copyWith(color: CprPalette.ink, height: 1.3),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Arma e Danno
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechField(
                            label: 'Arma Equipaggiata',
                            controller: _weaponCtrl,
                            onChanged: (_) => _save(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 130,
                          child: TechField(
                            label: 'Danno Arma',
                            controller: _damageCtrl,
                            onChanged: (_) => _save(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Loot / Tasche
                    TechField(
                      label: 'Loot nelle tasche (Bottino abbattuto)',
                      controller: _lootCtrl,
                      onChanged: (_) => _save(),
                    ),
                    const SizedBox(height: 12),

                    // Note Lunghe & Tattiche
                    TechField(
                      label: 'Note, Tattiche e Lore del PNG',
                      controller: _notesCtrl,
                      maxLines: 3,
                      onChanged: (_) => _save(),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: CprPalette.surfaceRaised,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TechButton(
                    label: 'Rimuovi Token',
                    icon: Icons.delete_outline,
                    variant: TechButtonVariant.danger,
                    onPressed: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!();
                      } else {
                        AppScope.of(context).removeToken(widget.token.id);
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                  TechButton(
                    label: 'Salva & Chiudi',
                    icon: Icons.check,
                    variant: TechButtonVariant.primary,
                    onPressed: () {
                      _save();
                      Navigator.of(context).pop();
                    },
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

// =============================================================================
// 2. TRACCIATORE CYBERPSICOSI E TERAPIA (CYBERPUNK RED PAG. 229-230)
// =============================================================================

class CyberpsychosisTherapyDialog extends StatefulWidget {
  const CyberpsychosisTherapyDialog({super.key, required this.state});

  final AppState state;

  @override
  State<CyberpsychosisTherapyDialog> createState() => _CyberpsychosisTherapyDialogState();
}

class _CyberpsychosisTherapyDialogState extends State<CyberpsychosisTherapyDialog> {
  String _outcomeLog = '';

  void _applyTherapy({required String type, required int cost, required int days, required int diceRoll}) {
    final sheet = widget.state.sheet;
    final totals = widget.state.totals;
    if (sheet == null || totals == null) return;

    if (sheet.eurobucks < cost) {
      setState(() {
        _outcomeLog = '❌ Fondi insufficienti! La $type costa $cost eb (tu ne hai ${sheet.eurobucks} eb).';
      });
      return;
    }

    // Spende eurodollari
    widget.state.mutate((CharacterSheet s) => s.eurobucks -= cost);

    // Recupera Umanità
    final int currentH = sheet.identity.currentHumanity;
    final int maxH = totals.maxHumanity;
    final int restored = math.min(diceRoll, maxH - currentH);
    final int newH = currentH + restored;
    widget.state.mutate((CharacterSheet s) => s.identity.currentHumanity = newH);

    setState(() {
      _outcomeLog = '✅ $type completata con successo!\n'
          '• Eurodollari spesi: -$cost eb\n'
          '• Tempo di degenza in clinica: $days giorni di riposo\n'
          '• Umanità recuperata: +$restored punti (Umanità attuale: $newH / $maxH)';
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.state.sheet;
    final totals = widget.state.totals;
    final int currentH = sheet?.identity.currentHumanity ?? 0;
    final int maxH = totals?.maxHumanity ?? 50;

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
            BoxShadow(color: CprPalette.magenta.withValues(alpha: 0.3), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.psychology_outlined, color: CprPalette.magenta, size: 24),
                const SizedBox(width: 8),
                Text('CLINICA DI RECUPERO UMANITÀ & TERAPIA', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Stato attuale: Umanità $currentH / $maxH · Eurodollari disponibili: ${sheet?.eurobucks ?? 0} eb',
              style: CprType.caption.copyWith(color: CprPalette.cyan),
            ),
            const SizedBox(height: 14),
            ChamferPanel(
              accent: CprPalette.cyan,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('TERAPIA STANDARD (PAG. 229)', style: CprType.label.copyWith(color: CprPalette.cyan)),
                  const SizedBox(height: 4),
                  Text(
                    'Costo: 500 eb · Degenza: 7 giorni · Recupero: 2d6 punti Umanità (massimo consentito da Empatia di base).',
                    style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  TechButton(
                    label: 'Esegui Terapia Standard (500 eb)',
                    icon: Icons.healing,
                    variant: TechButtonVariant.primary,
                    onPressed: () {
                      final int r = (math.Random().nextInt(6) + 1) + (math.Random().nextInt(6) + 1);
                      _applyTherapy(type: 'Terapia Standard', cost: 500, days: 7, diceRoll: r);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ChamferPanel(
              accent: CprPalette.magenta,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('TERAPIA ESTREMA IN VASCA AMNIOTICA (PAG. 230)', style: CprType.label.copyWith(color: CprPalette.magenta)),
                  const SizedBox(height: 4),
                  Text(
                    'Costo: 1000 eb · Degenza: 14 giorni · Recupero: 4d6 punti Umanità. Trattamento intensivo per chi è vicino al baratro cyberpsicotico.',
                    style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  TechButton(
                    label: 'Esegui Terapia Estrema (1000 eb)',
                    icon: Icons.biotech,
                    variant: TechButtonVariant.secondary,
                    onPressed: () {
                      int r = 0;
                      for (int i = 0; i < 4; i++) {
                        r += math.Random().nextInt(6) + 1;
                      }
                      _applyTherapy(type: 'Terapia Estrema', cost: 1000, days: 14, diceRoll: r);
                    },
                  ),
                ],
              ),
            ),
            if (_outcomeLog.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CprPalette.surfaceRaised,
                  border: Border.all(color: CprPalette.hairline),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(_outcomeLog, style: CprType.caption.copyWith(color: CprPalette.ink, height: 1.4)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 3. GENERATORE DI INCONTRI NOTTURNI & CONDIZIONI METEO
// =============================================================================

class NightCityEncounterDialog extends StatefulWidget {
  const NightCityEncounterDialog({super.key});

  @override
  State<NightCityEncounterDialog> createState() => _NightCityEncounterDialogState();
}

class _NightCityEncounterDialogState extends State<NightCityEncounterDialog> {
  String _currentEncounter = 'Premi "Estrai Incontro Notturno" per generare un evento casuale per la sessione.';
  String _currentWeather = 'Meteo: Cielo plumbeo al neon, smog denso.';

  static const List<String> _encounters = <String>[
    'Agguato dei Bozo: 3 clown cibernetici sbucano da un vicolo suonando clacson e lanciando granate a gas esilarante!',
    'Posto di Blocco Max-Tac: Una pattuglia in tuta pesante corazzata blocca la strada per scansionare i passanti alla ricerca di cyberpsicopatici.',
    'Pattuglia Tyger Claws: 4 centauri su moto Yaiba Kusanagi con spade katana termiche pretendono 100 eb di pedaggio territoriale.',
    'Rituale Maelstrom: 2 cyborg Maelstrom con innesti facciali completi stanno estraendo chip corticali da un cadavere aziendale.',
    'Traffico Bloccato da AV-4 Precipitato: Un aerodyne Trauma Team è atterrato d\'emergenza in mezzo alla carreggiata.',
    'Spacciatore di Black Lace: Un pusher nervoso offre fiale di Black Lace e Blue Glass a metà prezzo prima dell\'arrivo dell\'NCPD.',
    'Sparatoria Incrociata Gang vs Azienda: Proiettili vaganti rimbalzano sui muri tra guardie Arasaka e membri dei 6th Street.',
    'Dronata di Sorveglianza Netwatch: Un drone ottico autonomo scansiona la testa di un Netrunner del gruppo emettendo un allarme sonoro.',
  ];

  static const List<String> _weathers = <String>[
    'Meteo: Pioggia Acida Giallastra (-1 SP all\'armatura non protetta dopo 1 ora all\'aperto).',
    'Meteo: Smog Tossico da Raffineria (DV 13 Tempra per non tossire e subire -1 alle azioni).',
    'Meteo: Nebbia Artificiale al Neon (Visibilità ridotta a 10 metri, tiri a distanza a DV +2).',
    'Meteo: Blackout Parziale del Distretto (Tutte le luci spente, telecamere disattivate).',
    'Meteo: Vento Arido dalle Badlands (Polvere abrasiva, rumori attutiti).',
    'Meteo: Notte Serena con Luna Piena al Neon (Visibilità perfetta).',
  ];

  void _roll() {
    final rand = math.Random();
    setState(() {
      _currentEncounter = _encounters[rand.nextInt(_encounters.length)];
      _currentWeather = _weathers[rand.nextInt(_weathers.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.yellow, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.yellow.withValues(alpha: 0.3), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.flash_on, color: CprPalette.yellow, size: 24),
                const SizedBox(width: 8),
                Text('TABELLA INCONTRI NOTTURNI & METEO', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                border: Border.all(color: CprPalette.hairline),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_currentWeather, style: CprType.caption.copyWith(color: CprPalette.yellow, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_currentEncounter, style: CprType.body.copyWith(color: CprPalette.ink, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TechButton(
              label: 'Estrai Incontro Notturno',
              icon: Icons.casino,
              variant: TechButtonVariant.primary,
              onPressed: _roll,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 4. CALCOLATORE DV BALISTICO PER DISTANZA (METRI -> DV)
// =============================================================================

class BallisticDvCalculatorDialog extends StatefulWidget {
  const BallisticDvCalculatorDialog({super.key});

  @override
  State<BallisticDvCalculatorDialog> createState() => _BallisticDvCalculatorDialogState();
}

class _BallisticDvCalculatorDialogState extends State<BallisticDvCalculatorDialog> {
  double _meters = 15.0;

  // Tabella DV ufficiale Cyberpunk RED (pag. 173)
  int _getDv(String weapon, double m) {
    if (weapon == 'Pistola') {
      if (m <= 6) return 13;
      if (m <= 12) return 15;
      if (m <= 25) return 20;
      if (m <= 50) return 25;
      return 30;
    } else if (weapon == 'SMG') {
      if (m <= 6) return 15;
      if (m <= 12) return 13;
      if (m <= 25) return 15;
      if (m <= 50) return 20;
      return 25;
    } else if (weapon == 'Fucile a Pompa') {
      if (m <= 6) return 13;
      if (m <= 12) return 15;
      if (m <= 25) return 20;
      return 30;
    } else if (weapon == 'Fucile d\'Assalto') {
      if (m <= 6) return 17;
      if (m <= 12) return 16;
      if (m <= 25) return 15;
      if (m <= 50) return 13;
      if (m <= 100) return 15;
      return 20;
    } else if (weapon == 'Fucile di Precisione') {
      if (m <= 6) return 30;
      if (m <= 12) return 25;
      if (m <= 25) return 20;
      if (m <= 50) return 15;
      if (m <= 100) return 13;
      return 15;
    }
    return 15;
  }

  @override
  Widget build(BuildContext context) {
    final weapons = ['Pistola', 'SMG', 'Fucile a Pompa', 'Fucile d\'Assalto', 'Fucile di Precisione'];

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.cyan, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.cyan.withValues(alpha: 0.3), blurRadius: 16),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.track_changes, color: CprPalette.cyan, size: 24),
                const SizedBox(width: 8),
                Text('CALCOLATORE DV BALISTICO UFFICIALE', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Distanza bersaglio: ${_meters.round()} metri', style: CprType.caption.copyWith(color: CprPalette.cyan)),
            Slider(
              value: _meters,
              min: 1,
              max: 120,
              divisions: 119,
              activeColor: CprPalette.cyan,
              inactiveColor: CprPalette.hairline,
              onChanged: (v) => setState(() => _meters = v),
            ),
            const SizedBox(height: 10),
            Table(
              border: TableBorder.all(color: CprPalette.hairline),
              children: <TableRow>[
                TableRow(
                  decoration: const BoxDecoration(color: CprPalette.surfaceRaised),
                  children: const <Widget>[
                    Padding(padding: EdgeInsets.all(6), child: Text('Arma', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: EdgeInsets.all(6), child: Text('DV Bersaglio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    Padding(padding: EdgeInsets.all(6), child: Text('Efficacia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                ),
                for (final w in weapons) ...<TableRow>[
                  TableRow(
                    children: <Widget>[
                      Padding(padding: const EdgeInsets.all(6), child: Text(w, style: const TextStyle(fontSize: 11))),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          'DV ${_getDv(w, _meters)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getDv(w, _meters) <= 15 ? CprPalette.success : CprPalette.danger,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(
                          _getDv(w, _meters) <= 15 ? 'Portata Ottimale' : (_getDv(w, _meters) <= 20 ? 'Media' : 'Difficile / Svantaggio'),
                          style: const TextStyle(fontSize: 10, color: CprPalette.inkMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
