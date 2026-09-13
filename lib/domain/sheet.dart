import 'cyberware.dart';
import 'effects.dart';
import 'enums.dart';
import 'items.dart';
import 'json_support.dart';
import 'modifiers.dart';
import 'skills.dart';
import 'stats.dart';

/// Versione del formato `.cpredux` scritta in ogni file.
///
/// Serve al migratore per riconoscere i file vecchi e a noi per rifiutare in
/// modo pulito i file *piu' nuovi* dell'app installata, invece di leggerli a
/// meta' e salvarli corrotti.
///
/// * **v1** — le voci d'inventario contenevano l'oggetto per intero.
/// * **v2** — le voci contengono solo il riferimento al catalogo piu' le
///   personalizzazioni, e le munizioni sono stato d'istanza.
const int cpreduxFormatVersion = 2;

class Note {
  Note({
    required this.id,
    this.title = '',
    this.content = '',
    this.createdAt = '',
    this.updatedAt = '',
  });

  final String id;
  String title;
  String content;
  String createdAt;
  String updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static Note fromJson(Map<String, Object?> json) => Note(
        id: readString(json['id']),
        title: readString(json['title']),
        content: readString(json['content']),
        createdAt: readString(json['createdAt']),
        updatedAt: readString(json['updatedAt']),
      );
}

class Friend {
  Friend({required this.id, this.name = ''});

  final String id;
  String name;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};

  static Friend fromJson(Map<String, Object?> json) =>
      Friend(id: readString(json['id']), name: readString(json['name']));
}

class TragicStory {
  TragicStory({required this.id, this.name = ''});

  final String id;
  String name;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};

  static TragicStory fromJson(Map<String, Object?> json) =>
      TragicStory(id: readString(json['id']), name: readString(json['name']));
}

class Enemy {
  Enemy({
    required this.id,
    this.who = '',
    this.whatCausedIt = '',
    this.whatCanTheyThrowAtYou = '',
    this.whatsGonnaHappen = '',
  });

  final String id;
  String who;
  String whatCausedIt;
  String whatCanTheyThrowAtYou;
  String whatsGonnaHappen;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'who': who,
        'whatCausedIt': whatCausedIt,
        'whatCanTheyThrowAtYou': whatCanTheyThrowAtYou,
        'whatsGonnaHappen': whatsGonnaHappen,
      };

  static Enemy fromJson(Map<String, Object?> json) => Enemy(
        id: readString(json['id']),
        who: readString(json['who']),
        whatCausedIt: readString(json['whatCausedIt']),
        whatCanTheyThrowAtYou: readString(json['whatCanTheyThrowAtYou']),
        whatsGonnaHappen: readString(json['whatsGonnaHappen']),
      );
}

/// Il "Lifepath": la sezione narrativa della scheda.
class Background {
  Background({
    this.culturalOrigins = '',
    this.personality = '',
    this.favouriteClothingStyle = '',
    this.favouriteHairStyle = '',
    this.whatDoYouValueMost = '',
    this.feelingsAboutPeople = '',
    this.mostValuedPerson = '',
    this.mostValuedPossession = '',
    this.familyBackground = '',
    this.childhoodEnvironment = '',
    this.familyCrisis = '',
    this.lifeGoals = '',
    this.reputationEvents = '',
    this.roleSpecificLifepath = '',
    this.housing = '',
    this.housingRent = '',
    this.lifestyle = '',
    this.lifestyleCost = '',
    List<Friend>? friends,
    List<TragicStory>? tragicStories,
    List<Enemy>? enemies,
  })  : friends = friends ?? <Friend>[],
        tragicStories = tragicStories ?? <TragicStory>[],
        enemies = enemies ?? <Enemy>[];

  String culturalOrigins;
  String personality;
  String favouriteClothingStyle;
  String favouriteHairStyle;
  String whatDoYouValueMost;
  String feelingsAboutPeople;
  String mostValuedPerson;
  String mostValuedPossession;
  String familyBackground;
  String childhoodEnvironment;
  String familyCrisis;
  String lifeGoals;
  String reputationEvents;
  String roleSpecificLifepath;
  String housing;
  String housingRent;
  String lifestyle;
  String lifestyleCost;
  final List<Friend> friends;
  final List<TragicStory> tragicStories;
  final List<Enemy> enemies;

