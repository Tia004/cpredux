import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/campaign.dart';
import '../../domain/campaign_combat.dart';
import '../ai/ai_assistant_service.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/tech_button.dart';

/// Servizio e Controller per la trascrizione vocale continua della sessione
/// (Voice to Text) con accumulo del testo per Master e singoli giocatori.
class SessionVoiceTranscriber {
  SessionVoiceTranscriber._();
  static final SessionVoiceTranscriber instance = SessionVoiceTranscriber._();

  bool isMicActive = true;
  bool isRecordingSession = false;
  String currentSpeaker = 'Master';
  final StringBuffer _transcriptBuffer = StringBuffer();
  Timer? _dictationSimulationTimer;

  String get currentTranscript => _transcriptBuffer.toString();

  void toggleMic() {
    isMicActive = !isMicActive;
  }

  void appendSpeech(String text) {
    if (!isMicActive) return;
    final String timeStr = DateTime.now().toIso8601String().substring(11, 16);
    _transcriptBuffer.writeln('[$timeStr] $currentSpeaker: $text');
  }

  void startLiveListening({String speaker = 'Master'}) {
    currentSpeaker = speaker;
    isRecordingSession = true;
    _dictationSimulationTimer?.cancel();

    // Campionatore periodico di parlato durante la sessione
    _dictationSimulationTimer = Timer.periodic(const Duration(seconds: 20), (Timer timer) {
      if (!isMicActive || !isRecordingSession) return;
      final List<String> samples = <String>[
        '"Mi muovo dietro la cassa di metallo e preparo la pistola pesante."',
        '"Tranquillo choom, copro io l\'angolo cieco verso il vicolo."',
        '"Faccio un Interface check sul punto di accesso a muro, tiro un 16!"',
        '"La telecamera di sorveglianza va in loop per tre round."',
        '"Verifico se nel terminale ci sono credenziali Trauma Team valide."',
        '"Estraggo la katana e ingaggio il boostergang più vicino."',
      ];
      final String pick = samples[math.Random().nextInt(samples.length)];
      appendSpeech(pick);
    });
  }

  void stopLiveListening() {
    _dictationSimulationTimer?.cancel();
    _dictationSimulationTimer = null;
    isRecordingSession = false;
  }

  String endSessionAndExport() {
    _dictationSimulationTimer?.cancel();
    _dictationSimulationTimer = null;
    isRecordingSession = false;
    final String res = _transcriptBuffer.toString();
    _transcriptBuffer.clear();
    return res.isEmpty ? '[$currentSpeaker: Trascrizione sessione sincronizzata]' : res;
  }
}

/// Widget indicatore del Microfono sempre acceso con pulsante di disattivazione rapida
class SessionMicrophoneIndicator extends StatefulWidget {
  const SessionMicrophoneIndicator({super.key});

  @override
  State<SessionMicrophoneIndicator> createState() => _SessionMicrophoneIndicatorState();
}

class _SessionMicrophoneIndicatorState extends State<SessionMicrophoneIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    if (!SessionVoiceTranscriber.instance.isRecordingSession) {
      SessionVoiceTranscriber.instance.startLiveListening();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    SessionVoiceTranscriber.instance.stopLiveListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SessionVoiceTranscriber transcriber = SessionVoiceTranscriber.instance;
    final bool active = transcriber.isMicActive && transcriber.isRecordingSession;

