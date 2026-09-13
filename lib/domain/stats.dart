/// Le dieci caratteristiche di Cyberpunk RED.
///
/// `id` e' l'identificativo stabile usato dal database del vecchio progetto
/// (tabelle `stats`, `stats_alterations`): non va mai riassegnato, altrimenti
/// il migratore mappa le alterazioni alla caratteristica sbagliata.
enum Stat {
  intelligence(0, 'Intelligenza'),
  reflexes(1, 'Riflessi'),
  dexterity(2, 'Destrezza'),
  technique(3, 'Tecnica'),
  cool(4, 'Carisma'),
  willpower(5, 'Volonta'),
  luck(6, 'Fortuna'),
  movement(7, 'Velocita'),
  body(8, 'Fisico'),
  empathy(9, 'Empatia');

  const Stat(this.id, this.label);

  final int id;
  final String label;

  /// Sigla di tre lettere, derivata dal nome come nel progetto originale
  /// (`name.toUpperCase().substring(0, 3)`): INT, REF, DES, TEC, CAR, VOL,
  /// FOR, VEL, FIS, EMP.
  String get short => label.toUpperCase().substring(0, 3);

  /// Valore massimo consentito in creazione. Le caratteristiche in CP RED
  /// vanno da 2 a 8 dopo la distribuzione dei punti (alcune partono da 1),
  /// quindi il limite pratico e' 8 e lo teniamo come riferimento unico.
  static const int max = 8;

  static Stat? fromId(int id) {
    for (final Stat stat in Stat.values) {
      if (stat.id == id) return stat;
    }
    return null;
  }
}
