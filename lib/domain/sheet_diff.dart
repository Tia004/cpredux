import 'catalog_item.dart';
import 'cyberware.dart';
import 'effects.dart';
import 'items.dart';
import 'modifiers.dart';
import 'rules.dart';
import 'sheet.dart';
import 'skills.dart';
import 'stats.dart';

/// Confronto fra due schede.
///
/// Vive in `lib/domain/` e non dipende da Flutter: il confronto e' una
/// *lettura* dei dati, e come tale si puo' verificare senza disegnare niente.
/// La schermata che lo mostra e' un'altra cosa, e non deve poter cambiare il
/// risultato.
///
/// Tre scelte che vale la pena dichiarare, perche' ognuna ha un'alternativa
/// che sembrava piu' semplice:
///
/// * **si confrontano i valori, non i file.** Due `.cpredux` contengono anche
///   identificativi di riga, date di modifica e ordine degli elenchi: un
///   confronto testuale produrrebbe decine di differenze che non interessano a
///   nessuno e nasconderebbe quelle vere. Qui si confronta cio' che si legge
///   nella scheda.
/// * **le voci si agganciano per nome, non per identificativo.** Due schede
///   diverse non hanno gli stessi identificativi, e l'utente ragiona per nome.
///   Il nome viene normalizzato (maiuscole, punteggiatura e accenti ignorati),
///   cosi' "Armorjack leggero" e "Armorjack leggero !" sono la stessa voce.
/// * **si confrontano anche i valori calcolati.** "Caratteristiche" mostra il
///   totale (con carico, armature e impianti gia' applicati) e sotto la base
///   quando e' cambiata: un totale che non cambia mentre la base cambia e' una
///   differenza vera, e va mostrata invece che nascosta.

/// Cosa e' successo a una riga.
enum DiffState {
  /// Presente solo nella scheda di partenza.
  removed,

  /// Presente solo nella scheda di arrivo.
  added,

  /// Presente in entrambe, con valori diversi.
  changed,

  /// Identica. Si tiene lo stesso, perche' "mostra anche quello che non e'
  /// cambiato" e' meta' del senso di un confronto fianco a fianco.
  unchanged,
}

/// Una riga del confronto: un valore, nelle due schede.
class DiffRow {
  const DiffRow({
    required this.label,
    required this.before,
    required this.after,
    required this.state,
    this.detail,
    this.note,
  });

  /// Cosa si sta confrontando ("Destrezza", "Giacca corazzata").
  final String label;

  /// Il valore nella prima scheda. Nullo quando la riga non esisteva.
  final String? before;

  /// Il valore nella seconda scheda. Nullo quando la riga non esiste piu'.
  final String? after;

  final DiffState state;

  /// Riga secondaria: da dove viene il numero, o cosa e' cambiato oltre al
  /// valore mostrato ("base 5 → 7").
  final String? detail;

  /// Avviso sulla lettura di questa riga (testo accorciato, voci con lo stesso
  /// nome). Non e' un errore: e' il motivo per cui la riga va letta con
  /// attenzione.
  final String? note;

  bool get isChange => state != DiffState.unchanged;
}

/// Una sezione del confronto.
class DiffGroup {
  const DiffGroup({required this.title, required this.rows});

  final String title;
  final List<DiffRow> rows;

  int get changes => rows.where((DiffRow r) => r.isChange).length;

  bool get hasChanges => changes > 0;

  DiffGroup withRows(List<DiffRow> replacement) =>
      DiffGroup(title: title, rows: replacement);
}

/// Il confronto completo: due schede, sezione per sezione.
class SheetDiff {
  const SheetDiff({
    required this.beforeLabel,
    required this.afterLabel,
    required this.groups,
  });

  final String beforeLabel;
  final String afterLabel;
  final List<DiffGroup> groups;

  /// Quante righe differiscono, in tutto.
  int get changes => groups.fold(0, (int sum, DiffGroup g) => sum + g.changes);

  /// In quante sezioni.
  int get changedGroups => groups.where((DiffGroup g) => g.hasChanges).length;

  bool get identical => changes == 0;

