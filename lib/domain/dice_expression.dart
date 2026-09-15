/// Motore delle espressioni di dado.
///
/// Perche' esiste: la scheda sa tirare *un* dado con *un* modificatore, che
/// copre "abilita' + caratteristica" ma non copre il tavolo reale. Al tavolo si
/// tira `1d10 + RIF + Pistole`, si raddoppia per un attacco mirato, si sottrae
/// la penalita' di copertura, si tirano i danni `4d6` e si somma la qualita'
/// dell'arma. Ogni volta che l'app non sa farlo, il giocatore tira a mano e il
/// risultato non entra nel registro della sessione — che e' il motivo per cui
/// il registro esiste.
///
/// Il linguaggio e' quello che i giocatori scrivono gia' sulla scheda di carta:
///
/// ```text
/// 1d10 + RIF + Pistole          attacco normale
/// (1d10 + 8) * 2 - 4            attacco mirato con copertura
/// 4d6kh3                        danni tenendo i tre dadi migliori
/// 6d6!                          esplosione (critico che ritira)
/// 3d6 / 2                       raffica dimezzata
/// ```
///
/// Tre scelte deliberate:
///
/// 1. **I nomi si risolvono per sigla o per nome.** `RIF` e `Riflessi` sono la
///    stessa cosa, come `Pistole` e' una abilita'. Chi scrive la macro non deve
///    ricordare come l'app ha chiamato le cose.
/// 2. **Un nome sconosciuto e' un errore, non uno zero.** Se `Pistol` (in
///    inglese) diventasse 0, il tiro uscirebbe *plausibile e sbagliato*, che e'
///    il peggior esito possibile: nessuno se ne accorge.
/// 3. **Il risultato porta il dettaglio.** Ogni dado lanciato resta nel
///    risultato, non solo la somma: il registro della sessione deve poter dire
///    "10, ritira, 7 -> 17 + 8 = 25", altrimenti non serve a niente.
library;

import 'dart:math' as math;

import 'rules.dart';
import 'sheet.dart';
import 'skills.dart';
import 'stats.dart';

/// Errore di sintassi o di risoluzione di un'espressione.
class DiceExpressionError implements Exception {
  const DiceExpressionError(this.message, {this.expression = '', this.position});

  final String message;
  final String expression;

  /// Posizione del carattere che ha fatto fallire la lettura, quando nota.
  final int? position;

  @override
  String toString() {
    final String where = position == null ? '' : ' (posizione ${position! + 1})';
    return 'Espressione non valida$where: $message${expression.isEmpty ? '' : ' in "$expression"'}';
  }
}

/// Un gruppo di dadi lanciato: `4d6kh3` produce un `RolledDiceGroup` con
/// quattro risultati e tre tenuti.
class RolledDiceGroup {
  const RolledDiceGroup({
    required this.count,
    required this.faces,
    required this.results,
    required this.kept,
    this.exploded = false,
  });

  final int count;
  final int faces;

  /// Tutti i risultati in ordine di lancio, esplosioni incluse.
  final List<int> results;

  /// Quanti dadi sono stati tenuti (uguale a `results.length` senza `kh`/`kl`).
  final int kept;
  final bool exploded;

  /// Somma dei dadi tenuti, cioe' il valore effettivamente usato.
  int get sum {
    if (kept >= results.length) {
      return results.fold<int>(0, (int a, int b) => a + b);
    }
    final List<int> sorted = <int>[...results]..sort();
    // Si tengono i `kept` piu' alti: con `kh` e' quello che serve, con `kl` la
    // somma dei piu' bassi e' ricavata dai piu' alti scartati sotto.
    final List<int> highest = sorted.sublist(sorted.length - kept);
    return highest.fold<int>(0, (int a, int b) => a + b);
  }

  /// Somma dei dadi tenuti quando la selezione e' "i piu' bassi".
  int get sumLowest {
    final List<int> sorted = <int>[...results]..sort();
    final List<int> lowest = sorted.take(kept).toList();
    return lowest.fold<int>(0, (int a, int b) => a + b);
  }

  /// Quanti dadi hanno fatto il valore massimo (utile per i critici su d10).
  int get maxRolls => results.where((int r) => r == faces).length;

  /// Quanti dadi hanno fatto 1.
  int get minRolls => results.where((int r) => r == 1).length;

  String get label => '${count}d$faces';
}

/// Il risultato di un'espressione, con tutto il necessario per raccontarlo.
class ExpressionRoll {
  const ExpressionRoll({
    required this.expression,
    required this.total,
    required this.groups,
    required this.resolvedNames,
    required this.diceTotal,
    required this.constantTotal,
  });

  final String expression;
  final int total;

