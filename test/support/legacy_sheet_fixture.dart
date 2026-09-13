import 'package:sqlite3/sqlite3.dart';

/// Un PNG 1x1 valido: serve a verificare l'estrazione delle immagini, non a
/// guardarlo.
const String tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8AAAwAB/AL+2wAAAABJRU5ErkJggg==';

/// Costruisce una vecchia `.cpred_sheet` con **lo schema esatto** del progetto
/// Java (tabelle, colonne e chiavi di `key_parameters`).
///
/// Il valore di questo test sta proprio qui: la conversione e' l'unico punto in
/// cui il nuovo programma legge dati scritti da un altro programma, e un nome
/// di colonna sbagliato non si scopre compilando — si scopre quando l'utente
/// apre la sua scheda di due anni e vede un errore.
void createLegacySheet(String path) {
  final Database db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE key_parameters (param_key VARCHAR(32) NOT NULL PRIMARY KEY, param_value TEXT);
    CREATE TABLE notes (
      id INTEGER NOT NULL PRIMARY KEY,
      title VARCHAR(32) NOT NULL UNIQUE,
      content TEXT NOT NULL,
      creation_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      last_edit DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE stats (id INTEGER NOT NULL PRIMARY KEY, stat_value INTEGER NOT NULL);
    CREATE TABLE stats_alterations (
      id INTEGER NOT NULL PRIMARY KEY,
      stat_id INTEGER NOT NULL,
      alteration INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE skills (id INTEGER NOT NULL PRIMARY KEY, skill_level INTEGER NOT NULL DEFAULT 0);
    CREATE TABLE skills_alterations (
      id INTEGER NOT NULL PRIMARY KEY,
      skill_id INTEGER NOT NULL,
      alteration INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE proficiencies (
      id INTEGER NOT NULL PRIMARY KEY,
      master_skill_id INTEGER NOT NULL,
      proficiency_name TEXT NOT NULL UNIQUE,
      proficiency_level INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE proficiencies_alterations (
      id INTEGER NOT NULL PRIMARY KEY,
      proficiency_id INTEGER NOT NULL,
      alteration INTEGER NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE items (
      id INTEGER NOT NULL PRIMARY KEY,
      base64image TEXT,
      image_extension TEXT,
      name TEXT NOT NULL UNIQUE,
      cost INTEGER NOT NULL DEFAULT 0,
      description TEXT,
      rarity INTEGER NOT NULL DEFAULT 0,
      weight REAL NOT NULL DEFAULT 0,
      category INTEGER NOT NULL DEFAULT 0,
      quantity INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE armors (
      id INTEGER NOT NULL PRIMARY KEY,
      item_id INTEGER NOT NULL UNIQUE,
      slot INTEGER NOT NULL,
      sp INTEGER NOT NULL,
      penalties INTEGER NOT NULL DEFAULT 0,
      is_equipped INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE clothing (
      id INTEGER NOT NULL PRIMARY KEY,
      item_id INTEGER NOT NULL UNIQUE,
      slot INTEGER NOT NULL,
      style INTEGER NOT NULL,
      is_equipped INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE weapons (
      id INTEGER NOT NULL PRIMARY KEY,
      item_id INTEGER NOT NULL UNIQUE,
      weapon_skill INTEGER,
      hands_required TEXT NOT NULL,
      damage TEXT NOT NULL,
      current_ammo INTEGER NOT NULL DEFAULT 0,
      max_ammo INTEGER NOT NULL DEFAULT 0,
      rof INTEGER NOT NULL,
      is_concealable INTEGER NOT NULL DEFAULT 0,
      properties TEXT,
      is_equipped INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE installed_cyberware (
      id INTEGER NOT NULL PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      rarity INTEGER NOT NULL DEFAULT 0,
      base64image TEXT,
      image_extension TEXT,
      install_date TEXT NOT NULL,
      cyberware_category INTEGER NOT NULL,
      is_foundational INTEGER NOT NULL DEFAULT 0,
      description TEXT,
      effect_life INTEGER NOT NULL DEFAULT 0,
      effect_life_perc REAL NOT NULL DEFAULT 0,
      effect_load INTEGER NOT NULL DEFAULT 0,
      effect_load_perc REAL NOT NULL DEFAULT 0,
      humanity_lost INTEGER NOT NULL DEFAULT 0,
      weight REAL NOT NULL DEFAULT 0,
      cost INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE cyberware_stats_alterations (
      cyberware_id INTEGER NOT NULL, alteration_id INTEGER NOT NULL, PRIMARY KEY(cyberware_id, alteration_id)
    );
    CREATE TABLE cyberware_skills_alterations (
      cyberware_id INTEGER NOT NULL, alteration_id INTEGER NOT NULL, PRIMARY KEY(cyberware_id, alteration_id)
    );
    CREATE TABLE cyberware_proficiencies_alterations (
      cyberware_id INTEGER NOT NULL, alteration_id INTEGER NOT NULL, PRIMARY KEY(cyberware_id, alteration_id)
    );
    CREATE TABLE effects (
      id INTEGER NOT NULL PRIMARY KEY,
      name TEXT NOT NULL UNIQUE,
      duration TEXT,
      intensity INTEGER NOT NULL DEFAULT 0,
      is_treatable INTEGER NOT NULL DEFAULT -1,
      is_curable INTEGER NOT NULL DEFAULT -1,
      is_lethal INTEGER NOT NULL DEFAULT -1,
      life_effect INTEGER NOT NULL DEFAULT 0,
      life_percentage_effect REAL NOT NULL DEFAULT 0,
      load_effect REAL NOT NULL DEFAULT 0,
      load_percentage_effect REAL NOT NULL DEFAULT 0,
      other_effects TEXT,
      description TEXT,
      is_active INTEGER NOT NULL DEFAULT 0
    );
    CREATE TABLE effect_stats_alterations (
      effect_id INTEGER NOT NULL, alteration_id INTEGER NOT NULL, PRIMARY KEY(effect_id, alteration_id)
    );
    CREATE TABLE effect_skills_alterations (
      effect_id INTEGER NOT NULL, alteration_id INTEGER NOT NULL, PRIMARY KEY(effect_id, alteration_id)
    );
    CREATE TABLE effect_proficiencies_alterations (
      effect_id INTEGER NOT NULL, alteration_id INTEGER NOT NULL, PRIMARY KEY(effect_id, alteration_id)
    );
    CREATE TABLE bg_friends (id INTEGER NOT NULL PRIMARY KEY, name TEXT NOT NULL);
    CREATE TABLE bg_tragic_stories (id INTEGER NOT NULL PRIMARY KEY, name TEXT NOT NULL);
    CREATE TABLE bg_enemies (
      id INTEGER NOT NULL PRIMARY KEY,
      who TEXT NOT NULL,
      what_caused_it TEXT NOT NULL,
      what_can_they_throw_at_you TEXT NOT NULL,
      whats_gonna_happen TEXT NOT NULL
    );
  ''');

  void key(String k, String v) {
    db.execute('INSERT INTO key_parameters (param_key, param_value) VALUES (?, ?);', <Object?>[k, v]);
  }

  key('db_version', 'cpred_sheet_1.0');
  key('tag', 'Jackie');
  key('player_name', 'Tia');
  key('game_date', '2077, 12 giugno');
  key('aliases', 'Il Fantasma');
  key('reputation', '4');
  key('role', 'Solo');
  key('role_ability', 'Combat Awareness');
  key('role_rank', '4');
  key('current_hit_points', '32');
  key('current_luck', '5');
  key('current_improvement_points', '3');
  key('total_improvement_points', '12');
  key('severe_injuries', 'Costola incrinata');
  key('addictions', 'Nessuna');
  key('inspiration_points', '2');
  key('eurobucks', '1200');
  key('old_connections', 'Un fixer di nome Reyes');
  key('physical_description', 'Cicatrice sull occhio destro');
  key('age', '27');
  key('height', '1.78');
  key('weight', '74');
  key('eyes', 'Verdi');
  key('skin', 'Chiara');
  key('hair', 'Rasati');
  key('cultural_origins', 'Night City, Heywood');
  key('personality', 'Diretto');
  key('housing', 'Container in affitto');
  key('character_image', tinyPng);
  key('character_image_extension', 'png');

  // Caratteristiche: il resto resta al default 1.
  db.execute('INSERT INTO stats (id, stat_value) VALUES (8, 7), (9, 6), (2, 5);');
  db.execute('INSERT INTO skills (id, skill_level) VALUES (10, 6), (14, 4), (12, 3);');

  // Alterazione posseduta da un impianto, una da un effetto, una orfana.
  db.execute('INSERT INTO stats_alterations (id, stat_id, alteration, is_active) VALUES (1, 8, 2, 1), (2, 2, 1, 0), (3, 5, -1, 1);');
  db.execute('INSERT INTO skills_alterations (id, skill_id, alteration, is_active) VALUES (1, 10, 2, 1);');

  db.execute(
    'INSERT INTO proficiencies (id, master_skill_id, proficiency_name, proficiency_level) VALUES (?, ?, ?, ?);',
    <Object?>[1, 41, 'Chimica', 3],
  );
  db.execute('INSERT INTO proficiencies_alterations (id, proficiency_id, alteration, is_active) VALUES (1, 1, 1, 1);');

  db.execute(
    'INSERT INTO installed_cyberware '
    '(id, name, rarity, install_date, cyberware_category, is_foundational, effect_life, humanity_lost, weight, cost, description) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
    <Object?>[1, 'Interfaccia Neurale', 2, '2077-01-04', 1, 1, 5, 7, 1.5, 500, 'Slot per cyberdeck'],
  );
  db.execute('INSERT INTO cyberware_stats_alterations (cyberware_id, alteration_id) VALUES (1, 1);');
  db.execute('INSERT INTO cyberware_skills_alterations (cyberware_id, alteration_id) VALUES (1, 1);');

  // is_lethal resta al default -1: deve diventare "Sconosciuto", non "No".
  db.execute(
    'INSERT INTO effects '
    '(id, name, duration, intensity, is_treatable, is_curable, life_effect, description, is_active) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);',
    <Object?>[1, 'Veleno', '1 ora', 2, 1, 0, -3, 'Sostanza nel sangue', 1],
  );
  db.execute('INSERT INTO effect_stats_alterations (effect_id, alteration_id) VALUES (1, 3);');

  final PreparedStatement items = db.prepare(
    'INSERT INTO items (id, name, cost, description, rarity, weight, category, quantity, base64image, image_extension) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
  );
  items.execute(<Object?>[1, 'Pistola pesante', 100, 'Una mano', 2, 2.5, 5, 1, tinyPng, 'png']);
  items.execute(<Object?>[2, 'Giacca corazzata', 500, 'Kevlar', 3, 7.0, 4, 1, null, null]);
  items.execute(<Object?>[3, 'Tuta tecnica', 50, null, 0, 1.0, 3, 1, null, null]);
  items.close();

  db.execute(
    'INSERT INTO weapons (id, item_id, weapon_skill, hands_required, damage, current_ammo, max_ammo, rof, is_concealable, properties, is_equipped) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);',
    <Object?>[1, 1, 10, '1', '3d6', 8, 8, 2, 1, 'Kick', 1],
  );
  db.execute('INSERT INTO armors (id, item_id, slot, sp, penalties, is_equipped) VALUES (1, 2, 1, 11, 0, 1);');
  db.execute('INSERT INTO clothing (id, item_id, slot, style, is_equipped) VALUES (1, 3, 0, 4, 0);');

  db.execute(
    'INSERT INTO notes (id, title, content, creation_date, last_edit) VALUES (?, ?, ?, ?, ?);',
    <Object?>[1, 'Piano', 'Entrare dal tetto', '2077-06-01', '2077-06-02'],
  );
  db.execute('INSERT INTO bg_friends (id, name) VALUES (1, ?);', <Object?>['Kerry']);
  db.execute('INSERT INTO bg_tragic_stories (id, name) VALUES (1, ?);', <Object?>['Il fratello']);
  db.execute(
    'INSERT INTO bg_enemies (id, who, what_caused_it, what_can_they_throw_at_you, whats_gonna_happen) '
    'VALUES (?, ?, ?, ?, ?);',
    <Object?>[1, 'Arasaka', 'Ho rubato un prototipo', 'Squadre di recupero', 'Mi troveranno'],
  );

  db.close();
}

