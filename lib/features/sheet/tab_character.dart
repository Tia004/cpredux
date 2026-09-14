import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/enums.dart';
import '../../domain/rules.dart';
import '../../domain/sheet.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/health_heart.dart';
import '../../widgets/humanity_gauge.dart';
import '../../widgets/inputs.dart';

class CharacterTab extends StatelessWidget {
  const CharacterTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet;
    final totals = state.totals;
    if (sheet == null || totals == null) return const SizedBox.shrink();

    final bool isUncompiled = sheet.identity.tag.trim().isEmpty || sheet.identity.role.trim().isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (isUncompiled) ...<Widget>[
            const _EmptySheetGuideBanner(),
            const SizedBox(height: 16),
          ],
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              // Il cuore e la spira sono elementi grandi: sotto i 900 px si
              // impilano invece di comprimersi fino a diventare illeggibili.
              const Widget vitals = _VitalsPanel();
              const Widget identity = _IdentityPanel();
              if (c.maxWidth < 900) {
                return const Column(
                  children: <Widget>[vitals, SizedBox(height: 16), identity],
                );
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 5, child: vitals),
                  SizedBox(width: 16),
                  Expanded(flex: 6, child: identity),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          _DerivedPanel(totals: totals),
          const SizedBox(height: 16),
          _ConditionsPanel(sheet: sheet),
        ],
      ),
    );
  }
}

class _VitalsPanel extends StatelessWidget {
  const _VitalsPanel();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet!;
    final totals = state.totals!;
    final identity = sheet.identity;

