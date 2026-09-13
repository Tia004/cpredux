import 'stats.dart';

/// Categorie di abilita', usate per raggruppare la scheda.
enum SkillCategory {
  performance('Abilita Artistiche'),
  awareness('Abilita di Attenzione'),
  rangedWeapon('Abilita di Combattimento a Distanza'),
  fighting('Abilita di Combattimento Ravvicinato'),
  control('Abilita di Controllo'),
  body('Abilita Fisiche'),
  education('Abilita d\'Istruzione'),
  social('Abilita Sociali'),
  technique('Abilita Tecniche');

  const SkillCategory(this.label);

  final String label;
}

/// Le 68 abilita' di Cyberpunk RED.
///
/// Ogni voce porta il `id` stabile del vecchio database, la caratteristica di
/// riferimento, la categoria e i tre marcatori di regola:
///
/// * `isMaster` — abilita' che si specializza in *competenze* (Proficiency):
///   Musica, Conoscenza della Zona, Linguaggio, Scienza.
/// * `isEssential` — abilita' essenziali, costano doppio in progressione.
/// * `isDoubleCost` — abilita' che costano doppio punto in creazione.
enum Skill {
  acting(0, Stat.willpower, SkillCategory.performance, 'Recitare'),
  playInstrument(1, Stat.technique, SkillCategory.performance, 'Musica', isMaster: true),
  concentration(2, Stat.willpower, SkillCategory.awareness, 'Concentrazione', isEssential: true),
  lipReading(3, Stat.intelligence, SkillCategory.awareness, 'Leggere le Labbra'),
  concealRevealObject(4, Stat.intelligence, SkillCategory.awareness, 'Nascondere/Trovare Oggetti'),
  perception(5, Stat.intelligence, SkillCategory.awareness, 'Percezione', isEssential: true),
  tracking(6, Stat.intelligence, SkillCategory.awareness, 'Seguire Tracce'),
  heavyWeapons(7, Stat.reflexes, SkillCategory.rangedWeapon, 'Armi Pesanti', isDoubleCost: true),
  shoulderArms(8, Stat.reflexes, SkillCategory.rangedWeapon, 'Armi da Spalla'),
  autofire(9, Stat.reflexes, SkillCategory.rangedWeapon, 'Fuoco Automatico', isDoubleCost: true),
  handgun(10, Stat.reflexes, SkillCategory.rangedWeapon, 'Pistole'),
  archery(11, Stat.reflexes, SkillCategory.rangedWeapon, 'Tiro con l\'Arco'),
  meleeWeapon(12, Stat.dexterity, SkillCategory.fighting, 'Armi da Mischia'),
  martialArts(13, Stat.dexterity, SkillCategory.fighting, 'Arti Marziali', isDoubleCost: true),
  evasion(14, Stat.dexterity, SkillCategory.fighting, 'Elusione', isEssential: true),
  brawling(15, Stat.dexterity, SkillCategory.fighting, 'Rissa', isEssential: true),
  riding(16, Stat.reflexes, SkillCategory.control, 'Cavalcare'),
  driveLandVehicle(17, Stat.reflexes, SkillCategory.control, 'Guidare'),
  pilotAirVehicle(18, Stat.reflexes, SkillCategory.control, 'Pilotare Aeromobili', isDoubleCost: true),
  pilotSeaVehicle(19, Stat.reflexes, SkillCategory.control, 'Pilotare Imbarcazioni'),
  athletics(20, Stat.dexterity, SkillCategory.body, 'Atletica', isEssential: true),
  contortionist(21, Stat.dexterity, SkillCategory.body, 'Contorsionista'),
  dance(22, Stat.dexterity, SkillCategory.body, 'Danza'),
  stealth(23, Stat.dexterity, SkillCategory.body, 'Furtivita', isEssential: true),
  resistTortureDrugs(24, Stat.willpower, SkillCategory.body, 'Resistere a Tortura/Droghe'),
  endurance(25, Stat.willpower, SkillCategory.body, 'Tempra'),
  animalHandling(26, Stat.intelligence, SkillCategory.education, 'Allevamento'),
  librarySearch(27, Stat.intelligence, SkillCategory.education, 'Archivista'),
  bureaucracy(28, Stat.intelligence, SkillCategory.education, 'Burocrazia'),
  business(29, Stat.intelligence, SkillCategory.education, 'Business'),
  composition(30, Stat.intelligence, SkillCategory.education, 'Comporre'),
  localExpert(31, Stat.intelligence, SkillCategory.education, 'Conoscenza della Zona', isMaster: true),
  localExpertHome(32, Stat.intelligence, SkillCategory.education, 'Casa', isEssential: true),
  accounting(33, Stat.intelligence, SkillCategory.education, 'Contabilita'),
  criminology(34, Stat.intelligence, SkillCategory.education, 'Criminologia'),
  cryptography(35, Stat.intelligence, SkillCategory.education, 'Crittografia'),
  deduction(36, Stat.intelligence, SkillCategory.education, 'Deduzione'),
  gamble(37, Stat.intelligence, SkillCategory.education, 'Gioco d\'Azzardo'),
  education(38, Stat.intelligence, SkillCategory.education, 'Istruzione', isEssential: true),
  language(39, Stat.intelligence, SkillCategory.education, 'Linguaggio', isMaster: true),
  languageStreetslang(40, Stat.intelligence, SkillCategory.education, 'Streetslang', isEssential: true),
  science(41, Stat.intelligence, SkillCategory.education, 'Scienza', isMaster: true),
  wildernessSurvival(42, Stat.intelligence, SkillCategory.education, 'Survivalismo'),
  tactics(43, Stat.intelligence, SkillCategory.education, 'Tattica'),
  trading(44, Stat.cool, SkillCategory.social, 'Commercio'),
  conversation(45, Stat.empathy, SkillCategory.social, 'Conversazione', isEssential: true),
  bribery(46, Stat.cool, SkillCategory.social, 'Corrompere'),
  personalGrooming(47, Stat.cool, SkillCategory.social, 'Cura della Persona'),
  wardrobeAndStyle(48, Stat.cool, SkillCategory.social, 'Guardaroba e Stile'),
  interrogation(49, Stat.cool, SkillCategory.social, 'Interrogatorio'),
  persuasion(50, Stat.cool, SkillCategory.social, 'Persuasione', isEssential: true),
  streetwise(51, Stat.cool, SkillCategory.social, 'Scaltrezza'),
  humanPerception(52, Stat.empathy, SkillCategory.social, 'Sensibilita', isEssential: true),
  paintDrawSculpt(53, Stat.technique, SkillCategory.technique, 'Belle Arti'),
  pickPocket(54, Stat.technique, SkillCategory.technique, 'Borseggiare'),
  cybertech(55, Stat.technique, SkillCategory.technique, 'Cybertecnologia'),
  demolitions(56, Stat.technique, SkillCategory.technique, 'Demolizioni', isDoubleCost: true),
  electronicsSecurityTech(57, Stat.technique, SkillCategory.technique, 'Elettronica e Sicurezza', isDoubleCost: true),
  forgery(58, Stat.technique, SkillCategory.technique, 'Falsificare'),
  photographyFilm(59, Stat.technique, SkillCategory.technique, 'Fotografia'),
  paramedic(60, Stat.technique, SkillCategory.technique, 'Paramedico', isDoubleCost: true),
  firstAid(61, Stat.technique, SkillCategory.technique, 'Pronto Soccorso', isEssential: true),
  pickLock(62, Stat.technique, SkillCategory.technique, 'Scassinare'),
  airVehicleTech(63, Stat.technique, SkillCategory.technique, 'Tecnologia degli Aeromobili'),
  weaponstech(64, Stat.technique, SkillCategory.technique, 'Tecnologia delle Armi'),
  basicTech(65, Stat.technique, SkillCategory.technique, 'Tecnologia di Base'),
  seaVehicleTech(66, Stat.technique, SkillCategory.technique, 'Tecnologia delle Imbarcazioni'),
  landVehicleTech(67, Stat.technique, SkillCategory.technique, 'Tecnologia dei Veicoli di Terra');