  /// Le sezioni da mostrare, con le righe filtrate.
  ///
  /// Con `onlyDifferences` le sezioni senza differenze **spariscono** invece di
  /// comparire vuote: un elenco di quattordici intestazioni di cui dodici
  /// dicono "niente" e' peggio di un elenco di due.
  List<DiffGroup> groupsWith({required bool onlyDifferences}) {
    if (!onlyDifferences) return groups;
    return <DiffGroup>[
      for (final DiffGroup group in groups)
        if (group.hasChanges)
          group.withRows(
            <DiffRow>[
              for (final DiffRow row in group.rows)
                if (row.isChange) row,
            ],
          ),
    ];
  }

  /// Confronta due schede.
  ///
  /// [lookup] serve solo a risolvere i nomi degli oggetti di catalogo: senza
  /// catalogo le voci personalizzate portano la propria definizione e il
  /// confronto funziona lo stesso.
  static SheetDiff compare({
    required CharacterSheet before,
    required CharacterSheet after,
    required String beforeLabel,
    required String afterLabel,
    CatalogLookup? lookup,
  }) {
    // Senza catalogo le voci personalizzate portano la propria definizione, e
    // il confronto resta corretto: e' lo stesso ripiego del resto del dominio.
    final CatalogLookup resolve = lookup ?? _noCatalog;
    final SheetTotals totalsBefore = computeTotals(before, lookup: resolve);
    final SheetTotals totalsAfter = computeTotals(after, lookup: resolve);

    return SheetDiff(
      beforeLabel: beforeLabel,
      afterLabel: afterLabel,
      groups: <DiffGroup>[
        _document(before, after),
        _identity(before, after),
        _derived(totalsBefore, totalsAfter),
        _stats(before, after, totalsBefore, totalsAfter),
        _skills(before, after, totalsBefore, totalsAfter),
        _money(before, after),
        _manualModifiers(before, after),
        _proficiencies(before, after),
        _inventory(before, after, resolve),
        _cyberware(before, after),
        _effects(before, after),
        _notes(before, after),
        _background(before, after),
        _physical(before, after),
      ],
    );
  }

  // --- Le sezioni ---------------------------------------------------------

  static DiffGroup _document(CharacterSheet before, CharacterSheet after) {
    final _Group g = _Group('Documento');
    g.text('Nome', before.meta.name, after.meta.name);
    g.text('Creato', before.meta.createdAt, after.meta.createdAt);
    g.text('Ultima modifica', before.meta.updatedAt, after.meta.updatedAt);
    return g.build();
  }

  static DiffGroup _identity(CharacterSheet before, CharacterSheet after) {
    final SheetIdentity a = before.identity;
    final SheetIdentity b = after.identity;
    final _Group g = _Group('Personaggio');
    g.text('Nome del personaggio', a.tag, b.tag);
    g.text('Giocatore', a.playerName, b.playerName);
    g.text('Data di gioco', a.gameDate, b.gameDate);
    g.text('Soprannomi', a.aliases, b.aliases);
    g.text('Reputazione', a.reputation, b.reputation);
    g.text('Ruolo', a.role, b.role);
    g.text('Abilita di ruolo', a.roleAbility, b.roleAbility);
    g.text('Grado di ruolo', a.roleRank, b.roleRank);
    g.number('Punti Vita attuali', a.currentHp, b.currentHp);
    g.number('Fortuna attuale', a.currentLuck, b.currentLuck);
    g.number('Punti Miglioramento attuali', a.currentImprovementPoints, b.currentImprovementPoints);
    g.number('Punti Miglioramento totali', a.totalImprovementPoints, b.totalImprovementPoints);
    g.number('Punti Ispirazione', a.inspirationPoints, b.inspirationPoints);
    g.number('Umanita attuale', a.currentHumanity, b.currentHumanity);
    g.number('Empatia attuale', a.currentEmpathy, b.currentEmpathy);
    g.text('Ferite gravi', a.severeInjuries, b.severeInjuries);
    g.text('Dipendenze', a.addictions, b.addictions);
    return g.build();
  }

  /// I valori che il programma calcola: sono questi a contare al tavolo, e sono
  /// quelli che cambiano quando cambia un impianto che nessuno ricorda di aver
  /// aggiunto.
  static DiffGroup _derived(SheetTotals before, SheetTotals after) {
    final _Group g = _Group('Valori calcolati');
    g.number('Punti Vita massimi', before.maxHitPoints, after.maxHitPoints);
    g.number('Soglia ferite gravi', before.severeInjuriesThreshold, after.severeInjuriesThreshold);
    g.number('Empatia massima', before.maxEmpathy, after.maxEmpathy);
    g.number('Umanita massima', before.maxHumanity, after.maxHumanity);
    g.number('Umanita persa', before.humanityLost, after.humanityLost);
    g.number('Carico massimo', before.maxLoad, after.maxLoad);
    g.decimal('Carico attuale', before.currentLoad, after.currentLoad);
    g.text('Stato di carico', before.loadStatus.label, after.loadStatus.label);
    return g.build();
  }