    return ChamferPanel(
      title: 'Stato vitale',
      accent: CprPalette.healthColorFor(
        totals.maxHitPoints == 0 ? 0 : identity.currentHp / totals.maxHitPoints,
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Tooltip(
                message: 'Punti Vita (PV): 10 + 5 × Media(FIS, VOL). A metà PV sei Ferito Gravemente (-2 a tutte le azioni). A 0 PV sei Morente.',
                waitDuration: const Duration(milliseconds: 200),
                child: HealthHeart(
                  current: identity.currentHp,
                  max: totals.maxHitPoints,
                  size: 178,
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Umanità: Inizia a Empatia × 10. Si riduce installando Cyberware. Sotto i 10 punti rischi la Cyberpsicosi!',
                waitDuration: const Duration(milliseconds: 200),
                child: HumanityGauge(
                  current: identity.currentHumanity,
                  max: totals.maxHumanity,
                  size: 178,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _DamageControls(
            current: identity.currentHp,
            max: totals.maxHitPoints,
            onSet: (int value) => state.mutate((s) => s.identity.currentHp = value),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TechNumberStepper(
                  label: 'Fortuna corrente',
                  value: identity.currentLuck,
                  max: 99,
                  accent: CprPalette.yellow,
                  onChanged: (int v) => state.mutate((s) => s.identity.currentLuck = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Empatia corrente',
                  value: identity.currentEmpathy,
                  max: totals.maxEmpathy,
                  accent: CprPalette.humanityIntact,
                  onChanged: (int v) => state.mutate((s) => s.identity.currentEmpathy = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: TechNumberStepper(
                  label: 'Umanita corrente',
                  value: identity.currentHumanity,
                  max: totals.maxHumanity,
                  accent: CprPalette.humanityIntact,
                  onChanged: (int v) => state.mutate((s) => s.identity.currentHumanity = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Punti ispirazione',
                  value: identity.inspirationPoints,
                  max: 99,
                  accent: CprPalette.magenta,
                  onChanged: (int v) => state.mutate((s) => s.identity.inspirationPoints = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: TechNumberStepper(
                  label: 'Punti miglioramento',
                  value: identity.currentImprovementPoints,
                  max: 999,
                  compact: true,
                  onChanged: (int v) => state.mutate((s) => s.identity.currentImprovementPoints = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TechNumberStepper(
                  label: 'Totale guadagnati',
                  value: identity.totalImprovementPoints,
                  max: 999,
                  compact: true,
                  onChanged: (int v) => state.mutate((s) => s.identity.totalImprovementPoints = v),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Controlli di danno e cura.
///
/// Il caso d'uso reale e' quasi sempre "ho preso 7 danni" oppure "ho usato un
/// Medkit": chiedere all'utente di calcolare mentalmente il nuovo totale e
/// digitarlo e' un errore di progetto, perche' lo espone a sbagliare proprio
/// nel momento in cui la sessione e' piu' concitata.
class _DamageControls extends StatelessWidget {
  const _DamageControls({
    required this.current,
    required this.max,
    required this.onSet,
  });

  final int current;
  final int max;
  final ValueChanged<int> onSet;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: <Widget>[
            _QuickButton(
              label: '1 danno',
              color: CprPalette.danger,
              onTap: () => onSet((current - 1).clamp(0, max)),
            ),
            _QuickButton(
              label: '5 danni',
              color: CprPalette.danger,
              onTap: () => onSet((current - 5).clamp(0, max)),
            ),
            _QuickButton(
              label: '10 danni',
              color: CprPalette.danger,
              onTap: () => onSet((current - 10).clamp(0, max)),
            ),
            _QuickButton(
              label: '1 cura',
              color: CprPalette.success,
              onTap: () => onSet((current + 1).clamp(0, max)),
            ),
            _QuickButton(
              label: '5 cura',
              color: CprPalette.success,
              onTap: () => onSet((current + 5).clamp(0, max)),
            ),
            _QuickButton(
              label: 'Riposo completo',
              color: CprPalette.success,
              onTap: () => onSet(max),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.label, required this.color, required this.onTap});

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
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            border: Border.all(color: CprPalette.veil(color, 0.55)),
            color: CprPalette.veil(color, 0.08),
          ),
          child: Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(fontSize: 9.5, color: color),
          ),
        ),
      ),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel();

  static const List<Map<String, String>> _standardRoles = <Map<String, String>>[
    <String, String>{'role': 'Solo', 'ability': 'Consapevolezza del Combattimento'},
    <String, String>{'role': 'Netrunner', 'ability': 'Interfaccia'},
    <String, String>{'role': 'Tech', 'ability': 'Fabbricazione / Riparazione'},
    <String, String>{'role': 'Medtech', 'ability': 'Medicina'},
    <String, String>{'role': 'Rockerboy', 'ability': 'Impatto Carismatico'},
    <String, String>{'role': 'Fixer', 'ability': 'Mercato Nero / Contatti'},
    <String, String>{'role': 'Media', 'ability': 'Credibilità'},
    <String, String>{'role': 'Lawman', 'ability': 'Backup Legale'},
    <String, String>{'role': 'Exec', 'ability': 'Lavoro di Squadra'},
    <String, String>{'role': 'Nomade', 'ability': 'Moto / Famiglia'},
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final identity = state.sheet!.identity;

    return ChamferPanel(
      title: 'Anagrafica',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Tooltip(
                  message: 'Il nome da strada (Handle) con cui il tuo personaggio è conosciuto.',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Nome del personaggio',
                    value: identity.tag,
                    hint: 'Come ti chiamano in strada',
                    onChanged: (String v) => state.mutate((s) => s.identity.tag = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: 'Il tuo nome o nickname reale al tavolo di gioco.',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Giocatore',
                    value: identity.playerName,
                    onChanged: (String v) => state.mutate((s) => s.identity.playerName = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: Tooltip(
                  message: 'Soprannomi o pseudonimi usati nelle strade di Night City.',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Soprannomi',
                    value: identity.aliases,
                    hint: 'Separati da virgola',
                    onChanged: (String v) => state.mutate((s) => s.identity.aliases = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: 'Anno e data corrente della campagna (es. 2045 o 2077).',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Data in gioco',
                    value: identity.gameDate,
                    hint: 'gg/mm/aaaa',
                    onChanged: (String v) => state.mutate((s) => s.identity.gameDate = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Tooltip(
                      message: 'Scegli la tua carriera: clicca un pulsante rapido sotto o digita un ruolo.',
                      waitDuration: const Duration(milliseconds: 200),
                      child: TechField(
                        label: 'Ruolo',
                        value: identity.role,
                        hint: 'Solo, Nomade, Netrunner…',
                        accent: CprPalette.yellow,
                        onChanged: (String v) => state.mutate((s) => s.identity.role = v),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: <Widget>[
                        for (final r in _standardRoles)
                          _RoleChip(
                            label: r['role']!,
                            selected: identity.role.trim().toLowerCase() == r['role']!.toLowerCase(),
                            onTap: () => state.mutate((s) {
                              s.identity.role = r['role']!;
                              if (s.identity.roleAbility.trim().isEmpty) {
                                s.identity.roleAbility = r['ability']!;
                              }
                              if (s.identity.roleRank.trim().isEmpty || s.identity.roleRank == '0') {
                                s.identity.roleRank = '4';
                              }
                            }),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: 'Reputazione: quanto sei temuto o rispettato (da 0 per sconosciuto a 10 per leggenda).',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Punti reputazione',
                    value: identity.reputation,
                    onChanged: (String v) => state.mutate((s) => s.identity.reputation = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: Tooltip(
                  message: 'La capacità speciale unica derivante dal tuo Ruolo.',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Abilita di ruolo',
                    value: identity.roleAbility,
                    onChanged: (String v) => state.mutate((s) => s.identity.roleAbility = v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Tooltip(
                  message: 'Grado di competenza dell\'abilità di ruolo (da 1 a 10, di norma 4 alla creazione).',
                  waitDuration: const Duration(milliseconds: 200),
                  child: TechField(
                    label: 'Rango',
                    value: identity.roleRank,
                    numeric: true,
                    onChanged: (String v) => state.mutate((s) => s.identity.roleRank = v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? CprPalette.yellow : CprPalette.inkMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(CprPalette.yellow, 0.15) : CprPalette.surfaceRaised,
            border: Border.all(
              color: selected ? CprPalette.yellow : CprPalette.hairline,
              width: 1,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: CprType.label.copyWith(
              fontSize: 9,
              color: color,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySheetGuideBanner extends StatelessWidget {
  const _EmptySheetGuideBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CprPalette.veil(CprPalette.yellow, 0.08),
        border: Border.all(color: CprPalette.veil(CprPalette.yellow, 0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.lightbulb_outline, color: CprPalette.yellow, size: 18),
              const SizedBox(width: 8),
              Text(
                'GUIDA ALLA COMPILAZIONE DELLA SCHEDA',
                style: CprType.label.copyWith(color: CprPalette.yellow, letterSpacing: 1.1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '• Compila il Nome (Handle) del personaggio e clicca sul tuo Ruolo nei pulsanti rapidi sotto.\n'
            '• Apri la sezione "Statistiche e Abilità" nel menu a sinistra per distribuire i 62 punti tra le 10 caratteristiche.\n'
            '• Punti Vita (PV), Umanità, Soglia Ferita Grave e Basi Abilità si calcolano automaticamente in tempo reale!',
            style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12.5, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _DerivedPanel extends StatelessWidget {
  const _DerivedPanel({required this.totals});

  final SheetTotals totals;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Valori calcolati',
      accent: CprPalette.inkFaint,
      trailing: Text(
        'ricalcolati automaticamente',
        style: CprType.caption.copyWith(color: CprPalette.inkFaint),
      ),
      child: Wrap(
        spacing: 26,
        runSpacing: 14,
        children: <Widget>[
          _DerivedValue(
            label: 'Punti vita massimi',
            value: '${totals.maxHitPoints}',
            tooltip: 'Formula da manuale: 10 + 5 × Media(FIS, VOL).',
          ),
          _DerivedValue(
            label: 'Soglia ferite gravi',
            value: '${totals.severeInjuriesThreshold}',
            hint: 'ogni danno oltre questa soglia',
            tooltip: 'A metà dei PV massimi. Sei Ferito Gravemente (-2 a tutte le azioni).',
          ),
          _DerivedValue(
            label: 'Empatia massima',
            value: '${totals.maxEmpathy}',
            tooltip: 'Il valore di Empatia attuale, calcolato come Umanità / 10.',
          ),
          _DerivedValue(
            label: 'Umanita massima',
            value: '${totals.maxHumanity}',
            tooltip: 'Umanità massima iniziale = Empatia base × 10.',
          ),
          _DerivedValue(
            label: 'Umanita persa',
            value: '${totals.humanityLost}',
            danger: totals.humanityLost > 0,
            tooltip: 'Umanità sottratta a causa di Cyberware installato o traumi psicologici.',
          ),
          _DerivedValue(
            label: 'Carico massimo',
            value: '${totals.maxLoad.toStringAsFixed(1)} kg',
            tooltip: 'Peso trasportabile prima di subire penalità al movimento.',
          ),
          _DerivedValue(
            label: 'Carico attuale',
            value: '${totals.currentLoad.toStringAsFixed(1)} kg',
            tooltip: 'Peso complessivo di inventario ed equipaggiamento.',
          ),
          _DerivedValue(
            label: 'Stato di carico',
            value: totals.loadStatus.label,
            danger: totals.loadStatus == LoadStatus.overload,
            tooltip: 'Stato del carico: Normale, Pesante o Sovraccarico (-2 VEL).',
          ),
        ],
      ),
    );
  }
}

class _DerivedValue extends StatelessWidget {
  const _DerivedValue({
    required this.label,
    required this.value,
    this.hint,
    this.tooltip,
    this.danger = false,
  });

  final String label;
  final String value;
  final String? hint;
  final String? tooltip;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
        const SizedBox(height: 3),
        Text(
          value,
          style: CprType.numeral.copyWith(
            fontSize: 19,
            color: danger ? CprPalette.danger : CprPalette.ink,
          ),
        ),
        if (hint != null)
          Text(hint!, style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10)),
      ],
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 200),
        child: content,
      );
    }
    return content;
  }
}

class _ConditionsPanel extends StatelessWidget {
  const _ConditionsPanel({required this.sheet});

  final CharacterSheet sheet;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return ChamferPanel(
      title: 'Condizioni',
      accent: CprPalette.warning,
      child: Column(
        children: <Widget>[
          TechTextArea(
            label: 'Ferite gravi',
            value: sheet.identity.severeInjuries,
            hint: 'Una per riga: cosa, dove, quanto e\' guarita',
            lines: 3,
            accent: CprPalette.danger,
            onChanged: (String v) => state.mutate((s) => s.identity.severeInjuries = v),
          ),
          const SizedBox(height: 12),
          TechTextArea(
            label: 'Dipendenze',
            value: sheet.identity.addictions,
            hint: 'Sostanza, grado di dipendenza',
            lines: 3,
            accent: CprPalette.magenta,
            onChanged: (String v) => state.mutate((s) => s.identity.addictions = v),
          ),
        ],
      ),
    );
  }
}
