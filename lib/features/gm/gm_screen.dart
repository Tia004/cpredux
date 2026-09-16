import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/catalog_item.dart';
import '../../domain/dice_expression.dart';
import '../../domain/enums.dart';
import '../../domain/net_architecture.dart';
import '../../domain/gm/gm_calculators.dart';
import '../../domain/transport.dart';
import '../../domain/world_map.dart';
import '../../domain/gm/gm_generators.dart';
import '../../domain/gm/gm_rules.dart';
import '../../domain/map_token.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/cyber_markdown_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../campaign/enemy_loot_dialog.dart';

/// La console del Master.
///
/// Perche' una schermata sola e non tredici voci di menu': al tavolo questi
/// strumenti si usano **insieme e in fretta**, spesso a meta' frase ("aspetta,
/// quanto DV a trenta metri?"). Un menu che costringe a scegliere uno strumento,
/// usarlo e tornare indietro costa tre clic per una domanda da due secondi. Una
/// barra laterale costa un clic, e la sezione precedente resta a un clic di
/// distanza mentre il Master continua a parlare.
///
/// La seconda decisione e' visibile in tutta la schermata: **nessun numero e'
/// presentato senza dire quanto vale**. Accanto ai valori che vengono dal
/// manuale c'e' un'etichetta che distingue "verificato" da "da verificare", e le
/// tabelle inventate da questa applicazione lo dichiarano nell'intestazione. Un
/// Master che scopre a meta' sessione che un numero era una proposta non si
/// fida piu' di nessuno degli altri, ed e' un danno che non si ripara.
class GmScreen extends StatelessWidget {
  const GmScreen({super.key});

  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.fromLTRB(18, 16, 18, 18), child: GmConsole());
}

/// Come si presenta la console.
///
/// Due disposizioni e non due schermate: gli strumenti e la logica sono gli
/// stessi, cambia solo dove sta il selettore. Duplicarli avrebbe significato due
/// copie da tenere allineate, e la prima cosa che sarebbe divergita e' proprio
/// quella che serve al tavolo.
enum GmConsoleLayout {
  /// Pagina intera: barra laterale a sinistra, con l'intestazione.
  page,

  /// Pannello stretto: il selettore diventa una striscia di icone in alto.
  panel,
}

/// Le sezioni della console.
enum GmTool {
  dadi(
    'Dadi e macro',
    'Espressioni complete: 1d10 + RIF + Pistole, (1d10+8)*2−4, 4d6kh3.',
    Icons.casino_outlined,
  ),
  incontro(
    'Incontro notturno',
    'Un agguato, una pattuglia o solo la pioggia acida, con i nemici pronti.',
    Icons.nightlight_outlined,
  ),
  bottino(
    'Bottino',
    'Cosa aveva addosso chi e\' caduto, gia\' contato.',
    Icons.inventory_2_outlined,
  ),
  screamsheet(
    'Screamsheet',
    'Un trafiletto di giornale da leggere ai giocatori prima della sessione.',
    Icons.newspaper_outlined,
  ),
  png('PNG rapidi', 'Nemici di scena con tre numeri, in dieci secondi.', Icons.groups_outlined),
  dv(
    'DV balistico',
    'Distanza in metri, classe d\'arma, DV da battere.',
    Icons.my_location_outlined,
  ),
  terapia(
    'Cyberpsicosi e terapia',
    'Quanta Umanita\' manca, quanto costa tornare indietro e in quante settimane.',
    Icons.psychology_alt_outlined,
  ),
  guarigione(
    'Guarigione',
    'Giorni di degenza, con o senza Medtech, con o senza un letto.',
    Icons.healing_outlined,
  ),
  stileVita(
    'Stile di vita',
    'Cibo, alloggio e debiti: quanto costa un mese e quanti ne restano.',
    Icons.home_work_outlined,
  ),
  debiti(
    'Debiti',
    'Prestiti, interessi settimanali e chi sta crescendo piu\' in fretta.',
    Icons.receipt_long_outlined,
  ),
  mercato(
    'Mercato nero',
    'Cosa si trova davvero, in base al rango di Contatti.',
    Icons.storefront_outlined,
  ),
  trasporti(
    'Trasporti in tempo reale',
    'Metti un mezzo in strada, guardalo andare, e fermalo quando serve.',
    Icons.local_taxi_outlined,
  ),
  rete(
    'Console di rete',
    'Attacchi ai programmi con il REZ che scende, colpo per colpo.',
    Icons.lan_outlined,
  ),
  regole(
    'Numeri e regole',
    'Ogni valore usato qui, con la sua provenienza e la possibilita\' di correggerlo.',
    Icons.tune_outlined,
  );

  const GmTool(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;

  Color get accent {
    switch (this) {
      case GmTool.dadi:
      case GmTool.bottino:
        return CprPalette.yellow;
      case GmTool.incontro:
        return CprPalette.magenta;
      case GmTool.screamsheet:
      case GmTool.stileVita:
        return CprPalette.cyan;
      case GmTool.png:
        return CprPalette.danger;
      case GmTool.dv:
      case GmTool.debiti:
        return CprPalette.warning;
      case GmTool.terapia:
        return CprPalette.humanityEroded;
      case GmTool.guarigione:
        return CprPalette.success;
      case GmTool.mercato:
        return CprPalette.violet;
      case GmTool.trasporti:
      case GmTool.rete:
        return CprPalette.info;
      case GmTool.regole:
        return CprPalette.inkMuted;
    }
  }
}

/// La console vera e propria, usabile sia come pagina sia come pannello.
class GmConsole extends StatefulWidget {
  const GmConsole({super.key, this.layout = GmConsoleLayout.page});

  final GmConsoleLayout layout;

  @override
  State<GmConsole> createState() => _GmConsoleState();
}

class _GmConsoleState extends State<GmConsole> {
  GmTool _tool = GmTool.dadi;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.layout == GmConsoleLayout.page) ...<Widget>[
          _Header(ruleCount: state.gmRuleBook.rules.length),
          const SizedBox(height: 14),
        ] else
          const SizedBox.shrink(),
        Expanded(
          child: widget.layout == GmConsoleLayout.page
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 226,
                      child: SingleChildScrollView(
                        child: _Rail(
                          selected: _tool,
                          overriddenCount: state.settings.gmRuleOverrides.length,
                          onSelect: (GmTool t) => setState(() => _tool = t),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: _body(state)),
                  ],
                )
              : _panelLayout(state),
        ),
      ],
    );
  }

  /// Nel pannello stretto il selettore e' una striscia: duecentoventisei pixel
  /// di barra laterale dentro un cassetto da quattrocento non lasciano spazio
  /// agli strumenti, che sono la ragione per cui il pannello esiste.
  Widget _panelLayout(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: GmTool.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: 4),
            itemBuilder: (BuildContext context, int index) {
              final GmTool tool = GmTool.values[index];
              return _ToolChip(tool: tool, selected: tool == _tool, onTap: () => setState(() => _tool = tool));
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: _body(state)),
      ],
    );
  }

  Widget _body(AppState state) {
    final Widget content = switch (_tool) {
      GmTool.dadi => _DicePanel(key: ValueKey<String>('dadi'), state: state),
      GmTool.incontro => _EncounterPanel(key: ValueKey<String>('incontro'), state: state),
      GmTool.bottino => _LootPanel(key: ValueKey<String>('bottino'), state: state),
      GmTool.screamsheet => _ScreamsheetPanel(key: ValueKey<String>('scream'), state: state),
      GmTool.png => _MookPanel(key: ValueKey<String>('png'), state: state),
      GmTool.dv => _BallisticsPanel(key: ValueKey<String>('dv'), state: state),
      GmTool.terapia => _TherapyPanel(key: ValueKey<String>('terapia'), state: state),
      GmTool.guarigione => _HealingPanel(key: ValueKey<String>('guarigione'), state: state),
      GmTool.stileVita => _LifestylePanel(key: ValueKey<String>('vita'), state: state),
      GmTool.debiti => _DebtPanel(key: ValueKey<String>('debiti'), state: state),
      GmTool.mercato => _MarketPanel(key: ValueKey<String>('mercato'), state: state),
      GmTool.trasporti => _TransportPanel(key: ValueKey<String>('trasporti'), state: state),
      GmTool.rete => _NetPanel(key: ValueKey<String>('rete'), state: state),
      GmTool.regole => _RulesPanel(key: ValueKey<String>('regole'), state: state),
    };

    // Lo scorrimento sta **fuori** dal pannello, non dentro il suo `child`.
    //
    // Dentro non funziona, e non e' una preferenza: `ChamferPanel` dispone
    // titolo e contenuto in una `Column`, e una vista scorrevole come figlio
    // reclama tutta l'altezza disponibile. Il titolo resta senza spazio e la
    // `Column` va in overflow di ottantotto pixel — su una finestra di 800x600
    // si vedrebbe la striscia a righe gialle e nere. Con lo scorrimento fuori,
    // il pannello prende l'altezza che gli serve e scorre lui.
    return SingleChildScrollView(
      child: ChamferPanel(title: _tool.label, accent: _tool.accent, padding: const EdgeInsets.all(16), child: content),
    );
  }
}

/// La voce del selettore nella disposizione a pannello: solo l'icona, con il
/// nome nel suggerimento. In quattrocento pixel di larghezza un'etichetta per
/// tredici strumenti non ci sta, e un elenco a scorrimento di nomi troncati e'
/// peggio di tredici icone riconoscibili.
class _ToolChip extends StatelessWidget {
  const _ToolChip({required this.tool, required this.selected, required this.onTap});

  final GmTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tool.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: selected ? CprPalette.veil(tool.accent, 0.16) : CprPalette.surfaceSunken,
              border: Border.all(color: selected ? tool.accent : CprPalette.hairline),
            ),
            child: Icon(tool.icon, size: 16, color: selected ? tool.accent : CprPalette.inkMuted),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ruleCount});

  final int ruleCount;

  @override
  Widget build(BuildContext context) {
    // L'`Expanded` non e' cosmetico: senza, la riga di spiegazione prende la
    // larghezza che le serve invece di andare a capo, e a 800 pixel di finestra
    // il testo lungo sfonda il bordo destro.
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('STRUMENTI DEL MASTER', style: CprType.display.copyWith(fontSize: 22, color: CprPalette.violet)),
              const SizedBox(height: 4),
              Text(
                '$ruleCount numeri, ognuno con la sua fonte. Quelli non verificati sono segnati: correggili una volta e valgono per tutta la campagna.',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.selected, required this.onSelect, required this.overriddenCount});

  final GmTool selected;
  final ValueChanged<GmTool> onSelect;
  final int overriddenCount;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final GmTool tool in GmTool.values)
            _RailButton(tool: tool, selected: tool == selected, onTap: () => onSelect(tool)),
          if (overriddenCount > 0) ...<Widget>[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$overriddenCount valori corretti dal tavolo',
                style: CprType.caption.copyWith(color: CprPalette.warning, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({required this.tool, required this.selected, required this.onTap});

  final GmTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.tool.accent;
    final bool active = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: active ? CprPalette.veil(accent, 0.14) : (_hover ? CprPalette.surfaceHover : Colors.transparent),
            border: Border(left: BorderSide(color: active ? accent : Colors.transparent, width: 3)),
          ),
          child: Row(
            children: <Widget>[
              Icon(widget.tool.icon, size: 15, color: active ? accent : CprPalette.inkMuted),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  widget.tool.label,
                  style: CprType.caption.copyWith(
                    color: active ? CprPalette.ink : CprPalette.inkMuted,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
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

// --------------------------------------------------------------------------
// Elementi comuni
// --------------------------------------------------------------------------

/// Intestazione di sezione: cosa fa lo strumento, in una riga.
class _ToolIntro extends StatelessWidget {
  const _ToolIntro({required this.text, this.confidence});

  final String text;
  final GmConfidence? confidence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(text, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
          ),
          if (confidence != null) ...<Widget>[const SizedBox(width: 10), _ConfidenceBadge(confidence: confidence!)],
        ],
      ),
    );
  }
}

