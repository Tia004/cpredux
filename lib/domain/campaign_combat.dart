import 'json_support.dart';

/// Scheda rapida per un PNG o Mook posizionato come token sulla mappa.
class QuickNpcSheet {
  QuickNpcSheet({
    required this.id,
    required this.name,
    this.archetype = 'Solo Gangster',
    this.combatNumber = 12,
    this.defenseNumber = 12,
    this.currentHp = 30,
    this.maxHp = 30,
    this.currentArmorHead = 7,
    this.maxArmorHead = 7,
    this.currentArmorBody = 11,
    this.maxArmorBody = 11,
    this.primaryWeapon = 'Pistola Pesante (3d6)',
    this.secondaryWeapon = 'Coltello da Combattimento (1d6)',
    this.rof = 2,
    this.ammoRemaining = 16,
    this.maxAmmo = 16,
    this.eurobucks = 120,
    this.notes = '',
    this.loot = '120 eb, Chip dati cifrato, Munizioni 9mm x20',
    this.refBonus = 6,
    this.initiativeRoll,
    this.isDefeated = false,
  });

  final String id;
  String name;
  String archetype;
  int combatNumber;
  int defenseNumber;
  int currentHp;
  int maxHp;
  int currentArmorHead;
  int maxArmorHead;
  int currentArmorBody;
  int maxArmorBody;
  String primaryWeapon;
  String secondaryWeapon;
  int rof;
  int ammoRemaining;
  int maxAmmo;
  int eurobucks;
  String notes;
  String loot;
  int refBonus;
  int? initiativeRoll;
  bool isDefeated;

  /// Applica danno subendo l'armatura e l'ablazione regolamentare di Cyberpunk RED
  ({int hpLost, int armorAblated, bool isDead}) applyDamage(int rawDamage, {bool isHeadShot = false}) {
    final int currentSp = isHeadShot ? currentArmorHead : currentArmorBody;
    final int effectiveDmg = rawDamage - currentSp;

    if (effectiveDmg <= 0) {
      return (hpLost: 0, armorAblated: 0, isDead: currentHp <= 0);
    }

    // Il colpo ha superato l'armatura: infligge danno (raddoppiato se alla testa)
    final int totalDmg = isHeadShot ? effectiveDmg * 2 : effectiveDmg;
    currentHp = (currentHp - totalDmg).clamp(0, maxHp);

    // Regola Cyberpunk RED: ogni volta che un colpo perfora l'armatura, la SP si riduce di 1 punto (ablazione)
    if (isHeadShot) {
      currentArmorHead = (currentArmorHead - 1).clamp(0, maxArmorHead);
    } else {
      currentArmorBody = (currentArmorBody - 1).clamp(0, maxArmorBody);
    }

    if (currentHp <= 0) isDefeated = true;

    return (hpLost: totalDmg, armorAblated: 1, isDead: currentHp <= 0);
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'archetype': archetype,
        'combatNumber': combatNumber,
        'defenseNumber': defenseNumber,
        'currentHp': currentHp,
        'maxHp': maxHp,
        'currentArmorHead': currentArmorHead,
        'maxArmorHead': maxArmorHead,
        'currentArmorBody': currentArmorBody,
        'maxArmorBody': maxArmorBody,
        'primaryWeapon': primaryWeapon,
        'secondaryWeapon': secondaryWeapon,
        'rof': rof,
        'ammoRemaining': ammoRemaining,
        'maxAmmo': maxAmmo,
        'eurobucks': eurobucks,
        'notes': notes,
        'loot': loot,
        'refBonus': refBonus,
        if (initiativeRoll != null) 'initiativeRoll': initiativeRoll,
        'isDefeated': isDefeated,
      };

