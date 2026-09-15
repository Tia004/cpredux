import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/net_architecture.dart';
import 'package:cpredux/net/cloud_sync_service.dart';
import 'package:cpredux/features/ai/ai_assistant_service.dart';
import 'package:cpredux/widgets/cyber_help_tooltip.dart';

void main() {
  group('CampaignSheetProfile & Overlay Tests', () {
    test('Campagna overlay non muta la scheda base', () {
      final CharacterSheet sheet = CharacterSheet.fresh(
        id: 'sheet_01',
        name: 'V',
        now: '2026-09-15T00:00:00Z',
      );
      sheet.identity.currentHp = 40;
      sheet.identity.currentLuck = 7;
      sheet.identity.severeInjuries = '';

      expect(sheet.effectiveHp, 40);
      expect(sheet.effectiveLuck, 7);
      expect(sheet.effectiveSevereInjuries, '');
      expect(sheet.activeProfile, isNull);

      // Crea un profilo per la campagna "Night City 2045"
      final CampaignSheetProfile profile = sheet.getOrCreateProfile(
        'camp_123',
        'Night City 2045',
      );
      expect(profile.campaignName, 'Night City 2045');

      sheet.selectCampaignProfile('camp_123');
      expect(sheet.activeProfile, isNotNull);
      expect(sheet.activeProfile?.campaignName, 'Night City 2045');

      // Modifica PV e fortuna nel profilo campagna
      sheet.effectiveHp = 25;
      sheet.effectiveLuck = 4;
      sheet.effectiveSevereInjuries = 'Gamba Amputata';

      expect(sheet.effectiveHp, 25);
      expect(sheet.effectiveLuck, 4);
      expect(sheet.effectiveSevereInjuries, 'Gamba Amputata');

      // Verifica che la scheda BASE sia rimasta invariata!
      expect(sheet.identity.currentHp, 40);
      expect(sheet.identity.currentLuck, 7);
      expect(sheet.identity.severeInjuries, '');

      // Disattiva il profilo (ritorno a Scheda Base)
      sheet.selectCampaignProfile(null);
      expect(sheet.activeProfile, isNull);
      expect(sheet.effectiveHp, 40);
      expect(sheet.effectiveLuck, 7);
      expect(sheet.effectiveSevereInjuries, '');
    });

    test('Serializzazione e deserializzazione JSON dei profili campagna nello stesso file', () {
      final CharacterSheet original = CharacterSheet.fresh(
        id: 'sheet_02',
        name: 'V Silverhand',
        now: '2026-09-15T00:00:00Z',
      );
      original.identity.currentHp = 50;

      final CampaignSheetProfile prof = original.getOrCreateProfile(
        'c_red_01',
        'Operazione Arasaka',
      );
      prof.currentHp = 18;
      prof.currentLuck = 2;
      prof.severeInjuries = 'Occhio Cieco';
      original.selectCampaignProfile('c_red_01');

      final Map<String, Object?> json = original.toJson();
      final CharacterSheet restored = CharacterSheet.fromJson(json);

      expect(restored.meta.name, 'V Silverhand');
      expect(restored.identity.currentHp, 50); // Base intatta
      expect(restored.activeCampaignProfileId, 'c_red_01');
      expect(restored.campaignProfiles.containsKey('c_red_01'), isTrue);

      final CampaignSheetProfile restoredProf = restored.campaignProfiles['c_red_01']!;
      expect(restoredProf.campaignName, 'Operazione Arasaka');
      expect(restored.effectiveHp, 18);
      expect(restored.effectiveLuck, 2);
      expect(restored.effectiveSevereInjuries, 'Occhio Cieco');
    });
  });

  group('NetArchitecture Netrunner Map Tests', () {
    test('Creazione, piani, nodi e serializzazione NET Architecture', () {
      final NetArchitecture arch = NetArchitecture(
        id: 'arch_01',
        name: 'Arasaka Sub-Net Level 3',
        description: 'Server blindato con connessione satellitare',
        floors: <NetFloor>[
          NetFloor(
            floorNumber: 1,
            nodes: <NetNode>[
              NetNode(
                id: 'node_pw1',
                type: NetNodeType.password,
                name: 'Gateway Firewall',
                dv: 8,
              ),
            ],
          ),
          NetFloor(
            floorNumber: 2,
            isRevealed: true,
            nodes: <NetNode>[
              NetNode(
                id: 'node_ctrl1',
                type: NetNodeType.controlNode,
                name: 'Controllo Torrette',
                dv: 8,
                devices: <NetDeviceType>[NetDeviceType.turret],
              ),
              NetNode(
                id: 'node_ice1',
                type: NetNodeType.blackIce,
                name: 'Hellhound',
                ice: NetIceProgram.presets.firstWhere((p) => p.name == 'Hellhound'),
              ),
            ],
          ),
          NetFloor(
            floorNumber: 3,
            nodes: <NetNode>[
              NetNode(
                id: 'node_root',
                type: NetNodeType.rootVirus,
                name: 'Mainframe Root',
                dv: 10,
              ),
            ],
          ),
        ],
      );

      expect(arch.floors.length, 3);
      expect(arch.floors[1].nodes.length, 2);
      expect(arch.floors[1].nodes[1].ice?.name, 'Hellhound');
      expect(arch.floors[1].nodes[1].ice?.isAntiPersonnel, isTrue);

      // Toggling floor reveal for Fog of War
      expect(arch.floors[1].isRevealed, isTrue);
      expect(arch.floors[0].isRevealed, isFalse);

      // Serialization
      final Map<String, Object?> json = arch.toJson();
      final NetArchitecture restored = NetArchitecture.fromJson(json);

      expect(restored.name, 'Arasaka Sub-Net Level 3');
      expect(restored.floors.length, 3);
      expect(restored.floors[1].isRevealed, isTrue);
      expect(restored.floors[0].isRevealed, isFalse);
      expect(restored.floors[1].nodes[1].name, 'Hellhound');
      expect(restored.floors[1].nodes[1].ice?.attack, 6);
    });
  });

  group('CloudSyncService Real Auth Validation Tests', () {
    test('Rifiuta email non valide o prive di formato reale', () async {
      final CloudSyncService cloud = CloudSyncService.instance;

      final bool failed1 = await cloud.signInWithGoogle(email: 'notanemail');
      expect(failed1, isFalse);
      expect(cloud.lastError, contains('email valido'));

      final bool failed2 = await cloud.signInWithGoogle(email: '');
      expect(failed2, isFalse);
    });

    test('Accetta email valide e imposta currentUser', () async {
      final CloudSyncService cloud = CloudSyncService.instance;
      await cloud.signOut();
      expect(cloud.isAuthenticated, isFalse);

      final bool ok = await cloud.signInWithGoogle(
        email: 'runner.test@gmail.com',
        customName: 'Test Runner',
      );

      expect(ok, isTrue);
      expect(cloud.isAuthenticated, isTrue);
      expect(cloud.currentUser?.email, 'runner.test@gmail.com');
      expect(cloud.currentUser?.displayName, 'Test Runner');
    });
  });

  group('AiAssistantService Offline Heuristic & NPC Generator Tests', () {
    test('Heuristic Engine risponde a domande su regole e lore senza internet', () async {
      final AiAssistantService ai = AiAssistantService.instance;

      final String respIce = await ai.askAssistant('Cosa fa il Black ICE?');
      expect(respIce.toLowerCase(), contains('black ice'));
      expect(respIce, contains('Hellhound'));

      final String respNet = await ai.askAssistant('Come funziona il Netrunning?');
      expect(respNet.toLowerCase(), contains('netrunning'));
      expect(respNet, contains('Incursione'));

      final String respCrit = await ai.askAssistant('Cosa succede con un tiro della morte?');
      expect(respCrit.toLowerCase(), contains('morte'));
    });

    test('Generatore PNG crea battute contestualizzate per il Master', () async {
      final AiAssistantService ai = AiAssistantService.instance;

      final String fixerQuote = await ai.generateNpcDialogue(
        archetype: NpcArchetype.fixer,
        npcName: 'Santiago Fixer',
        tone: NpcTone.cynical,
        situationOrTopic: 'I giocatori chiedono un anticipo per il lavoro',
      );

      expect(fixerQuote, isNotEmpty);
      expect(fixerQuote, contains('anticipo'));

      final String corpQuote = await ai.generateNpcDialogue(
        archetype: NpcArchetype.corp,
        npcName: 'Direttore Tanaka',
        tone: NpcTone.menacing,
        situationOrTopic: 'Trattativa sui contratti Arasaka',
      );

      expect(corpQuote, isNotEmpty);
      expect(corpQuote, contains('contratti'));
    });

    test('Riepilogo sessione usa il servizio IA e ha un fallback offline', () async {
      final AiAssistantService ai = AiAssistantService.instance;
      final String summary = await ai.generateSessionSummary(
        sessionIndex: 4,
        transcript: 'Il gruppo ha recuperato un chip e ha negoziato con un Fixer.',
      );

      expect(summary, isNotEmpty);
    });
  });

  group('CyberHelpTooltip Widget Test', () {
    testWidgets('CyberHelpTooltip renderizza icona ? e apre bubble su click/tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: CyberHelpTooltip(
                title: 'Test Titolo',
                message: 'Spiegazione di test per tooltip cyberpunk.',
                tag: 'Info Test',
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CyberHelpTooltip), findsOneWidget);
      expect(find.text('?'), findsOneWidget);

      // Clicca sull'icona ? per aprire la bubble
      await tester.tap(find.text('?'));
      await tester.pump();

      // La bubble di spiegazione appare a schermo in stile cyberpunk (maiuscolo)
      expect(find.text('TEST TITOLO'), findsOneWidget);
      expect(find.text('Spiegazione di test per tooltip cyberpunk.'), findsOneWidget);
      expect(find.text('INFO TEST'), findsOneWidget);

      // Clicca di nuovo per chiudere
      await tester.tap(find.text('?'));
      await tester.pump();
      expect(find.text('Test Titolo'), findsNothing);
    });
  });
}