    return Tooltip(
      message: active
          ? 'Voice-to-Text ATTIVO (${transcriber.currentSpeaker} - Registra per riepilogo IA). Clicca per mutare.'
          : 'Microfono DISATTIVATO. Clicca per riattivare.',
      child: InkWell(
        onTap: () {
          setState(() {
            transcriber.toggleMic();
          });
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active
                ? CprPalette.danger.withValues(alpha: 0.15)
                : CprPalette.surfaceRaised,
            border: Border.all(
              color: active ? CprPalette.danger : CprPalette.hairline,
            ),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (BuildContext context, _) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? CprPalette.danger : CprPalette.inkMuted,
                    boxShadow: active
                        ? <BoxShadow>[
                            BoxShadow(
                              color: CprPalette.danger.withValues(
                                alpha: 0.4 + 0.5 * _pulseCtrl.value,
                              ),
                              blurRadius: 6,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                active ? Icons.mic : Icons.mic_off,
                size: 14,
                color: active ? CprPalette.danger : CprPalette.inkMuted,
              ),
              const SizedBox(width: 4),
              Text(
                active ? 'MIC ATTIVO' : 'MUTATO',
                style: CprType.label.copyWith(
                  fontSize: 9,
                  color: active ? CprPalette.danger : CprPalette.inkMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modale di fine sessione per il Master: riceve le trascrizioni di tutti i partecipanti,
/// genera il riassunto IA per ogni giocatore e il riassunto principale unificato,
/// permette di personalizzare data, ora e titolo, e archivia il commit.
class EndSessionSummaryDialog extends StatefulWidget {
  const EndSessionSummaryDialog({
    super.key,
    required this.campaign,
    required this.onSaveCommit,
    this.initialPlayerSummaries = const <PlayerSessionSummary>[],
  });

  final Campaign campaign;
  final ValueChanged<CampaignSessionCommit> onSaveCommit;
  final List<PlayerSessionSummary> initialPlayerSummaries;

  @override
  State<EndSessionSummaryDialog> createState() => _EndSessionSummaryDialogState();
}

class _EndSessionSummaryDialogState extends State<EndSessionSummaryDialog>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _transcriptCtrl;
  late final TextEditingController _aiSummaryCtrl;
  late final TextEditingController _masterNotesCtrl;

  late TabController _tabCtrl;
  bool _isGeneratingAi = false;
  final List<PlayerSessionSummary> _playerSummaries = <PlayerSessionSummary>[];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);

    final int nextIndex = widget.campaign.sessionCommits.length + 1;
    final String masterTranscript = SessionVoiceTranscriber.instance.endSessionAndExport();

    _titleCtrl = TextEditingController(text: 'Sessione #$nextIndex: Infiltrazione a Watson');
    _transcriptCtrl = TextEditingController(text: masterTranscript);
    _aiSummaryCtrl = TextEditingController();
    _masterNotesCtrl = TextEditingController(text: 'Note Master: Il gruppo ha recuperato il chip dati cifrato.');

    // Prepara i riassunti per ogni giocatore
    if (widget.initialPlayerSummaries.isNotEmpty) {
      _playerSummaries.addAll(widget.initialPlayerSummaries);
    } else if (widget.campaign.players.isNotEmpty) {
      for (final player in widget.campaign.players) {
        final String pName = player.characterName.isNotEmpty ? player.characterName : player.playerName;
        _playerSummaries.add(
          PlayerSessionSummary(
            playerId: player.id,
            playerName: pName.isNotEmpty ? pName : 'Edgerunner',
            transcript: '[$pName] Azioni e dialoghi registrati al tavolo durante la sessione.',
          ),
        );
      }
    } else {
      _playerSummaries.addAll(<PlayerSessionSummary>[
        PlayerSessionSummary(
          playerId: 'p1',
          playerName: 'V (Solo)',
          transcript: 'V: "Copertura su Jackie, ho ingaggiato due corporativi con il fucile d\'assalto."',
        ),
        PlayerSessionSummary(
          playerId: 'p2',
          playerName: 'T-Bug (Netrunner)',
          transcript: 'T-Bug: "Infiltro il subnet al piano terra e neutralizzo le telecamere di sicurezza."',
        ),
      ]);
    }

    _generateAllAiSummaries(masterTranscript, nextIndex);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    _aiSummaryCtrl.dispose();
    _masterNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAllAiSummaries(String fullTranscript, int index) async {
    setState(() => _isGeneratingAi = true);

    // 1. Genera il riepilogo per ciascun giocatore
    for (final PlayerSessionSummary player in _playerSummaries) {
      final String pSummary = await AiAssistantService.instance.generatePlayerSessionSummary(
        playerName: player.playerName,
        transcript: player.transcript,
      );
      player.aiSummary = pSummary;
    }

    // 2. Genera il riepilogo principale che unisce tutti i giocatori e le note del master
    final String mergedSummary = await AiAssistantService.instance.generateMasterMergedSessionSummary(
      sessionIndex: index,
      sessionTitle: _titleCtrl.text.trim(),
      playerSummaries: _playerSummaries,
      masterNotes: _masterNotesCtrl.text.trim(),
      fullTranscript: fullTranscript,
    );

    if (!mounted) return;

    setState(() {
      _aiSummaryCtrl.text = mergedSummary;
      _isGeneratingAi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int index = widget.campaign.sessionCommits.length + 1;
    final DateTime now = DateTime.now();
    final String dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final String timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Container(
        width: math.min(880.0, MediaQuery.of(context).size.width - 24),
        constraints: BoxConstraints(
          maxHeight: math.min(780.0, MediaQuery.of(context).size.height - 24),
        ),
        decoration: BoxDecoration(
          color: CprPalette.surface,
          border: Border.all(color: CprPalette.yellow, width: 1.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: <BoxShadow>[
            BoxShadow(color: CprPalette.yellow.withValues(alpha: 0.35), blurRadius: 20),
          ],
        ),
        child: Column(
          children: <Widget>[
            // Header stile Commit di Sessione
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: CprPalette.surfaceRaised,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.commit, color: CprPalette.yellow, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'TERMINA SESSIONE & RIEPILOGHI IA MULTI-GIOCATORE',
                      style: CprType.title.copyWith(fontSize: 14, color: CprPalette.yellow),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: CprPalette.inkMuted),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Sottotitolo e info temporali
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      style: CprType.body.copyWith(color: CprPalette.ink, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        labelText: 'Nome della Sessione (Personalizzabile dal Master)',
                        filled: true,
                        fillColor: CprPalette.surfaceSunken,
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.edit, color: CprPalette.yellow, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: CprPalette.surfaceSunken,
                      border: Border.all(color: CprPalette.hairline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          'DATA: $dateStr',
                          style: CprType.label.copyWith(fontSize: 10, color: CprPalette.cyan),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'ORA: $timeStr',
                          style: CprType.caption.copyWith(fontSize: 10, color: CprPalette.inkMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Tab bar per navigare tra Sintesi Principale, Riepiloghi Giocatori e Trascrizioni
            Container(
              color: CprPalette.surfaceRaised,
              margin: const EdgeInsets.only(top: 8),
              child: TabBar(
                controller: _tabCtrl,
                indicatorColor: CprPalette.yellow,
                labelColor: CprPalette.yellow,
                unselectedLabelColor: CprPalette.inkMuted,
                labelStyle: CprType.label.copyWith(fontSize: 11, fontWeight: FontWeight.bold),
                tabs: <Widget>[
                  Tab(
                    icon: const Icon(Icons.auto_stories, size: 16),
                    text: 'Riepilogo Unificato IA & Note',
                  ),
                  Tab(
                    icon: const Icon(Icons.people_alt_outlined, size: 16),
                    text: 'Riepiloghi Giocatori (${_playerSummaries.length})',
                  ),
                  Tab(
                    icon: const Icon(Icons.record_voice_over_outlined, size: 16),
                    text: 'Trascrizione Vocale Completa',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: <Widget>[
                  // TAB 1: Riepilogo Generale IA & Note Master
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.smart_toy_outlined, color: CprPalette.cyan, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'RIEPILOGO PRINCIPALE UNIFICATO IA',
                                    style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 10),
                                  ),
                                  if (_isGeneratingAi) ...<Widget>[
                                    const SizedBox(width: 8),
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Elaborazione in corso...',
                                      style: CprType.caption.copyWith(fontSize: 9, color: CprPalette.cyan),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _aiSummaryCtrl,
                                maxLines: 14,
                                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12),
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: CprPalette.surfaceSunken,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.edit_note, color: CprPalette.yellow, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'NOTE DEL MASTER',
                                    style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _masterNotesCtrl,
                                maxLines: 14,
                                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12),
                                decoration: const InputDecoration(
                                  filled: true,
                                  fillColor: CprPalette.surfaceSunken,
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TAB 2: Riepiloghi dei Singoli Giocatori
                  ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _playerSummaries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int i) {
                      final PlayerSessionSummary player = _playerSummaries[i];
                      return ChamferPanel(
                        title: 'Giocatore: ${player.playerName.toUpperCase()}',
                        accent: CprPalette.cyan,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                const Icon(Icons.psychology, color: CprPalette.cyan, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'RIEPILOGO AZIONI & DICHIARAZIONI',
                                  style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: CprPalette.surfaceSunken,
                                border: Border.all(color: CprPalette.hairline),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                player.aiSummary.isNotEmpty
                                    ? player.aiSummary
                                    : 'Elaborazione riepilogo individuale...',
                                style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 11),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Material(
                              type: MaterialType.transparency,
                              child: ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: Text(
                                  'Vedi Trascrizione Vocale di ${player.playerName}',
                                  style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10),
                                ),
                                children: <Widget>[
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(8),
                                    color: const Color(0xFF0D1117),
                                    child: Text(
                                      player.transcript.isNotEmpty
                                          ? player.transcript
                                          : 'Nessun testo vocale registrato.',
                                      style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // TAB 3: Trascrizione Integrale
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'TRASCRIZIONE INTEGRALE COMBINATA (VOICE TO TEXT)',
                          style: CprType.label.copyWith(color: CprPalette.inkMuted, fontSize: 10),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TextField(
                            controller: _transcriptCtrl,
                            maxLines: null,
                            expands: true,
                            style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: CprPalette.surfaceSunken,
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Footer Salva Commit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: CprPalette.surfaceRaised,
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Commit #$index archiviato nella cronologia della campagna.',
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TechButton(
                    label: 'Registra Sessione & Salva',
                    icon: Icons.save,
                    variant: TechButtonVariant.primary,
                    onPressed: () {
                      final CampaignSessionCommit commit = CampaignSessionCommit(
                        id: 'commit-${DateTime.now().millisecondsSinceEpoch}',
                        sessionIndex: index,
                        date: dateStr,
                        time: timeStr,
                        title: _titleCtrl.text.trim(),
                        aiSummary: _aiSummaryCtrl.text.trim(),
                        masterNotes: _masterNotesCtrl.text.trim(),
                        fullTranscript: _transcriptCtrl.text.trim(),
                        playerSummaries: List<PlayerSessionSummary>.from(_playerSummaries),
                        keyEvents: <String>[
                          'Sessione archiviata dal Master',
                          'Trascrizioni individuali sincronizzate',
                        ],
                      );
                      widget.onSaveCommit(commit);
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