  Map<String, Object?> toJson() => <String, Object?>{
        'culturalOrigins': culturalOrigins,
        'personality': personality,
        'favouriteClothingStyle': favouriteClothingStyle,
        'favouriteHairStyle': favouriteHairStyle,
        'whatDoYouValueMost': whatDoYouValueMost,
        'feelingsAboutPeople': feelingsAboutPeople,
        'mostValuedPerson': mostValuedPerson,
        'mostValuedPossession': mostValuedPossession,
        'familyBackground': familyBackground,
        'childhoodEnvironment': childhoodEnvironment,
        'familyCrisis': familyCrisis,
        'lifeGoals': lifeGoals,
        'reputationEvents': reputationEvents,
        'roleSpecificLifepath': roleSpecificLifepath,
        'housing': housing,
        'housingRent': housingRent,
        'lifestyle': lifestyle,
        'lifestyleCost': lifestyleCost,
        'friends': friends.map((Friend f) => f.toJson()).toList(),
        'tragicStories': tragicStories.map((TragicStory t) => t.toJson()).toList(),
        'enemies': enemies.map((Enemy e) => e.toJson()).toList(),
      };

  static Background fromJson(Map<String, Object?> json) => Background(
        culturalOrigins: readString(json['culturalOrigins']),
        personality: readString(json['personality']),
        favouriteClothingStyle: readString(json['favouriteClothingStyle']),
        favouriteHairStyle: readString(json['favouriteHairStyle']),
        whatDoYouValueMost: readString(json['whatDoYouValueMost']),
        feelingsAboutPeople: readString(json['feelingsAboutPeople']),
        mostValuedPerson: readString(json['mostValuedPerson']),
        mostValuedPossession: readString(json['mostValuedPossession']),
        familyBackground: readString(json['familyBackground']),
        childhoodEnvironment: readString(json['childhoodEnvironment']),
        familyCrisis: readString(json['familyCrisis']),
        lifeGoals: readString(json['lifeGoals']),
        reputationEvents: readString(json['reputationEvents']),
        roleSpecificLifepath: readString(json['roleSpecificLifepath']),
        housing: readString(json['housing']),
        housingRent: readString(json['housingRent']),
        lifestyle: readString(json['lifestyle']),
        lifestyleCost: readString(json['lifestyleCost']),
        friends: readObjectList(json['friends']).map(Friend.fromJson).toList(),
        tragicStories: readObjectList(json['tragicStories']).map(TragicStory.fromJson).toList(),
        enemies: readObjectList(json['enemies']).map(Enemy.fromJson).toList(),
      );
}

class PhysicalDescription {
  PhysicalDescription({
    this.age = '',
    this.height = '',
    this.weight = '',
    this.eyes = '',
    this.skin = '',
    this.hair = '',
    this.description = '',
    this.imagePath,
  });

  String age;
  String height;
  String weight;
  String eyes;
  String skin;
  String hair;
  String description;
  String? imagePath;

  Map<String, Object?> toJson() => <String, Object?>{
        'age': age,
        'height': height,
        'weight': weight,
        'eyes': eyes,
        'skin': skin,
        'hair': hair,
        'description': description,
        'imagePath': imagePath,
      };

  static PhysicalDescription fromJson(Map<String, Object?> json) => PhysicalDescription(
        age: readString(json['age']),
        height: readString(json['height']),
        weight: readString(json['weight']),
        eyes: readString(json['eyes']),
        skin: readString(json['skin']),
        hair: readString(json['hair']),
        description: readString(json['description']),
        imagePath: readNullableString(json['imagePath']),
      );
}

/// I dati anagrafici della sezione "Personaggio".
class SheetIdentity {
  SheetIdentity({
    this.tag = '',
    this.playerName = '',
    this.gameDate = '',
    this.aliases = '',
    this.reputation = '',
    this.role = '',
    this.roleAbility = '',
    this.roleRank = '',
    this.currentHp = 0,
    this.currentLuck = 0,
    this.currentImprovementPoints = 0,
    this.totalImprovementPoints = 0,
    this.severeInjuries = '',
    this.addictions = '',
    this.inspirationPoints = 0,
    this.currentHumanity = 0,
    this.currentEmpathy = 0,
  });

  String tag;
  String playerName;
  String gameDate;
  String aliases;
  String reputation;

  /// Ruolo (Solo, Nomade, Netrunner...) e relativa abilita' di ruolo.
  String role;
  String roleAbility;
  String roleRank;

  int currentHp;
  int currentLuck;
  int currentImprovementPoints;
  int totalImprovementPoints;
  String severeInjuries;
  String addictions;
  int inspirationPoints;
  int currentHumanity;
  int currentEmpathy;

  Map<String, Object?> toJson() => <String, Object?>{
        'tag': tag,
        'playerName': playerName,
        'gameDate': gameDate,
        'aliases': aliases,
        'reputation': reputation,
        'role': role,
        'roleAbility': roleAbility,
        'roleRank': roleRank,
        'currentHp': currentHp,
        'currentLuck': currentLuck,
        'currentImprovementPoints': currentImprovementPoints,
        'totalImprovementPoints': totalImprovementPoints,
        'severeInjuries': severeInjuries,
        'addictions': addictions,
        'inspirationPoints': inspirationPoints,
        'currentHumanity': currentHumanity,
        'currentEmpathy': currentEmpathy,
      };