/// Quanto ci si puo' fidare del numero che sta accanto.
class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence});

  final GmConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (confidence) {
      GmConfidence.verificato => CprPalette.success,
      GmConfidence.daVerificare => CprPalette.warning,
      GmConfidence.proposta => CprPalette.violet,
    };

    return Tooltip(
      message: confidence.explanation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: CprPalette.veil(color, 0.13),
          border: Border.all(color: CprPalette.veil(color, 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              switch (confidence) {
                GmConfidence.verificato => Icons.verified_outlined,
                GmConfidence.daVerificare => Icons.report_problem_outlined,
                GmConfidence.proposta => Icons.architecture_outlined,
              },
              size: 11,
              color: color,
            ),
            const SizedBox(width: 5),
            Text(confidence.label.toUpperCase(), style: CprType.label.copyWith(fontSize: 9, color: color)),
          ],
        ),
      ),
    );
  }
}

/// Il risultato di uno strumento, con il pulsante per portarlo in chat.
class _Result extends StatelessWidget {
  const _Result({required this.text, this.accent, this.selectable = true});

  final String text;
  final Color? accent;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return TechWell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CyberMarkdownView(
            markdown: text,
            accent: accent,
            selectable: selectable,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: _CopyButton(text: text, accent: accent),
          ),
        ],
      ),
    );
  }
}

/// Copia negli appunti, dicendo che l'ha fatto.
///
/// Il cambio di etichetta non e' decorazione: `Clipboard.setData` non produce
/// nessun segnale visibile, e senza un riscontro l'utente preme due volte e
/// incolla due volte.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text, this.accent});

  final String text;
  final Color? accent;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return TechButton(
      label: _copied ? 'Copiato' : 'Copia',
      icon: _copied ? Icons.check : Icons.copy_all_outlined,
      compact: true,
      tooltip: 'Copia negli appunti, pronto da incollare in chat',
      onPressed: _copy,
    );
  }
}

/// Un numero grande, isolato: il risultato che si legge da un metro di distanza.
class _BigNumber extends StatelessWidget {
  const _BigNumber({required this.value, required this.label, required this.accent});

  final String value;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(value, style: CprType.numeral.copyWith(fontSize: 42, color: accent)),
        const SizedBox(width: 10),
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkMuted)),
      ],
    );
  }
}

/// Porta un gruppo di PNG sulla mappa come token.
///
/// Ritorna quanti ne sono stati messi. I token nascono **in cerchio attorno al
/// centro della mappa**: fanno parte del tavolo e il Master li sposta subito, ma
/// nascerne otto impilati nello stesso pixel vorrebbe dire non vederne nessuno.
///
/// I tre numeri del PNG rapido viaggiano con il token: arrivare sulla mappa e
/// dover ricopiare a mano i Punti Vita dalla console sarebbe il lavoro che
/// questa funzione esiste per togliere.
int sendBandToTable(
  AppState state,
  List<Mook> band, {
  required String groupLabel,
  Offset center = const Offset(0.5, 0.5),
  TokenKind kind = TokenKind.nemico,
}) {
  if (band.isEmpty) return 0;
  final List<Offset> spots = tokenCluster(count: band.length, center: center);
  final List<MapToken> tokens = <MapToken>[
    for (int i = 0; i < band.length; i++)
      MapToken(
        id: '',
        name: band[i].name,
        x: spots[i].dx,
        y: spots[i].dy,
        kind: kind,
        hp: band[i].hitPoints,
        maxHp: band[i].hitPoints,
        sp: band[i].sp,
        combat: band[i].combat,
        defense: band[i].defense,
        damage: band[i].damage,
        note: band[i].shtick,
      ),
  ];
  return state.addTokens(tokens: tokens, groupLabel: groupLabel).length;
}

/// Aggiunge una voce di bottino all'inventario della scheda aperta, dicendo
/// perche' non si puo' quando non si puo'.
void sendLootToInventory(BuildContext context, AppState state, LootEntry entry) {
  if (state.sheet == null) {
    showTechMessage(
      context,
      title: 'Nessuna scheda aperta',
      message:
          'Il bottino entra nell\'inventario di una scheda: aprine una e riprova. '
          'Senza scheda non c\'e\' un inventario in cui metterlo.',
      isError: true,
    );
    return;
  }
  final int placed = state.addLootToInventory(name: entry.name, quantity: entry.quantity, note: entry.note);
  final bool known = state.catalog.matchByName(entry.name) != null;
  showTechMessage(
    context,
    title: 'Bottino',
    message: known
        ? '${entry.short}: ${placed == 1 ? 'entrato' : 'entrati'} nell\'inventario come voce di catalogo.'
        : '${entry.short}: ${placed == 1 ? 'entrato' : 'entrati'} nell\'inventario come oggetto definito nella scheda. '
              'Il catalogo non ha una voce con questo nome.',
  );
}

// --------------------------------------------------------------------------
// Dadi e macro
// --------------------------------------------------------------------------

class _DicePanel extends StatefulWidget {
  const _DicePanel({super.key, required this.state});

  final AppState state;

  @override
  State<_DicePanel> createState() => _DicePanelState();
}

class _DicePanelState extends State<_DicePanel> {
  final math.Random _random = math.Random();
  String _expression = '1d10 + RIF + Pistole';
  ExpressionRoll? _result;
  String? _error;

  String? _newMacroName;
  String _newMacroExpression = '';

  DiceExpression get _engine => DiceExpression(
    random: _random,
    resolveName: widget.state.sheet == null
        ? null
        : sheetNameResolver(widget.state.sheet!, lookup: widget.state.catalogLookup),
  );

