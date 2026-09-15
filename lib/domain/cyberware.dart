import 'enums.dart';
import 'json_support.dart';
import 'modifiers.dart';

/// Cyberware installato.
///
/// Porta con se' le proprie correzioni a caratteristiche e abilita': e' il
/// modello corretto perche' un impianto e' un blocco unico. Nel vecchio
/// database le alterazioni stavano in tabelle separate collegate da tabelle
/// ponte, e questo rendeva possibile — in caso di errore nella cancellazione —
/// lasciare alterazioni attive senza il cyberware che le giustificava, cioe'
/// bonus permanenti dal nulla.
class Cyberware {
  Cyberware({
    required this.id,
    required this.name,
    this.category = CyberwareCategory.neuralware,
    this.rarity = Rarity.common,
    this.isFoundational = false,
    this.description = '',
    this.imagePath,
    this.installedAt,
    this.humanityLost = 0,
    this.weight = 0,
    this.cost = 0,
    this.lifeEffect = 0,
    this.lifePercentEffect = 0,
    this.loadEffect = 0,
    this.loadPercentEffect = 0,
    this.optionSlots = 0,
    this.slotsRequired = 1,
    this.parentFoundationId,
    this.bodyZone = 'torso',
    List<StatModifier>? statModifiers,
    List<SkillModifier>? skillModifiers,
    List<ProficiencyModifier>? proficiencyModifiers,
  })  : statModifiers = statModifiers ?? <StatModifier>[],
        skillModifiers = skillModifiers ?? <SkillModifier>[],
        proficiencyModifiers = proficiencyModifiers ?? <ProficiencyModifier>[];

  final String id;
  String name;
  CyberwareCategory category;
  Rarity rarity;

  /// Il cyberware fondamentale è la base strutturale (es. Collegamento Neuronale, Cyberocchio, Cyberbraccio)
  /// che ospita e abilita le sotto-opzioni tramite gli slot dedicati.
  bool isFoundational;

  /// Numero di slot opzione disponibili forniti da questo componente (se fondamentale).
  int optionSlots;

  /// Numero di slot consumati dall'installazione di questo componente (0 per il componente fondamentale).
  int slotsRequired;

  /// Riferimento all'ID del componente fondamentale che ospita questo cyberware opzionale.
  String? parentFoundationId;

  /// Zona anatomica corporea: head, eyes, ears, torso, arms, hands, legs, groin, skin
  String bodyZone;

  String description;
  String? imagePath;

  /// Data d'installazione in formato ISO (yyyy-MM-dd).
  String? installedAt;

  /// Punti di Umanita' permanentemente persi.
  int humanityLost;

  double weight;
  int cost;

  // Effetti su Punti Vita e Carico, sommati su tutti gli impianti installati.
  int lifeEffect;
  double lifePercentEffect;
  double loadEffect;
  double loadPercentEffect;

  final List<StatModifier> statModifiers;
  final List<SkillModifier> skillModifiers;
  final List<ProficiencyModifier> proficiencyModifiers;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'category': category.id,
        'rarity': rarity.name,
        'isFoundational': isFoundational,
        'optionSlots': optionSlots,
        'slotsRequired': slotsRequired,
        if (parentFoundationId != null) 'parentFoundationId': parentFoundationId,
        'bodyZone': bodyZone,
        'description': description,
        'imagePath': imagePath,
        'installedAt': installedAt,
        'humanityLost': humanityLost,
        'weight': weight,
        'cost': cost,
        'lifeEffect': lifeEffect,
        'lifePercentEffect': lifePercentEffect,
        'loadEffect': loadEffect,
        'loadPercentEffect': loadPercentEffect,
        'statModifiers': statModifiers.map((StatModifier m) => m.toJson()).toList(),
        'skillModifiers': skillModifiers.map((SkillModifier m) => m.toJson()).toList(),
        'proficiencyModifiers': proficiencyModifiers.map((ProficiencyModifier m) => m.toJson()).toList(),
      };

  static Cyberware fromJson(Map<String, Object?> json) => Cyberware(
        id: readString(json['id']),
        name: readString(json['name']),
        category: CyberwareCategory.fromId(readInt(json['category'])) ?? CyberwareCategory.neuralware,
        rarity: Rarity.values.firstWhere(
          (Rarity r) => r.name == readString(json['rarity']),
          orElse: () => Rarity.common,
        ),
        isFoundational: readBool(json['isFoundational']),
        optionSlots: readInt(json['optionSlots'], 0),
        slotsRequired: readInt(json['slotsRequired'], 1),
        parentFoundationId: readNullableString(json['parentFoundationId']),
        bodyZone: readString(json['bodyZone'], 'torso'),
        description: readString(json['description']),
        imagePath: readNullableString(json['imagePath']),
        installedAt: readNullableString(json['installedAt']),
        humanityLost: readInt(json['humanityLost']),
        weight: readDouble(json['weight']),
        cost: readInt(json['cost']),
        lifeEffect: readInt(json['lifeEffect']),
        lifePercentEffect: readDouble(json['lifePercentEffect']),
        loadEffect: readDouble(json['loadEffect']),
        loadPercentEffect: readDouble(json['loadPercentEffect']),
        statModifiers: readObjectList(json['statModifiers']).map(StatModifier.fromJson).toList(growable: false),
        skillModifiers: readObjectList(json['skillModifiers']).map(SkillModifier.fromJson).toList(growable: false),
        proficiencyModifiers: readObjectList(json['proficiencyModifiers']).map(ProficiencyModifier.fromJson).toList(growable: false),
      );
}

