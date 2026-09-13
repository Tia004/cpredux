import 'dart:math' as math;

import 'catalog_item.dart';
import 'cyberware.dart';
import 'effects.dart';
import 'enums.dart';
import 'items.dart';
import 'modifiers.dart';
import 'sheet.dart';
import 'skills.dart';
import 'stats.dart';

/// Tutti i valori *derivati* di una scheda.
///
/// Il principio: la scheda memorizza solo cio' che l'utente ha inserito (valori
/// base, correzioni, oggetti) e **tutto il resto si ricalcola**. Nessun totale
/// viene salvato su disco. Cosi' e' impossibile che un file contenga un totale
/// incoerente con i dati che lo generano — un problema che nel vecchio progetto
/// esisteva, perche' i valori massimi erano ricalcolati a schermo ma i punti
/// vita correnti vivevano in una chiave separata dello stesso database.
class SheetTotals {
  const SheetTotals({
    required this.stats,
    required this.skills,
    required this.maxHitPoints,
    required this.severeInjuriesThreshold,
    required this.maxEmpathy,
    required this.maxHumanity,
    required this.humanityLost,
    required this.currentLoad,
    required this.maxLoad,
    required this.loadPercentage,
    required this.loadStatus,
  });

  /// Caratteristiche calcolate, penalita' di carico gia' inclusa.
  final Map<Stat, int> stats;

  /// Livelli abilita' calcolati, correzioni gia' incluse.
  final Map<Skill, int> skills;

  final int maxHitPoints;

  /// Soglia oltre la quale ogni danno inflitto causa una ferita grave.
  final int severeInjuriesThreshold;
  final int maxEmpathy;
  final int maxHumanity;

  /// Umanita' persa per via del cyberware installato.
  final int humanityLost;
  final double currentLoad;
  final double maxLoad;
  final double loadPercentage;
  final LoadStatus loadStatus;

  int statValue(Stat stat) => stats[stat] ?? 0;

  int skillValue(Skill skill) => skills[skill] ?? 0;

  /// Totale di un tiro di abilita': caratteristica + livello abilita'.
  ///
  /// In CP RED un tiro e' 1d10 + CARATTERISTICA + ABILITA': tenere distinte le
  /// due componenti e' necessario, perche' la scheda deve mostrare *da dove*
  /// arriva il numero quando il master chiede "come fai ad avere 17?".
  int skillCheck(Skill skill) => statValue(skill.stat) + skillValue(skill);
}

/// Lookup vuoto: usato quando il catalogo non e' disponibile. Le voci
/// personalizzate continuano a funzionare perche' portano i propri dati.
CatalogItem? _noCatalog(String catalogId) => null;

/// Risolve un identificativo di catalogo nella voce corrispondente.
///
/// Il calcolo riceve una **funzione** e non il catalogo: `lib/domain/` non
/// importa nulla di Flutter e non conosce il database, cosi' resta verificabile
/// con i test puri e riutilizzabile dallo script che genera il catalogo.
/// Passare `null` significa "nessun catalogo": tutte le voci risultano
/// personalizzate e portano la propria definizione.
typedef CatalogLookup = CatalogItem? Function(String catalogId);

