import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_state.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/campaign.dart';
import '../../domain/campaign_combat.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../ai/ai_assistant_service.dart';
import 'session_transcriber.dart';

/// Sezione dedicata: Riepiloghi & Diario delle Sessioni.
///
/// Permette al Master di:
/// - Visualizzare lo stato della sessione dal vivo (durata, trascrittore vocale).
/// - Avviare o terminare la sessione live con compilazione automatica del commit IA.
/// - Consultare l'elenco completo di tutti i commit archiviati.
/// - Esaminare per ciascuna sessione: riassunto unificato IA, note Master,
///   riassunti specifici per singolo Edgerunner, eventi chiave e trascrizione audio grezza.
/// - Esportare i riassunti in formato Markdown o copiarli negli appunti.
/// - Rigenerare le analisi tramite IA o inserire commit retroattivi manuali.
class SessionSummariesSection extends StatefulWidget {
  const SessionSummariesSection({super.key});

  @override
  State<SessionSummariesSection> createState() => _SessionSummariesSectionState();
}

class _SessionSummariesSectionState extends State<SessionSummariesSection> {
  String _searchQuery = '';
  final TextEditingController _quickSpeechCtrl = TextEditingController();
  Timer? _liveTimer;
  Duration _sessionDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final AppState state = AppScope.of(context);
      if (state.isSessionLive && state.sessionStartTime != null) {
        if (mounted) {
          setState(() {
            _sessionDuration = DateTime.now().difference(state.sessionStartTime!);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _quickSpeechCtrl.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final String h = d.inHours.toString().padLeft(2, '0');
    final String m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final String s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final Campaign? campaign = state.campaign;
    if (campaign == null) return const SizedBox.shrink();

    final List<CampaignSessionCommit> commits = campaign.sessionCommits;
    final List<CampaignSessionCommit> filteredCommits = _searchQuery.trim().isEmpty
        ? commits.reversed.toList()
        : commits.reversed.where((CampaignSessionCommit c) {
            final String q = _searchQuery.toLowerCase();
            return c.title.toLowerCase().contains(q) ||
                c.date.toLowerCase().contains(q) ||
                c.aiSummary.toLowerCase().contains(q) ||
                c.masterNotes.toLowerCase().contains(q);
          }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Live Session Controller Panel
              _buildLiveControlCard(context, state, campaign),
              const SizedBox(height: 18),

              // Search & Filter Header
              Row(
                children: <Widget>[
                  Expanded(
                    child: TechField(
                      label: 'Cerca nei riepiloghi e trascrizioni',
                      hint: 'Filtra per titolo, data, parole chiave o eventi...',
                      value: _searchQuery,
                      accent: CprPalette.yellow,
                      suffix: Icon(Icons.search, size: 18, color: CprPalette.yellow),
                      onChanged: (String val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TechButton(
                    label: 'Nuovo Commit Manuale',
                    icon: Icons.note_add_outlined,
                    variant: TechButtonVariant.secondary,
                    tooltip: 'Crea una voce di diario senza avviare la registrazione dal vivo',
                    onPressed: () => _showManualCommitDialog(context, state, campaign),
                  ),
                  const SizedBox(width: 8),
                  TechButton(
                    label: 'Esporta Tutto (.md)',
                    icon: Icons.file_download_outlined,
                    variant: TechButtonVariant.ghost,
                    tooltip: 'Copia tutti i riepiloghi in formato Markdown completo',
                    onPressed: commits.isEmpty ? null : () => _exportAllMarkdown(context, commits),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Commits List
              if (commits.isEmpty)
                _buildEmptyState(context, state, campaign)
              else if (filteredCommits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'Nessun riepilogo trovato per "$_searchQuery".',
                      style: CprType.body.copyWith(color: CprPalette.inkMuted),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredCommits.length,
                  separatorBuilder: (BuildContext _, int index) => const SizedBox(height: 16),
                  itemBuilder: (BuildContext context, int index) {
                    final CampaignSessionCommit commit = filteredCommits[index];
                    return _SessionCommitCard(
                      commit: commit,
                      onDelete: () => _deleteCommit(state, commit),
                      onRegenerateAi: () => _regenerateAiSummary(context, state, commit),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveControlCard(BuildContext context, AppState state, Campaign campaign) {
    final bool isLive = state.isSessionLive;
    final SessionVoiceTranscriber transcriber = SessionVoiceTranscriber.instance;

    return ChamferPanel(
      title: isLive ? 'SESSIONE DAL VIVO IN CORSO' : 'STATO SESSIONE DI GIOCO',
      accent: isLive ? CprPalette.danger : CprPalette.cyan,
      trailing: isLive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CprPalette.danger.withValues(alpha: 0.15),
                border: Border.all(color: CprPalette.danger),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.timer_outlined, size: 15, color: CprPalette.danger),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(_sessionDuration),
                    style: CprType.mono(
                      CprPalette.danger,
                      size: 13,
                      weight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!isLive) ...<Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CprPalette.surfaceRaised,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CprPalette.hairline),
                  ),
                  child: Icon(Icons.mic_off_outlined, color: CprPalette.inkMuted, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Nessuna sessione attiva al momento',
                        style: CprType.title.copyWith(fontSize: 15, color: CprPalette.ink),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Avvia la sessione quando il tavolo comincia a giocare: il microfono e la registrazione vocale si attiveranno automaticamente.',
                        style: CprType.caption.copyWith(color: CprPalette.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                TechButton(
                  label: 'Avvia Sessione & Mic',
                  icon: Icons.play_arrow_outlined,
                  variant: TechButtonVariant.primary,
                  onPressed: () => state.startLiveSession(),
                ),
              ],
            ),
          ] else ...<Widget>[
            Row(
              children: <Widget>[
                const SessionMicrophoneIndicator(),
                const SizedBox(width: 12),
                Text(
                  'Oratore Corrente: ${transcriber.currentSpeaker}',
                  style: CprType.mono(CprPalette.ink, size: 12),
                ),
                const Spacer(),
                TechButton(
                  label: 'Termina Sessione & Genera Riepilogo IA',
                  icon: Icons.stop_circle_outlined,
                  variant: TechButtonVariant.danger,
                  onPressed: () {
                    state.endLiveSession();
                    showDialog<void>(
                      context: context,
                      builder: (_) => EndSessionSummaryDialog(
                        campaign: campaign,
                        initialPlayerSummaries: state.pendingPlayerSummaries.values.toList(),
                        onSaveCommit: (CampaignSessionCommit commit) {
                          state.mutateCampaign((Campaign c) {
                            c.sessionCommits.add(commit);
                          });
                          state.pendingPlayerSummaries.clear();
                          state.appendSessionEvent(
                            description: 'Master: Sessione archiviata: ${commit.title} (ID: ${commit.id})',
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Quick speech insertion
            Row(
              children: <Widget>[
                Expanded(
                  child: TechField(
                    label: 'Inserisci battuta o azione rapida nel transcript dal vivo',
                    hint: 'Es: "L\'agente Militech attiva il camuffamento ottico..."',
                    value: _quickSpeechCtrl.text,
                    accent: CprPalette.danger,
                    onChanged: (String v) => _quickSpeechCtrl.text = v,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: TechButton(
                    label: 'Registra Nota',
                    icon: Icons.send_outlined,
                    variant: TechButtonVariant.secondary,
                    compact: true,
                    onPressed: () {
                      final String text = _quickSpeechCtrl.text.trim();
                      if (text.isNotEmpty) {
                        transcriber.appendSpeech(text);
                        _quickSpeechCtrl.clear();
                        setState(() {});
                      }
                    },
                  ),
                ),
              ],
            ),
            if (transcriber.recentEntries.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CprPalette.surfaceSunken,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: CprPalette.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'ULTIMI EVENTI REGISTRATI (${transcriber.recentEntries.length}):',
                      style: CprType.label.copyWith(fontSize: 10, color: CprPalette.danger),
                    ),
                    const SizedBox(height: 6),
                    ...transcriber.recentEntries.reversed.take(4).map(
                          (String e) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(
                              e,
                              style: CprType.mono(CprPalette.inkMuted, size: 11),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState state, Campaign campaign) {
    return ChamferPanel(
      title: 'DIARIO DI BORDO VUOTO',
      accent: CprPalette.yellow,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        child: Column(
          children: <Widget>[
            Icon(Icons.history_edu, size: 54, color: CprPalette.yellow.withValues(alpha: 0.8)),
            const SizedBox(height: 16),
            Text(
              'Nessuna sessione archiviata in questa campagna',
              style: CprType.title.copyWith(fontSize: 17, color: CprPalette.ink),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Text(
                'Quando avvii una sessione di gioco dal vivo, l\'app registra il parlato, sintetizza le azioni chiave dei singoli giocatori ed elabora automaticamente un riassunto narrativo cybernetico tramite Gemini IA.',
                textAlign: TextAlign.center,
                style: CprType.body.copyWith(color: CprPalette.inkMuted),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: <Widget>[
                TechButton(
                  label: 'Avvia Prima Sessione Live',
                  icon: Icons.play_arrow_outlined,
                  variant: TechButtonVariant.primary,
                  onPressed: () => state.startLiveSession(),
                ),
                TechButton(
                  label: 'Inserisci Sessione Manuale',
                  icon: Icons.edit_note_outlined,
                  variant: TechButtonVariant.secondary,
                  onPressed: () => _showManualCommitDialog(context, state, campaign),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showManualCommitDialog(BuildContext context, AppState state, Campaign campaign) {
    final int nextIndex = campaign.sessionCommits.length + 1;
    final DateTime now = DateTime.now();
    final String dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final String timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final TextEditingController titleCtrl =
        TextEditingController(text: 'Sessione #$nextIndex');
    final TextEditingController summaryCtrl = TextEditingController();
    final TextEditingController notesCtrl = TextEditingController();
    final TextEditingController eddiesCtrl = TextEditingController(text: '0');

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: CprPalette.surfaceRaised,
          title: Text('Nuovo Commit Manuale Sessione #$nextIndex', style: CprType.title),
          content: SizedBox(
            width: 580,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TechField(
                    label: 'Titolo Sessione',
                    hint: 'Es: Il colpo al magazzino Arasaka',
                    value: titleCtrl.text,
                    accent: CprPalette.yellow,
                    onChanged: (String v) => titleCtrl.text = v,
                  ),
                  const SizedBox(height: 12),
                  TechField(
                    label: 'Riassunto Generale / Narrativo',
                    hint: 'Descrivi cosa è successo al tavolo...',
                    value: summaryCtrl.text,
                    maxLines: 4,
                    accent: CprPalette.yellow,
                    onChanged: (String v) => summaryCtrl.text = v,
                  ),
                  const SizedBox(height: 12),
                  TechField(
                    label: 'Note Master (Segrete / Punti trama futuri)',
                    hint: 'Appunti riservati per le prossime sessioni...',
                    value: notesCtrl.text,
                    maxLines: 3,
                    accent: CprPalette.violet,
                    onChanged: (String v) => notesCtrl.text = v,
                  ),
                  const SizedBox(height: 12),
                  TechField(
                    label: 'Eurodollari (Eddies) Circolati / Guadagnati',
                    hint: '0',
                    value: eddiesCtrl.text,
                    accent: CprPalette.cyan,
                    onChanged: (String v) => eddiesCtrl.text = v,
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Annulla', style: TextStyle(color: CprPalette.inkMuted)),
            ),
            TechButton(
              label: 'Salva nel Diario',
              icon: Icons.check,
              variant: TechButtonVariant.primary,
              onPressed: () {
                final int eddies = int.tryParse(eddiesCtrl.text.trim()) ?? 0;
                final CampaignSessionCommit newCommit = CampaignSessionCommit(
                  id: 'commit_${DateTime.now().millisecondsSinceEpoch}',
                  sessionIndex: nextIndex,
                  date: dateStr,
                  time: timeStr,
                  title: titleCtrl.text.trim().isEmpty ? 'Sessione #$nextIndex' : titleCtrl.text.trim(),
                  aiSummary: summaryCtrl.text.trim(),
                  masterNotes: notesCtrl.text.trim(),
                  eddiesCirculated: eddies,
                );
                state.mutateCampaign((Campaign c) {
                  c.sessionCommits.add(newCommit);
                });
                state.appendSessionEvent(
                  description: 'Master: Aggiunto commit manuale: ${newCommit.title}',
                );
                Navigator.of(ctx).pop();
                setState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  void _deleteCommit(AppState state, CampaignSessionCommit commit) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: CprPalette.surfaceRaised,
        title: Text('Eliminare commit "${commit.title}"?', style: CprType.title),
        content: Text(
          'Questa operazione rimuoverà la trascrizione e il riepilogo archiviato dal diario della campagna.',
          style: CprType.body,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Annulla', style: TextStyle(color: CprPalette.inkMuted)),
          ),
          TechButton(
            label: 'Elimina',
            icon: Icons.delete_outline,
            variant: TechButtonVariant.danger,
            onPressed: () {
              state.mutateCampaign((Campaign c) {
                c.sessionCommits.removeWhere((CampaignSessionCommit item) => item.id == commit.id);
              });
              Navigator.of(ctx).pop();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Future<void> _regenerateAiSummary(
      BuildContext context, AppState state, CampaignSessionCommit commit) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Rielaborazione IA in corso per "${commit.title}"...'),
        backgroundColor: CprPalette.cyan,
      ),
    );

    final String newSummary = await AiAssistantService.instance.generateMasterMergedSessionSummary(
      sessionIndex: commit.sessionIndex,
      sessionTitle: commit.title,
      playerSummaries: commit.playerSummaries,
      masterNotes: commit.masterNotes,
      fullTranscript: commit.fullTranscript,
    );

    state.mutateCampaign((Campaign c) {
      final int idx = c.sessionCommits.indexWhere((CampaignSessionCommit item) => item.id == commit.id);
      if (idx != -1) {
        c.sessionCommits[idx].aiSummary = newSummary;
      }
    });

    messenger.showSnackBar(
      SnackBar(
        content: const Text('Riepilogo IA aggiornato con successo!'),
        backgroundColor: CprPalette.success,
      ),
    );
    setState(() {});
  }

  void _exportAllMarkdown(BuildContext context, List<CampaignSessionCommit> commits) {
    final StringBuffer sb = StringBuffer();
    sb.writeln('# DIARIO DI BORDO DELLA CAMPAGNA');
    sb.writeln('Generato il ${DateTime.now().toIso8601String().substring(0, 10)}\n');

    for (final CampaignSessionCommit commit in commits) {
      sb.writeln('---');
      sb.writeln('## Sessione #${commit.sessionIndex}: ${commit.title}');
      sb.writeln('**Data**: ${commit.date} ore ${commit.time} | **Eddies**: ${commit.eddiesCirculated} eb\n');
      if (commit.aiSummary.isNotEmpty) {
        sb.writeln('### Riepilogo Narrativo');
        sb.writeln(commit.aiSummary);
        sb.writeln();
      }
      if (commit.masterNotes.isNotEmpty) {
        sb.writeln('### Note del Game Master');
        sb.writeln(commit.masterNotes);
        sb.writeln();
      }
      if (commit.playerSummaries.isNotEmpty) {
        sb.writeln('### Dettagli Edgerunner');
        for (final PlayerSessionSummary p in commit.playerSummaries) {
          sb.writeln('- **${p.playerName}**: ${p.aiSummary.isNotEmpty ? p.aiSummary : p.transcript}');
        }
        sb.writeln();
      }
    }

    Clipboard.setData(ClipboardData(text: sb.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Tutti i riepiloghi copiati negli appunti in formato Markdown!'),
        backgroundColor: CprPalette.cyan,
      ),
    );
  }
}

/// Scheda espandibile per un singolo Commit di Sessione
class _SessionCommitCard extends StatefulWidget {
  const _SessionCommitCard({
    required this.commit,
    required this.onDelete,
    required this.onRegenerateAi,
  });

  final CampaignSessionCommit commit;
  final VoidCallback onDelete;
  final VoidCallback onRegenerateAi;

  @override
  State<_SessionCommitCard> createState() => _SessionCommitCardState();
}

class _SessionCommitCardState extends State<_SessionCommitCard> {
  bool _isExpanded = false;
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final CampaignSessionCommit c = widget.commit;

    return Container(
      decoration: BoxDecoration(
        color: CprPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: _isExpanded ? CprPalette.yellow : CprPalette.hairline,
          width: _isExpanded ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Header Row
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: CprPalette.yellow.withValues(alpha: 0.15),
                      border: Border.all(color: CprPalette.yellow),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '#${c.sessionIndex}',
                      style: CprType.mono(
                        CprPalette.yellow,
                        size: 13,
                        weight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          c.title,
                          style: CprType.title.copyWith(fontSize: 15, color: CprPalette.ink),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: <Widget>[
                            Icon(Icons.calendar_today, size: 12, color: CprPalette.inkMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${c.date} (${c.time})',
                              style: CprType.mono(CprPalette.inkMuted, size: 11),
                            ),
                            if (c.eddiesCirculated > 0) ...<Widget>[
                              const SizedBox(width: 12),
                              Icon(Icons.attach_money, size: 13, color: CprPalette.cyan),
                              Text(
                                '${c.eddiesCirculated} eb',
                                style: CprType.mono(CprPalette.cyan, size: 11),
                              ),
                            ],
                            if (c.playerSummaries.isNotEmpty) ...<Widget>[
                              const SizedBox(width: 12),
                              Icon(Icons.people_outline, size: 13, color: CprPalette.violet),
                              Text(
                                '${c.playerSummaries.length} PG',
                                style: CprType.mono(CprPalette.violet, size: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: CprPalette.inkMuted,
                    ),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (_isExpanded) ...<Widget>[
            Divider(height: 1, color: CprPalette.hairline),
            // Navigation Sub-tabs
            Container(
              color: CprPalette.surfaceSunken,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Row(
                children: <Widget>[
                  _buildSubTab(0, 'Riepilogo Narrativo', Icons.auto_awesome),
                  const SizedBox(width: 6),
                  _buildSubTab(1, 'Note Master', Icons.lock_outline),
                  const SizedBox(width: 6),
                  _buildSubTab(2, 'Partecipanti (${c.playerSummaries.length})', Icons.group_outlined),
                  const SizedBox(width: 6),
                  _buildSubTab(3, 'Trascrizione Audio', Icons.text_snippet_outlined),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16),
                    tooltip: 'Copia Riepilogo',
                    color: CprPalette.inkMuted,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: c.aiSummary.isNotEmpty ? c.aiSummary : c.masterNotes));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Riepilogo copiato negli appunti!'),
                          backgroundColor: CprPalette.yellow,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 16),
                    tooltip: 'Rigenera Riepilogo IA',
                    color: CprPalette.cyan,
                    onPressed: widget.onRegenerateAi,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16),
                    tooltip: 'Elimina Commit',
                    color: CprPalette.danger,
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildSelectedTabContent(c),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubTab(int index, String label, IconData icon) {
    final bool active = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? CprPalette.surfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: active ? CprPalette.hairlineBright : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 14, color: active ? CprPalette.yellow : CprPalette.inkMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: CprType.label.copyWith(
                fontSize: 11,
                color: active ? CprPalette.ink : CprPalette.inkMuted,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent(CampaignSessionCommit c) {
    switch (_selectedTab) {
      case 0:
        return SelectableText(
          c.aiSummary.isNotEmpty
              ? c.aiSummary
              : 'Nessun riepilogo generato per questa sessione.',
          style: CprType.body.copyWith(color: CprPalette.ink, height: 1.5),
        );
      case 1:
        return SelectableText(
          c.masterNotes.isNotEmpty ? c.masterNotes : 'Nessuna nota riservata inserita dal Master.',
          style: CprType.body.copyWith(color: CprPalette.inkMuted, height: 1.4),
        );
      case 2:
        if (c.playerSummaries.isEmpty) {
          return Text(
            'Nessun dato individuale salvato per i giocatori.',
            style: CprType.body.copyWith(color: CprPalette.inkMuted),
          );
        }
        return Column(
          children: c.playerSummaries.map((PlayerSessionSummary p) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CprPalette.surfaceSunken,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: CprPalette.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    p.playerName,
                    style: CprType.title.copyWith(fontSize: 13, color: CprPalette.cyan),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(
                    p.aiSummary.isNotEmpty ? p.aiSummary : p.transcript,
                    style: CprType.caption.copyWith(color: CprPalette.ink, height: 1.4),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      case 3:
      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: CprPalette.voidBlack,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: CprPalette.hairline),
          ),
          child: SelectableText(
            c.fullTranscript.isNotEmpty ? c.fullTranscript : '[Trascrizione vuota o non registrata]',
            style: CprType.mono(CprPalette.inkMuted, size: 11),
          ),
        );
    }
  }
}