/// Zone anatomiche per la mappatura del cyberware sul corpo umano.
enum CyberBodyZone {
  head('head', 'Testa', 'Neuralware, cervello e innesti cranici'),
  eyes('eyes', 'Occhi', 'Cyberottica e visori digitali'),
  ears('ears', 'Orecchie', 'Cyberaudio e trasmettitori'),
  torso('torso', 'Busto', 'Organi sintetici e impianti interni'),
  arms('arms', 'Braccia · lato non assegnato', 'Cyberarti superiori e innesti muscolari'),
  hands('hands', 'Mani · lato non assegnato', 'Prese neurali, connettori e artigli'),
  groin('groin', 'Bacino', 'Supporti biomeccanici e sintetici'),
  legs('legs', 'Gambe · lato non assegnato', 'Cyberarti inferiori e propulsori'),
  skin('skin', 'Pelle', 'Rivestimento dermico e fashionware'),
  leftArm('left_arm', 'Braccio SX', 'Cyberbraccio sinistro'),
  rightArm('right_arm', 'Braccio DX', 'Cyberbraccio destro'),
  leftHand('left_hand', 'Mano SX', 'Cybermano sinistra e connettori'),
  rightHand('right_hand', 'Mano DX', 'Cybermano destra e connettori'),
  leftLeg('left_leg', 'Gamba SX', 'Cybergamba sinistra'),
  rightLeg('right_leg', 'Gamba DX', 'Cybergamba destra');

  const CyberBodyZone(this.id, this.label, this.description);
  final String id;
  final String label;
  final String description;

  bool get hasUnassignedSide => this == arms || this == hands || this == legs;

  /// The renderer and new installs use explicit sides. Legacy ids are retained
  /// in saved sheets until the player assigns a side in the implant editor.
  static List<CyberBodyZone> get selectable => values.where(
      (CyberBodyZone zone) => !zone.hasUnassignedSide).toList(growable: false);

  static CyberBodyZone fromId(String? id) {
    if (id == null) return CyberBodyZone.torso;
    for (final CyberBodyZone z in CyberBodyZone.values) {
      if (z.id.toLowerCase() == id.toLowerCase()) return z;
    }
    return CyberBodyZone.torso;
  }
}

/// Slot base forniti di default da un componente fondamentale secondo il manuale CP RED.
int defaultFoundationSlotsFor(CyberwareCategory category, [String? name]) {
  final String lower = (name ?? '').toLowerCase();
  if (lower.contains('gamba') || lower.contains('leg')) return 3;
  if (lower.contains('braccio') || lower.contains('arm')) return 4;
  switch (category) {
    case CyberwareCategory.neuralware:
      return 5;
    case CyberwareCategory.cyberoptics:
      return 3;
    case CyberwareCategory.cyberaudio:
      return 3;
    case CyberwareCategory.cyberlimbs:
      return 4;
    case CyberwareCategory.fashionware:
    case CyberwareCategory.internalCyberware:
    case CyberwareCategory.externalCyberware:
    case CyberwareCategory.borgware:
      return 3;
  }
}

/// Riconosce la zona corporea idonea per la categoria/nome dell'impianto.
String defaultBodyZoneFor(CyberwareCategory category, [String? name]) {
  final String lower = (name ?? '').toLowerCase();
  final String? side = lower.contains('sinistr') || RegExp(r'\b(left|sx)\b').hasMatch(lower)
      ? 'left' : lower.contains('destr') || RegExp(r'\b(right|dx)\b').hasMatch(lower) ? 'right' : null;
  if (side != null) {
    if (lower.contains('mano') || lower.contains('hand') || lower.contains('artigl')) return '${side}_hand';
    if (lower.contains('braccio') || lower.contains('arm')) return '${side}_arm';
    if (lower.contains('gamba') || lower.contains('leg') || lower.contains('piede') || lower.contains('foot')) return '${side}_leg';
  }
  if (lower.contains('gamba') || lower.contains('leg') || lower.contains('piede') || lower.contains('foot')) return 'legs';
  if (lower.contains('mano') || lower.contains('hand') || lower.contains('artigl') || lower.contains('claw')) return 'hands';
  if (lower.contains('braccio') || lower.contains('arm')) return 'arms';
  if (lower.contains('occhio') || lower.contains('ottic') || lower.contains('eye') || lower.contains('vision')) return 'eyes';
  if (lower.contains('orecch') || lower.contains('audit') || lower.contains('ear') || lower.contains('audio')) return 'ears';
  if (lower.contains('pelle') || lower.contains('skin') || lower.contains('dermal') || lower.contains('corazza')) return 'skin';
  if (lower.contains('cervello') || lower.contains('neural') || lower.contains('testa') || lower.contains('head')) return 'head';
  if (lower.contains('bacino') || lower.contains('groin') || lower.contains('genit')) return 'groin';

  switch (category) {
    case CyberwareCategory.neuralware:
      return 'head';
    case CyberwareCategory.cyberoptics:
      return 'eyes';
    case CyberwareCategory.cyberaudio:
      return 'ears';
    case CyberwareCategory.cyberlimbs:
      return 'arms';
    case CyberwareCategory.externalCyberware:
      return 'skin';
    case CyberwareCategory.internalCyberware:
    case CyberwareCategory.borgware:
    case CyberwareCategory.fashionware:
      return 'torso';
  }
}

