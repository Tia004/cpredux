import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../../data/app_paths.dart';
import '../../domain/gm/gm_generators.dart';

/// Risultato di una generazione di bottino (IA o euristica avanzata).
class AiLootResult {
  const AiLootResult({
    required this.eurodollars,
    required this.entries,
    required this.source,
  });

  final int eurodollars;
  final List<LootEntry> entries;
  final String source;
}

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

  /// Chiave configurata al momento della compilazione tramite
  /// `--dart-define=GEMINI_API_KEY=xxx`.
  /// Questa modalità resta utile per sviluppo locale. Per le release pubbliche
  /// usare `GEMINI_PROXY_URL`: la chiave resta nel Worker cloud e non finisce
  /// nell'applicazione distribuita.
  static const String _envApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envProxyUrl = String.fromEnvironment('GEMINI_PROXY_URL');

  String _geminiApiKey = '';
  String get geminiApiKey => _geminiApiKey;

  /// Restituisce la chiave effettiva: l'impostazione utente ha la priorità,
  /// altrimenti viene usata la chiave compilata nell'ambiente dell'app.
  String get effectiveApiKey {
    if (_geminiApiKey.trim().isNotEmpty) return _geminiApiKey.trim();
    if (_envApiKey.trim().isNotEmpty) return _envApiKey.trim();
    return '';
  }

  String get effectiveProxyUrl => _envProxyUrl.trim();

  bool get hasGeminiKey => effectiveProxyUrl.isNotEmpty || effectiveApiKey.isNotEmpty;
  bool get hasEnvKey => _envApiKey.trim().isNotEmpty;

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
    if (effectiveProxyUrl.isNotEmpty) {
      return _callGeminiProxy(prompt);
    }

    final String key = effectiveApiKey;
    if (key.isEmpty) throw Exception('Nessuna chiave API Gemini configurata');
    final Uri url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$key',
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

  Future<String> _callGeminiProxy(String prompt) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest req = await client.postUrl(Uri.parse(effectiveProxyUrl));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(<String, String>{'prompt': prompt}));
      final HttpClientResponse resp = await req.close();
      final String respBody = await resp.transform(utf8.decoder).join();
      final Object? decoded = jsonDecode(respBody);
      if (resp.statusCode >= 200 && resp.statusCode < 300 && decoded is Map && decoded['text'] is String) {
        return '${decoded['text']}'.trim();
      }
      throw Exception('Proxy Gemini: ${decoded is Map ? decoded['error'] ?? 'risposta non valida' : 'risposta non valida'}');
    } finally {
      client.close(force: true);
    }
  }

  /// Genera il bottino (loot) per un nemico usando l'IA di Gemini o un generatore procedurale indipendente.
  ///
  /// Non si basa mai sul bottino precedente: ogni chiamata produce un risultato fresco e originale.
  Future<AiLootResult> generateLootWithAi({
    required String prompt,
    required int quality,
  }) async {
    final int q = quality.clamp(0, 10);
    _isGenerating = true;
    notifyListeners();

    if (hasGeminiKey) {
      try {
        final String aiPrompt = 'Genera il bottino (loot delle tasche ed equipaggiamento) per questo nemico di Cyberpunk RED.\n'
            'Nemico: "$prompt"\n'
            'Livello Qualità Loot: $q su 10 (dove 0 = tasche quasi vuote/spazzatura, 5 = standard da strada, 10 = prototipi militari/cyberware raro/molti soldi).\n\n'
            'Rispondi ESCLUSIVAMENTE con un JSON valido (senza testo introduttivo) in questo esatto formato:\n'
            '{\n'
            '  "eurodollars": 150,\n'
            '  "items": [\n'
            '    {"name": "Nome Oggetto", "kind": "denaro|chip|munizioni|droga|arma|equipaggiamento|cyberware|oggetto", "quantity": 1, "note": "Breve nota descrittiva"}\n'
            '  ]\n'
            '}';

        final String rawReply = await _callGeminiApi(aiPrompt);
        final AiLootResult? parsed = _parseLootJson(rawReply);
        if (parsed != null && parsed.entries.isNotEmpty) {
          _isGenerating = false;
          notifyListeners();
          return parsed;
        }
      } catch (_) {}
    }

    final AiLootResult procedural = _generateProceduralLoot(prompt: prompt, quality: q);
    _isGenerating = false;
    notifyListeners();
    return procedural;
  }

  AiLootResult? _parseLootJson(String raw) {
    try {
      String clean = raw.trim();
      if (clean.startsWith('```json')) clean = clean.substring(7);
      if (clean.startsWith('```')) clean = clean.substring(3);
      if (clean.endsWith('```')) clean = clean.substring(0, clean.length - 3);
      clean = clean.trim();

      final int start = clean.indexOf('{');
      final int end = clean.lastIndexOf('}');
      if (start >= 0 && end > start) {
        clean = clean.substring(start, end + 1);
      }

      final Object? decoded = jsonDecode(clean);
      if (decoded is Map) {
        final int eb = (decoded['eurodollars'] as num?)?.toInt() ?? 0;
        final List<LootEntry> entries = <LootEntry>[];
        if (decoded['items'] is List) {
          for (final item in decoded['items'] as List) {
            if (item is Map) {
              final String name = '${item['name'] ?? ''}'.trim();
              if (name.isEmpty) continue;
              final String kindStr = '${item['kind'] ?? 'oggetto'}'.toLowerCase();
              final LootKind kind = switch (kindStr) {
                'denaro' => LootKind.denaro,
                'chip' => LootKind.chip,
                'munizioni' => LootKind.munizioni,
                'droga' => LootKind.droga,
                'arma' => LootKind.arma,
                'equipaggiamento' => LootKind.equipaggiamento,
                'cyberware' => LootKind.cyberware,
                _ => LootKind.oggetto,
              };
              final int qty = (item['quantity'] as num?)?.toInt() ?? 1;
              final String note = '${item['note'] ?? ''}'.trim();
              entries.add(LootEntry(name: name, kind: kind, quantity: math.max(1, qty), note: note));
            }
          }
        }
        return AiLootResult(eurodollars: math.max(0, eb), entries: entries, source: 'Gemini AI');
      }
    } catch (_) {}
    return null;
  }

  /// Genera proceduralmente il bottino in modo sincrono e deterministico (o casuale fresco),
  /// utile per anteprime immediate o quando si opera offline senza attendere l'IA.
  AiLootResult generateLootWithAiProceduralSync({
    required String prompt,
    required int quality,
    math.Random? random,
  }) {
    return _generateProceduralLoot(
      prompt: prompt,
      quality: quality.clamp(0, 10),
      rnd: random,
    );
  }

  AiLootResult _generateProceduralLoot({
    required String prompt,
    required int quality,
    math.Random? rnd,
  }) {
    final math.Random random = rnd ?? math.Random();
    final String pLower = prompt.toLowerCase();

    // Eurodollari in base alla qualità
    final int eurodollars = switch (quality) {
      0 => random.nextInt(12),
      1 || 2 => 10 + random.nextInt(50),
      3 || 4 => 50 + random.nextInt(150),
      5 || 6 => 150 + random.nextInt(450),
      7 || 8 => 500 + random.nextInt(1500),
      9 || 10 => 1800 + random.nextInt(4500),
      _ => 100,
    };

    final List<LootEntry> entries = <LootEntry>[];

    if (quality == 0) {
      final List<LootEntry> junk = <LootEntry>[
        const LootEntry(name: 'Accendino al plastico rotto', kind: LootKind.oggetto, quantity: 1, note: 'senza gas'),
        const LootEntry(name: 'Scontrino sporco di fango', kind: LootKind.oggetto, quantity: 1, note: 'Kibble bar di South Night City'),
        const LootEntry(name: 'Spiccioli di latta', kind: LootKind.denaro, quantity: 1, note: 'valuta locale usurata'),
        const LootEntry(name: 'Mascherina anti-smog bucata', kind: LootKind.equipaggiamento, quantity: 1),
        const LootEntry(name: 'Bottiglia di Smash vuota', kind: LootKind.oggetto, quantity: 1),
      ];
      entries.add(junk[random.nextInt(junk.length)]);
      return AiLootResult(eurodollars: eurodollars, entries: entries, source: 'Generatore Procedurale');
    }

    // Identifica archetipo nemico
    final bool isCop = pLower.contains('poliziotto') || pLower.contains('ncpd') || pLower.contains('sbirro') || pLower.contains('agente di polizia');
    final bool isCorp = pLower.contains('corp') || pLower.contains('arasaka') || pLower.contains('militech') || pLower.contains('biotechnica');
    final bool isNetrunner = pLower.contains('netrunner') || pLower.contains('hacker') || pLower.contains('deck');
    final bool isDoc = pLower.contains('doc') || pLower.contains('medico') || pLower.contains('ripperdoc') || pLower.contains('chirurgo');
    final bool isCivilian = pLower.contains('civile') || pLower.contains('passante') || pLower.contains('cittadino') || pLower.contains('impiegato');

    // Pool specifici
    final List<LootEntry> candidates = <LootEntry>[];

    if (isCop) {
      candidates.addAll(<LootEntry>[
        const LootEntry(name: 'Distintivo NCPD', kind: LootKind.oggetto, quantity: 1, note: 'matricola distretto 4'),
        LootEntry(name: 'Caricatore 9mm Heavy Pistol', kind: LootKind.munizioni, quantity: 1 + quality ~/ 3, note: 'munizioni standard'),
        const LootEntry(name: 'Manette in legaplastica', kind: LootKind.equipaggiamento, quantity: 1),
        const LootEntry(name: 'Ricetrasmittente criptata NCPD', kind: LootKind.equipaggiamento, quantity: 1, note: 'frequenze radio di zona'),
        if (quality >= 5) const LootEntry(name: 'Heavy Pistol (HQ)', kind: LootKind.arma, quantity: 1, note: 'arma d\'ordinanza ben curata'),
        if (quality >= 7) const LootEntry(name: 'Giubbotto Antiproiettile SP 12', kind: LootKind.equipaggiamento, quantity: 1, note: 'kevlar rinforzato'),
      ]);
    } else if (isCorp) {
      candidates.addAll(<LootEntry>[
        const LootEntry(name: 'Badge magnetico d\'accesso aziendale', kind: LootKind.chip, quantity: 1, note: 'autorizzazione di sicurezza livello 2'),
        const LootEntry(name: 'Chip dati cifrato', kind: LootKind.chip, quantity: 1, note: 'contiene report finanziari riservati'),
        const LootEntry(name: 'Smart Phone Agent d\'alta gamma', kind: LootKind.oggetto, quantity: 1, note: 'contatti di quadri intermedi'),
        if (quality >= 4) const LootEntry(name: 'Smartgun subdola Arasaka', kind: LootKind.arma, quantity: 1, note: 'collegamento interfaccia neurale'),
        if (quality >= 6) const LootEntry(name: 'Chip crediti aziendali', kind: LootKind.denaro, quantity: 1, note: 'trasferimento immediato'),
        if (quality >= 8) const LootEntry(name: 'Subdermal Pocket chirurgica', kind: LootKind.cyberware, quantity: 1, note: 'tasca sottocutanea nascosta'),
      ]);
    } else if (isNetrunner) {
      candidates.addAll(<LootEntry>[
        const LootEntry(name: 'Cavi neurali di collegamento', kind: LootKind.equipaggiamento, quantity: 1, note: 'interfaccia diretta plug-in'),
        const LootEntry(name: 'Chip con exploit ICE', kind: LootKind.chip, quantity: 1, note: 'programma Wurm / Eraser monouso'),
        LootEntry(name: 'Stimolante sinaptico booster', kind: LootKind.droga, quantity: 1 + quality ~/ 4, note: '+2 concentrazione temporaneo'),
        if (quality >= 5) const LootEntry(name: 'Cyberdeck portatile modificato', kind: LootKind.cyberware, quantity: 1, note: '5 slot programma'),
        if (quality >= 7) const LootEntry(name: 'Chip chiavi crittografiche', kind: LootKind.chip, quantity: 1, note: 'decritta nodi NET di livello medio'),
      ]);
    } else if (isDoc) {
      candidates.addAll(<LootEntry>[
        LootEntry(name: 'Fiala di Speedheal', kind: LootKind.droga, quantity: 1 + quality ~/ 3, note: 'stabilizza ferite in emergenza'),
        const LootEntry(name: 'Kit bisturi chirurgico sonico', kind: LootKind.equipaggiamento, quantity: 1),
        const LootEntry(name: 'Anestetico sintetico da strada', kind: LootKind.droga, quantity: 2),
        if (quality >= 5) const LootEntry(name: 'Innesto cibernetico in scatola sterile', kind: LootKind.cyberware, quantity: 1, note: 'Cyberaudio o Occhio cybereye nuovo'),
      ]);
    } else if (isCivilian) {
      candidates.addAll(<LootEntry>[
        const LootEntry(name: 'Mazzo di chiavi dell\'appartamento', kind: LootKind.oggetto, quantity: 1, note: 'zona Watson / Heywood'),
        const LootEntry(name: 'Carta d\'identità elettronica (Agent)', kind: LootKind.chip, quantity: 1),
        const LootEntry(name: 'Pacchetto di sigarette sintetico', kind: LootKind.oggetto, quantity: 1),
        const LootEntry(name: 'Piccolo coltellino di autodifesa', kind: LootKind.arma, quantity: 1),
        if (quality >= 5) const LootEntry(name: 'Chip di risparmi personali', kind: LootKind.denaro, quantity: 1, note: 'qualche centinaio di eb'),
      ]);
    } else {
      // Scagnozzo / Ganger da strada
      candidates.addAll(<LootEntry>[
        LootEntry(name: 'Munizioni per pistola/fucile', kind: LootKind.munizioni, quantity: 1 + quality ~/ 2, note: 'caricatore sfuso'),
        const LootEntry(name: 'Dose di Synthcoke', kind: LootKind.droga, quantity: 1, note: 'bustina sigillata'),
        const LootEntry(name: 'Dose di Black Lace', kind: LootKind.droga, quantity: 1, note: 'fiala da inalare'),
        const LootEntry(name: 'Coltello da strada affilato', kind: LootKind.arma, quantity: 1),
        const LootEntry(name: 'Telefono usa e getta (Burner)', kind: LootKind.oggetto, quantity: 1, note: 'tre chiamate perse da un Fixer'),
        if (quality >= 4) const LootEntry(name: 'Pistola Medium / Heavy Pistol', kind: LootKind.arma, quantity: 1, note: 'graffiata con il simbolo della gang'),
        if (quality >= 6) const LootEntry(name: 'Braccio cibernetico con lama a scomparsa', kind: LootKind.cyberware, quantity: 1, note: 'necessita smontaggio'),
        if (quality >= 8) const LootEntry(name: 'Mitraglietta SMG d\'alta cadenza', kind: LootKind.arma, quantity: 1, note: 'completa di caricatore a tamburo'),
      ]);
    }

    // Mescola e prendi da 1 a 4 elementi unici
    candidates.shuffle(random);
    final int count = math.min(candidates.length, 1 + (quality ~/ 3));
    for (int i = 0; i < count; i++) {
      entries.add(candidates[i]);
    }

    return AiLootResult(
      eurodollars: eurodollars,
      entries: entries,
      source: 'Generatore Procedurale',
    );
  }
}
