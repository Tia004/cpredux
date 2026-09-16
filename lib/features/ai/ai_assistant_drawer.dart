import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../widgets/cyber_markdown_view.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/tech_button.dart';
import 'ai_assistant_service.dart';

/// Pannello laterale o schermata a tutto schermo per il Chatbot IA e il generatore PNG per il Master.
class AiAssistantDrawer extends StatefulWidget {
  const AiAssistantDrawer({
    super.key,
    this.onClose,
    this.isFullWidth = false,
  });

  final VoidCallback? onClose;
  final bool isFullWidth;

  @override
  State<AiAssistantDrawer> createState() => _AiAssistantDrawerState();
}

class _AiAssistantDrawerState extends State<AiAssistantDrawer> {
  int _activeTab = 0; // 0: Parla come PNG, 1: Assistente Regole & Lore

  // PNG State
  NpcArchetype _selectedArchetype = NpcArchetype.fixer;
  NpcTone _selectedTone = NpcTone.friendly;
  final TextEditingController _npcNameCtrl = TextEditingController(text: 'Fixer Martinez');
  final TextEditingController _npcSituationCtrl = TextEditingController(text: 'Offre una missione per recuperare un prototipo Militech');
  String _generatedNpcDialogue = '';

  // Regole/Chat State
  final TextEditingController _promptCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _npcNameCtrl.dispose();
    _npcSituationCtrl.dispose();
    _promptCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AiAssistantService ai = AiAssistantService.instance;