  static DiffGroup _stats(
    CharacterSheet before,
    CharacterSheet after,
    SheetTotals totalsBefore,
    SheetTotals totalsAfter,
  ) {
    final _Group g = _Group('Caratteristiche');
    for (final Stat stat in Stat.values) {
      final int baseBefore = before.statBase[stat] ?? 0;
      final int baseAfter = after.statBase[stat] ?? 0;
      final int totalBefore = totalsBefore.statValue(stat);
      final int totalAfter = totalsAfter.statValue(stat);
      g.number(
        stat.label,
        totalBefore,
        totalAfter,
        detail: baseBefore == baseAfter ? null : 'base $baseBefore → $baseAfter',
        // La base puo' cambiare senza che il totale cambi (una correzione che
        // compensa): e' comunque una differenza, e nasconderla sarebbe il modo
        // piu' rapido per far sembrare identiche due schede diverse.
        changed: totalBefore != totalAfter || baseBefore != baseAfter,
      );
    }
    return g.build();
  }

  static DiffGroup _skills(
    CharacterSheet before,
    CharacterSheet after,
    SheetTotals totalsBefore,
    SheetTotals totalsAfter,
  ) {
    final _Group g = _Group('Abilita');
    for (final Skill skill in Skill.values) {
      final int baseBefore = before.skillLevels[skill] ?? 0;
      final int baseAfter = after.skillLevels[skill] ?? 0;
      final int totalBefore = totalsBefore.skillValue(skill);
      final int totalAfter = totalsAfter.skillValue(skill);
      g.number(
        skill.name,
        totalBefore,
        totalAfter,
        detail: baseBefore == baseAfter ? null : 'base $baseBefore → $baseAfter',
        changed: totalBefore != totalAfter || baseBefore != baseAfter,
      );
    }
    return g.build();
  }

  static DiffGroup _money(CharacterSheet before, CharacterSheet after) {
    final _Group g = _Group('Denaro e contatti');
    g.number('Eurobucks', before.eurobucks, after.eurobucks);
    g.text('Vecchie conoscenze', before.oldConnections, after.oldConnections);
    return g.build();
  }

  /// Le correzioni inserite a mano, distinte da quelle che arrivano da
  /// impianti ed effetti: sono l'unica parte della scheda che l'utente scrive
  /// direttamente, quindi un cambiamento qui e' sempre voluto.
  static DiffGroup _manualModifiers(CharacterSheet before, CharacterSheet after) {
    final _Group g = _Group('Correzioni manuali');
    g.list<StatModifier>(
      before: before.statModifiers,
      after: after.statModifiers,
      label: (StatModifier m) => m.target.label,
      describe: (StatModifier m) =>
          '${m.value >= 0 ? '+' : ''}${m.value}${m.isActive ? '' : ' · disattivata'}',
      key: (StatModifier m) => m.target.label,
    );
    g.list<SkillModifier>(
      before: before.skillModifiers,
      after: after.skillModifiers,
      label: (SkillModifier m) => m.skill?.name ?? 'Abilita sconosciuta (${m.skillId})',
      describe: (SkillModifier m) =>
          '${m.value >= 0 ? '+' : ''}${m.value}${m.isActive ? '' : ' · disattivata'}',
      key: (SkillModifier m) => m.skill?.name ?? 'abilita ${m.skillId}',
    );
    return g.build();
  }

  static DiffGroup _proficiencies(CharacterSheet before, CharacterSheet after) {
    final _Group g = _Group('Competenze');
    g.list<Proficiency>(
      before: before.proficiencies,
      after: after.proficiencies,
      label: (Proficiency p) => p.name,
      describe: (Proficiency p) =>
          'livello ${p.level}${p.masterSkill == null ? '' : ' · ${p.masterSkill!.name}'}',
      key: (Proficiency p) => '${p.name} ${p.masterSkill?.name ?? p.masterSkillId}',
    );
    return g.build();
  }

