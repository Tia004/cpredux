import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../data/app_paths.dart';

/// Archetipi di Personaggi Non Giocanti (PNG) di Cyberpunk RED per il Master.
enum NpcArchetype {
  fixer('Fixer (Mediatore / Mercato Nero)', 'Fixer Martinez'),
  solo('Solo (Mercenario / Guardia del Corpo)', 'Slag "Il Macellaio"'),
  netrunner('Netrunner (Hacker del Ciberspazio)', 'GhostByte'),
  rockerboy('Rockerboy (Cantante Ribelle / Icona)', 'Johnny Vane'),
  cop('Poliziotto Corrotto NCPD', 'Tenente Miller'),
  corp('Agente di Sicurezza Corporativa', 'Agente Sato (Arasaka)'),
  ripperdoc('Bisturi da Strada (Ripperdoc)', 'Doc Chrome'),
  nomad('Nomade della Famiglia Aldecaldo', 'Javier "Dust"'),
  psycho('Sospetto Cyberpsicopatico', 'Unit Zero');

  const NpcArchetype(this.label, this.defaultName);
  final String label;
  final String defaultName;
}

/// Tono di voce per la battuta del PNG.
enum NpcTone {
  menacing('Minaccioso & Freddo'),
  friendly('Amichevole & Negoziale'),
  nervous('Nervoso & Paranoico'),
  technical('Tecnico & Distaccato'),
  cynical('Cinico da Strada'),
  psychotic('Cyberpsicopatico');

  const NpcTone(this.label);
  final String label;
}

/// Messaggio della cronologia della chat IA.
class AiChatMessage {
  const AiChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.npcName,
  });

  final String id;
  final String sender;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? npcName;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'sender': sender,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        if (npcName != null) 'npcName': npcName,
      };

  static AiChatMessage fromJson(Map<String, Object?> json) => AiChatMessage(
        id: '${json['id'] ?? ''}',
        sender: '${json['sender'] ?? 'AI'}',
        text: '${json['text'] ?? ''}',
        isUser: json['isUser'] == true,
        timestamp: DateTime.tryParse('${json['timestamp']}') ?? DateTime.now(),
        npcName: json['npcName'] as String?,
      );
}

/// Servizio di assistenza IA gratuito con motore euristico Cyberpunk RED + supporto Google Gemini.
class AiAssistantService extends ChangeNotifier {
  AiAssistantService._() {
    _loadConfig();
  }

  static final AiAssistantService instance = AiAssistantService._();

  String _geminiApiKey = '';
  String get geminiApiKey => _geminiApiKey;

  bool get hasGeminiKey => _geminiApiKey.trim().isNotEmpty;

  final List<AiChatMessage> _messages = <AiChatMessage>[];
  List<AiChatMessage> get messages => List<AiChatMessage>.unmodifiable(_messages);

  bool _isGenerating = false;
  bool get isGenerating => _isGenerating;

  File _configFile() => File(p.join(AppPaths.configDir().path, 'ai_settings.json'));

  void _loadConfig() {
    try {
      final File f = _configFile();
      if (!f.existsSync()) return;
      final Object? decoded = jsonDecode(f.readAsStringSync());
      if (decoded is Map) {
        _geminiApiKey = '${decoded['geminiApiKey'] ?? ''}';
      }
    } catch (_) {}
  }

  void saveGeminiApiKey(String key) {
    _geminiApiKey = key.trim();
    try {
      final File f = _configFile();
      f.writeAsStringSync(jsonEncode(<String, Object?>{'geminiApiKey': _geminiApiKey}));
    } catch (_) {}
    notifyListeners();
  }

  void clearHistory() {
    _messages.clear();
    notifyListeners();
  }

