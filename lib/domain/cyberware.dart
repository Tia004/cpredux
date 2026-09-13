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
    List<StatModifier>? statModifiers,
    List<SkillModifier>? skillModifiers,
  })  : statModifiers = statModifiers ?? <StatModifier>[],
        skillModifiers = skillModifiers ?? <SkillModifier>[];

  final String id;
  String name;
  CyberwareCategory category;
  Rarity rarity;

  /// Il cyberware fondazionale non puo' essere rimosso senza sostituire
  /// l'intero arto o sistema: e' un'informazione di regola, non estetica.
  bool isFoundational;
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

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'category': category.id,
        'rarity': rarity.name,
        'isFoundational': isFoundational,
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
      );
}