  static DiffGroup _inventory(
    CharacterSheet before,
    CharacterSheet after,
    CatalogLookup lookup,
  ) {
    final List<ResolvedItem> itemsBefore = ResolvedItem.resolveAll(before.inventory, lookup);
    final List<ResolvedItem> itemsAfter = ResolvedItem.resolveAll(after.inventory, lookup);

    final _Group g = _Group('Inventario');
    g.list<ResolvedItem>(
      before: itemsBefore,
      after: itemsAfter,
      label: (ResolvedItem i) => i.name,
      key: (ResolvedItem i) => i.name,
      describe: (ResolvedItem i) {
        final StringBuffer out = StringBuffer('×${i.entry.quantity}');
        if (i.entry.isEquipped) out.write(' · equipaggiato');
        final WeaponData? weapon = i.weapon;
        if (weapon != null && weapon.maxAmmo > 0) {
          out.write(' · ${weapon.currentAmmo}/${weapon.maxAmmo} colpi');
        }
        if (i.isCustom) {
          out.write(' · scritto a mano');
        } else if (i.isPersonalised) {
          out.write(' · personalizzato');
        }
        return out.toString();
      },
    );
    return g.build();
  }

  static DiffGroup _cyberware(CharacterSheet before, CharacterSheet after) {
    final _Group g = _Group('Cyberware');
    g.list<Cyberware>(
      before: before.cyberware,
      after: after.cyberware,
      label: (Cyberware c) => c.name,
      key: (Cyberware c) => c.name,
      describe: (Cyberware c) {
        final StringBuffer out = StringBuffer(c.category.label);
        out.write(' · ${c.humanityLost} umanita');
        if (c.isFoundational) out.write(' · fondamentale');
        return out.toString();
      },
    );
    return g.build();
  }

  static DiffGroup _effects(CharacterSheet before, CharacterSheet after) {
    final _Group g = _Group('Effetti');
    g.list<Effect>(
      before: before.effects,
      after: after.effects,
      label: (Effect e) => e.name,
      key: (Effect e) => e.name,
      describe: (Effect e) {
        final StringBuffer out = StringBuffer('intensita ${e.intensity}');
        out.write(e.isActive ? ' · attivo' : ' · archiviato');
        if (e.duration.isNotEmpty) out.write(' · ${e.duration}');
        return out.toString();
      },
    );
    return g.build();
  }

  static DiffGroup _notes(CharacterSheet before, CharacterSheet after) {
    final _Group g = _Group('Note');
    g.list<Note>(
      before: before.notes,
      after: after.notes,
      label: (Note n) => n.title.isEmpty ? 'Senza titolo' : n.title,
      key: (Note n) => n.title.isEmpty ? 'senza titolo' : n.title,
      // Il testo di una nota sono righe di appunti: viene accorciato come
      // qualunque altro valore lungo, e la riga lo dichiara.
      describe: (Note n) => n.content,
    );
    return g.build();
  }

  static DiffGroup _background(CharacterSheet before, CharacterSheet after) {
    final Background a = before.background;
    final Background b = after.background;
    final _Group g = _Group('Background');

    g.text('Origini culturali', a.culturalOrigins, b.culturalOrigins);
    g.text('Personalita', a.personality, b.personality);
    g.text('Stile di abbigliamento', a.favouriteClothingStyle, b.favouriteClothingStyle);
    g.text('Acconciatura', a.favouriteHairStyle, b.favouriteHairStyle);
    g.text('Cosa apprezzi di piu', a.whatDoYouValueMost, b.whatDoYouValueMost);
    g.text('Cosa pensi delle persone', a.feelingsAboutPeople, b.feelingsAboutPeople);
    g.text('Persona piu importante', a.mostValuedPerson, b.mostValuedPerson);
    g.text('Oggetto piu importante', a.mostValuedPossession, b.mostValuedPossession);
    g.text('Famiglia', a.familyBackground, b.familyBackground);
    g.text('Infanzia', a.childhoodEnvironment, b.childhoodEnvironment);
    g.text('Crisi familiare', a.familyCrisis, b.familyCrisis);
    g.text('Obiettivi', a.lifeGoals, b.lifeGoals);
    g.text('Eventi di reputazione', a.reputationEvents, b.reputationEvents);
    g.text('Percorso di ruolo', a.roleSpecificLifepath, b.roleSpecificLifepath);
    g.text('Abitazione', a.housing, b.housing);
    g.text('Affitto', a.housingRent, b.housingRent);
    g.text('Stile di vita', a.lifestyle, b.lifestyle);
    g.text('Costo stile di vita', a.lifestyleCost, b.lifestyleCost);

    g.list<Friend>(
      before: a.friends,
      after: b.friends,
      label: (Friend f) => f.name,
      key: (Friend f) => f.name,
      describe: (Friend _) => 'amico',
    );
    g.list<TragicStory>(
      before: a.tragicStories,
      after: b.tragicStories,
      label: (TragicStory t) => t.name,
      key: (TragicStory t) => t.name,
      describe: (TragicStory _) => 'storia tragica',
    );
    g.list<Enemy>(
      before: a.enemies,
      after: b.enemies,
      label: (Enemy e) => e.who,
      key: (Enemy e) => e.who,
      describe: (Enemy e) => <String>[
        if (e.whatCausedIt.isNotEmpty) e.whatCausedIt,
        if (e.whatCanTheyThrowAtYou.isNotEmpty) e.whatCanTheyThrowAtYou,
        if (e.whatsGonnaHappen.isNotEmpty) e.whatsGonnaHappen,
      ].join(' · '),
    );
    return g.build();
  }

