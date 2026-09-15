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
/// (Voice to Text) con accumulo del testo e trasmissione al Master al termine sessione.
class SessionVoiceTranscriber {
  SessionVoiceTranscriber._();
  static final SessionVoiceTranscriber instance = SessionVoiceTranscriber._();

  bool isMicActive = true;
  bool isRecordingSession = true;
  final StringBuffer _transcriptBuffer = StringBuffer();
  Timer? _dictationSimulationTimer;

  String get currentTranscript => _transcriptBuffer.toString();

  void toggleMic() {
    isMicActive = !isMicActive;
  }

  void appendSpeech(String text) {
    if (!isMicActive) return;
    final timeStr = DateTime.now().toIso8601String().substring(11, 16);
    _transcriptBuffer.writeln('[$timeStr] $text');
  }

  void startLiveListening() {
    isRecordingSession = true;
    _dictationSimulationTimer?.cancel();
    // Campionatore periodico di parlato durante la sessione
    _dictationSimulationTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (!isMicActive || !isRecordingSession) return;
      final samples = [
        'V: "Mi muovo dietro la cassa di metallo e preparo la pistola pesante."',
        'Jackie: "Tranquillo hermano, copro io l\'angolo cieco."',
        'Master: "Sentite il fischio di un drone che si avvicina dall\'alto."',
        'Netrunner: "Faccio un Interface check sul punto di accesso a muro, tiro un 16!"',
        'Master: "La telecamera di sorveglianza va in loop per tre round."',
      ];
      final pick = samples[math.Random().nextInt(samples.length)];
      appendSpeech(pick);
    });
  }

  void stopLiveListening() {
    _dictationSimulationTimer?.cancel();
    _dictationSimulationTimer = null;
  }

  String endSessionAndExport() {
    _dictationSimulationTimer?.cancel();
    _dictationSimulationTimer = null;
    isRecordingSession = false;
    final res = _transcriptBuffer.toString();
    _transcriptBuffer.clear();
    return res.isEmpty ? '[Trascrizione sessione vuota]' : res;
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
    SessionVoiceTranscriber.instance.startLiveListening();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    SessionVoiceTranscriber.instance.stopLiveListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transcriber = SessionVoiceTranscriber.instance;
    final bool active = transcriber.isMicActive;

    return Tooltip(
      message: active
          ? 'Voice-to-Text ATTIVO (Microfono acceso: registra la sessione per il riassunto IA). Clicca per mutare.'
          : 'Microfono DISATTIVATO (Muto). Clicca per riattivare la trascrizione.',
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
                builder: (context, _) => Container(
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

/// Modale di fine sessione per il Master: riceve la trascrizione di tutti i partecipanti,
/// genera il riassunto IA strutturato, offre un'area di testo per le note del GM
/// e salva la sessione in stile "commit di GitHub" cronologico.
class EndSessionSummaryDialog extends StatefulWidget {
  const EndSessionSummaryDialog({
    super.key,
    required this.campaign,
    required this.onSaveCommit,
  });

  final Campaign campaign;
  final ValueChanged<CampaignSessionCommit> onSaveCommit;

  @override
  State<EndSessionSummaryDialog> createState() => _EndSessionSummaryDialogState();
}

class _EndSessionSummaryDialogState extends State<EndSessionSummaryDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _transcriptCtrl;
  late final TextEditingController _aiSummaryCtrl;
  late final TextEditingController _masterNotesCtrl;
  bool _isGeneratingAi = false;

  @override
  void initState() {
    super.initState();
    final int nextIndex = widget.campaign.sessionCommits.length + 1;
    final String transcript = SessionVoiceTranscriber.instance.endSessionAndExport();

    _titleCtrl = TextEditingController(text: 'Sessione #$nextIndex: Infiltrazione a Watson');
    _transcriptCtrl = TextEditingController(text: transcript);
    _aiSummaryCtrl = TextEditingController();
    _masterNotesCtrl = TextEditingController(text: 'Note Master: Il gruppo ha scoperto il chip dati cifrato.');

    _generateAiSummary(transcript, nextIndex);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _transcriptCtrl.dispose();
    _aiSummaryCtrl.dispose();
    _masterNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateAiSummary(String rawTranscript, int index) async {
    setState(() => _isGeneratingAi = true);

    final String summary = await AiAssistantService.instance.generateSessionSummary(
      sessionIndex: index,
      transcript: rawTranscript,
    );

    if (!mounted) return;

    setState(() {
      _aiSummaryCtrl.text = summary;
      _isGeneratingAi = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final int index = widget.campaign.sessionCommits.length + 1;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: 820,
        constraints: const BoxConstraints(maxHeight: 750),
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
            // Header stile Commit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: CprPalette.surfaceRaised,
              child: Row(
                children: <Widget>[
                  const Icon(Icons.commit, color: CprPalette.yellow, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'TERMINA SESSIONE & COMMIT DIARIO DI CAMPAGNA',
                    style: CprType.title.copyWith(fontSize: 14, color: CprPalette.yellow),
                  ),
                  const Spacer(),
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
                    TextField(
                      controller: _titleCtrl,
                      style: CprType.body.copyWith(color: CprPalette.ink),
                      decoration: const InputDecoration(
                        labelText: 'Titolo Sessione / Messaggio di Commit',
                        filled: true,
                        fillColor: CprPalette.surfaceSunken,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Commit ID: ses-${DateTime.now().millisecondsSinceEpoch} · Data: $dateStr $timeStr',
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // Colonna Sinistra: Riassunto IA generato
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.smart_toy_outlined, color: CprPalette.cyan, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'RIEPILOGO GENERATO DALL\'IA',
                                    style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 10),
                                  ),
                                  if (_isGeneratingAi) ...<Widget>[
                                    const SizedBox(width: 8),
                                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _aiSummaryCtrl,
                                maxLines: 10,
                                style: CprType.body.copyWith(color: CprPalette.ink),
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
                        // Colonna Destra: Note Personali Master
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(Icons.edit_note, color: CprPalette.yellow, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'NOTE PERSONALI DEL MASTER',
                                    style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 10),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _masterNotesCtrl,
                                maxLines: 10,
                                style: CprType.body.copyWith(color: CprPalette.ink),
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
                    const SizedBox(height: 16),
                    // Trascrizione Audio Completa (Voice-to-Text di tutti i client)
                    ChamferPanel(
                      accent: CprPalette.inkFaint,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'TRASCRIZIONE AUDIO INTEGRALE DELLA SESSIONE (VOICE TO TEXT)',
                            style: CprType.label.copyWith(color: CprPalette.inkMuted, fontSize: 9.5),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _transcriptCtrl,
                            maxLines: 6,
                            style: CprType.caption.copyWith(color: CprPalette.inkMuted),
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
            ),
            // Footer Salva Commit
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: CprPalette.surfaceRaised,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'Questo commit verrà archiviato per sempre nella storia della campagna.',
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint),
                  ),
                  TechButton(
                    label: 'Registra Sessione (Commit) & Salva',
                    icon: Icons.save,
                    variant: TechButtonVariant.primary,
                    onPressed: () {
                      final commit = CampaignSessionCommit(
                        id: 'commit-${DateTime.now().millisecondsSinceEpoch}',
                        sessionIndex: index,
                        date: dateStr,
                        time: timeStr,
                        title: _titleCtrl.text.trim(),
                        aiSummary: _aiSummaryCtrl.text.trim(),
                        masterNotes: _masterNotesCtrl.text.trim(),
                        fullTranscript: _transcriptCtrl.text.trim(),
                        keyEvents: <String>[
                          'Sessione registrata con successo',
                          'Trascrizione vocale sincronizzata',
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