    return Container(
      width: widget.isFullWidth ? double.infinity : 360,
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        border: widget.isFullWidth
            ? null
            : Border(left: BorderSide(color: CprPalette.cyan, width: 1.5)),
        boxShadow: widget.isFullWidth
            ? null
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 16,
                  offset: const Offset(-4, 0),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHeader(context, ai),
          _buildTabBar(),
          Expanded(
            child: _activeTab == 0
                ? _buildNpcGeneratorTab(context, state, ai)
                : _buildRulesChatTab(context, ai),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AiAssistantService ai) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      color: CprPalette.surface,
      child: Row(
        children: <Widget>[
          Icon(Icons.smart_toy_outlined, color: CprPalette.cyan, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'CYBER AI ASSISTANT',
                  style: CprType.label.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: CprPalette.cyan,
                    fontSize: 11.5,
                  ),
                ),
                Text(
                  ai.effectiveProxyUrl.isNotEmpty
                      ? 'Motore: Google Gemini 2.5 Flash · proxy cloud'
                      : ai.hasGeminiKey
                          ? 'Motore: Google Gemini 2.5 Flash'
                          : 'Motore: Offline Heuristic Free',
                  style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 9.5),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, size: 16, color: CprPalette.inkMuted),
            tooltip: 'Configura Chiave Google Gemini Gratuita',
            onPressed: () => _promptConfigApiKey(context, ai),
          ),
          if (widget.onClose != null)
            IconButton(
              icon: Icon(Icons.close, size: 18, color: CprPalette.ink),
              tooltip: 'Chiudi assistente',
              onPressed: widget.onClose,
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _tabButton('PARLA COME PNG', 0, Icons.record_voice_over_outlined),
          ),
          Expanded(
            child: _tabButton('REGOLE & LORE', 1, Icons.menu_book_outlined),
          ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, IconData icon) {
    final bool active = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? CprPalette.cyan : Colors.transparent,
              width: 2,
            ),
          ),
          color: active ? CprPalette.surfaceRaised : Colors.transparent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, size: 14, color: active ? CprPalette.cyan : CprPalette.inkMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: CprType.label.copyWith(
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
                color: active ? CprPalette.cyan : CprPalette.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- TAB 1: PARLA COME PNG -------------------------------------------------

  Widget _buildNpcGeneratorTab(
    BuildContext context,
    AppState state,
    AiAssistantService ai,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Fai parlare i personaggi secondari (PNG) con lo stile di Night City e pubblica le battute direttamente nella chat del tavolo di gioco.',
            style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.3),
          ),
          const SizedBox(height: 14),

          // Selezione Archetipo
          DropdownButtonFormField<NpcArchetype>(
            initialValue: _selectedArchetype,
            decoration: const InputDecoration(labelText: 'Archetipo PNG'),
            items: NpcArchetype.values.map((NpcArchetype a) {
              return DropdownMenuItem<NpcArchetype>(
                value: a,
                child: Text(a.label, style: CprType.body.copyWith(fontSize: 12)),
              );
            }).toList(),
            onChanged: (NpcArchetype? val) {
              if (val != null) {
                setState(() {
                  _selectedArchetype = val;
                  _npcNameCtrl.text = val.defaultName;
                });
              }
            },
          ),
          const SizedBox(height: 10),

          // Nome PNG
          TextField(
            controller: _npcNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nome o Identità del PNG',
              hintText: 'Es. Fixer Martinez',
            ),
          ),
          const SizedBox(height: 10),

          // Tono
          DropdownButtonFormField<NpcTone>(
            initialValue: _selectedTone,
            decoration: const InputDecoration(labelText: 'Tono della Risposta'),
            items: NpcTone.values.map((NpcTone t) {
              return DropdownMenuItem<NpcTone>(
                value: t,
                child: Text(t.label, style: CprType.body.copyWith(fontSize: 12)),
              );
            }).toList(),
            onChanged: (NpcTone? val) {
              if (val != null) setState(() => _selectedTone = val);
            },
          ),
          const SizedBox(height: 10),

          // Situazione o Argomento
          TextField(
            controller: _npcSituationCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Cosa sta succedendo? (Argomento / Contesto)',
              hintText: 'Es. Vuole 2000 eddies per il chip di accesso.',
            ),
          ),
          const SizedBox(height: 14),

          // Pulsante Genera
          TechButton(
            label: ai.isGenerating ? 'Generazione in corso…' : 'Genera Battuta PNG con IA',
            icon: Icons.auto_awesome,
            variant: TechButtonVariant.primary,
            compact: true,
            onPressed: ai.isGenerating
                ? () {}
                : () async {
                    final String res = await ai.generateNpcDialogue(
                      archetype: _selectedArchetype,
                      tone: _selectedTone,
                      npcName: _npcNameCtrl.text.trim(),
                      situationOrTopic: _npcSituationCtrl.text.trim(),
                    );
                    setState(() => _generatedNpcDialogue = res);
                  },
          ),

          if (_generatedNpcDialogue.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                border: Border.all(color: CprPalette.cyan, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(Icons.format_quote, size: 16, color: CprPalette.cyan),
                      const SizedBox(width: 6),
                      Text(
                        _npcNameCtrl.text.trim().toUpperCase(),
                        style: CprType.label.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: CprPalette.cyan,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _generatedNpcDialogue,
                    style: CprType.body.copyWith(fontSize: 12.5, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 12),
                  TechButton(
                    label: 'INVIA AL TAVOLO COME "${_npcNameCtrl.text.trim().toUpperCase()}"',
                    icon: Icons.send,
                    variant: TechButtonVariant.secondary,
                    compact: true,
                    onPressed: () {
                      final String speaker = _npcNameCtrl.text.trim().isNotEmpty
                          ? _npcNameCtrl.text.trim()
                          : _selectedArchetype.defaultName;

                      // Invio al tavolo chat
                      state.masterChat(
                        '[$speaker]: "$_generatedNpcDialogue"',
                      );

                      showTechMessage(
                        context,
                        title: 'Messaggio Inviato al Tavolo',
                        message: 'La battuta di $speaker è stata trasmessa a tutti i giocatori.',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- TAB 2: REGOLE & LORE --------------------------------------------------

  Widget _buildRulesChatTab(BuildContext context, AiAssistantService ai) {
    return Column(
      children: <Widget>[
        Expanded(
          child: ListenableBuilder(
            listenable: ai,
            builder: (BuildContext context, _) {
              if (ai.messages.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.psychology_outlined, size: 36, color: CprPalette.inkFaint),
                        const SizedBox(height: 12),
                        Text(
                          'Chiedi qualsiasi regola di Cyberpunk RED o spunto per la tua campagna a Night City.',
                          textAlign: TextAlign.center,
                          style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: ai.messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final AiChatMessage m = ai.messages[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: m.isUser ? CprPalette.surfaceSunken : CprPalette.surface,
                      border: Border.all(
                        color: m.isUser ? CprPalette.hairline : CprPalette.cyan.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          m.sender,
                          style: CprType.label.copyWith(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: m.isUser ? CprPalette.yellow : CprPalette.cyan,
                          ),
                        ),
                        const SizedBox(height: 4),
                        m.isUser
                            ? Text(
                                m.text,
                                style: CprType.body.copyWith(fontSize: 12, height: 1.35),
                              )
                            : CyberMarkdownView(
                                markdown: m.text,
                                accent: CprPalette.cyan,
                              ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CprPalette.surface,
            border: Border(top: BorderSide(color: CprPalette.hairline)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _promptCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Chiedi una regola (es. Tiro della morte)…',
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  onSubmitted: (_) => _sendPrompt(ai),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.send, size: 18, color: CprPalette.cyan),
                onPressed: () => _sendPrompt(ai),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendPrompt(AiAssistantService ai) {
    final String text = _promptCtrl.text.trim();
    if (text.isEmpty) return;
    _promptCtrl.clear();
    ai.askAssistant(text);
  }

  Future<void> _promptConfigApiKey(BuildContext context, AiAssistantService ai) async {
    final TextEditingController keyCtrl = TextEditingController(text: ai.geminiApiKey);

    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: CprPalette.surface,
        title: Text('Chiave API Google Gemini (Gratuita)', style: CprType.body.copyWith(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Puoi usare gratuitamente il modello Gemini 1.5/2.0 Flash di Google ottenendo una chiave API gratuita da Google AI Studio (aistudio.google.com). Se lasci vuoto, l\'app usa il motore locale integrato.',
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(
                labelText: 'Chiave API Google Gemini',
                hintText: 'AIzaSy...',
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annulla')),
          TechButton(
            label: 'Salva Chiave',
            variant: TechButtonVariant.primary,
            compact: true,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (ok == true) {
      ai.saveGeminiApiKey(keyCtrl.text.trim());
    }
  }
}
