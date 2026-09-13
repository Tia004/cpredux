import 'enums.dart';
import 'json_support.dart';
import 'modifiers.dart';

/// Effetto attivo sul personaggio: una ferita, una droga, una malattia.
///
/// La distinzione importante e' `isActive`: un effetto registrato ma non
/// attivo resta in scheda come memoria clinica (utile al master per capire cosa
/// e' successo) senza incidere sui totali. Il vecchio progetto faceva la stessa
/// cosa con la colonna `is_active`, ed e' la ragione per cui gli effetti non
/// vengono semplicemente cancellati quando guariscono.
class Effect {
  Effect({
    required this.id,
    required this.name,
    this.duration = '',
    this.intensity = 0,
    this.isTreatable = EffectKnowledge.unknown,
    this.isCurable = EffectKnowledge.unknown,
    this.isLethal = EffectKnowledge.unknown,
    this.lifeEffect = 0,
    this.lifePercentEffect = 0,
    this.loadEffect = 0,
    this.loadPercentEffect = 0,
    this.otherEffects = '',
    this.description = '',
    this.isActive = false,
    List<StatModifier>? statModifiers,
    List<SkillModifier>? skillModifiers,
  })  : statModifiers = statModifiers ?? <StatModifier>[],
        skillModifiers = skillModifiers ?? <SkillModifier>[];

  final String id;
  String name;
  String duration;
  int intensity;
  EffectKnowledge isTreatable;
  EffectKnowledge isCurable;
  EffectKnowledge isLethal;
  int lifeEffect;
  double lifePercentEffect;
  double loadEffect;
  double loadPercentEffect;
  String otherEffects;
  String description;
  bool isActive;
  final List<StatModifier> statModifiers;
  final List<SkillModifier> skillModifiers;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'duration': duration,
        'intensity': intensity,
        'isTreatable': isTreatable.id,
        'isCurable': isCurable.id,
        'isLethal': isLethal.id,
        'lifeEffect': lifeEffect,
        'lifePercentEffect': lifePercentEffect,
        'loadEffect': loadEffect,
        'loadPercentEffect': loadPercentEffect,
        'otherEffects': otherEffects,
        'description': description,
        'isActive': isActive,
        'statModifiers': statModifiers.map((StatModifier m) => m.toJson()).toList(),
        'skillModifiers': skillModifiers.map((SkillModifier m) => m.toJson()).toList(),
      };

  static Effect fromJson(Map<String, Object?> json) => Effect(
        id: readString(json['id']),
        name: readString(json['name']),
        duration: readString(json['duration']),
        intensity: readInt(json['intensity']),
        isTreatable: EffectKnowledge.fromId(readInt(json['isTreatable'], -1)) ?? EffectKnowledge.unknown,
        isCurable: EffectKnowledge.fromId(readInt(json['isCurable'], -1)) ?? EffectKnowledge.unknown,
        isLethal: EffectKnowledge.fromId(readInt(json['isLethal'], -1)) ?? EffectKnowledge.unknown,
        lifeEffect: readInt(json['lifeEffect']),
        lifePercentEffect: readDouble(json['lifePercentEffect']),
        loadEffect: readDouble(json['loadEffect']),
        loadPercentEffect: readDouble(json['loadPercentEffect']),
        otherEffects: readString(json['otherEffects']),
        description: readString(json['description']),
        isActive: readBool(json['isActive']),
        statModifiers: readObjectList(json['statModifiers']).map(StatModifier.fromJson).toList(growable: false),
        skillModifiers: readObjectList(json['skillModifiers']).map(SkillModifier.fromJson).toList(growable: false),
      );
}