  static DiffGroup _physical(CharacterSheet before, CharacterSheet after) {
    final PhysicalDescription a = before.physical;
    final PhysicalDescription b = after.physical;
    final _Group g = _Group('Descrizione fisica');
    g.text('Eta', a.age, b.age);
    g.text('Altezza', a.height, b.height);
    g.text('Peso', a.weight, b.weight);
    g.text('Occhi', a.eyes, b.eyes);
    g.text('Pelle', a.skin, b.skin);
    g.text('Capelli', a.hair, b.hair);
    g.text('Descrizione', a.description, b.description);

    // L'immagine si confronta per **presenza** e non per percorso: due schede
    // della stessa persona su due computer hanno percorsi diversi, e una
    // differenza che e' solo il nome della cartella di un altro utente non e'
    // una differenza.
    final bool hasImageBefore = (a.imagePath ?? '').trim().isNotEmpty;
    final bool hasImageAfter = (b.imagePath ?? '').trim().isNotEmpty;
    g.text(
      'Immagine',
      hasImageBefore ? 'presente' : 'nessuna',
      hasImageAfter ? 'presente' : 'nessuna',
    );
    return g.build();
  }
}

/// Lookup vuoto: nessun catalogo. Le voci scritte a mano portano i propri
/// dati, quindi non serve altro.
CatalogItem? _noCatalog(String catalogId) => null;

/// Quanto e' lungo un valore prima di essere accorciato.
///
/// Una cella di tabella con dentro un paragrafo non e' piu' una tabella: oltre
/// questa soglia il testo viene tagliato, e la riga **dice** che era piu'
/// lungo. Un valore tagliato in silenzio e' peggio di un valore assente,
/// perche' sembra completo.
const int _maxValueLength = 90;

String _clip(String value) =>
    value.length <= _maxValueLength ? value : '${value.substring(0, _maxValueLength)}…';

/// Chiave di aggancio per un nome.
///
/// Maiuscole, punteggiatura, spazi e accenti spariscono: "Armorjack leggero",
/// "Armorjack leggero !" e "armorjack leggero" sono la stessa voce. Senza
/// questa normalizzazione il confronto fra due schede diverse sarebbe una
/// lista di oggetti tolti e rimessi, che e' esattamente cio' che non e'
/// successo.
String _nameKey(String raw) => raw.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

/// Accumulatore di una sezione.
///
/// Registra **tutte** le righe, comprese quelle identiche: la schermata decide
/// poi se mostrarle. Filtrarle qui renderebbe impossibile la vista "tutto", che
/// e' la ragione per cui si guarda un confronto fianco a fianco invece di due
/// schermate una dopo l'altra.
class _Group {
  _Group(this.title);

  final String title;
  final List<DiffRow> rows = <DiffRow>[];

  DiffGroup build() => DiffGroup(title: title, rows: rows);

  void text(String label, String before, String after, {String? detail}) {
    _add(
      label: label,
      before: before,
      after: after,
      state: before == after ? DiffState.unchanged : DiffState.changed,
      detail: detail,
    );
  }

  void number(String label, num before, num after, {String? detail, bool? changed}) {
    _add(
      label: label,
      before: '$before',
      after: '$after',
      state: (changed ?? before != after) ? DiffState.changed : DiffState.unchanged,
      detail: detail,
    );
  }

