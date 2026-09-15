import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/gm/gm_generators.dart';
import '../../widgets/tech_button.dart';
import '../ai/ai_assistant_service.dart';

/// Modalità del generatore di bottino del nemico.
enum LootGeneratorMode { base, avanzata, manuale }

/// Dialogo completo per la generazione e configurazione del Loot di un nemico.
///
/// Supporta 3 modalità:
/// 1. Base: tipi generici, qualità 0-10, reroll indipendente.
/// 2. Avanzata: prompt personalizzato ("chi è, cosa fa"), generazione IA, reroll indipendente.
/// 3. Manuale: modifica riga per riga degli oggetti nella tabella.
class EnemyLootDialog extends StatefulWidget {
  const EnemyLootDialog({
    super.key,
    this.initialLoot = '',
    required this.onApply,
    this.initialEnemyName,
  });

  final String initialLoot;
  final ValueChanged<String> onApply;
  final String? initialEnemyName;

  @override
  State<EnemyLootDialog> createState() => _EnemyLootDialogState();
}

class _EnemyLootDialogState extends State<EnemyLootDialog> {
  LootGeneratorMode _mode = LootGeneratorMode.base;

  // Base Mode State
  String _baseArchetype = 'Scagnozzo da strada';
  int _baseQuality = 5;

  // Advanced Mode State
  late final TextEditingController _advancedPromptCtrl;
  bool _isAiGenerating = false;

  // Manual Mode State
  final TextEditingController _manualItemNameCtrl = TextEditingController();
  final TextEditingController _manualItemNoteCtrl = TextEditingController();
  final TextEditingController _manualEbCtrl = TextEditingController(text: '150');
  LootKind _manualKind = LootKind.oggetto;
  int _manualQuantity = 1;

  // Current Working Loot
  int _eurodollars = 100;
  List<LootEntry> _entries = <LootEntry>[];
  String _generationSource = 'Iniziale';

  final List<String> _baseArchetypes = <String>[
    'Scagnozzo da strada',
    'Civile / Passante',
    'Poliziotto NCPD',
    'Guardia Corporativa',
    'Netrunner da vicolo',
    'Bisturi da strada (Ripperdoc)',
    'Solo Mercenario / Boss',
  ];

  @override
  void initState() {
    super.initState();
    final String name = widget.initialEnemyName ?? 'Nemico sconosciuto';
    _advancedPromptCtrl = TextEditingController(
      text: '$name nei vicoli di Night City',
    );

    // Se c'è un loot iniziale, impostalo in manuale o genera
    if (widget.initialLoot.trim().isNotEmpty) {
      _parseInitialLoot(widget.initialLoot.trim());
    } else {
      _generateBaseLoot();
    }
  }

  @override
  void dispose() {
    _advancedPromptCtrl.dispose();
    _manualItemNameCtrl.dispose();
    _manualItemNoteCtrl.dispose();
    _manualEbCtrl.dispose();
    super.dispose();
  }

  void _parseInitialLoot(String lootStr) {
    _entries = <LootEntry>[
      LootEntry(name: lootStr, kind: LootKind.oggetto, quantity: 1),
    ];
    _generationSource = 'Esistente';
  }

  /// Generazione Modalità Base (completamente indipendente dal loot precedente).
  void _generateBaseLoot() {
    final math.Random rnd = math.Random();
    final AiAssistantService service = AiAssistantService.instance;
    final AiLootResult res = service.generateLootWithAiProceduralSync(
      prompt: _baseArchetype,
      quality: _baseQuality,
      random: rnd,
    );
    setState(() {
      _eurodollars = res.eurodollars;
      _entries = List<LootEntry>.from(res.entries);
      _generationSource = 'Base ($_baseArchetype, Q: $_baseQuality/10)';
      _manualEbCtrl.text = '$_eurodollars';
    });
  }