  /// Invia un prompt dell'utente e genera la risposta.
  Future<String> askAssistant(String userPrompt) async {
    final String clean = userPrompt.trim();
    if (clean.isEmpty) return '';

    _messages.add(
      AiChatMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'TU',
        text: clean,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    _isGenerating = true;
    notifyListeners();

    String reply;
    try {
      if (hasGeminiKey) {
        reply = await _callGeminiApi(clean);
      } else {
        reply = _heuristicCyberpunkRedResponse(clean);
      }
    } catch (e) {
      reply = _heuristicCyberpunkRedResponse(clean);
    }

    _messages.add(
      AiChatMessage(
        id: 'msg_ai_${DateTime.now().millisecondsSinceEpoch}',
        sender: 'AI COMPANION',
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      ),
    );

    _isGenerating = false;
    notifyListeners();
    return reply;
  }

  /// Genera una battuta in-character per un PNG del Master.
  Future<String> generateNpcDialogue({
    required NpcArchetype archetype,
    required NpcTone tone,
    required String npcName,
    required String situationOrTopic,
  }) async {
    _isGenerating = true;
    notifyListeners();

    String dialogue;
    final String prompt = 'Agisci come il personaggio di Cyberpunk RED "$npcName" (Ruolo: ${archetype.label}, Tono: ${tone.label}). '
        'Situazione: "$situationOrTopic". Rispondi con una sola battuta da recitare al tavolo, '
        'usando lo slang di Night City (choom, eddies, cromo, zero, preem, corpo).';

    try {
      if (hasGeminiKey) {
        dialogue = await _callGeminiApi(prompt);
      } else {
        dialogue = _generateLocalNpcDialogue(archetype, tone, npcName, situationOrTopic);
      }
    } catch (_) {
      dialogue = _generateLocalNpcDialogue(archetype, tone, npcName, situationOrTopic);
    }

    _isGenerating = false;
    notifyListeners();
    return dialogue;
  }

  String _generateLocalNpcDialogue(
    NpcArchetype archetype,
    NpcTone tone,
    String npcName,
    String topic,
  ) {
    final Map<NpcArchetype, List<String>> templates = <NpcArchetype, List<String>>{
      NpcArchetype.fixer: <String>[
        'Ascoltami bene, choom. Ho un lavoro pulito che fa per voi, ma se parlate con qualcun altro la taglia ve la metto io sulle gengive.',
        'Gli eddies sono già nel conto cifrato. Prendete il pacco prima che la Militech si accorga del buco nel magazzino.',
        'A Night City la fiducia si paga in anticipo. Vi do il 30% adesso e il resto quando vedo il chip integro.',
      ],
      NpcArchetype.solo: <String>[
        'Tenete le teste giù e controllate la linea di tiro. Se vedo un borg muoversi in quel vicolo, prima sparo e poi conto i fori.',
        'La mia tariffa è 500 eddies all\'ora, proiettili esclusi. Se volete che qualcuno resti a terra in fretta, siete capitati dal tipo giusto.',
        'Se quell\'agente tocca la fondina, la sua giornata finisce sul pavimento.',
      ],
      NpcArchetype.netrunner: <String>[
        'Hanno alzato un Firewall DV 10 e c\'è un Hellhound in agguato nel nodo 3. Datemi 20 secondi o il mio deck si trasforma in carbonella.',
        'Il segnale è debole... aspetta, ho forzato la porta dell\'ascensore. Muovetevi prima che il SysOp resetti le chiavi crittografiche!',
        'Tracce pulite. Ho cancellato i filmati di sorveglianza degli ultimi 10 minuti. Ora tocca a voi non fare casino con la porta blindata.',
      ],
      NpcArchetype.rockerboy: <String>[
        'Questa città si nutre della paura della gente, ma stasera la nostra voce farà vibrare le finestre dell\'Arasaka Tower!',
        'Non si tratta dei soldi, choom! Si tratta di fargli capire che non siamo numeri su un foglio paga corporativo!',
        'Alza quel cazzo di amplificatore! Quando la musica parte, i teppisti della strada sapranno da che parte stare.',
      ],
      NpcArchetype.cop: <String>[
        'NCPD, distretto 4! Mettete le mani sul cofano e non fate movimenti bruschi se ci tenete alla respirazione polmonare.',
        'Sentite, nessuno vuole compilare rapporti stanotte. Posate 100 eddies sul cruscotto e vi lascio sparire nel vicolo.',
        'La legge qui dice quello che decido io. Se quel camion non riparte tra due minuti, vi mando direttamente a Blackgate.',
      ],
      NpcArchetype.corp: <String>[
        'La vostra presenza in quest\'area costituisce una violazione del protocollo di sicurezza di livello 3. Allontanatevi immediatamente.',
        'Le nostre risorse legali e paramilitari sono ampiamente preparate a qualsiasi contingenza. Considerate attentamente la vostra prossima frase.',
        'Un accordo è stipulabile, a patto che il prototipo venga restituito sigillato prima delle 06:00.',
      ],
      NpcArchetype.ripperdoc: <String>[
        'Siediti sulla sedia e non agitarti. Il biomonitor dice che sei a tre battiti dal collasso, quindi lascia lavorare il bisturi.',
        'Questo innesto di seconda mano è ancora caldo, ma ha una lega di titanio militare. Mordi questa cinghia di gomma e conta fino a dieci.',
        'Non faccio domande sui buchi di proiettile, basta che gli eddies siano autentici.',
      ],
      NpcArchetype.nomad: <String>[
        'La famiglia viene prima di tutto. Se toccate uno dei nostri camion sulle Badlands, vi inseguiremo fino a Seattle.',
        'La tempesta di sabbia sta arrivando. Rifornite le moto e legate il carico, stanotte la strada sarà un inferno.',
        'In città vivete come topi nelle gabbie. Là fuori c\'è solo polvere e orizzonte, ma almeno l\'aria è nostra.',
      ],
      NpcArchetype.psycho: <String>[
        'Senti il ronzio? Il cromo... il cromo è così freddo, ma dentro brucia tutto... non potete fermare il metallo!',
        'Occhi rossi nel buio... troppi innesti... loro pensano che sia carne, ma siamo solo macchine!',
        'Silenzio! Le frequenze della rete parlano tutte insieme... devo spegnere le loro teste!',
      ],
    };

    final List<String> list = templates[archetype] ?? templates[NpcArchetype.fixer]!;
    final math.Random rnd = math.Random();
    final String chosen = list[rnd.nextInt(list.length)];
    if (topic.trim().isNotEmpty) {
      return '$chosen — "$topic"';
    }
    return chosen;
  }

  String _heuristicCyberpunkRedResponse(String query) {
    final String q = query.toLowerCase();

    if (q.contains('tiro della morte') || q.contains('death save')) {
      return 'IL TIRO DELLA MORTE (Cyberpunk RED pag. 222):\n'
          '• Quando i Punti Vita arrivano a 0, il personaggio è Morente.\n'
          '• All\'inizio di ogni proprio turno, il giocatore lancia 1d10 + penalità cumulate (+1 per ogni round a 0 PV).\n'
          '• Per sopravvivere, il risultato del dado deve essere INFERIORE al valore base di FISICO (BODY).\n'
          '• Se il risultato è pari o superiore al Fisico, o esce un 10 naturale: il personaggio muore all\'istante.';
    }

    if (q.contains('ferit') || q.contains('grave')) {
      return 'FERITE GRAVI (Cyberpunk RED pag. 220-223):\n'
          '• Se i PV scendono sotto la metà dei PV massimi, si entra in stato "Ferito Gravemente": -2 a tutte le azioni!\n'
          '• Inoltre, se in un attacco con arma da fuoco o mischia escono due o più 6 sui dadi di danno, si infligge una Ferita Critica con tabella dedicata (es. Braccio fratturato, Trauma cranico, Polmone perforato) con 5 danni bonus diretti ai PV.';
    }

    if (q.contains('netrun') || q.contains('ice') || q.contains('architettur')) {
      return 'NETRUNNING IN CYBERPUNK RED (pag. 206-221):\n'
          '• L\'azione Incursione permette di scendere di 1 piano nell\'architettura NET.\n'
          '• Per forzare Password e Nodi di controllo si usano prove di Interfaccia contro il DV stabilito dal SysOp (tipicamente DV 6 Facile, DV 8 Medio, DV 10 Difficile).\n'
          '• I Black ICE si dividono in Anti-Programma (es. Raven, Killer, Dragon) e Anti-Personale (es. Hellhound che infiamma la mente infliggendo 2d6 danni diretti al Netrunner).';
    }

    if (q.contains('fortuna') || q.contains('luck')) {
      return 'PUNTI FORTUNA (LUCK):\n'
          '• Puoi spendere 1 o più punti Fortuna PRIMA di un tiro per aggiungere un bonus di +1 per punto speso.\n'
          '• I punti spesi non si ricaricano durante la sessione, ma tornano al massimo all\'inizio di ogni nuova sessione di gioco.';
    }

    if (q.contains('armatur') || q.contains('sp') || q.contains('stopping power')) {
      return 'ARMATURA E STOPPING POWER (SP):\n'
          '• L\'armatura protegge Testa e Corpo con un valore di SP (es. SP 11 per Kevlar, SP 13 per Giubbotto Antiproiettile Leggero).\n'
          '• Se il danno supera l\'SP, il danno in eccesso viene sottratto dai Punti Vita, e l\'SP dell\'armatura viene abrasato di 1 punto permanentemente per colpo.';
    }

    if (q.contains('iniziativ') || q.contains('combattimento')) {
      return 'INIZIATIVA E COMBATTIMENTO:\n'
          '• Iniziativa = RIFLESSI (REF) + 1d10.\n'
          '• Ogni turno un personaggio ha a disposizione 1 Azione (Attacco, Abilità, Ricarica, Usa Oggetto) + 1 Movimento (metri pari a VEL).';
    }

    return 'Sono l\'assistente cibernetico di CPRedux per Cyberpunk RED!\n'
        'Puoi chiedermi chiarimenti sulle regole (Tiro della morte, Ferite critiche, Armature SP, Iniziativa, Netrunning) '
        'oppure usare il generatore PNG a fianco per far recitare battute ai personaggi e inviarle direttamente nella chat del tavolo.';
  }

  Future<String> _callGeminiApi(String prompt) async {
    final Uri url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_geminiApiKey',
    );

    final HttpClient client = HttpClient();
    final HttpClientRequest req = await client.postUrl(url);
    req.headers.contentType = ContentType.json;

    final Map<String, Object?> body = <String, Object?>{
      'contents': <Map<String, Object?>>[
        <String, Object?>{
          'parts': <Map<String, String>>[
            <String, String>{
              'text': 'Sei un assistente per il gioco di ruolo Cyberpunk RED. '
                  'Conosci perfettamente il manuale base di Cyberpunk RED (R. Talsorian Games). '
                  'Rispondi in modo conciso, accurato e d\'atmosfera cyberpunk.\n\n$prompt',
            },
          ],
        },
      ],
    };

    req.write(jsonEncode(body));
    final HttpClientResponse resp = await req.close();
    final String respBody = await resp.transform(utf8.decoder).join();
    client.close();

    final Object? decoded = jsonDecode(respBody);
    if (decoded is Map && decoded['candidates'] is List) {
      final List<dynamic> cands = decoded['candidates'] as List<dynamic>;
      if (cands.isNotEmpty && cands.first is Map) {
        final Map cand = cands.first as Map;
        final Map content = cand['content'] as Map;
        final List parts = content['parts'] as List;
        if (parts.isNotEmpty && parts.first is Map) {
          return '${parts.first['text']}'.trim();
        }
      }
    }
    throw Exception('Formato risposta Gemini non valido');
  }
}