  /// Somma di tutti i dadi lanciati, dopo `kh`/`kl`.
  final int diceTotal;

  /// Somma algebrica dei valori non-dado (modificatori, moltiplicatori).
  /// Puo' essere zero quando l'espressione e' fatta solo di dadi.
  final int constantTotal;

  final List<RolledDiceGroup> groups;

  /// Nomi risolti (sigle e abilita') con il valore che hanno assunto.
  final Map<String, int> resolvedNames;

  bool get hasDice => groups.isNotEmpty;

  /// Nota umana da mostrare nel registro: "4d6: 5, 3, 2, 1 -> tiene 5, 3, 2".
  String get breakdown {
    if (groups.isEmpty) return 'nessun dado';
    return groups
        .map((RolledDiceGroup g) {
          final String rolls = g.results.join(', ');
          if (g.kept >= g.results.length) return '${g.label}: $rolls';
          return '${g.label}: $rolls -> tiene $g.kept (${g.sum})';
        })
        .join(' | ');
  }

  /// Un'espressione con un solo d10: se ne ricava critico o fallimento, come
  /// nel gioco base. Restituisce `null` quando la lettura non ha senso (piu'
  /// dadi, o dadi diversi dal d10).
  DiceOutcome? get singleD10Outcome {
    final List<RolledDiceGroup> tens = groups.where((RolledDiceGroup g) => g.faces == 10).toList();
    if (tens.length != 1 || groups.length != 1) return null;
    final RolledDiceGroup g = tens.single;
    if (g.count != 1) return null;
    if (g.results.first == 10) return DiceOutcome.critical;
    if (g.results.first == 1) return DiceOutcome.fumble;
    return DiceOutcome.normal;
  }
}

/// Esito del singolo d10 di una prova.
enum DiceOutcome { critical, normal, fumble }

/// Risolve un nome scritto in una macro nel suo valore numerico.
///
/// Il valore `null` significa "non lo conosco": e' diverso da zero, ed e'
/// quello che permette di distinguere una macro sbagliata da un modificatore
/// che vale davvero zero.
typedef DiceNameResolver = int? Function(String name);

/// Una macro salvata dal giocatore.
///
/// Esempio reale, quello della richiesta: "Attacco con Malorian 3516" ->
/// `1d10 + RIF + Pistole` con nota "arma +1 qualita' Eccellente".
class DiceMacro {
  const DiceMacro({
    required this.id,
    required this.name,
    required this.expression,
    this.note = '',
  });

  final String id;
  final String name;
  final String expression;
  final String note;

  DiceMacro copyWith({String? name, String? expression, String? note}) => DiceMacro(
        id: id,
        name: name ?? this.name,
        expression: expression ?? this.expression,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'expression': expression,
        'note': note,
      };