  /// Numeri con la virgola: il carico si legge in chili, non in unita'.
  void decimal(String label, double before, double after, {String? detail}) {
    _add(
      label: label,
      before: _decimal(before),
      after: _decimal(after),
      state: before == after ? DiffState.unchanged : DiffState.changed,
      detail: detail,
    );
  }

  static String _decimal(double value) =>
      value.toStringAsFixed(1).replaceAll('.', ',');

  /// Confronta due elenchi agganciando le voci per [key] normalizzata.
  ///
  /// Sopraggiunge una cosa che un confronto riga-per-riga non puo' fare:
  /// **l'ordine non conta**. Un oggetto spostato in fondo all'inventario non e'
  /// una differenza, e con gli indici lo sembrerebbe.
  void list<T>({
    required List<T> before,
    required List<T> after,
    required String Function(T) label,
    required String Function(T) describe,
    required String Function(T) key,
  }) {
    final Map<String, List<T>> indexBefore = _index(before, key);
    final Map<String, List<T>> indexAfter = _index(after, key);

    // L'ordine dell'elenco di partenza, poi le voci nuove: cosi' un confronto
    // fra due schede non cambia ordine solo perche' e' cambiata la seconda.
    final List<String> keys = <String>[
      ...indexBefore.keys,
      for (final String k in indexAfter.keys)
        if (!indexBefore.containsKey(k)) k,
    ];

    for (final String k in keys) {
      final List<T>? sideBefore = indexBefore[k];
      final List<T>? sideAfter = indexAfter[k];
      final T sample = (sideAfter ?? sideBefore!).first;

      final ({String text, String? note})? valueBefore =
          sideBefore == null ? null : _readable(describe(sideBefore.first));
      final ({String text, String? note})? valueAfter =
          sideAfter == null ? null : _readable(describe(sideAfter.first));

      // Quante voci portano questo nome. Due anelli con lo stesso nome
      // esistono davvero, e "×2 → ×1" e' una differenza che il valore della
      // riga non racconta.
      final int countBefore = sideBefore?.length ?? 0;
      final int countAfter = sideAfter?.length ?? 0;

      DiffState state;
      if (sideBefore == null) {
        state = DiffState.added;
      } else if (sideAfter == null) {
        state = DiffState.removed;
      } else {
        state = valueBefore!.text == valueAfter!.text && countBefore == countAfter
            ? DiffState.unchanged
            : DiffState.changed;
      }

      final List<String> notes = <String>[
        if (countBefore != countAfter && (countBefore > 1 || countAfter > 1))
          'piu voci con lo stesso nome',
        if (valueAfter?.note != null) valueAfter!.note!,
      ];

      rows.add(DiffRow(
        label: label(sample),
        before: valueBefore?.text,
        after: valueAfter?.text,
        state: state,
        detail: countBefore == countAfter ? null : 'voci: $countBefore → $countAfter',
        note: notes.isEmpty ? null : notes.join(' · '),
      ));
    }
  }

  static Map<String, List<T>> _index<T>(List<T> items, String Function(T) key) {
    final Map<String, List<T>> map = <String, List<T>>{};
    for (final T item in items) {
      map.putIfAbsent(_nameKey(key(item)), () => <T>[]).add(item);
    }
    return map;
  }

  void _add({
    required String label,
    required String? before,
    required String? after,
    required DiffState state,
    String? detail,
  }) {
    final ({String text, String? note}) readableBefore = _readable(before);
    final ({String text, String? note}) readableAfter = _readable(after);
    final String? note = readableAfter.note ?? readableBefore.note;

    rows.add(DiffRow(
      label: label,
      before: readableBefore.text,
      after: readableAfter.text,
      state: state,
      detail: detail,
      note: note,
    ));
  }
}

/// Come si legge un valore in tabella.
({String text, String? note}) _readable(String? value) {
  if (value == null) return (text: '—', note: null);
  if (value.trim().isEmpty) return (text: '(vuoto)', note: null);
  final String clipped = _clip(value);
  return (
    text: clipped,
    note: clipped == value ? null : '${value.length} caratteri',
  );
}

/// Una voce del registro delle differenze: un aggiornamento di stato applicato
/// alla scheda (dal master durante la sessione), con data, ora, motivo e il diff.
class StateDiffEntry {
  const StateDiffEntry({
    required this.id,
    required this.timestamp,
    required this.reason,
    required this.diff,
  });

  final String id;
  final DateTime timestamp;
  final String reason;
  final SheetDiff diff;
}