  /// Generazione Modalità Avanzata con IA (completamente indipendente dal loot precedente).
  Future<void> _generateAdvancedLoot() async {
    final String prompt = _advancedPromptCtrl.text.trim().isEmpty
        ? 'Nemico misterioso di Night City'
        : _advancedPromptCtrl.text.trim();

    setState(() => _isAiGenerating = true);

    final AiAssistantService service = AiAssistantService.instance;
    final AiLootResult res = await service.generateLootWithAi(
      prompt: prompt,
      // La modalità avanzata ricava il bottino dal contesto del prompt;
      // il livello standard resta interno e non appare come selettore.
      quality: 6,
    );

    if (!mounted) return;
    setState(() {
      _isAiGenerating = false;
      _eurodollars = res.eurodollars;
      _entries = List<LootEntry>.from(res.entries);
      _generationSource = 'Avanzata (${res.source})';
      _manualEbCtrl.text = '$_eurodollars';
    });
  }

  void _addManualEntry() {
    final String name = _manualItemNameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _entries.add(
        LootEntry(
          name: name,
          kind: _manualKind,
          quantity: math.max(1, _manualQuantity),
          note: _manualItemNoteCtrl.text.trim(),
        ),
      );
      _manualItemNameCtrl.clear();
      _manualItemNoteCtrl.clear();
      _manualQuantity = 1;
      _generationSource = 'Manuale';
    });
  }

  void _removeManualEntry(int index) {
    setState(() {
      _entries.removeAt(index);
      _generationSource = 'Manuale';
    });
  }

  String _formatCompiledLoot() {
    final List<String> parts = <String>[];
    if (_eurodollars > 0) {
      parts.add('$_eurodollars eb');
    }
    for (final LootEntry e in _entries) {
      final String qtyStr = e.quantity > 1 ? ' ×${e.quantity}' : '';
      final String noteStr = e.note.isNotEmpty ? ' (${e.note})' : '';
      parts.add('${e.name}$qtyStr$noteStr');
    }
    if (parts.isEmpty) return 'Tasche vuote (0 eb)';
    return parts.join(', ');
  }

  String _qualityLabel(int q) => switch (q) {
    0 => '0 - Spazzatura / Tasche vuote',
    1 || 2 => '$q - Povero (Spiccioli, stracci)',
    3 || 4 => '$q - Basso (Munizioni sfuse, cibarie)',
    5 || 6 => '$q - Standard (Arma comune, chip, crediti)',
    7 || 8 => '$q - Avanzato (Cyberware, droghe pure, armi HQ)',
    9 || 10 => '$q - Leggendario (Prototipi militari, alta tecnologia)',
    _ => '$q',
  };

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 640,
        constraints: const BoxConstraints(maxHeight: 760),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.yellow, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.yellow.withValues(alpha: 0.25), blurRadius: 18),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Header
            Row(
              children: <Widget>[
                const Icon(Icons.inventory_2, color: CprPalette.yellow, size: 22),
                const SizedBox(width: 8),
                Text('GENERATORE DI LOOT & TASCHE NEMICI', style: CprType.title.copyWith(fontSize: 14)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Configura il bottino dell\'avversario: rigenera più volte (Reroll) senza residui precedenti.',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 12),

            // Mode Selector Tabs (Base, Avanzata, Manuale)
            Row(
              children: <Widget>[
                _ModeTabButton(
                  title: '1. BASE (GENERICO)',
                  icon: Icons.casino_outlined,
                  active: _mode == LootGeneratorMode.base,
                  onTap: () => setState(() => _mode = LootGeneratorMode.base),
                ),
                const SizedBox(width: 8),
                _ModeTabButton(
                  title: '2. AVANZATA (AI CHATBOT)',
                  icon: Icons.auto_awesome,
                  active: _mode == LootGeneratorMode.avanzata,
                  onTap: () => setState(() => _mode = LootGeneratorMode.avanzata),
                ),
                const SizedBox(width: 8),
                _ModeTabButton(
                  title: '3. MANUALE',
                  icon: Icons.edit_note,
                  active: _mode == LootGeneratorMode.manuale,
                  onTap: () => setState(() => _mode = LootGeneratorMode.manuale),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab Content
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_mode == LootGeneratorMode.base) _buildBaseTab(),
                    if (_mode == LootGeneratorMode.avanzata) _buildAdvancedTab(),
                    if (_mode == LootGeneratorMode.manuale) _buildManualTab(),
                    const SizedBox(height: 16),
                    _buildPreviewSection(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Fonte: $_generationSource',
                  style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
                ),
                Row(
                  children: <Widget>[
                    TechButton(
                      label: 'Annulla',
                      icon: Icons.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    TechButton(
                      label: 'Applica al Nemico',
                      icon: Icons.check,
                      variant: TechButtonVariant.primary,
                      onPressed: () {
                        widget.onApply(_formatCompiledLoot());
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseTab() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('TIPO DI NEMICO GENERALE', style: CprType.label.copyWith(color: CprPalette.yellow)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final String arch in _baseArchetypes)
                InkWell(
                  onTap: () => setState(() => _baseArchetype = arch),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _baseArchetype == arch ? CprPalette.yellow : CprPalette.surfaceRaised,
                      border: Border.all(color: _baseArchetype == arch ? CprPalette.yellow : CprPalette.hairline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      arch,
                      style: CprType.caption.copyWith(
                        color: _baseArchetype == arch ? Colors.black : CprPalette.ink,
                        fontWeight: _baseArchetype == arch ? FontWeight.bold : FontWeight.normal,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Text('QUALITÀ DELLA LOOT TABLE: ', style: CprType.label.copyWith(fontSize: 11)),
              Text(_qualityLabel(_baseQuality), style: CprType.caption.copyWith(color: CprPalette.cyan, fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: _baseQuality.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: CprPalette.cyan,
            inactiveColor: CprPalette.hairline,
            onChanged: (double v) => setState(() => _baseQuality = v.round()),
          ),
          const SizedBox(height: 8),
          TechButton(
            label: 'REROLL LOOT BASE (GENERAZIONE FRESCA)',
            icon: Icons.casino,
            expand: true,
            variant: TechButtonVariant.primary,
            tooltip: 'Genera un nuovo bottino casuale senza basarsi su quello precedente',
            onPressed: _generateBaseLoot,
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    final bool hasKey = AiAssistantService.instance.hasGeminiKey;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('PROMPT NEMICO: CHI È, COSA FA', style: CprType.label.copyWith(color: CprPalette.magenta)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: hasKey ? CprPalette.veil(CprPalette.success, 0.15) : CprPalette.veil(CprPalette.warning, 0.15),
                  border: Border.all(color: hasKey ? CprPalette.success : CprPalette.warning),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  hasKey ? 'Gemini AI Online' : 'AI Offline (Fallback attivo)',
                  style: CprType.caption.copyWith(
                    color: hasKey ? CprPalette.success : CprPalette.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _advancedPromptCtrl,
            maxLines: 2,
            style: CprType.body.copyWith(color: CprPalette.ink),
            decoration: const InputDecoration(
              hintText: 'es. Ingegnere chimico della Biotechnica in fuga con chip cifrato',
              filled: true,
              fillColor: CprPalette.surfaceRaised,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TechButton(
            label: _isAiGenerating ? 'GENERAZIONE IN CORSO...' : 'GENERA LOOT CON IA (REROLL INDIPENDENTE)',
            icon: Icons.auto_awesome,
            expand: true,
            variant: TechButtonVariant.secondary,
            tooltip: 'L\'IA analizza il prompt e genera un bottino contestuale senza memoria pregressa',
            onPressed: _isAiGenerating ? null : _generateAdvancedLoot,
          ),
        ],
      ),
    );
  }

  Widget _buildManualTab() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('EURODOLLARI IN CONTANTI (EB)', style: CprType.label.copyWith(color: CprPalette.yellow)),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              SizedBox(
                width: 140,
                child: TextField(
                  controller: _manualEbCtrl,
                  keyboardType: TextInputType.number,
                  style: CprType.body.copyWith(color: CprPalette.yellow),
                  decoration: const InputDecoration(
                    suffixText: 'eb',
                    filled: true,
                    fillColor: CprPalette.surfaceRaised,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String v) {
                    setState(() {
                      _eurodollars = int.tryParse(v) ?? 0;
                      _generationSource = 'Manuale';
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 6,
                children: <Widget>[
                  for (final int eb in <int>[0, 50, 150, 500, 1000])
                    TechButton(
                      label: '$eb',
                      compact: true,
                      onPressed: () {
                        setState(() {
                          _eurodollars = eb;
                          _manualEbCtrl.text = '$eb';
                          _generationSource = 'Manuale';
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text('AGGIUNGI OGGETTO ALLA TABELLA', style: CprType.label.copyWith(color: CprPalette.yellow)),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _manualItemNameCtrl,
                  style: CprType.body.copyWith(color: CprPalette.ink),
                  decoration: const InputDecoration(
                    labelText: 'Nome Oggetto',
                    filled: true,
                    fillColor: CprPalette.surfaceRaised,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<LootKind>(
                  initialValue: _manualKind,
                  decoration: const InputDecoration(
                    labelText: 'Tipo',
                    filled: true,
                    fillColor: CprPalette.surfaceRaised,
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final LootKind k in LootKind.values)
                      DropdownMenuItem<LootKind>(value: k, child: Text(k.name)),
                  ],
                  onChanged: (LootKind? v) {
                    if (v != null) setState(() => _manualKind = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextField(
                  keyboardType: TextInputType.number,
                  style: CprType.body.copyWith(color: CprPalette.ink),
                  decoration: const InputDecoration(
                    labelText: 'Qt.',
                    filled: true,
                    fillColor: CprPalette.surfaceRaised,
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: '$_manualQuantity'),
                  onChanged: (v) => _manualQuantity = int.tryParse(v) ?? 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _manualItemNoteCtrl,
                  style: CprType.body.copyWith(color: CprPalette.ink),
                  decoration: const InputDecoration(
                    labelText: 'Nota / Descrizione (opzionale)',
                    filled: true,
                    fillColor: CprPalette.surfaceRaised,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TechButton(
                label: 'Aggiungi',
                icon: Icons.add,
                variant: TechButtonVariant.primary,
                onPressed: _addManualEntry,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        border: Border.all(color: CprPalette.yellow.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('RISULTATO LOOT TABLE ATTUALE', style: CprType.label.copyWith(color: CprPalette.yellow)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.yellow, 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text('$_eurodollars eb', style: CprType.numeral.copyWith(color: CprPalette.yellow, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_entries.isEmpty && _eurodollars <= 0)
            Text('Nessun oggetto nel bottino (tasche vuote).', style: CprType.caption.copyWith(color: CprPalette.inkFaint))
          else ...<Widget>[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (int i = 0; i < _entries.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: CprPalette.surfaceSunken,
                      border: Border.all(color: CprPalette.hairline),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(_lootIcon(_entries[i].kind), size: 13, color: CprPalette.cyan),
                        const SizedBox(width: 6),
                        Text(_entries[i].short, style: CprType.caption.copyWith(fontWeight: FontWeight.w600)),
                        if (_entries[i].note.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 4),
                          Text('— ${_entries[i].note}', style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11)),
                        ],
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _removeManualEntry(i),
                          child: const Icon(Icons.close, size: 12, color: CprPalette.inkFaint),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: CprPalette.surfaceSunken,
              borderRadius: BorderRadius.circular(2),
            ),
            child: SelectableText(
              _formatCompiledLoot(),
              style: CprType.caption.copyWith(color: CprPalette.cyan, height: 1.3),
            ),
          ),
        ],
      ),
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

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.title,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? CprPalette.yellow : CprPalette.surfaceSunken,
            border: Border.all(color: active ? CprPalette.yellow : CprPalette.hairline),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 14, color: active ? Colors.black : CprPalette.inkMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: CprType.label.copyWith(
                    color: active ? Colors.black : CprPalette.inkMuted,
                    fontSize: 10.5,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
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