  static QuickNpcSheet fromJson(Map<String, Object?> json) => QuickNpcSheet(
        id: readString(json['id']),
        name: readString(json['name']),
        archetype: readString(json['archetype']),
        combatNumber: readInt(json['combatNumber'], 12),
        defenseNumber: readInt(json['defenseNumber'], 12),
        currentHp: readInt(json['currentHp'], 30),
        maxHp: readInt(json['maxHp'], 30),
        currentArmorHead: readInt(json['currentArmorHead'], 7),
        maxArmorHead: readInt(json['maxArmorHead'], 7),
        currentArmorBody: readInt(json['currentArmorBody'], 11),
        maxArmorBody: readInt(json['maxArmorBody'], 11),
        primaryWeapon: readString(json['primaryWeapon'], 'Pistola Pesante (3d6)'),
        secondaryWeapon: readString(json['secondaryWeapon'], 'Coltello (1d6)'),
        rof: readInt(json['rof'], 2),
        ammoRemaining: readInt(json['ammoRemaining'], 16),
        maxAmmo: readInt(json['maxAmmo'], 16),
        eurobucks: readInt(json['eurobucks'], 100),
        notes: readString(json['notes']),
        loot: readString(json['loot']),
        refBonus: readInt(json['refBonus'], 6),
        initiativeRoll: json['initiativeRoll'] != null ? readInt(json['initiativeRoll']) : null,
        isDefeated: readBool(json['isDefeated']),
      );
}

/// Riepilogo archiviato di una sessione di gioco con trascrizione vocale e note.
class CampaignSessionCommit {
  CampaignSessionCommit({
    required this.id,
    required this.sessionIndex,
    required this.date,
    required this.time,
    required this.title,
    this.fullTranscript = '',
    this.aiSummary = '',
    this.masterNotes = '',
    this.eddiesCirculated = 0,
    this.keyEvents = const <String>[],
  });

  final String id;
  final int sessionIndex;
  final String date;
  final String time;
  String title;
  String fullTranscript;
  String aiSummary;
  String masterNotes;
  int eddiesCirculated;
  List<String> keyEvents;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'sessionIndex': sessionIndex,
        'date': date,
        'time': time,
        'title': title,
        'fullTranscript': fullTranscript,
        'aiSummary': aiSummary,
        'masterNotes': masterNotes,
        'eddiesCirculated': eddiesCirculated,
        'keyEvents': keyEvents,
      };

  static CampaignSessionCommit fromJson(Map<String, Object?> json) => CampaignSessionCommit(
        id: readString(json['id']),
        sessionIndex: readInt(json['sessionIndex'], 1),
        date: readString(json['date']),
        time: readString(json['time']),
        title: readString(json['title']),
        fullTranscript: readString(json['fullTranscript']),
        aiSummary: readString(json['aiSummary']),
        masterNotes: readString(json['masterNotes']),
        eddiesCirculated: readInt(json['eddiesCirculated']),
        keyEvents: readStringList(json['keyEvents']),
      );
}

/// Singolo partecipante nell'iniziativa tattica condivisa al tavolo.
class CombatInitiativeEntry {
  CombatInitiativeEntry({
    required this.id,
    required this.name,
    required this.initiative,
    this.isPlayer = false,
    this.playerId = '',
    this.waypointId,
    this.currentHp = 30,
    this.maxHp = 30,
    this.hasActed = false,
  });

  final String id;
  final String name;
  int initiative;
  final bool isPlayer;
  final String playerId;
  final String? waypointId;
  int currentHp;
  int maxHp;
  bool hasActed;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'initiative': initiative,
        'isPlayer': isPlayer,
        'playerId': playerId,
        if (waypointId != null) 'waypointId': waypointId,
        'currentHp': currentHp,
        'maxHp': maxHp,
        'hasActed': hasActed,
      };

  static CombatInitiativeEntry fromJson(Map<String, Object?> json) => CombatInitiativeEntry(
        id: readString(json['id']),
        name: readString(json['name']),
        initiative: readInt(json['initiative']),
        isPlayer: readBool(json['isPlayer']),
        playerId: readString(json['playerId']),
        waypointId: readNullableString(json['waypointId']),
        currentHp: readInt(json['currentHp'], 30),
        maxHp: readInt(json['maxHp'], 30),
        hasActed: readBool(json['hasActed']),
      );
}