  const Skill(
    this.id,
    this.stat,
    this.category,
    this.name, {
    this.isMaster = false,
    this.isEssential = false,
    this.isDoubleCost = false,
  });

  final int id;
  final Stat stat;
  final SkillCategory category;
  final String name;
  final bool isMaster;
  final bool isEssential;
  final bool isDoubleCost;

  /// Nome mostrato nella scheda: le abilita' a costo doppio sono marcate,
  /// come faceva il progetto originale, perche' e' un'informazione che serve
  /// *mentre* si spendono i punti, non dopo.
  String get displayName => isDoubleCost ? '$name (x2)' : name;

  /// Abilita' che si specializzano in competenze.
  static final List<Skill> masterSkills =
      Skill.values.where((Skill s) => s.isMaster).toList(growable: false);

  static final List<Skill> nonMasterSkills =
      Skill.values.where((Skill s) => !s.isMaster).toList(growable: false);

  /// Abilita' utilizzabili con le armi: mischia, piu' tutte le a distanza
  /// che non sono contenitori di competenze.
  static final List<Skill> weaponSkills = <Skill>[
    Skill.meleeWeapon,
    ...Skill.values.where(
      (Skill s) => s.category == SkillCategory.rangedWeapon && !s.isMaster,
    ),
  ];

  static final Map<SkillCategory, List<Skill>> byCategory = <SkillCategory, List<Skill>>{
    for (final SkillCategory category in SkillCategory.values)
      category: Skill.values.where((Skill s) => s.category == category).toList(growable: false),
  };

  static Skill? fromId(int id) {
    for (final Skill skill in Skill.values) {
      if (skill.id == id) return skill;
    }
    return null;
  }
}