  static SheetIdentity fromJson(Map<String, Object?> json) => SheetIdentity(
        tag: readString(json['tag']),
        playerName: readString(json['playerName']),
        gameDate: readString(json['gameDate']),
        aliases: readString(json['aliases']),
        reputation: readString(json['reputation']),
        role: readString(json['role']),
        roleAbility: readString(json['roleAbility']),
        roleRank: readString(json['roleRank']),
        currentHp: readInt(json['currentHp']),
        currentLuck: readInt(json['currentLuck']),
        currentImprovementPoints: readInt(json['currentImprovementPoints']),
        totalImprovementPoints: readInt(json['totalImprovementPoints']),
        severeInjuries: readString(json['severeInjuries']),
        addictions: readString(json['addictions']),
        inspirationPoints: readInt(json['inspirationPoints']),
        currentHumanity: readInt(json['currentHumanity']),
        currentEmpathy: readInt(json['currentEmpathy']),
      );
}

/// Intestazione del documento: cosa mostra il browser dei file.
class DocumentMeta {
  DocumentMeta({
    required this.id,
    required this.name,
    this.kind = DocumentKind.sheet,
    this.formatVersion = cpreduxFormatVersion,
    this.createdAt = '',
    this.updatedAt = '',
  });

  /// Modificabile: la scheda si puo' ricollegare a un tavolo diverso rigenerando
  /// l'identificativo, operazione che il vecchio progetto offriva come "reset ID".
  String id;
  String name;
  DocumentKind kind;
  int formatVersion;
  String createdAt;
  String updatedAt;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'kind': kind.name,
        'formatVersion': formatVersion,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  static DocumentMeta fromJson(Map<String, Object?> json) => DocumentMeta(
        id: readString(json['id']),
        name: readString(json['name']),
        kind: DocumentKind.values.firstWhere(
          (DocumentKind k) => k.name == readString(json['kind']),
          orElse: () => DocumentKind.sheet,
        ),
        formatVersion: readInt(json['formatVersion'], cpreduxFormatVersion),
        createdAt: readString(json['createdAt']),
        updatedAt: readString(json['updatedAt']),
      );
}

/// La scheda personaggio completa.
///
/// E' un *aggregato*: si carica e si salva sempre per intero. Questa e' la
/// ragione per cui il formato `.cpredux` salva un documento JSON dentro SQLite
/// invece di ricalcare le venti tabelle del vecchio schema: una scheda non si
/// interroga mai "per colonna", si apre e si guarda tutta, quindi la
/// normalizzazione relazionale non portava nessun vantaggio e costava
/// complessita' (tabelle ponte, cascade, ricostruzione a ogni apertura).
/// Il catalogo oggetti, che invece *si* interroga e filtra, resta relazionale.
class CharacterSheet {
  CharacterSheet({
    required this.meta,
    SheetIdentity? identity,
    Map<Stat, int>? statBase,
    Map<Skill, int>? skillLevels,
    List<StatModifier>? statModifiers,
    List<SkillModifier>? skillModifiers,
    List<Proficiency>? proficiencies,
    List<InventoryEntry>? inventory,
    List<Cyberware>? cyberware,
    List<Effect>? effects,
    List<Note>? notes,
    Background? background,
    PhysicalDescription? physical,
    this.eurobucks = 0,
    this.oldConnections = '',
  })  : identity = identity ?? SheetIdentity(),
        statBase = statBase ?? <Stat, int>{for (final Stat s in Stat.values) s: 1},
        skillLevels = skillLevels ??
            <Skill, int>{for (final Skill s in Skill.values) s: s.isEssential ? 2 : 0},
        statModifiers = statModifiers ?? <StatModifier>[],
        skillModifiers = skillModifiers ?? <SkillModifier>[],
        proficiencies = proficiencies ?? <Proficiency>[],
        inventory = inventory ?? <InventoryEntry>[],
        cyberware = cyberware ?? <Cyberware>[],
        effects = effects ?? <Effect>[],
        notes = notes ?? <Note>[],
        background = background ?? Background(),
        physical = physical ?? PhysicalDescription();

  final DocumentMeta meta;
  SheetIdentity identity;

  /// Valori base delle caratteristiche, senza correzioni.
  final Map<Stat, int> statBase;

  /// Livelli base delle abilita', senza correzioni.
  final Map<Skill, int> skillLevels;

  /// Correzioni inserite a mano (non generate da cyberware o effetti).
  final List<StatModifier> statModifiers;
  final List<SkillModifier> skillModifiers;

  final List<Proficiency> proficiencies;
  final List<InventoryEntry> inventory;
  final List<Cyberware> cyberware;
  final List<Effect> effects;
  final List<Note> notes;
  Background background;
  PhysicalDescription physical;

