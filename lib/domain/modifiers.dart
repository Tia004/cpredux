import 'json_support.dart';
import 'skills.dart';
import 'stats.dart';

/// Correzione a una caratteristica.
///
/// Le correzioni vivono **dentro** l'elemento che le genera (cyberware,
/// effetto) oppure nella lista manuale della scheda: non esiste un elenco
/// globale con puntatori incrociati. La conseguenza pratica e' che rimuovere
/// un impianto rimuove automaticamente le sue correzioni, senza rischio di
/// lasciare in giro modificatori orfani che falserebbero i totali.
class StatModifier {
  StatModifier({
    required this.target,
    this.value = 0,
    this.isActive = true,
  });

  final Stat target;
  int value;
  bool isActive;

  /// Contributo al totale calcolato, zero se la correzione e' disattivata.
  int get contribution => isActive ? value : 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'target': target.id,
        'value': value,
        'active': isActive,
      };

  static StatModifier fromJson(Map<String, Object?> json) => StatModifier(
        target: Stat.fromId(readInt(json['target'])) ?? Stat.intelligence,
        value: readInt(json['value']),
        isActive: readBool(json['active'], true),
      );
}

/// Correzione a un'abilita'. Si salva l'id numerico e non l'enum, cosi' un
/// riferimento a un'abilita' sconosciuta non fa saltare l'apertura del file.
class SkillModifier {
  SkillModifier({
    required this.skillId,
    this.value = 0,
    this.isActive = true,
  });

  final int skillId;
  int value;
  bool isActive;

  Skill? get skill => Skill.fromId(skillId);

  int get contribution => isActive ? value : 0;

  Map<String, Object?> toJson() => <String, Object?>{
        'skillId': skillId,
        'value': value,
        'active': isActive,
      };

  static SkillModifier fromJson(Map<String, Object?> json) => SkillModifier(
        skillId: readInt(json['skillId']),
        value: readInt(json['value']),
        isActive: readBool(json['active'], true),
      );
}

/// Competenza: la specializzazione di un'abilita' "master" (Musica,
/// Linguaggio, Scienza, Conoscenza della Zona).
class Proficiency {
  Proficiency({
    required this.id,
    required this.masterSkillId,
    required this.name,
    this.level = 0,
    List<StatModifier>? statModifiers,
    List<SkillModifier>? skillModifiers,
  })  : statModifiers = statModifiers ?? <StatModifier>[],
        skillModifiers = skillModifiers ?? <SkillModifier>[];

  final String id;
  final int masterSkillId;

  /// Modificabile: una competenza si rinomina dalla scheda, e obbligare a
  /// cancellarla e ricrearla per correggere una lettera perderebbe i suoi
  /// modificatori associati.
  String name;
  int level;
  final List<StatModifier> statModifiers;
  final List<SkillModifier> skillModifiers;

  Skill? get masterSkill => Skill.fromId(masterSkillId);

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'masterSkillId': masterSkillId,
        'name': name,
        'level': level,
        'statModifiers': statModifiers.map((StatModifier m) => m.toJson()).toList(),
        'skillModifiers': skillModifiers.map((SkillModifier m) => m.toJson()).toList(),
      };

  static Proficiency fromJson(Map<String, Object?> json) => Proficiency(
        id: readString(json['id']),
        masterSkillId: readInt(json['masterSkillId']),
        name: readString(json['name']),
        level: readInt(json['level']),
        statModifiers: readObjectList(json['statModifiers'])
            .map(StatModifier.fromJson)
            .toList(growable: false),
        skillModifiers: readObjectList(json['skillModifiers'])
            .map(SkillModifier.fromJson)
            .toList(growable: false),
      );
}
