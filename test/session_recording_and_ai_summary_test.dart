import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cpredux/domain/campaign.dart';
import 'package:cpredux/domain/campaign_combat.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/features/ai/ai_assistant_service.dart';
import 'package:cpredux/features/campaign/session_transcriber.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Session Recording & Player AI Summaries Model Tests', () {
    test('PlayerSessionSummary serializzazione e deserializzazione JSON', () {
      final PlayerSessionSummary player = PlayerSessionSummary(
        playerId: 'p-101',
        playerName: 'Johnny Silverhand',
        transcript: 'Johnny: "Distruggiamo la torre dell\'Arasaka."',
        aiSummary: '• Ha guidato l\'assalto\n• Ha dichiarato fuoco di copertura',
        keyActions: <String>['Infiltrazione', 'Spari'],
      );

      final Map<String, Object?> json = player.toJson();
      final PlayerSessionSummary restored = PlayerSessionSummary.fromJson(json);

      expect(restored.playerId, equals('p-101'));
      expect(restored.playerName, equals('Johnny Silverhand'));
      expect(restored.transcript, contains('Arasaka'));
      expect(restored.aiSummary, contains('Ha guidato'));
      expect(restored.keyActions, contains('Infiltrazione'));
    });

    test('CampaignSessionCommit con riepiloghi multi-giocatore e titolo personalizzato', () {
      final CampaignSessionCommit commit = CampaignSessionCommit(
        id: 'commit-12345',
        sessionIndex: 3,
        date: '2077-10-15',
        time: '21:30',
        title: 'Operazione Fuoco Notturno',
        aiSummary: 'La crew ha completato la missione a Japantown.',
        masterNotes: 'Il Fixer Dexter DeShawn ha pagato 5000 eb.',
        playerSummaries: <PlayerSessionSummary>[
          PlayerSessionSummary(
            playerId: 'p1',
            playerName: 'V',
            transcript: 'V: "Copertura su Jackie."',
            aiSummary: '• Ha ingaggiato le guardie.',
          ),
          PlayerSessionSummary(
            playerId: 'p2',
            playerName: 'Jackie Welles',
            transcript: 'Jackie: "Ci penso io, hermano."',
            aiSummary: '• Ha sfondato la porta blindata.',
          ),
        ],
      );

      final Map<String, Object?> json = commit.toJson();
      final CampaignSessionCommit restored = CampaignSessionCommit.fromJson(json);

      expect(restored.id, equals('commit-12345'));
      expect(restored.sessionIndex, equals(3));
      expect(restored.date, equals('2077-10-15'));
      expect(restored.time, equals('21:30'));
      expect(restored.title, equals('Operazione Fuoco Notturno'));
      expect(restored.playerSummaries.length, equals(2));
      expect(restored.playerSummaries.first.playerName, equals('V'));
      expect(restored.playerSummaries.last.playerName, equals('Jackie Welles'));
      expect(restored.playerSummaries.first.aiSummary, contains('guardie'));
    });

    test('AiAssistantService genera riassunto per singolo giocatore e riassunto master fuso', () async {
      final AiAssistantService ai = AiAssistantService.instance;

      // 1. Riassunto singolo giocatore
      final String pSummary = await ai.generatePlayerSessionSummary(
        playerName: 'V (Solo)',
        transcript: 'V: "Estraggo il fucile e proteggo l\'hacker mentre buca il terminale."',
      );
      expect(pSummary, isNotEmpty);
      expect(pSummary, contains('V (Solo)'));

      // 2. Riassunto Master Unificato
      final String merged = await ai.generateMasterMergedSessionSummary(
        sessionIndex: 1,
        sessionTitle: 'Infiltrazione a Watson',
        playerSummaries: <PlayerSessionSummary>[
          PlayerSessionSummary(
            playerId: 'p1',
            playerName: 'V (Solo)',
            transcript: 'V: "Fuoco di soppressione!"',
            aiSummary: '• Ha coperto la ritirata.',
          ),
          PlayerSessionSummary(
            playerId: 'p2',
            playerName: 'T-Bug (Netrunner)',
            transcript: 'T-Bug: "Accesso al subnet garantito."',
            aiSummary: '• Ha disattivato i laser.',
          ),
        ],
        masterNotes: 'Il gruppo ha ottenuto il convoglio.',
        fullTranscript: 'Trascrizione generale della sessione.',
      );

      expect(merged, isNotEmpty);
      expect(merged, contains('Infiltrazione a Watson'));
      expect(merged, contains('V (Solo)'));
    });

    test('SessionVoiceTranscriber avvia ascolto, accumula parlato e termina sessione', () {
      final SessionVoiceTranscriber transcriber = SessionVoiceTranscriber.instance;
      transcriber.startLiveListening(speaker: 'Panam');
      expect(transcriber.isRecordingSession, isTrue);
      expect(transcriber.currentSpeaker, equals('Panam'));

      transcriber.appendSpeech('Il lanciarazzi è carico!');
      expect(transcriber.currentTranscript, contains('Panam'));
      expect(transcriber.currentTranscript, contains('lanciarazzi'));

      final String exported = transcriber.endSessionAndExport();
      expect(exported, contains('lanciarazzi'));
      expect(transcriber.isRecordingSession, isFalse);
      expect(transcriber.currentTranscript, isEmpty);
    });
  });

  group('EndSessionSummaryDialog Widget Tests', () {
    testWidgets('EndSessionSummaryDialog visualizza titolo personalizzabile, riepiloghi giocatori e salva commit',
        (WidgetTester tester) async {
      final Campaign campaign = Campaign(meta: DocumentMeta(id: 'camp-test', name: 'Campagna Night City'));
      CampaignSessionCommit? savedCommit;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext ctx) => ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: ctx,
                    builder: (_) => EndSessionSummaryDialog(
                      campaign: campaign,
                      initialPlayerSummaries: <PlayerSessionSummary>[
                        PlayerSessionSummary(
                          playerId: 'p1',
                          playerName: 'V (Solo)',
                          transcript: 'V: "Copertura garantita."',
                        ),
                      ],
                      onSaveCommit: (CampaignSessionCommit commit) {
                        savedCommit = commit;
                      },
                    ),
                  ),
                  child: const Text('Apri Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Apri Dialog'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EndSessionSummaryDialog), findsOneWidget);
      expect(find.text('TERMINA SESSIONE & RIEPILOGHI IA MULTI-GIOCATORE'), findsOneWidget);
      expect(find.text('Nome della Sessione (Personalizzabile dal Master)'), findsOneWidget);

      // Clicca sulla tab dei giocatori
      await tester.tap(find.text('Riepiloghi Giocatori (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('GIOCATORE: V (SOLO)'), findsOneWidget);

      // Clicca Salva
      await tester.tap(find.text('REGISTRA SESSIONE & SALVA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(savedCommit, isNotNull);
      expect(savedCommit!.playerSummaries.length, equals(1));
      expect(savedCommit!.playerSummaries.first.playerName, equals('V (Solo)'));
    });
  });
}