  int eurobucks;
  String oldConnections;

  /// Crea una scheda nuova con i default del progetto originale: tutte le
  /// caratteristiche a 1, abilita' essenziali a 2 e le altre a 0.
  factory CharacterSheet.fresh({required String id, required String name, required String now}) {
    return CharacterSheet(
      meta: DocumentMeta(id: id, name: name, createdAt: now, updatedAt: now),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'meta': meta.toJson(),
        'identity': identity.toJson(),
        'statBase': <String, Object?>{
          for (final MapEntry<Stat, int> e in statBase.entries) e.key.id.toString(): e.value,
        },
        'skillLevels': <String, Object?>{
          for (final MapEntry<Skill, int> e in skillLevels.entries) e.key.id.toString(): e.value,
        },
        'statModifiers': statModifiers.map((StatModifier m) => m.toJson()).toList(),
        'skillModifiers': skillModifiers.map((SkillModifier m) => m.toJson()).toList(),
        'proficiencies': proficiencies.map((Proficiency p) => p.toJson()).toList(),
        'inventory': inventory.map((InventoryEntry i) => i.toJson()).toList(),
        'cyberware': cyberware.map((Cyberware c) => c.toJson()).toList(),
        'effects': effects.map((Effect e) => e.toJson()).toList(),
        'notes': notes.map((Note n) => n.toJson()).toList(),
        'background': background.toJson(),
        'physical': physical.toJson(),
        'eurobucks': eurobucks,
        'oldConnections': oldConnections,
      };

  static CharacterSheet fromJson(Map<String, Object?> json) {
    final Map<String, Object?> statRaw = json['statBase'] is Map
        ? (json['statBase']! as Map<Object?, Object?>)
            .map((Object? k, Object? v) => MapEntry(k.toString(), v))
        : const <String, Object?>{};
    final Map<String, Object?> skillRaw = json['skillLevels'] is Map
        ? (json['skillLevels']! as Map<Object?, Object?>)
            .map((Object? k, Object? v) => MapEntry(k.toString(), v))
        : const <String, Object?>{};

    // Si parte dai default e si sovrascrive: se un file e' incompleto (o
    // scritto da una versione che non conosceva una caratteristica) la scheda
    // si apre comunque invece di restare con valori mancanti.
    final Map<Stat, int> stats = <Stat, int>{for (final Stat s in Stat.values) s: 1};
    for (final MapEntry<String, Object?> e in statRaw.entries) {
      final Stat? stat = Stat.fromId(int.tryParse(e.key) ?? -1);
      if (stat != null) stats[stat] = readInt(e.value, 1);
    }

    final Map<Skill, int> skills = <Skill, int>{
      for (final Skill s in Skill.values) s: s.isEssential ? 2 : 0,
    };
    for (final MapEntry<String, Object?> e in skillRaw.entries) {
      final Skill? skill = Skill.fromId(int.tryParse(e.key) ?? -1);
      if (skill != null) skills[skill] = readInt(e.value);
    }

    return CharacterSheet(
      meta: DocumentMeta.fromJson(
        json['meta'] is Map
            ? (json['meta']! as Map<Object?, Object?>)
                .map((Object? k, Object? v) => MapEntry(k.toString(), v))
            : const <String, Object?>{},
      ),
      identity: SheetIdentity.fromJson(
        json['identity'] is Map
            ? (json['identity']! as Map<Object?, Object?>)
                .map((Object? k, Object? v) => MapEntry(k.toString(), v))
            : const <String, Object?>{},
      ),
      statBase: stats,
      skillLevels: skills,
      statModifiers: readObjectList(json['statModifiers']).map(StatModifier.fromJson).toList(),
      skillModifiers: readObjectList(json['skillModifiers']).map(SkillModifier.fromJson).toList(),
      proficiencies: readObjectList(json['proficiencies']).map(Proficiency.fromJson).toList(),
      inventory: readObjectList(json['inventory']).map(InventoryEntry.fromJson).toList(),
      cyberware: readObjectList(json['cyberware']).map(Cyberware.fromJson).toList(),
      effects: readObjectList(json['effects']).map(Effect.fromJson).toList(),
      notes: readObjectList(json['notes']).map(Note.fromJson).toList(),
      background: Background.fromJson(
        json['background'] is Map
            ? (json['background']! as Map<Object?, Object?>)
                .map((Object? k, Object? v) => MapEntry(k.toString(), v))
            : const <String, Object?>{},
      ),
      physical: PhysicalDescription.fromJson(
        json['physical'] is Map
            ? (json['physical']! as Map<Object?, Object?>)
                .map((Object? k, Object? v) => MapEntry(k.toString(), v))
            : const <String, Object?>{},
      ),
      eurobucks: readInt(json['eurobucks']),
      oldConnections: readString(json['oldConnections']),
    );
  }
}