/// Calcola tutti i valori derivati di una scheda.
SheetTotals computeTotals(CharacterSheet sheet, {CatalogLookup? lookup}) {
  // 1. Correzioni alle caratteristiche, raccolte da tutte le fonti.
  final Map<Stat, int> statAdjust = <Stat, int>{for (final Stat s in Stat.values) s: 0};
  void applyStat(List<StatModifier> mods) {
    for (final StatModifier m in mods) {
      if (m.isActive) statAdjust[m.target] = (statAdjust[m.target] ?? 0) + m.value;
    }
  }

  applyStat(sheet.statModifiers);
  for (final Cyberware c in sheet.cyberware) {
    applyStat(c.statModifiers);
  }
  for (final Effect e in sheet.effects) {
    if (e.isActive) applyStat(e.statModifiers);
  }

  // 2. Effetti cumulativi su Punti Vita e Carico.
  int lifeEffect = 0;
  double lifePercent = 0;
  double loadEffect = 0;
  double loadPercent = 0;

  for (final Cyberware c in sheet.cyberware) {
    lifeEffect += c.lifeEffect;
    lifePercent += c.lifePercentEffect;
    loadEffect += c.loadEffect;
    loadPercent += c.loadPercentEffect;
  }
  for (final Effect e in sheet.effects) {
    if (!e.isActive) continue;
    lifeEffect += e.lifeEffect;
    lifePercent += e.lifePercentEffect;
    loadEffect += e.loadEffect;
    loadPercent += e.loadPercentEffect;
  }

  // 3. Punti Vita massimi: media di Fisico e Volonta', arrotondata per
  //    eccesso, poi 10 + 5 per punto. E' la formula del progetto originale.
  final int bodyBase = sheet.statBase[Stat.body] ?? 1;
  final int willpowerBase = sheet.statBase[Stat.willpower] ?? 1;
  final int body = bodyBase + (statAdjust[Stat.body] ?? 0);
  final int willpower = willpowerBase + (statAdjust[Stat.willpower] ?? 0);

  final int average = ((body + willpower) / 2).ceil();
  int maxHitPoints = 10 + (5 * average);
  maxHitPoints = (maxHitPoints * (1 + (lifePercent / 100.0)) + lifeEffect).ceil();
  if (maxHitPoints < 1) maxHitPoints = 1;

  final int severeThreshold = (maxHitPoints / 2).ceil();

  // 4. Umanita': il massimo e' dieci volte l'Empatia calcolata.
  final int maxEmpathy = (sheet.statBase[Stat.empathy] ?? 1) + (statAdjust[Stat.empathy] ?? 0);
  final int maxHumanity = maxEmpathy * 10;

  int humanityLost = 0;
  for (final Cyberware c in sheet.cyberware) {
    humanityLost += c.humanityLost;
  }

  // 5. Carico. Il peso del cyberware conta: e' dentro il corpo, ma e' peso.
  //    Il peso degli oggetti arriva dal catalogo, unito alle personalizzazioni:
  //    la scheda non contiene piu' i dati dell'oggetto, quindi il carico non si
  //    puo' calcolare senza risolvere i riferimenti.
  final List<ResolvedItem> resolved =
      ResolvedItem.resolveAll(sheet.inventory, lookup ?? _noCatalog);

  double currentLoad = 0;
  for (final ResolvedItem item in resolved) {
    currentLoad += item.totalWeight;
  }
  for (final Cyberware c in sheet.cyberware) {
    currentLoad += c.weight;
  }

  double maxLoad = body * 10.0;
  maxLoad = (maxLoad * (1 + (loadPercent / 100.0))) + loadEffect;

  final double loadPercentage = maxLoad <= 0 ? 0 : (currentLoad / maxLoad) * 100.0;
  final LoadStatus loadStatus = LoadStatus.fromPercentage(loadPercentage);

  // 6. Penalita' delle armature indossate. Nel progetto originale il valore
  //    salvato e' la **grandezza** della penalita' ed e' positivo: si somma e,
  //    solo se il totale e' maggiore di zero, si sottrae a Riflessi, Destrezza
  //    e Velocita'. Un'armatura con penalita' negativa (un bonus) non diventa
  //    quindi un bonus: e' il comportamento del progetto originale, e sui dati
  //    salvati e' l'unica lettura coerente.
  int armorPenalties = 0;
  for (final ResolvedItem item in resolved) {
    if (!item.entry.isEquipped) continue;
    final ArmorData? armor = item.armor;
    if (armor == null) continue;
    armorPenalties += armor.penalties;
  }

  // 7. Caratteristiche finali. Le correzioni si applicano *dopo* il calcolo del
  //    carico: Velocita' e Destrezza non entrano nella formula del carico
  //    massimo, quindi non c'e' circolarita'.
  final Map<Stat, int> stats = <Stat, int>{
    for (final Stat s in Stat.values) s: (sheet.statBase[s] ?? 1) + (statAdjust[s] ?? 0),
  };
  stats[Stat.dexterity] = (stats[Stat.dexterity] ?? 0) + loadStatus.statPenalty;
  stats[Stat.movement] = (stats[Stat.movement] ?? 0) + loadStatus.statPenalty;
  if (armorPenalties > 0) {
    for (final Stat stat in <Stat>[Stat.reflexes, Stat.dexterity, Stat.movement]) {
      stats[stat] = (stats[stat] ?? 0) - armorPenalties;
    }
  }

  // 8. Nessuna caratteristica calcolata scende sotto 1: e' il limite del
  //    progetto originale (`Math.max(1, ...)`) e va applicato **dopo** aver
  //    sommato tutte le correzioni, incluse quelle di carico e armatura.
  for (final Stat stat in Stat.values) {
    if ((stats[stat] ?? 1) < 1) stats[stat] = 1;
  }

  // 9. Abilita'.
  final Map<Skill, int> skills = <Skill, int>{
    for (final Skill s in Skill.values) s: sheet.skillLevels[s] ?? 0,
  };
  void applySkill(List<SkillModifier> mods) {
    for (final SkillModifier m in mods) {
      if (!m.isActive) continue;
      final Skill? skill = m.skill;
      if (skill == null) continue;
      skills[skill] = (skills[skill] ?? 0) + m.value;
    }
  }

  applySkill(sheet.skillModifiers);
  for (final Cyberware c in sheet.cyberware) {
    applySkill(c.skillModifiers);
  }
  for (final Effect e in sheet.effects) {
    if (e.isActive) applySkill(e.skillModifiers);
  }

  return SheetTotals(
    stats: stats,
    skills: skills,
    maxHitPoints: maxHitPoints,
    severeInjuriesThreshold: severeThreshold,
    maxEmpathy: maxEmpathy,
    maxHumanity: maxHumanity,
    humanityLost: humanityLost,
    currentLoad: currentLoad,
    maxLoad: maxLoad,
    loadPercentage: loadPercentage,
    loadStatus: loadStatus,
  );
}