  static DiceMacro fromJson(Map<String, Object?> json) => DiceMacro(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        expression: json['expression'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}

/// Lettore ed esecutore di espressioni di dado.
///
/// Non ha stato: si costruisce una volta con il risolutore dei nomi e il
/// `Random` (iniettabile, perche' un test del critico non puo' dipendere dalla
/// fortuna) e si usa quante volte serve.
class DiceExpression {
  const DiceExpression({this.resolveName, this.random});

  final DiceNameResolver? resolveName;
  final math.Random? random;

  math.Random get _rng => random ?? _fallback;

  static final math.Random _fallback = math.Random();

  /// Valuta un'espressione e restituisce il risultato completo.
  ExpressionRoll evaluate(String expression) {
    final _Parser parser = _Parser(expression, resolveName: resolveName, random: _rng);
    final _Value value = parser.parse();
    return ExpressionRoll(
      expression: expression.trim(),
      total: value.total,
      diceTotal: value.diceTotal,
      constantTotal: value.constantTotal,
      groups: parser.groups,
      resolvedNames: parser.resolvedNames,
    );
  }

  /// Verifica che un'espressione sia leggibile senza lanciare niente.
  ///
  /// Serve all'editor delle macro: si vuole dire "questo non si legge" mentre
  /// si scrive, non quando si preme tira durante la partita.
  static String? validate(String expression, {DiceNameResolver? resolveName}) {
    if (expression.trim().isEmpty) return 'Espressione vuota';
    try {
      // Lancia davvero, ma con un risolutore che accetta qualunque nome: cosi'
      // si controlla la *forma* e non si pretende che i nomi esistano gia'.
      DiceExpression(
        random: math.Random(1),
        resolveName: resolveName ?? (String _) => 0,
      ).evaluate(expression);
      return null;
    } on DiceExpressionError catch (e) {
      return e.message;
    }
  }

  /// Comodita': il totale, o `null` se l'espressione non si legge.
  int? tryTotal(String expression) {
    try {
      return evaluate(expression).total;
    } on DiceExpressionError {
      return null;
    }
  }
}

/// Risolutore dei nomi basato su una scheda: sigle delle caratteristiche
/// (`RIF`) e nomi di abilita' (`Pistole`), case-insensitive, con accenti
/// opzionali.
///
/// `lookup` serve per le correzioni del catalogo, come altrove nel progetto.
DiceNameResolver sheetNameResolver(CharacterSheet sheet, {CatalogLookup? lookup}) {
  final SheetTotals totals = computeTotals(sheet, lookup: lookup);
  final Map<String, int> byName = <String, int>{};
  for (final Stat stat in Stat.values) {
    byName[_key(stat.short)] = totals.statValue(stat);
    byName[_key(stat.label)] = totals.statValue(stat);
  }
  for (final Skill skill in Skill.values) {
    byName[_key(skill.name)] = totals.skillValue(skill);
  }
  return (String name) => byName[_key(name)];
}

String _key(String raw) => raw
    .toLowerCase()
    .replaceAll('à', 'a')
    .replaceAll('è', 'e')
    .replaceAll('é', 'e')
    .replaceAll('ì', 'i')
    .replaceAll('ò', 'o')
    .replaceAll('ù', 'u')
    .replaceAll(RegExp(r'[\s_\-]'), '');

/// Valore intermedio di una sotto-espressione.
class _Value {
  const _Value(this.total, this.diceTotal, this.constantTotal);

  final int total;
  final int diceTotal;
  final int constantTotal;

  _Value operator +(_Value o) => _Value(
        total + o.total,
        diceTotal + o.diceTotal,
        constantTotal + o.constantTotal,
      );

  _Value multiply(int times) => _Value(
        total * times,
        diceTotal * times,
        constantTotal * times,
      );
}

/// Lettore a discesa ricorsiva.
///
/// La grammatica, in ordine di precedenza crescente:
///
/// ```text
/// espressione := termine (('+' | '-') termine)*
/// termine     := fattore (('*' | '/') fattore)*
/// fattore     := ('-' | '+')? primario
/// primario    := NUMERO | DADI | '(' espressione ')' | NOME
/// dadi        := [N] 'd' F [('!' | 'kh' N | 'kl' N)]
/// ```
class _Parser {
  _Parser(this.source, {this.resolveName, required this.random});

  final String source;
  final DiceNameResolver? resolveName;
  final math.Random random;

  final List<RolledDiceGroup> groups = <RolledDiceGroup>[];
  final Map<String, int> resolvedNames = <String, int>{};

  int _pos = 0;

  /// Quante volte un dado puo' esplodere di seguito. Il limite esiste perche'
  /// una catena di 10 su un d10 non e' impossibile, solo improbabile, e senza
  /// tetto un `Random` difettoso diventerebbe un ciclo infinito.
  static const int _maxExplosions = 20;

  _Value parse() {
    final _Value value = _expression();
    _skipSpaces();
    if (_pos < source.length) {
      throw DiceExpressionError('carattere inatteso "${source[_pos]}"', expression: source, position: _pos);
    }
    return value;
  }

  _Value _expression() {
    _Value left = _term();
    while (true) {
      _skipSpaces();
      if (_accept('+')) {
        left = left + _term();
      } else if (_accept('-')) {
        left = left + _term().multiply(-1);
      } else {
        return left;
      }
    }
  }

  _Value _term() {
    _Value left = _factor();
    while (true) {
      _skipSpaces();
      if (_accept('*')) {
        left = left.multiply(_factor().total);
      } else if (_accept('/')) {
        final _Value divisor = _factor();
        if (divisor.total == 0) {
          throw DiceExpressionError('divisione per zero', expression: source, position: _pos);
        }
        // Divisione intera con troncamento verso lo zero, come si fa al tavolo
        // ("dimezza i danni" non produce mezzi punti vita).
        left = _Value(left.total ~/ divisor.total, left.diceTotal ~/ divisor.total, left.constantTotal ~/ divisor.total);
      } else {
        return left;
      }
    }
  }

  _Value _factor() {
    _skipSpaces();
    if (_accept('-')) return _factor().multiply(-1);
    if (_accept('+')) return _factor();
    return _primary();
  }

  _Value _primary() {
    _skipSpaces();
    if (_accept('(')) {
      final _Value inner = _expression();
      _skipSpaces();
      if (!_accept(')')) {
        throw DiceExpressionError('manca la parentesi chiusa', expression: source, position: _pos);
      }
      return inner;
    }
    if (_pos >= source.length) {
      throw DiceExpressionError('espressione incompleta', expression: source, position: _pos);
    }
    final String? ch = _peek();
    if (ch != null && _isDigit(ch)) {
      // Un numero seguito da 'd' e' un gruppo di dadi; altrimenti una costante.
      final int number = _number();
      if (_peekLower() == 'd') {
        return _dice(count: number);
      }
      return _Value(number, 0, number);
    }
    // `d10` senza il numero davanti e' il modo in cui tutti scrivono "un d10":
    // rifiutarlo per pedanteria sintattica sarebbe un difetto d'uso, non una
    // semplificazione.
    if (ch != null && (ch == 'd' || ch == 'D') && _pos + 1 < source.length && _isDigit(source[_pos + 1])) {
      return _dice(count: 1);
    }
    if (ch != null && _isNameStart(ch)) {
      final String name = _name();
      final int? value = resolveName?.call(name);
      if (value == null) {
        throw DiceExpressionError('nome sconosciuto "$name"', expression: source, position: _pos - name.length);
      }
      resolvedNames[name] = value;
      return _Value(value, 0, value);
    }
    throw DiceExpressionError('atteso un numero, un dado o un nome', expression: source, position: _pos);
  }

  /// Legge `NdF` con eventuale esplosione o scarto.
  _Value _dice({int? count}) {
    _expectLower('d');
    final int faces = _number();
    if (faces < 2) {
      throw DiceExpressionError('un dado ha almeno 2 facce', expression: source, position: _pos);
    }
    final int n = count ?? 1;
    if (n < 1 || n > 200) {
      throw DiceExpressionError('numero di dadi fuori intervallo (1..200)', expression: source, position: _pos);
    }

    bool explode = false;
    int? keepHighest;
    int? keepLowest;
    _skipSpaces();
    if (_accept('!')) {
      explode = true;
    } else if (_peekLower() == 'k') {
      _pos++;
      final String mode = _peekLower() ?? '';
      if (mode == 'h' || mode == 'l') {
        _pos++;
        keepHighest = mode == 'h' ? _number() : null;
        keepLowest = mode == 'l' ? _number() : null;
      } else {
        throw DiceExpressionError('dopo "k" serve "h" (tieni i piu alti) o "l" (tieni i piu bassi)', expression: source, position: _pos);
      }
    }

    final List<int> results = <int>[];
    for (int i = 0; i < n; i++) {
      int r = _roll(faces);
      results.add(r);
      if (explode) {
        int guard = 0;
        while (r == faces && guard < _maxExplosions) {
          r = _roll(faces);
          results.add(r);
          guard++;
        }
      }
    }

    int kept = results.length;
    if (keepHighest != null) {
      if (keepHighest < 1 || keepHighest > n) {
        throw DiceExpressionError('"kh$keepHighest" non ha senso su ${n}d$faces', expression: source, position: _pos);
      }
      kept = keepHighest;
    }
    if (keepLowest != null) {
      if (keepLowest < 1 || keepLowest > n) {
        throw DiceExpressionError('"kl$keepLowest" non ha senso su ${n}d$faces', expression: source, position: _pos);
      }
      kept = keepLowest;
    }

    final RolledDiceGroup group = RolledDiceGroup(
      count: n,
      faces: faces,
      results: results,
      kept: kept,
      exploded: explode,
    );
    groups.add(group);

    final int sum = keepLowest != null ? group.sumLowest : group.sum;
    return _Value(sum, sum, 0);
  }

  int _roll(int faces) => random.nextInt(faces) + 1;

  int _number() {
    _skipSpaces();
    final int start = _pos;
    while (_pos < source.length && _isDigit(source[_pos])) {
      _pos++;
    }
    if (start == _pos) {
      throw DiceExpressionError('atteso un numero', expression: source, position: _pos);
    }
    final int value = int.parse(source.substring(start, _pos));
    return value;
  }

  String _name() {
    final int start = _pos;
    while (_pos < source.length && _isNamePart(source[_pos])) {
      _pos++;
    }
    return source.substring(start, _pos);
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  static bool _isNameStart(String c) {
    final int u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122) || u > 127;
  }

  static bool _isNamePart(String c) => _isNameStart(c) || _isDigit(c);

  String? _peek() => _pos < source.length ? source[_pos] : null;

  String? _peekLower() => _pos < source.length ? source[_pos].toLowerCase() : null;

  void _skipSpaces() {
    while (_pos < source.length && source[_pos] == ' ') {
      _pos++;
    }
  }

  bool _accept(String ch) {
    if (_pos < source.length && source[_pos] == ch) {
      _pos++;
      return true;
    }
    return false;
  }

  void _expectLower(String ch) {
    if (_pos < source.length && source[_pos].toLowerCase() == ch) {
      _pos++;
      return;
    }
    throw DiceExpressionError('atteso "$ch"', expression: source, position: _pos);
  }
}