  void _roll(String expression) {
    try {
      final ExpressionRoll roll = _engine.evaluate(expression);
      setState(() {
        _expression = expression;
        _result = roll;
        _error = null;
      });
    } on DiceExpressionError catch (e) {
      setState(() {
        _error = e.message;
        _result = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.state;
    final bool hasSheet = state.sheet != null;
    final String? validation = DiceExpression.validate(
      _expression,
      resolveName: hasSheet ? sheetNameResolver(state.sheet!, lookup: state.catalogLookup) : (String _) => 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Le espressioni dei dadi del gioco: sigle delle caratteristiche (RIF, FIS), nomi '
              'delle abilità e la matematica che serve al tavolo. `!` fa esplodere un dado, '
              '`kh`/`kl` tengono i migliori o i peggiori.',
        ),
        if (!hasSheet)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: _Notice(
              text:
                  'Nessuna scheda aperta: le sigle e i nomi di abilità non si possono risolvere, '
                  'quindi restano validi solo i dadi e i numeri.',
              tone: Tone.info,
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TechField(
                label: 'Espressione',
                value: _expression,
                hint: '4d6kh3',
                onChanged: (String v) => setState(() => _expression = v),
              ),
            ),
            const SizedBox(width: 10),
            TechButton(label: 'Tira', icon: Icons.casino, onPressed: () => _roll(_expression)),
          ],
        ),
        if (validation != null && _expression.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(validation, style: CprType.caption.copyWith(color: CprPalette.warning)),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _Notice(text: _error!, tone: Tone.danger),
          ),
        const SizedBox(height: 16),
        if (_result != null) ...<Widget>[
          _BigNumber(value: '${_result!.total}', label: _outcomeLabel(_result!), accent: _outcomeColor(_result!)),
          const SizedBox(height: 10),
          const SizedBox(height: 2),
          _DiceBreakdown(roll: _result!),
          const SizedBox(height: 10),
          _Result(text: _rollText(_result!), accent: CprPalette.yellow, selectable: false),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TechButton(
                label: 'Al registro',
                icon: Icons.receipt_long_outlined,
                compact: true,
                tooltip: state.canRecordSession
                    ? 'Scrive il tiro nel registro della sessione'
                    : 'Apri una campagna o una scheda: senza un documento il registro non ha dove restare',
                onPressed: state.canRecordSession
                    ? () => state.recordSessionEvent(_rollText(_result!).replaceAll('\n', ' · '), delta: 'TIRO')
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 22),
        ],
        TechSection(
          title: 'Macro',
          trailing: TechButton(
            label: 'Nuova',
            icon: Icons.add,
            compact: true,
            onPressed: () => _newMacroDialog(context),
          ),
          children: <Widget>[
            if (state.gmMacros.isEmpty)
              Text(
                'Nessuna macro salvata. "Attacco con Malorian 3516: 1d10 + RIF + Pistole" è il tipo di '
                'tiro che si rifà ogni sessione, ed è quello che vale la pena salvare.',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint),
              )
            else
              for (final DiceMacro macro in state.gmMacros)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _MacroRow(
                    macro: macro,
                    onRoll: () => _roll(macro.expression),
                    onDelete: () => state.deleteGmMacro(macro.id),
                  ),
                ),
          ],
        ),
      ],
    );
  }

  String _outcomeLabel(ExpressionRoll roll) {
    final DiceOutcome? outcome = roll.singleD10Outcome;
    return switch (outcome) {
      DiceOutcome.critical => 'critico',
      DiceOutcome.fumble => 'fallimento critico',
      _ => 'totale',
    };
  }

  Color _outcomeColor(ExpressionRoll roll) {
    return switch (roll.singleD10Outcome) {
      DiceOutcome.critical => CprPalette.success,
      DiceOutcome.fumble => CprPalette.danger,
      _ => CprPalette.yellow,
    };
  }

  String _rollText(ExpressionRoll roll) {
    final StringBuffer b = StringBuffer('${roll.expression} = ${roll.total}');
    if (roll.groups.isNotEmpty) b.write('\n${roll.breakdown}');
    if (roll.resolvedNames.isNotEmpty) {
      b.write('\n${roll.resolvedNames.entries.map((MapEntry<String, int> e) => '${e.key} ${e.value}').join(', ')}');
    }
    return b.toString();
  }

  Future<void> _newMacroDialog(BuildContext context) async {
    _newMacroName = '';
    _newMacroExpression = _expression;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => StatefulBuilder(
        builder: (BuildContext ctx, StateSetter setDialogState) => AlertDialog(
          backgroundColor: CprPalette.surface,
          title: Text('NUOVA MACRO', style: CprType.label.copyWith(color: CprPalette.yellow)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TechField(
                  label: 'Nome',
                  value: _newMacroName ?? '',
                  hint: 'Attacco con Malorian 3516',
                  onChanged: (String v) => _newMacroName = v,
                ),
                const SizedBox(height: 12),
                TechField(
                  label: 'Espressione',
                  value: _newMacroExpression,
                  onChanged: (String v) => _newMacroExpression = v,
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (BuildContext ctx) {
                    final String? problem = DiceExpression.validate(_newMacroExpression, resolveName: (String _) => 0);
                    return Text(
                      problem ?? 'Si legge.',
                      style: CprType.caption.copyWith(color: problem == null ? CprPalette.success : CprPalette.warning),
                    );
                  },
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TechButton(label: 'Annulla', compact: true, onPressed: () => Navigator.of(ctx).pop(false)),
            TechButton(
              label: 'Salva',
              icon: Icons.save_outlined,
              compact: true,
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      ),
    );

    final String name = (_newMacroName ?? '').trim();
    if (ok != true || name.isEmpty) return;
    if (!mounted) return;
    await widget.state.saveGmMacro(
      DiceMacro(
        id: 'macro_${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        expression: _newMacroExpression.trim(),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({required this.macro, required this.onRoll, required this.onDelete});

  final DiceMacro macro;
  final VoidCallback onRoll;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(macro.name, style: CprType.body),
                Text(macro.expression, style: CprType.mono(CprPalette.inkMuted, size: 12)),
              ],
            ),
          ),
          TechButton(label: 'Tira', icon: Icons.casino_outlined, compact: true, onPressed: onRoll),
          const SizedBox(width: 6),
          TechButton(
            label: '',
            icon: Icons.delete_outline,
            compact: true,
            tooltip: 'Elimina la macro',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Come e' uscito il tiro, dado per dado.
class _DiceBreakdown extends StatelessWidget {
  const _DiceBreakdown({required this.roll});

  final ExpressionRoll roll;

  @override
  Widget build(BuildContext context) {
    if (roll.groups.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        for (final RolledDiceGroup group in roll.groups)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CprPalette.surfaceSunken,
              border: Border.all(color: CprPalette.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(group.label, style: CprType.label.copyWith(color: CprPalette.yellow)),
                const SizedBox(width: 8),
                for (final int face in group.results)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '$face',
                      style: CprType.numeralSmall.copyWith(
                        // Il dieci si vede: su un d10 e' il critico, e su una
                        // riga di numeri uguali e' l'unico che conta.
                        color: face == group.faces ? CprPalette.success : CprPalette.ink,
                        fontWeight: face == group.faces ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                if (group.kept < group.results.length)
                  Text('→ ${group.sum}', style: CprType.caption.copyWith(color: CprPalette.cyan)),
              ],
            ),
          ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Trasporti in tempo reale
// --------------------------------------------------------------------------

/// Il pannello che mette un veicolo in strada e lo tiene d'occhio.
///
/// La scelta di progetto che si vede subito: **la rotta si compone dalle
/// fermate**, prendendole dai waypoint che sono gia' sulla mappa. Non c'e' un
/// grafo stradale dentro quest'applicazione — la geometria di Night City e'
/// quattro assi di scorrimento e dei poligoni di distretto, non una rete
/// percorribile — e inventarne uno per far sembrare il percorso "vero" sarebbe
/// la stessa bugia dei numeri senza provenienza, applicata alla geografia. La
/// rotta e' quello che il Master direbbe a voce: "prima all'Afterlife, poi a
/// Corpo Plaza, poi a casa", e le distanze le calcola la scala dichiarata, con
/// l'allungamento delle strade dichiarato accanto.
///
/// La seconda: **gli eventi si scatenano, non si tirano da soli**. Un agguato
/// non e' un evento casuale della strada, e' una decisione narrativa: l'app
/// mette i pulsanti e dice cosa comporta ognuno, e il Master decide quando.
class _TransportPanel extends StatefulWidget {
  const _TransportPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_TransportPanel> createState() => _TransportPanelState();
}

class _TransportPanelState extends State<_TransportPanel> {
  TransportMode _mode = TransportMode.taxi;
  double? _speed;
  String _name = '';

  /// Le fermate, in ordine: l'identificativo del waypoint.
  final List<String> _route = <String>[];
  final Set<String> _aboard = <String>{};
  String? _selectedId;

  List<RouteStop> _stops() => <RouteStop>[
    for (final String id in _route)
      for (final MapWaypoint w in widget.state.mapWaypoints)
        if (w.id == id) RouteStop(w.label, w.position),
  ];

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.state;
    final double span = state.gmRuleBook.rule(GmRules.transportMapSpan).value;
    final double speed = _speed ?? _mode.cruiseKmh;
    final List<RouteStop> stops = _stops();
    final double meters = routeLengthMeters(stops, span);
    final Transport? selected = _selectedId == null
        ? null
        : state.mapTransports.where((Transport t) => t.id == _selectedId).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Il veicolo si muove da solo, sul tempo reale moltiplicato: la velocita\' mostrata e\' '
              'quella vera, e\' l\'orologio a correre. La scala e il moltiplicatore si correggono da '
              '"Numeri e regole" e valgono per tutta la campagna.',
          confidence: GmConfidence.proposta,
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 210,
              child: TechDropdown<TransportMode>(
                label: 'Mezzo',
                value: _mode,
                items: TransportMode.values,
                labelOf: (TransportMode m) => '${m.label} (${m.cruiseKmh.round()} km/h)',
                onChanged: (TransportMode m) => setState(() {
                  _mode = m;
                  _speed = null;
                }),
              ),
            ),
            SizedBox(
              width: 150,
              child: TechNumberStepper(
                label: 'Velocità km/h',
                value: speed.round(),
                min: 1,
                max: 600,
                onChanged: (int v) => setState(() => _speed = v.toDouble()),
              ),
            ),
            SizedBox(
              width: 220,
              child: TechField(
                label: 'Nome',
                value: _name,
                hint: 'Taxi di Jig-Jig',
                onChanged: (String v) => setState(() => _name = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TechSection(
          title: 'Percorso',
          trailing: Text(
            stops.length < 2
                ? 'servono due fermate'
                : '${meters.round()} m · ${_minutes(meters, speed)} a questa velocita\'',
            style: CprType.caption.copyWith(color: CprPalette.inkFaint),
          ),
          children: <Widget>[
            if (state.mapWaypoints.isEmpty)
              Text(
                'Nessun waypoint sulla mappa: le fermate di un percorso sono i segni che hai gia\' '
                'messo. Aggiungine due dalla sezione Mappa e tornare qui.',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final MapWaypoint w in state.mapWaypoints)
                    TechButton(
                      // Il numero e' l'ordine di passaggio: e' la cosa che serve
                      // sapere quando la rotta ha cinque fermate.
                      label: '${_route.indexOf(w.id) + 1 > 0 ? '${_route.indexOf(w.id) + 1}. ' : ''}${w.label}',
                      icon: _route.contains(w.id) ? Icons.check_circle : Icons.add_circle_outline,
                      compact: true,
                      tooltip: _route.contains(w.id)
                          ? 'Toglila dal percorso'
                          : 'Aggiungila come prossima fermata',
                      onPressed: () => setState(() {
                        if (!_route.remove(w.id)) _route.add(w.id);
                      }),
                    ),
                ],
              ),
            if (_route.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                stops.map((RouteStop s) => s.name).join(' → '),
                style: CprType.caption.copyWith(color: CprPalette.cyan),
              ),
              const SizedBox(height: 6),
              TechButton(
                label: 'Svuota percorso',
                icon: Icons.clear_all,
                compact: true,
                onPressed: () => setState(_route.clear),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        TechSection(
          title: 'A bordo',
          trailing: Text('su ${state.mapTokens.length} token', style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
          children: <Widget>[
            if (state.mapTokens.isEmpty)
              Text(
                'Nessun token sulla mappa. Un personaggio che prende un taxi deve prima esistere sulla '
                'mappa: il suo token viaggia con il mezzo.',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final MapToken t in state.mapTokens)
                    TechButton(
                      label: t.name,
                      icon: _aboard.contains(t.id) ? Icons.airline_seat_recline_normal : Icons.person_add_alt,
                      compact: true,
                      tooltip: _aboard.contains(t.id) ? 'Fallo scendere' : 'Fallo salire: viaggerà con il mezzo',
                      onPressed: () => setState(() {
                        if (!_aboard.remove(t.id)) _aboard.add(t.id);
                      }),
                    ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        TechButton(
          label: 'Metti in strada',
          icon: Icons.play_arrow,
          expand: true,
          tooltip: stops.length < 2
              ? 'Serve un percorso con almeno due fermate'
              : 'Il veicolo parte subito dalla prima fermata',
          onPressed: stops.length < 2 ? null : () => _depart(stops, speed),
        ),
        const SizedBox(height: 22),
        TechSection(
          title: 'In strada',
          trailing: Text('${state.mapTransports.length}', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
          children: <Widget>[
            if (state.mapTransports.isEmpty)
              Text('Nessun mezzo in strada.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
            else ...<Widget>[
              for (final Transport t in state.mapTransports)
                _VehicleStrip(
                  transport: t,
                  selected: t.id == _selectedId,
                  span: span,
                  timeScale: state.gmRuleBook.rule(GmRules.transportTimeScale).value,
                  onSelect: () => setState(() => _selectedId = t.id),
                  onHalt: () => state.haltTransport(t.id),
                  onResume: () => state.resumeTransport(t.id),
                  onDelete: () => setState(() {
                    state.removeTransport(t.id);
                    if (_selectedId == t.id) _selectedId = null;
                  }),
                ),
            ],
          ],
        ),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 16),
          TechSection(
            title: 'Scatena su ${selected.name}',
            children: <Widget>[
              Text(
                'Ogni evento dice cosa comporta: quanto dura, cosa resta dopo, e la prova che il tavolo '
                'deve superare. Le durate sono proposte di questa applicazione.',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final TransportIncident i in TransportIncidents.all)
                    TechButton(
                      label: i.title,
                      icon: _incidentIcon(i),
                      compact: true,
                      tooltip: _incidentTooltip(i),
                      onPressed:
                          selected.status == TransportStatus.arrivato ? null : () => _trigger(context, selected, i),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _depart(List<RouteStop> stops, double speed) {
    final AppState state = widget.state;
    final List<String> names = <String>[
      for (final MapToken t in state.mapTokens)
        if (_aboard.contains(t.id)) t.name,
    ];
    final Transport t = state.startTransport(
      name: _name.trim().isEmpty ? '${_mode.label} senza nome' : _name.trim(),
      mode: _mode,
      stops: stops,
      speedKmh: speed,
      passengers: names,
      passengerTokenIds: _aboard.toList(),
    );
    setState(() {
      _selectedId = t.id;
      _route.clear();
      _aboard.clear();
      _name = '';
    });
  }

  void _trigger(BuildContext context, Transport transport, TransportIncident incident) {
    widget.state.triggerTransportIncident(transport.id, incident);
    final String hold = incident.holdUntilReleased
        ? 'resta fermo finché non lo rilasci'
        : 'riparte da solo fra ${incident.haltSeconds} secondi';
    showTechMessage(
      context,
      title: incident.title,
      message: '${incident.description}\n\nIl veicolo $hold.'
          '${incident.check == null ? '' : '\n\nProva di ${incident.check!.name} DV ${incident.checkDv}. ${incident.checkStake}'}',
    );
  }

  String _minutes(double meters, double kmh) {
    if (kmh <= 0) return '—';
    final double seconds = meters / (kmh * 1000 / 3600);
    if (seconds < 90) return '${seconds.round()} s di strada';
    return '${(seconds / 60).round()} min di strada';
  }

  IconData _incidentIcon(TransportIncident i) => switch (i.id) {
    'agguato' => Icons.gps_fixed,
    'incidente' => Icons.car_crash_outlined,
    'guasto' => Icons.build_outlined,
    'fermo-polizia' => Icons.local_police_outlined,
    'posto-di-blocco' => Icons.block_outlined,
    'deviazione' => Icons.alt_route_outlined,
    'ingorgo' => Icons.traffic_outlined,
    _ => Icons.pan_tool_alt_outlined,
  };

  String _incidentTooltip(TransportIncident i) => <String>[
    if (i.holdUntilReleased) 'finché non lo rilasci' else '${i.haltSeconds} s',
    if (i.speedFactor != 1) 'poi al ${(i.speedFactor * 100).round()}% della velocità',
    if (i.check != null) 'prova di ${i.check!.name} DV ${i.checkDv}',
  ].join(' · ');
}

/// Un veicolo nella lista della console: i numeri che servono a decidere.
class _VehicleStrip extends StatelessWidget {
  const _VehicleStrip({
    required this.transport,
    required this.selected,
    required this.span,
    required this.timeScale,
    required this.onSelect,
    required this.onHalt,
    required this.onResume,
    required this.onDelete,
  });

  final Transport transport;
  final bool selected;
  final double span;
  final double timeScale;
  final VoidCallback onSelect;
  final VoidCallback onHalt;
  final VoidCallback onResume;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final Duration? eta = transport.eta(span, timeScale: timeScale);
    final Color accent = transport.status == TransportStatus.fermo
        ? CprPalette.healthFlatline
        : (transport.status == TransportStatus.arrivato ? CprPalette.inkMuted : CprPalette.info);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(accent, 0.10) : CprPalette.surfaceSunken,
            border: Border.all(color: selected ? CprPalette.veil(accent, 0.6) : CprPalette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(transport.status == TransportStatus.fermo ? Icons.report_gmailerrorred_outlined : Icons.local_taxi_outlined,
                      size: 13, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transport.name,
                      overflow: TextOverflow.ellipsis,
                      style: CprType.body.copyWith(fontWeight: FontWeight.w600, fontSize: 12.5),
                    ),
                  ),
                  Text(
                    eta == null ? '—' : '${eta.inSeconds} s',
                    style: CprType.numeral.copyWith(fontSize: 12, color: accent),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${transport.routeLine}\n${transport.statLine}',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  if (transport.status == TransportStatus.fermo)
                    TechButton(label: 'Rilascia', icon: Icons.play_arrow, compact: true, onPressed: onResume)
                  else if (transport.status == TransportStatus.inViaggio)
                    TechButton(label: 'Ferma', icon: Icons.pause, compact: true, onPressed: onHalt),
                  TechButton(label: 'Togli', icon: Icons.close, compact: true, onPressed: onDelete),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Incontro notturno
// --------------------------------------------------------------------------

class _EncounterPanel extends StatefulWidget {
  const _EncounterPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_EncounterPanel> createState() => _EncounterPanelState();
}

class _EncounterPanelState extends State<_EncounterPanel> {
  final math.Random _random = math.Random();
  int _players = 4;
  NightEncounter? _encounter;

  void _generate() => setState(() {
    _encounter = NightEncounterGenerator.generate(_random, playerCount: _players);
  });

  @override
  Widget build(BuildContext context) {
    final NightEncounter? e = _encounter;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Composizione e agganci sono scritti da questa applicazione: il manuale definisce le gang, '
              'non chi passa in quel vicolo stanotte.',
          confidence: NightEncounterGenerator.table.confidence,
        ),
        // `Wrap` e non `Row`: nel pannello da quattrocento pixel il selettore
        // piu' i due pulsanti non stanno su una riga sola, e `Row` li taglia
        // fuori dallo schermo invece di mandarli a capo. Il pulsante che manda
        // la banda sulla mappa era il primo a sparire.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: <Widget>[
            // `TechNumberStepper` contiene un `Expanded`: fuori da una larghezza
            // definita non ha niente da riempire e la riga va in errore. Per
            // questo nel progetto compare sempre dentro un `Expanded` o un
            // `SizedBox`.
            SizedBox(
              width: 220,
              child: TechNumberStepper(
                label: 'Giocatori al tavolo',
                value: _players,
                min: 1,
                max: 10,
                onChanged: (int v) => setState(() => _players = v),
              ),
            ),
            TechButton(label: 'Genera incontro', icon: Icons.nightlight, onPressed: _generate),
            if ((_encounter?.enemies.isNotEmpty ?? false))
              TechButton(
                label: 'Manda al tavolo',
                icon: Icons.person_add_alt,
                compact: true,
                tooltip: widget.state.tokensArePersisted
                    ? 'Crea un token sulla mappa per ogni nemico, con i suoi Punti Vita'
                    : 'Senza una campagna aperta i token non vengono salvati: apri il tavolo prima',
                onPressed: () => _sendToTable(context),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (e == null)
          Text('Nessun incontro generato.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
        else ...<Widget>[
          _BigNumber(value: e.threat.label.toUpperCase(), label: 'minaccia', accent: _threatColor(e.threat)),
          const SizedBox(height: 6),
          Text(
            '${e.title} · ${e.enemies.length} nemici · uscito ${e.roll.index} su ${e.roll.total} (${e.roll.percentage})',
            style: CprType.caption.copyWith(color: CprPalette.inkMuted),
          ),
          const SizedBox(height: 14),
          if (e.enemies.isNotEmpty) ...<Widget>[
            for (final Mook m in e.enemies)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _MookCard(mook: m),
              ),
            const SizedBox(height: 10),
          ],
          _Result(text: e.briefing, accent: CprPalette.magenta),
        ],
      ],
    );
  }

  void _sendToTable(BuildContext context) {
    final NightEncounter? e = _encounter;
    if (e == null || e.enemies.isEmpty) return;
    final int placed = sendBandToTable(widget.state, e.enemies, groupLabel: e.title);
    showTechMessage(
      context,
      title: 'Sulla mappa',
      message: placed == 1
          ? 'Un token sulla mappa. Aprilo sulla mappa per ferirlo: i Punti Vita che vedi sono quelli del PNG rapido.'
          : '$placed token sulla mappa. Sono un gruppo: a fine scontro si tolgono tutti insieme dalla lista dei token.',
    );
  }

  Color _threatColor(EncounterThreat threat) => switch (threat) {
    EncounterThreat.bassa => CprPalette.success,
    EncounterThreat.media => CprPalette.warning,
    EncounterThreat.alta => CprPalette.danger,
    EncounterThreat.letale => CprPalette.healthFlatline,
  };
}

// --------------------------------------------------------------------------
// Bottino
// --------------------------------------------------------------------------

class _LootPanel extends StatefulWidget {
  const _LootPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_LootPanel> createState() => _LootPanelState();
}

class _LootPanelState extends State<_LootPanel> {
  final math.Random _random = math.Random();
  MookTier _tier = MookTier.scagnozzo;
  int _count = 3;
  LootBundle? _loot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Quello che un nemico porta addosso. Il manuale non lo stabilisce: è una proposta di '
              'questa applicazione, e le quantità seguono la taglia dell\'avversario.',
          confidence: LootGenerator.table.confidence,
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 210,
              child: TechDropdown<MookTier>(
                label: 'Chi è caduto',
                value: _tier,
                items: MookTier.values,
                labelOf: (MookTier t) => t.label,
                onChanged: (MookTier t) => setState(() => _tier = t),
              ),
            ),
            SizedBox(
              width: 150,
              child: TechNumberStepper(
                label: 'Quanti',
                value: _count,
                min: 1,
                max: 12,
                onChanged: (int v) => setState(() => _count = v),
              ),
            ),
            TechButton(
              label: 'Racogli',
              icon: Icons.inventory_2_outlined,
              onPressed: () => setState(() {
                _loot = LootGenerator.band(MookGenerator.band(_tier, _count, _random), _random);
              }),
            ),
            TechButton(
              label: 'Generatore Loot (Base/IA/Manuale)',
              icon: Icons.auto_awesome,
              variant: TechButtonVariant.primary,
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => EnemyLootDialog(
                    initialEnemyName: _tier.label,
                    onApply: (String compiled) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Bottino configurato:\n$compiled'),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loot == null)
          Text('Nessun bottino raccolto.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
        else ...<Widget>[
          _BigNumber(value: '${_loot!.eurodollars}', label: 'eurodollari', accent: CprPalette.yellow),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final LootEntry entry in _loot!.entries)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: CprPalette.surfaceSunken,
                    border: Border.all(color: CprPalette.hairline),
                  ),
                  // La nota sta **sotto** il nome, non accanto. Accanto,
                  // nome e nota su una riga sola sfondavano la larghezza del
                  // pannello: le note sono frasi ("contatti, codici di accesso
                  // o un registro di pagamenti") e una frase non sta in uno
                  // spazio pensato per un nome. Sotto, va a capo e si legge.
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(_lootIcon(entry.kind), size: 12, color: CprPalette.cyan),
                          const SizedBox(width: 6),
                          Flexible(child: Text(entry.short, style: CprType.caption)),
                        ],
                      ),
                      if (entry.note.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 3),
                        Text(entry.note, style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              TechButton(
                label: 'Contanti al portafoglio',
                icon: Icons.payments_outlined,
                compact: true,
                tooltip: 'Aggiunge ${_loot!.eurodollars} eb alla scheda aperta',
                onPressed: () => _cash(context),
              ),
              for (final LootEntry entry in _loot!.entries)
                TechButton(
                  label: entry.short,
                  icon: Icons.add,
                  compact: true,
                  tooltip: 'Aggiungi all\'inventario della scheda aperta',
                  onPressed: () => sendLootToInventory(context, widget.state, entry),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Result(text: _loot!.chatBlock, accent: CprPalette.yellow),
        ],
      ],
    );
  }

  void _cash(BuildContext context) {
    final LootBundle? loot = _loot;
    if (loot == null) return;
    if (!widget.state.addEurobucks(loot.eurodollars, reason: 'Bottino')) {
      showTechMessage(
        context,
        title: 'Nessuna scheda aperta',
        message: 'Gli eurodollari vanno sul conto di un personaggio: apri una scheda e riprova.',
        isError: true,
      );
      return;
    }
    showTechMessage(
      context,
      title: 'Contanti',
      message: '${loot.eurodollars} eb sul conto della scheda aperta, con la causale nel registro di sessione.',
    );
  }

  IconData _lootIcon(LootKind kind) => switch (kind) {
    LootKind.denaro => Icons.payments_outlined,
    LootKind.chip => Icons.memory,
    LootKind.munizioni => Icons.bolt_outlined,
    LootKind.droga => Icons.science_outlined,
    LootKind.arma => Icons.gps_fixed,
    LootKind.equipaggiamento => Icons.build_outlined,
    LootKind.cyberware => Icons.settings_input_component_outlined,
    LootKind.oggetto => Icons.category_outlined,
  };
}

// --------------------------------------------------------------------------
// Screamsheet
// --------------------------------------------------------------------------

class _ScreamsheetPanel extends StatefulWidget {
  const _ScreamsheetPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_ScreamsheetPanel> createState() => _ScreamsheetPanelState();
}

class _ScreamsheetPanelState extends State<_ScreamsheetPanel> {
  final math.Random _random = math.Random();
  Screamsheet? _sheet;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Un pezzo di giornale da leggere ad alta voce prima della sessione. Titoli, firme e '
              'brevi sono composti da questa applicazione, e ogni tiro dà un pezzo diverso.',
          confidence: GmConfidence.proposta,
        ),
        TechButton(
          label: 'Nuova edizione',
          icon: Icons.newspaper,
          onPressed: () => setState(() => _sheet = ScreamsheetGenerator.generate(_random)),
        ),
        const SizedBox(height: 16),
        if (_sheet == null)
          Text('Nessuna edizione.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
        else ...<Widget>[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: CprPalette.surfaceSunken,
              border: Border.all(color: CprPalette.hairlineBright, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(_sheet!.section.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.yellow)),
                    const Spacer(),
                    Text(_sheet!.dateLine, style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(_sheet!.headline, style: CprType.display.copyWith(fontSize: 26, height: 1.15, letterSpacing: 0.4)),
                const SizedBox(height: 10),
                Container(height: 2, color: CprPalette.hairlineBright),
                const SizedBox(height: 10),
                Text(
                  _sheet!.standfirst,
                  style: CprType.title.copyWith(fontSize: 15, color: CprPalette.inkMuted, height: 1.4),
                ),
                const SizedBox(height: 14),
                Text(_sheet!.body, style: CprType.body.copyWith(height: 1.6)),
                const SizedBox(height: 12),
                Text('— ${_sheet!.byline}', style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
                if (_sheet!.ticker.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text('IN BREVE', style: CprType.label.copyWith(color: CprPalette.magenta)),
                  const SizedBox(height: 6),
                  for (final String t in _sheet!.ticker)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $t', style: CprType.caption),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Result(text: _sheet!.plainText, accent: CprPalette.cyan),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------
// PNG rapidi
// --------------------------------------------------------------------------

class _MookPanel extends StatefulWidget {
  const _MookPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_MookPanel> createState() => _MookPanelState();
}

class _MookPanelState extends State<_MookPanel> {
  final math.Random _random = math.Random();
  MookTier _tier = MookTier.professionista;
  int _count = 4;
  List<Mook> _band = <Mook>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Tre numeri per nemico invece di una scheda intera: combattimento, difesa, PV e armatura. '
              'La forma è quella che serve quando i giocatori stanno aspettando.',
          confidence: GmConfidence.proposta,
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 12,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 210,
              child: TechDropdown<MookTier>(
                label: 'Livello',
                value: _tier,
                items: MookTier.values,
                labelOf: (MookTier t) => t.label,
                onChanged: (MookTier t) => setState(() => _tier = t),
              ),
            ),
            SizedBox(
              width: 150,
              child: TechNumberStepper(
                label: 'Quanti',
                value: _count,
                min: 1,
                max: 12,
                onChanged: (int v) => setState(() => _count = v),
              ),
            ),
            TechButton(
              label: 'Genera',
              icon: Icons.groups_outlined,
              onPressed: () => setState(() => _band = MookGenerator.band(_tier, _count, _random)),
            ),
            if (_band.isNotEmpty)
              TechButton(
                label: 'Manda al tavolo',
                icon: Icons.person_add_alt,
                compact: true,
                tooltip: widget.state.tokensArePersisted
                    ? 'Crea un token sulla mappa per ogni PNG'
                    : 'Senza una campagna aperta i token non vengono salvati',
                onPressed: () =>
                    setState(() => sendBandToTable(widget.state, _band, groupLabel: 'PNG rapidi (${_tier.label})')),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_band.isEmpty)
          Text('Nessun PNG generato.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
        else
          for (final Mook m in _band)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _MookCard(mook: m, showShtick: true),
            ),
      ],
    );
  }
}

class _MookCard extends StatelessWidget {
  const _MookCard({required this.mook, this.showShtick = false});

  final Mook mook;
  final bool showShtick;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border(left: BorderSide(color: CprPalette.danger, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(mook.name, style: CprType.body.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Text(mook.tier.label.toUpperCase(), style: CprType.label.copyWith(fontSize: 9, color: CprPalette.danger)),
            ],
          ),
          const SizedBox(height: 4),
          Text(mook.statLine, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
          Text('${mook.weapon} — ${mook.damage}', style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
          if (showShtick) ...<Widget>[
            const SizedBox(height: 4),
            Text(mook.shtick, style: CprType.caption.copyWith(color: CprPalette.cyan, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// DV balistico
// --------------------------------------------------------------------------

class _BallisticsPanel extends StatefulWidget {
  const _BallisticsPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_BallisticsPanel> createState() => _BallisticsPanelState();
}

class _BallisticsPanelState extends State<_BallisticsPanel> {
  WeaponClass _weapon = WeaponClass.pistola;
  double _meters = 10.0;
  bool _aimed = false;
  bool _cover = false;
  bool _moving = false;

  static const List<double> _presetDistances = <double>[3, 6, 10, 15, 25, 35, 50, 75, 100, 150];

  void _selectBand(RangeBand band) {
    // Imposta la distanza al punto medio logico della fascia
    final double mid = band.minMeters == 0
        ? band.maxMeters / 2
        : (band.minMeters + band.maxMeters) / 2;
    setState(() => _meters = mid);
  }

  @override
  Widget build(BuildContext context) {
    final BallisticSolution solution = Ballistics.solve(
      weapon: _weapon,
      meters: _meters,
      aimedShot: _aimed,
      targetInCover: _cover,
      movingTarget: _moving,
      rules: widget.state.gmRuleBook,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Il DV dipende dalla fascia di distanza balistica. Puoi cliccare direttamente '
              'sulle caselle delle fasce o usare i preset di metri reali per calcolare istantaneamente il tiro.',
          confidence: GmConfidence.daVerificare,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            SizedBox(
              width: 230,
              child: TechDropdown<WeaponClass>(
                label: 'Classe d\'arma',
                value: _weapon,
                items: WeaponClass.values,
                labelOf: (WeaponClass w) => w.label,
                onChanged: (WeaponClass w) => setState(() => _weapon = w),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 130,
              child: TechField(
                label: 'Distanza reale (m)',
                value: _meters.toStringAsFixed(_meters.truncateToDouble() == _meters ? 0 : 1),
                numeric: true,
                onChanged: (String v) {
                  final double? parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed != null && parsed >= 0) {
                    setState(() => _meters = parsed);
                  }
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Selettore e Slider Distanza Reale in Metri
        Row(
          children: <Widget>[
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: CprPalette.yellow,
                  inactiveTrackColor: CprPalette.veil(CprPalette.yellow, 0.2),
                  thumbColor: CprPalette.yellow,
                  overlayColor: CprPalette.veil(CprPalette.yellow, 0.2),
                  trackHeight: 3,
                ),
                child: Slider(
                  min: 0,
                  max: 200,
                  value: _meters.clamp(0, 200),
                  onChanged: (double val) => setState(() => _meters = val.roundToDouble()),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_meters.toStringAsFixed(0)} m',
              style: CprType.label.copyWith(color: CprPalette.yellow, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: <Widget>[
            for (final double d in _presetDistances)
              InkWell(
                onTap: () => setState(() => _meters = d),
                borderRadius: BorderRadius.circular(3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_meters - d).abs() < 0.5
                        ? CprPalette.veil(CprPalette.yellow, 0.22)
                        : CprPalette.surfaceSunken,
                    border: Border.all(
                      color: (_meters - d).abs() < 0.5 ? CprPalette.yellow : CprPalette.hairline,
                    ),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${d.toStringAsFixed(0)} m',
                    style: CprType.caption.copyWith(
                      fontSize: 11,
                      fontWeight: (_meters - d).abs() < 0.5 ? FontWeight.bold : FontWeight.normal,
                      color: (_meters - d).abs() < 0.5 ? CprPalette.yellow : CprPalette.inkMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          children: <Widget>[
            _Toggle(label: 'Tiro mirato (-8 al tiro)', value: _aimed, onChanged: (bool v) => setState(() => _aimed = v)),
            _Toggle(label: 'Bersaglio in copertura', value: _cover, onChanged: (bool v) => setState(() => _cover = v)),
            _Toggle(
              label: 'Bersaglio in movimento',
              value: _moving,
              onChanged: (bool v) => setState(() => _moving = v),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (!solution.inRange)
          _Notice(
            text:
                'A ${solution.distanceMeters.toStringAsFixed(0)} m non c\'è nessuna fascia: oltre la gittata massima il tiro non si può fare.',
            tone: Tone.danger,
          )
        else ...<Widget>[
          _BigNumber(
            value: '${solution.finalDv}',
            label: 'DV da battere',
            accent: solution.modifier == 0 ? CprPalette.yellow : CprPalette.warning,
          ),
          const SizedBox(height: 8),
          Text(solution.summary, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
          const SizedBox(height: 12),
          for (final String note in solution.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $note', style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
            ),
          const SizedBox(height: 16),
          TechSection(
            title: '${_weapon.label}: tutte le fasce (clicca per selezionare)',
            children: <Widget>[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final RangeBand band in RangeBand.values)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _selectBand(band),
                        borderRadius: BorderRadius.circular(3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: band == solution.band
                                ? CprPalette.veil(CprPalette.yellow, 0.20)
                                : CprPalette.surfaceSunken,
                            border: Border.all(
                              color: band == solution.band ? CprPalette.yellow : CprPalette.hairline,
                              width: band == solution.band ? 1.5 : 1,
                            ),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Column(
                            children: <Widget>[
                              Text(
                                band.label,
                                style: CprType.caption.copyWith(
                                  fontSize: 10,
                                  fontWeight: band == solution.band ? FontWeight.bold : FontWeight.normal,
                                  color: band == solution.band ? CprPalette.yellow : CprPalette.inkFaint,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${Ballistics.dvAtBand(_weapon, band, rules: widget.state.gmRuleBook)}',
                                style: CprType.numeralSmall.copyWith(
                                  color: band == solution.band ? CprPalette.yellow : CprPalette.ink,
                                  fontWeight: band == solution.band ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.value, required this.onChanged});

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 34,
              height: 18,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: value ? CprPalette.veil(CprPalette.yellow, 0.25) : CprPalette.surfaceSunken,
                border: Border.all(color: value ? CprPalette.yellow : CprPalette.hairlineBright),
              ),
              child: AnimatedAlign(
                duration: CprMotion.hover,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(width: 12, color: value ? CprPalette.yellow : CprPalette.inkFaint),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: CprType.caption),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Cyberpsicosi e terapia
// --------------------------------------------------------------------------

class _TherapyPanel extends StatefulWidget {
  const _TherapyPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_TherapyPanel> createState() => _TherapyPanelState();
}

class _TherapyPanelState extends State<_TherapyPanel> {
  String _empathy = '8';
  String _lost = '30';
  String _implants = '3';
  TherapyProgram _program = TherapyProgram.standard;

  @override
  Widget build(BuildContext context) {
    final GmRuleBook rules = widget.state.gmRuleBook;
    final int empathy = int.tryParse(_empathy) ?? 0;
    final int lost = int.tryParse(_lost) ?? 0;
    final int implants = int.tryParse(_implants) ?? 0;
    final HumanityReport report = Cyberpsychosis.report(
      empathyAtCreation: empathy,
      currentEmpathy: empathy,
      humanityLost: lost,
      implantCount: implants,
    );
    final TherapyPlan plan = Cyberpsychosis.plan(report: report, program: _program, rules: rules);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'L\'Umanità è la risorsa che il cyberware consuma e che solo la terapia restituisce. '
              'Qui si vede quanto manca, quanto costa tornare indietro e in quante settimane.',
          confidence: GmConfidence.daVerificare,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.state.isTherapyEnabled ? CprPalette.surfaceSunken : CprPalette.veil(CprPalette.healthFlatline, 0.12),
            border: Border.all(color: widget.state.isTherapyEnabled ? CprPalette.hairline : CprPalette.healthFlatline),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                widget.state.isTherapyEnabled ? Icons.check_circle_outline : Icons.block,
                size: 16,
                color: widget.state.isTherapyEnabled ? CprPalette.success : CprPalette.healthFlatline,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.state.isTherapyEnabled ? 'Terapia Umanità: ABILITATA' : 'Terapia Umanità: DISATTIVATA DAL MASTER',
                  style: CprType.caption.copyWith(
                    color: widget.state.isTherapyEnabled ? CprPalette.success : CprPalette.healthFlatline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TechButton(
                label: widget.state.isTherapyEnabled ? 'Disattiva' : 'Abilita',
                icon: widget.state.isTherapyEnabled ? Icons.power_settings_new : Icons.play_arrow,
                compact: true,
                variant: widget.state.isTherapyEnabled ? TechButtonVariant.danger : TechButtonVariant.primary,
                onPressed: () async {
                  await widget.state.setTherapyEnabled(!widget.state.isTherapyEnabled);
                  setState(() {});
                },
              ),
            ],
          ),
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TechField(
                label: 'EMP alla creazione',
                value: _empathy,
                numeric: true,
                onChanged: (String v) => setState(() => _empathy = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TechField(
                label: 'Umanità persa',
                value: _lost,
                numeric: true,
                onChanged: (String v) => setState(() => _lost = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TechField(
                label: 'Impianti installati',
                value: _implants,
                numeric: true,
                onChanged: (String v) => setState(() => _implants = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Text(
                  '${report.current}',
                  style: CprType.numeral.copyWith(fontSize: 40, color: _statusColor(report.status)),
                ),
                const SizedBox(width: 6),
                Text('/ ${report.maxHumanity}', style: CprType.title.copyWith(color: CprPalette.inkMuted)),
              ],
            ),
            _StatusChip(status: report.status),
          ],
        ),
        const SizedBox(height: 8),
        Text(report.status.explanation, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
        const SizedBox(height: 12),
        // Se il soggetto è cyberpsicopatico: avviso che è irreversibile / morto
        if (report.status == HumanityStatus.cyberpsicosi)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CprPalette.veil(CprPalette.healthFlatline, 0.18),
              border: Border.all(color: CprPalette.healthFlatline, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.dangerous, color: CprPalette.healthFlatline, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'SOGGETTO CYBERPSICOPATICO (DA CONSIDERARE MORTO / PERSO)',
                        style: CprType.title.copyWith(fontSize: 13, color: CprPalette.healthFlatline, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Empatia azzerata e Umanità inferiore a 10. Il personaggio ha superato il punto di non ritorno: '
                        'non ci sono terapie standard per curarlo (solo trattamenti estremi/sperimentali corporativi o Max-Tac). '
                        'Il personaggio cessa di essere un PG ed è da considerare perso/morto: diventa un PNG ostile in mano al Master.',
                        style: CprType.body.copyWith(fontSize: 11.5, color: CprPalette.ink),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // Tabella soglie Umanità da manuale Cyberpunk RED
        TechSection(
          title: 'Soglie Umanità & Sintomi (Manuale Ufficiale Cyberpunk RED)',
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                border: Border.all(color: CprPalette.hairline),
              ),
              child: Column(
                children: <Widget>[
                  _ThresholdRow(
                    range: '> 40 UMA',
                    state: 'Stabile',
                    color: CprPalette.humanityIntact,
                    desc: 'Nessun sintomo evidente. Il sistema nervoso tollera bene il cyberware.',
                    isCurrent: report.current > 40,
                  ),
                  const Divider(height: 1),
                  _ThresholdRow(
                    range: '≤ 40 UMA',
                    state: 'In erosione',
                    color: CprPalette.warning,
                    desc: 'Inizio decadimento sistema nervoso e dissociazione. Necessari immunosoppressori per rallentare il degrado neuronale.',
                    isCurrent: report.current <= 40 && report.current > 20,
                  ),
                  const Divider(height: 1),
                  _ThresholdRow(
                    range: '≤ 20 UMA (≥ 10)',
                    state: 'Al limite',
                    color: CprPalette.danger,
                    desc: 'Dissociazione acuta e sbalzi violenti. Con Umanità ≥ 10 NON si è ancora cyberpsicopatici conclamati.',
                    isCurrent: report.current <= 20 && report.current >= 10,
                  ),
                  const Divider(height: 1),
                  _ThresholdRow(
                    range: '< 10 UMA (EMP 0)',
                    state: 'CYBERPSICOSI',
                    color: CprPalette.healthFlatline,
                    desc: 'Cyberpsicopatico irreversibile. Nessuna cura convenzionale. Il PG è perso / morto e diventa PNG del GM.',
                    isCurrent: report.status == HumanityStatus.cyberpsicosi,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TechSection(
          title: 'Terapia',
          children: <Widget>[
            TechSegmented<TherapyProgram>(
              value: _program,
              items: TherapyProgram.values,
              labelOf: (TherapyProgram p) => p.label,
              onChanged: (TherapyProgram p) => setState(() => _program = p),
            ),
            const SizedBox(height: 14),
            if (report.status == HumanityStatus.cyberpsicosi)
              _Notice(
                text: 'La terapia ordinaria non ha effetto su un soggetto cyberpsicopatico conclamato. '
                    'Esistono solo cure sperimentali corporative estreme con asportazione forzata di ogni impianto e lobotomizzazione parziale.',
                tone: Tone.danger,
              )
            else if (plan.weeks == 0)
              Text('Nessuna terapia pianificata.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
            else ...<Widget>[
              Text(plan.summary, style: CprType.title.copyWith(fontSize: 16)),
              const SizedBox(height: 10),
              for (final TherapyWeek week in plan.schedule)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 46,
                        child: Text('S${week.week}', style: CprType.label.copyWith(color: CprPalette.inkFaint)),
                      ),
                      Expanded(child: Text(week.label, style: CprType.caption)),
                    ],
                  ),
                ),
              if (plan.cappedByImplantLimit) ...<Widget>[
                const SizedBox(height: 10),
                _Notice(
                  text:
                      'Il tetto per impianto ferma il recupero: ${plan.wastedHumanity} punti di terapia '
                      'non avrebbero effetto. Non si recupera più Umanità di quanta ne ha tolta ciascun impianto.',
                  tone: Tone.warning,
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  Color _statusColor(HumanityStatus status) => switch (status) {
    HumanityStatus.stabile => CprPalette.humanityIntact,
    HumanityStatus.inErosione => CprPalette.warning,
    HumanityStatus.alLimite => CprPalette.danger,
    HumanityStatus.cyberpsicosi => CprPalette.healthFlatline,
  };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final HumanityStatus status;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (status) {
      HumanityStatus.stabile => CprPalette.humanityIntact,
      HumanityStatus.inErosione => CprPalette.warning,
      HumanityStatus.alLimite => CprPalette.danger,
      HumanityStatus.cyberpsicosi => CprPalette.healthFlatline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CprPalette.veil(color, 0.14),
        border: Border.all(color: CprPalette.veil(color, 0.6)),
      ),
      child: Text(status.label.toUpperCase(), style: CprType.label.copyWith(color: color)),
    );
  }
}

class _ThresholdRow extends StatelessWidget {
  const _ThresholdRow({
    required this.range,
    required this.state,
    required this.color,
    required this.desc,
    required this.isCurrent,
  });

  final String range;
  final String state;
  final Color color;
  final String desc;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: isCurrent ? CprPalette.veil(color, 0.16) : Colors.transparent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Row(
              children: <Widget>[
                if (isCurrent)
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: Icon(Icons.arrow_right, size: 16, color: color),
                  ),
                Expanded(
                  child: Text(
                    range,
                    style: CprType.caption.copyWith(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? color : CprPalette.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: Text(
              state.toUpperCase(),
              style: CprType.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 10.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              desc,
              style: CprType.caption.copyWith(
                color: isCurrent ? CprPalette.ink : CprPalette.inkFaint,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Guarigione
// --------------------------------------------------------------------------

class _HealingPanel extends StatefulWidget {
  const _HealingPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_HealingPanel> createState() => _HealingPanelState();
}

class _HealingPanelState extends State<_HealingPanel> {
  String _missing = '30';
  String _body = '6';
  String _severe = '0';
  bool _rest = true;
  bool _medtech = false;
  bool _homeless = false;

  @override
  Widget build(BuildContext context) {
    final HealingPlan plan = Healing.plan(
      missingHitPoints: int.tryParse(_missing) ?? 0,
      body: int.tryParse(_body) ?? 0,
      completeRest: _rest,
      medtechWithDrugs: _medtech,
      severeInjuries: int.tryParse(_severe) ?? 0,
      rules: widget.state.gmRuleBook,
      homeless: _homeless,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Quanto tempo serve per rimettere in piedi qualcuno, con o senza un Medtech che usa '
              'Farmaci, e con o senza un letto. Una ferita grave ha il suo tempo e non si accorcia dormendo.',
          confidence: GmConfidence.daVerificare,
        ),
        Row(
          children: <Widget>[
            Expanded(
              child: TechField(
                label: 'PV mancanti',
                value: _missing,
                numeric: true,
                onChanged: (String v) => setState(() => _missing = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TechField(
                label: 'Fisico',
                value: _body,
                numeric: true,
                onChanged: (String v) => setState(() => _body = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TechField(
                label: 'Ferite gravi',
                value: _severe,
                numeric: true,
                onChanged: (String v) => setState(() => _severe = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          children: <Widget>[
            _Toggle(label: 'Riposo completo', value: _rest, onChanged: (bool v) => setState(() => _rest = v)),
            _Toggle(label: 'Medtech con Farmaci', value: _medtech, onChanged: (bool v) => setState(() => _medtech = v)),
            _Toggle(label: 'Senza alloggio', value: _homeless, onChanged: (bool v) => setState(() => _homeless = v)),
          ],
        ),
        const SizedBox(height: 18),
        if (plan.missingHitPoints <= 0)
          Text('Nessun danno da guarire.', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
        else ...<Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 26,
            runSpacing: 10,
            children: <Widget>[
              _BigNumber(value: '${plan.daysToFull}', label: 'giorni per i PV', accent: CprPalette.success),
              if (plan.severeInjuryDays > 0)
                _BigNumber(value: '${plan.severeInjuryDays}', label: 'giorni di degenza', accent: CprPalette.warning),
            ],
          ),
          const SizedBox(height: 10),
          Text(plan.summary, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
          const SizedBox(height: 12),
          for (final String note in plan.notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('· $note', style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
            ),
          if (plan.severeInjuryDays > 0) ...<Widget>[
            const SizedBox(height: 12),
            _Notice(
              text:
                  'La degenza comanda: si può avere la vita al massimo e la gamba ancora rotta. '
                  'Il tempo totale è ${plan.totalDays} giorni.',
              tone: Tone.info,
            ),
          ],
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Stile di vita
// --------------------------------------------------------------------------

class _LifestylePanel extends StatefulWidget {
  const _LifestylePanel({super.key, required this.state});

  final AppState state;

  @override
  State<_LifestylePanel> createState() => _LifestylePanelState();
}

class _LifestylePanelState extends State<_LifestylePanel> {
  FoodTier _food = FoodTier.prepak;
  HousingTier _housing = HousingTier.cubeHotel;
  String _other = '0';
  String _wallet = '3000';

  @override
  Widget build(BuildContext context) {
    final LifestyleLedger ledger = Lifestyle.ledger(
      food: _food,
      housing: _housing,
      rules: widget.state.gmRuleBook,
      otherRecurring: int.tryParse(_other) ?? 0,
      wallet: int.tryParse(_wallet) ?? 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'All\'inizio di ogni mese si pagano due cose: cosa si mangia e dove si dorme. Senza '
              'alloggio si guarisce peggio, ed è una penalità che si vede solo qui.',
          confidence: GmConfidence.daVerificare,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TechDropdown<FoodTier>(
                label: 'Cibo',
                value: _food,
                items: FoodTier.values,
                labelOf: (FoodTier f) => f.label,
                onChanged: (FoodTier f) => setState(() => _food = f),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TechDropdown<HousingTier>(
                label: 'Alloggio',
                value: _housing,
                items: HousingTier.values,
                labelOf: (HousingTier h) => h.label,
                onChanged: (HousingTier h) => setState(() => _housing = h),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Expanded(
              child: TechField(
                label: 'Altre spese ricorrenti',
                value: _other,
                numeric: true,
                onChanged: (String v) => setState(() => _other = v),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TechField(
                label: 'Contanti disponibili',
                value: _wallet,
                numeric: true,
                onChanged: (String v) => setState(() => _wallet = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 26,
          runSpacing: 10,
          children: <Widget>[
            _BigNumber(value: '${ledger.monthlyCost}', label: 'eb al mese', accent: CprPalette.yellow),
            _BigNumber(
              value: ledger.runwayMonths == 0 ? '—' : '${ledger.runwayMonths}',
              label: 'mesi di autonomia',
              accent: ledger.runwayMonths <= 2 ? CprPalette.danger : CprPalette.success,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Cibo ${ledger.foodCost} + alloggio ${ledger.housingCost} + ricorrenti ${ledger.otherRecurring}',
          style: CprType.caption.copyWith(color: CprPalette.inkMuted),
        ),
        if (_housing == HousingTier.nessuno) ...<Widget>[
          const SizedBox(height: 12),
          _Notice(
            text:
                'Senza alloggio il recupero dei PV viene moltiplicato per ${ledger.healFactor}. '
                'Dormire per strada non è un dettaglio narrativo, è una penalità.',
            tone: Tone.warning,
          ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Debiti
// --------------------------------------------------------------------------

class _DebtPanel extends StatefulWidget {
  const _DebtPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_DebtPanel> createState() => _DebtPanelState();
}

class _DebtPanelState extends State<_DebtPanel> {
  final DebtLedger _ledger = DebtLedger(<Debt>[
    const Debt(
      id: 'demo',
      creditor: 'un usuraio di Heywood',
      principal: 1200,
      weeklyRatePct: 5,
      weeksElapsed: 0,
      collateral: 'la tua pistola',
      note: 'Paga entro tre settimane o la pistola resta a lui.',
      playerName: 'Johnny Vane',
    ),
  ]);

  String _filterPlayer = 'Tutti';
  String _newPlayer = '';
  String _newCreditor = '';
  String _newAmount = '500';
  String _newRate = '5';

  @override
  Widget build(BuildContext context) {
    final String currentSheetName = (widget.state.sheet?.identity.tag.trim().isNotEmpty ?? false)
        ? widget.state.sheet!.identity.tag.trim()
        : ((widget.state.sheet?.identity.playerName.trim().isNotEmpty ?? false)
            ? widget.state.sheet!.identity.playerName.trim()
            : (widget.state.sheet?.meta.name.trim() ?? ''));
    final List<String> playerOptions = <String>{
      if (currentSheetName.isNotEmpty) currentSheetName,
      if (widget.state.campaign != null)
        for (final p in widget.state.campaign!.players) ...<String>[
          if (p.characterName.trim().isNotEmpty) p.characterName.trim(),
          if (p.playerName.trim().isNotEmpty) p.playerName.trim(),
        ],
      ..._ledger.distinctPlayerNames,
    }.toList();

    final List<Debt> visibleDebts = _filterPlayer == 'Tutti'
        ? _ledger.debts
        : _ledger.debtsForPlayer(_filterPlayer);

    final int totalOwed = _filterPlayer == 'Tutti'
        ? _ledger.totalOwed
        : _ledger.totalOwedBy(_filterPlayer);

    final Debt? worst = visibleDebts.isEmpty ? null : _ledger.fastestGrowing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Un debito cresce ogni settimana che passa. Il tasso lo decide il Master. '
              'Ora i debiti sono assegnati specificamente a ciascun giocatore o al gruppo.',
          confidence: GmConfidence.proposta,
        ),
        if (playerOptions.isNotEmpty) ...<Widget>[
          Row(
            children: <Widget>[
              Text('Filtra per Giocatore:', style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      for (final String opt in <String>['Tutti', ...playerOptions])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: InkWell(
                            onTap: () => setState(() => _filterPlayer = opt),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(
                                color: _filterPlayer == opt ? CprPalette.yellow : CprPalette.surfaceSunken,
                                border: Border.all(
                                  color: _filterPlayer == opt ? CprPalette.yellow : CprPalette.hairline,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                opt,
                                style: CprType.caption.copyWith(
                                  color: _filterPlayer == opt ? Colors.black : CprPalette.ink,
                                  fontWeight: _filterPlayer == opt ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        if (visibleDebts.isEmpty)
          Text(
            _filterPlayer == 'Tutti'
                ? 'Nessun debito aperto.'
                : 'Nessun debito aperto per $_filterPlayer.',
            style: CprType.caption.copyWith(color: CprPalette.inkFaint),
          )
        else ...<Widget>[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 26,
            runSpacing: 10,
            children: <Widget>[
              _BigNumber(value: '$totalOwed', label: 'eb dovuti ora ($_filterPlayer)', accent: CprPalette.warning),
              _BigNumber(value: '${visibleDebts.fold<int>(0, (int a, Debt d) => a + d.owedAt(d.weeksElapsed + 4))}', label: 'eb fra 4 settimane', accent: CprPalette.danger),
            ],
          ),
          if (worst != null) ...<Widget>[
            const SizedBox(height: 10),
            _Notice(
              text:
                  'Da pagare per primo: [${worst.debtorLabel}] ${worst.creditor}. Non è il più grosso, è quello che costa di più aspettare.',
              tone: Tone.info,
            ),
          ],
          const SizedBox(height: 16),
          for (final Debt debt in visibleDebts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: CprPalette.surfaceSunken,
                  border: Border(left: BorderSide(color: CprPalette.warning, width: 3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: CprPalette.veil(CprPalette.cyan, 0.15),
                            border: Border.all(color: CprPalette.cyan, width: 0.8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            debt.debtorLabel,
                            style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 10),
                          ),
                        ),
                        Expanded(
                          child: Text(debt.creditor, style: CprType.body.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        Text('${debt.owedNow} eb', style: CprType.numeralSmall.copyWith(color: CprPalette.warning)),
                        const SizedBox(width: 8),
                        TechButton(
                          label: '',
                          icon: Icons.delete_outline,
                          compact: true,
                          tooltip: 'Rimuovi dal registro',
                          onPressed: () => setState(() => _ledger.remove(debt.id)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(debt.summary, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
                    if (debt.note.isNotEmpty)
                      Text(debt.note, style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              TechButton(
                label: 'Aggiungi settimana',
                icon: Icons.schedule,
                compact: true,
                onPressed: () => setState(() {
                  final List<Debt> advanced = <Debt>[for (final Debt d in _ledger.debts) d.afterWeeks(1)];
                  _ledger.debts
                    ..clear()
                    ..addAll(advanced);
                }),
              ),
              const SizedBox(width: 10),
              TechButton(
                label: 'Paga 500 eb',
                icon: Icons.payments_outlined,
                compact: true,
                onPressed: () => setState(() => _ledger.pay(500)),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        TechSection(
          title: 'Nuovo debito per giocatore',
          children: <Widget>[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                SizedBox(
                  width: 170,
                  child: TechField(
                    label: 'Giocatore / PG Debitore',
                    value: _newPlayer,
                    hint: 'es. Johnny Vane',
                    onChanged: (String v) => setState(() => _newPlayer = v),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TechField(
                    label: 'Creditore',
                    value: _newCreditor,
                    hint: 'una banca, un fixer, Arasaka',
                    onChanged: (String v) => setState(() => _newCreditor = v),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TechField(
                    label: 'Capitale (eb)',
                    value: _newAmount,
                    numeric: true,
                    onChanged: (String v) => setState(() => _newAmount = v),
                  ),
                ),
                SizedBox(
                  width: 110,
                  child: TechField(
                    label: 'Interesse %/sett.',
                    value: _newRate,
                    numeric: true,
                    onChanged: (String v) => setState(() => _newRate = v),
                  ),
                ),
                TechButton(
                  label: 'Apri',
                  icon: Icons.add,
                  onPressed: () {
                    final String creditor = _newCreditor.trim();
                    if (creditor.isEmpty) return;
                    setState(() {
                      _ledger.add(
                        Debt(
                          id: 'debt_${DateTime.now().microsecondsSinceEpoch}',
                          creditor: creditor,
                          principal: int.tryParse(_newAmount) ?? 0,
                          weeklyRatePct: double.tryParse(_newRate) ?? 0,
                          weeksElapsed: 0,
                          playerName: _newPlayer.trim().isEmpty
                              ? (_filterPlayer != 'Tutti' ? _filterPlayer : 'Tavolo / PG')
                              : _newPlayer.trim(),
                        ),
                      );
                      _newCreditor = '';
                    });
                  },
                ),
              ],
            ),
            if (playerOptions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  for (final String opt in playerOptions)
                    InkWell(
                      onTap: () => setState(() => _newPlayer = opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: _newPlayer == opt ? CprPalette.yellow : CprPalette.surfaceSunken,
                          border: Border.all(color: CprPalette.hairline),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '+ $opt',
                          style: CprType.caption.copyWith(
                            color: _newPlayer == opt ? Colors.black : CprPalette.inkMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Mercato nero
// --------------------------------------------------------------------------

class _MarketPanel extends StatefulWidget {
  const _MarketPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_MarketPanel> createState() => _MarketPanelState();
}

class _MarketPanelState extends State<_MarketPanel> {
  int _rank = 4;

  @override
  Widget build(BuildContext context) {
    final MarketAccess access = BlackMarket.access(contactsRank: _rank, rules: widget.state.gmRuleBook);
    final List<CatalogItem> all = widget.state.catalog.all();
    final List<CatalogItem> reachable = BlackMarket.filter(all, access, (CatalogItem i) => i.rarity);
    final int? missing = access.ranksToUnlockNext();

    final Map<Rarity, int> byRarity = <Rarity, int>{};
    for (final CatalogItem item in all) {
      byRarity[item.rarity] = (byRarity[item.rarity] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Il rango di Contatti di un Fixer decide fin dove arriva il suo giro. Il manuale stabilisce '
              'il principio; la scala precisa è una scelta di questa applicazione, e si può cambiare.',
          confidence: GmConfidence.proposta,
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 20,
          runSpacing: 10,
          children: <Widget>[
            SizedBox(
              width: 220,
              child: TechNumberStepper(
                label: 'Rango di Contatti',
                value: _rank,
                min: 0,
                max: 10,
                onChanged: (int v) => setState(() => _rank = v),
              ),
            ),
            _BigNumber(value: access.maxRarity.label.toUpperCase(), label: 'fascia massima', accent: CprPalette.violet),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          missing == null
              ? 'Tutto il catalogo è raggiungibile.'
              : 'Mancano $missing ranghi per sbloccare la fascia successiva.',
          style: CprType.caption.copyWith(color: CprPalette.inkMuted),
        ),
        const SizedBox(height: 16),
        TechSection(
          title: 'La scala di reperibilità',
          children: <Widget>[
            for (final Rarity rarity in marketLadder)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: <Widget>[
                    Icon(
                      access.canFind(rarity) ? Icons.lock_open_outlined : Icons.lock_outline,
                      size: 13,
                      color: access.canFind(rarity) ? CprPalette.success : CprPalette.inkFaint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        rarity.label,
                        style: CprType.caption.copyWith(
                          color: access.canFind(rarity) ? CprPalette.ink : CprPalette.inkFaint,
                        ),
                      ),
                    ),
                    Text(
                      '${byRarity[rarity] ?? 0} voci nel catalogo',
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Con questo rango un Fixer può procurare ${reachable.length} delle ${all.length} voci del catalogo.',
          style: CprType.body,
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Console di rete
// --------------------------------------------------------------------------

class _NetPanel extends StatefulWidget {
  const _NetPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_NetPanel> createState() => _NetPanelState();
}

class _NetPanelState extends State<_NetPanel> {
  final math.Random _random = math.Random();
  final NetrunnerConsole _console = NetrunnerConsole();
  NetIceProgram _target = NetrunnerConsole.defaultIce.first;
  NetAttackProgram _program = NetrunnerPrograms.all.first;
  int _interface = 5;
  final List<ProgramAttackResult> _log = <ProgramAttackResult>[];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Un attacco a un programma della rete: d10 + Interfaccia contro la Difesa del bersaglio, '
              'e il danno si sottrae al REZ. I nomi dei programmi sono del manuale, i valori vanno confrontati '
              'con il loro blocco statistiche.',
          confidence: GmConfidence.daVerificare,
        ),
        TechSection(
          title: 'Programmi difensivi attivi',
          trailing: TechButton(
            label: 'Riavvia rete',
            icon: Icons.refresh,
            compact: true,
            onPressed: () => setState(() {
              _console.reset();
              _log.clear();
            }),
          ),
          children: <Widget>[
            for (final NetIceProgram ice in _console.ice)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: _IceRow(
                  ice: ice,
                  rez: _console.rezOf(ice),
                  destroyed: _console.isDestroyed(ice),
                  selected: ice.name == _target.name,
                  onSelect: () => setState(() => _target = ice),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(
              child: TechDropdown<NetAttackProgram>(
                label: 'Programma d\'attacco',
                value: _program,
                items: NetrunnerPrograms.all,
                labelOf: (NetAttackProgram p) => p.name,
                onChanged: (NetAttackProgram p) => setState(() => _program = p),
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 170,
              child: TechNumberStepper(
                label: 'Interfaccia',
                value: _interface,
                min: 0,
                max: 20,
                onChanged: (int v) => setState(() => _interface = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(_program.effect, style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
        const SizedBox(height: 14),
        TechButton(
          label: 'Attacca ${_target.name}',
          icon: Icons.bolt,
          onPressed: () => setState(() {
            _log.insert(
              0,
              _console.attack(program: _program, target: _target, interfaceRank: _interface, random: _random),
            );
          }),
        ),
        if (_log.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          TechSection(
            title: 'Registro attacchi',
            children: <Widget>[
              for (final ProgramAttackResult result in _log)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: CprPalette.surfaceSunken,
                      border: Border(
                        left: BorderSide(
                          color: result.destroyed
                              ? CprPalette.success
                              : (result.hit ? CprPalette.warning : CprPalette.inkFaint),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Text(result.log, style: CprType.caption),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: <Widget>[
              TechButton(
                label: 'Al registro',
                icon: Icons.receipt_long_outlined,
                compact: true,
                tooltip: widget.state.canRecordSession
                    ? 'Scrive gli attacchi nel registro della sessione'
                    : 'Apri una campagna o una scheda: senza un documento il registro non ha dove restare',
                onPressed: widget.state.canRecordSession
                    ? () => widget.state.recordSessionEvent(
                        _log.map((ProgramAttackResult r) => r.log).join(' · '),
                        delta: 'RETE',
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Result(text: _log.map((ProgramAttackResult r) => r.log).join('\n'), accent: CprPalette.info),
        ],
      ],
    );
  }
}

class _IceRow extends StatelessWidget {
  const _IceRow({
    required this.ice,
    required this.rez,
    required this.destroyed,
    required this.selected,
    required this.onSelect,
  });

  final NetIceProgram ice;
  final int rez;
  final bool destroyed;
  final bool selected;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final double ratio = ice.rez == 0 ? 0 : rez / ice.rez;
    final Color color = destroyed
        ? CprPalette.inkFaint
        : (ratio > 0.6 ? CprPalette.success : (ratio > 0.3 ? CprPalette.warning : CprPalette.danger));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? CprPalette.veil(CprPalette.info, 0.10) : CprPalette.surfaceSunken,
            border: Border.all(color: selected ? CprPalette.info : CprPalette.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(ice.name, style: CprType.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(
                    ice.category.toUpperCase(),
                    style: CprType.label.copyWith(fontSize: 9, color: CprPalette.inkFaint),
                  ),
                  const Spacer(),
                  Text(
                    destroyed ? 'DISTRUTTO' : 'REZ $rez/${ice.rez}',
                    style: CprType.numeralSmall.copyWith(color: color),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // La barra dice a colpo d'occhio quanto resta: il numero accanto la
              // conferma, ma nessuno legge un numero mentre sta parlando.
              Stack(
                children: <Widget>[
                  Container(height: 4, color: CprPalette.hairline),
                  FractionallySizedBox(
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: AnimatedContainer(duration: CprMotion.hover, height: 4, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Attacco ${ice.attack} · Difesa ${ice.defense} · Velocità ${ice.speed}',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Numeri e regole
// --------------------------------------------------------------------------

class _RulesPanel extends StatefulWidget {
  const _RulesPanel({super.key, required this.state});

  final AppState state;

  @override
  State<_RulesPanel> createState() => _RulesPanelState();
}

class _RulesPanelState extends State<_RulesPanel> {
  String? _openGroup;

  @override
  Widget build(BuildContext context) {
    final AppState state = widget.state;
    final List<GmRule> rules = state.gmRuleBook.rules;
    final List<String> groups = <String>[];
    for (final GmRule rule in rules) {
      final String group = rule.group.isEmpty ? 'Altro' : rule.group;
      if (!groups.contains(group)) groups.add(group);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ToolIntro(
          text:
              'Ogni numero che questa console usa. Il colore dice quanto è affidabile, e ognuno si può '
              'correggere: la correzione vale per tutta la campagna e resta salvata.',
        ),
        Row(
          children: <Widget>[
            TechButton(
              label: 'Ripristina tutto',
              icon: Icons.settings_backup_restore,
              compact: true,
              onPressed: () => state.resetAllGmRules(),
            ),
            const SizedBox(width: 12),
            Text(
              '${state.settings.gmRuleOverrides.length} corretti su ${rules.length}',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final String group in groups) ...<Widget>[
          _GroupHeader(
            group: group,
            count: rules.where((GmRule r) => (r.group.isEmpty ? 'Altro' : r.group) == group).length,
            open: _openGroup == group,
            onTap: () => setState(() => _openGroup = _openGroup == group ? null : group),
          ),
          if (_openGroup == group)
            for (final GmRule rule in rules.where((GmRule r) => (r.group.isEmpty ? 'Altro' : r.group) == group))
              _RuleRow(
                rule: rule,
                overridden: state.settings.gmRuleOverrides.containsKey(rule.id),
                onEdit: () => _editDialog(context, rule),
                onReset: () => state.resetGmRule(rule.id),
              ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Future<void> _editDialog(BuildContext context, GmRule rule) async {
    final TextEditingController controller = TextEditingController(text: rule.displayValue);
    final String? raw = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: CprPalette.surface,
        title: Text(rule.label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.yellow)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (rule.note.isNotEmpty) ...<Widget>[
                Text(rule.note, style: CprType.caption.copyWith(color: CprPalette.inkMuted)),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: rule.unit.isEmpty ? 'Valore' : 'Valore (${rule.unit})'),
              ),
              const SizedBox(height: 8),
              Text(
                'Intervallo ammesso: ${rule.min.toStringAsFixed(0)} – ${rule.max.toStringAsFixed(0)}',
                style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TechButton(label: 'Annulla', compact: true, onPressed: () => Navigator.of(ctx).pop()),
          TechButton(
            label: 'Salva',
            icon: Icons.check,
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(controller.text),
          ),
        ],
      ),
    );

    final double? value = double.tryParse((raw ?? '').replaceAll(',', '.'));
    if (value == null) return;
    await widget.state.setGmRule(rule.id, value);
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group, required this.count, required this.open, required this.onTap});

  final String group;
  final int count;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: CprPalette.surfaceRaised,
            border: Border(bottom: BorderSide(color: CprPalette.hairline)),
          ),
          child: Row(
            children: <Widget>[
              AnimatedRotation(
                duration: CprMotion.hover,
                turns: open ? 0.25 : 0,
                child: Icon(Icons.chevron_right, size: 15, color: CprPalette.inkMuted),
              ),
              const SizedBox(width: 8),
              Text(group.toUpperCase(), style: CprType.label),
              const Spacer(),
              Text('$count', style: CprType.caption.copyWith(color: CprPalette.inkFaint)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.rule, required this.overridden, required this.onEdit, required this.onReset});

  final GmRule rule;
  final bool overridden;
  final VoidCallback onEdit;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(child: Text(rule.label, style: CprType.caption)),
                    const SizedBox(width: 8),
                    _ConfidenceBadge(confidence: rule.confidence),
                    if (overridden) ...<Widget>[
                      const SizedBox(width: 6),
                      Text('CORRETTO', style: CprType.label.copyWith(fontSize: 9, color: CprPalette.warning)),
                    ],
                  ],
                ),
                if (rule.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(rule.note, style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onEdit,
              child: Text(
                '${rule.displayValue}${rule.unit.isEmpty ? '' : ' ${rule.unit}'}',
                style: CprType.mono(overridden ? CprPalette.warning : CprPalette.ink, size: 13),
              ),
            ),
          ),
          if (overridden) ...<Widget>[
            const SizedBox(width: 6),
            TechButton(
              label: '',
              icon: Icons.settings_backup_restore,
              compact: true,
              tooltip: 'Ripristina',
              onPressed: onReset,
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------------------
// Avvisi
// --------------------------------------------------------------------------

enum Tone { info, warning, danger }

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.tone});

  final String text;
  final Tone tone;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (tone) {
      Tone.info => (CprPalette.info, Icons.info_outline),
      Tone.warning => (CprPalette.warning, Icons.report_problem_outlined),
      Tone.danger => (CprPalette.danger, Icons.error_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CprPalette.veil(color, 0.08),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: CprType.caption.copyWith(height: 1.45))),
        ],
      ),
    );
  }
}