/// Esito di un tiro di dado.
class DiceRoll {
  const DiceRoll({
    required this.die,
    required this.result,
    this.label = '',
    this.modifier = 0,
  });

  final DiceType die;
  final int result;

  /// Cosa si stava tirando ("Pistole", "Iniziativa").
  final String label;
  final int modifier;

  int get total => result + modifier;

  /// In CP RED un 10 naturale e' un critico: si tira di nuovo e si somma.
  bool get isCritical => die == DiceType.d10 && result == 10;

  /// Un 1 naturale con 1d10 e' un fallimento critico.
  bool get isFumble => die == DiceType.d10 && result == 1;
}

/// Tira un dado a N facce. `Random` e' iniettabile per rendere i test
/// deterministici: senza questo, testare la logica dei critici significherebbe
/// tirare finche' non esce un 10.
DiceRoll rollDie(DiceType die, {String label = '', int modifier = 0, math.Random? random}) {
  final math.Random rng = random ?? math.Random();
  return DiceRoll(
    die: die,
    result: rng.nextInt(die.faces) + 1,
    label: label,
    modifier: modifier,
  );
}

/// Tiro di abilita': 1d10 + caratteristica + abilita'.
DiceRoll rollSkillCheck(
  CharacterSheet sheet,
  Skill skill, {
  math.Random? random,
  CatalogLookup? lookup,
}) {
  final SheetTotals totals = computeTotals(sheet, lookup: lookup);
  return rollDie(
    DiceType.d10,
    label: skill.name,
    modifier: totals.skillCheck(skill),
    random: random,
  );
}

/// Tira piu' dadi e somma: `rollDice(DiceType.d6, 3)` equivale a 3d6.
DiceRoll rollDice(DiceType die, int count, {String label = '', int modifier = 0, math.Random? random}) {
  final math.Random rng = random ?? math.Random();
  int sum = 0;
  for (int i = 0; i < count; i++) {
    sum += rng.nextInt(die.faces) + 1;
  }
  return DiceRoll(die: die, result: sum, label: label, modifier: modifier);
}
