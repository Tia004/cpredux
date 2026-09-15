/// Chi sta sulla mappa.
///
/// Questo file esiste **perche' non e' un waypoint**, e la distinzione non e'
/// pedanteria. Il modello dei waypoint dichiara di proposito di non essere un
/// motore di gioco: «un waypoint ha un nome, una nota, una posizione e una
/// categoria, e nient'altro. Non ha regole, non ha iniziativa, non muove nulla».
/// Quel vincolo e' giusto e va tenuto: un waypoint e' un **luogo** — il negozio,
/// il deposito, l'appuntamento — e un luogo non ha Punti Vita.
///
/// Un token e' una **persona**: il Tyger Claws che i giocatori hanno davanti
/// adesso. Ha dei Punti Vita perche' qualcuno glieli sta togliendo, un'armatura
/// perche' i colpi rimbalzano, e un nome perche' altrimenti il Master dice
/// "quello li'". Metterlo dentro `MapWaypoint` avrebbe voluto dire riempire di
/// campi vuoti (pv, sp, combattimento, difesa, stato) dei segnaposto che non li
/// hanno, e ogni futuro pezzo di codice avrebbe dovuto chiedersi quale dei due
/// tipi di waypoint sta guardando.
///
/// Restano comunque **sottili**, e la rinuncia e' deliberata: qui non ci sono
/// iniziativa, turni, movimento, automazione degli attacchi ne' regole di
/// ingaggio. Il token dice al tavolo *dove* e *in che stato*, che sono le due
/// cose che servono mentre si parla; tutto il resto lo fa il Master.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'json_support.dart';

/// Cosa rappresenta un token.
enum TokenKind {
  alleato('Alleato'),
  nemico('Nemico'),
  neutrale('Neutrale'),
  veicolo('Veicolo');

  const TokenKind(this.label);

  final String label;

  static TokenKind fromName(String name) =>
      TokenKind.values.firstWhere((TokenKind k) => k.name == name, orElse: () => TokenKind.nemico);
}

/// Lo stato di salute a colpo d'occhio.
///
/// Quattro gradini e non una percentuale continua: al tavolo si guarda un
/// anello per un istante, e un colore si riconosce prima di un numero. La
/// soglia coincide con quella che usa la scheda per il cuore dei Punti Vita,
/// perche' due scale diverse nella stessa applicazione sarebbero due bugie.
enum TokenHealth {
  illeso('Illeso'),
  ferito('Ferito'),
  critico('Critico'),
  aTerra('A terra');

  const TokenHealth(this.label);

  final String label;
}

/// Un segnaposto che rappresenta qualcuno.
class MapToken {
  MapToken({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.kind = TokenKind.nemico,
    this.hp = 0,
    this.maxHp = 0,
    this.sp = 0,
    this.combat = 0,
    this.defense = 0,
    this.damage = '',
    this.note = '',
    this.longNotes = '',
    this.role = '',
    this.weaponName = '',
    this.rof = 1,
    this.eurobucks = 0,
    this.loot = '',
    this.refBonus = 6,
    this.initiativeRoll,
    this.groupId = '',
    this.createdAt = '',
  });

  final String id;
  String name;

  /// Posizione in coordinate normalizzate 0..1, come i waypoint: stesso spazio,
  /// stessa geometria, stessa georeferenziazione di un'immagine importata.
  double x;
  double y;

  TokenKind kind;

  /// Punti Vita attuali e massimi. `maxHp` a zero significa "nessun dato":
  /// un token creato per dire solo "qui c'e' qualcuno" non deve mostrare un
  /// anello di salute che non significa niente.
  int hp;
  int maxHp;

  /// Punti Struttura dell'armatura (SP).
  int sp;

  /// I due numeri del PNG rapido: cosa somma al d10 per attaccare, e la Difesa
  /// che il giocatore deve battere per colpirlo.
  int combat;
  int defense;

  /// Danno dell'arma, gia' come espressione ("4d6") per non interpretarlo qui.
  String damage;

  String note;

  /// Scheda rapida estesa: note lunghe, biografia, tattiche o punti deboli.
  String longNotes;
  String role;
  String weaponName;
  int rof;
  int eurobucks;
  String loot;
  int refBonus;
  int? initiativeRoll;

  /// Da quale gruppo viene: gli otto della stessa banda si spostano e si
  /// cancellano insieme.
  String groupId;

  final String createdAt;

  Offset get position => Offset(x, y);

  set position(Offset value) {
    x = value.dx.clamp(0, 1).toDouble();
    y = value.dy.clamp(0, 1).toDouble();
  }

  bool get hasHealth => maxHp > 0;

  double get healthRatio => !hasHealth ? 1 : (hp / maxHp).clamp(0, 1).toDouble();

  bool get isDown => hasHealth && hp <= 0;

  TokenHealth get health {
    if (!hasHealth) return TokenHealth.illeso;
    if (hp <= 0) return TokenHealth.aTerra;
    if (healthRatio <= 0.30) return TokenHealth.critico;
    if (healthRatio <= 0.60) return TokenHealth.ferito;
    return TokenHealth.illeso;
  }

  /// La riga che si legge sotto il nome sulla mappa.
  String get statLine {
    final List<String> parts = <String>[];
    if (hasHealth) parts.add('PV $hp/$maxHp');
    if (sp > 0) parts.add('SP $sp');
    if (combat > 0) parts.add('Comb +$combat');
    if (defense > 0) parts.add('Dif $defense');
    return parts.join(' · ');
  }

  String get summary => '${kind.label}: $name${statLine.isEmpty ? '' : ' — $statLine'}';

  /// Applica un danno diretto grezzo ai PV.
  void applyDamage(int amount) {
    if (!hasHealth) return;
    hp = (hp - amount).clamp(0, maxHp);
  }

  /// Applicazione automatica del danno balistico secondo le regole Cyberpunk RED:
  /// Se il danno supera l'armatura SP, la differenza è sottratta ai PV (raddoppiata
  /// per colpi mirati alla testa) e l'armatura SP subisce 1 punto di ablazione permanente.
  ({int hpLost, int armorAblated, bool isDown}) applyPenetratingDamage(int rawDmg, {bool isHead = false}) {
    if (!hasHealth) return (hpLost: 0, armorAblated: 0, isDown: false);
    final int effective = rawDmg - sp;
    if (effective <= 0) {
      return (hpLost: 0, armorAblated: 0, isDown: isDown);
    }
    final int taken = isHead ? effective * 2 : effective;
    hp = (hp - taken).clamp(0, maxHp);
    if (sp > 0) sp = (sp - 1).clamp(0, 99);
    return (hpLost: taken, armorAblated: 1, isDown: hp <= 0);
  }

  void heal(int amount) {
    if (!hasHealth) return;
    hp = (hp + amount).clamp(0, maxHp);
  }

  MapToken copyWith({
    String? name,
    TokenKind? kind,
    int? hp,
    int? maxHp,
    int? sp,
    int? combat,
    int? defense,
    String? damage,
    String? note,
    String? longNotes,
    String? role,
    String? weaponName,
    int? rof,
    int? eurobucks,
    String? loot,
    int? refBonus,
    int? initiativeRoll,
  }) => MapToken(
    id: id,
    name: name ?? this.name,
    x: x,
    y: y,
    kind: kind ?? this.kind,
    hp: hp ?? this.hp,
    maxHp: maxHp ?? this.maxHp,
    sp: sp ?? this.sp,
    combat: combat ?? this.combat,
    defense: defense ?? this.defense,
    damage: damage ?? this.damage,
    note: note ?? this.note,
    longNotes: longNotes ?? this.longNotes,
    role: role ?? this.role,
    weaponName: weaponName ?? this.weaponName,
    rof: rof ?? this.rof,
    eurobucks: eurobucks ?? this.eurobucks,
    loot: loot ?? this.loot,
    refBonus: refBonus ?? this.refBonus,
    initiativeRoll: initiativeRoll ?? this.initiativeRoll,
    groupId: groupId,
    createdAt: createdAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'x': x,
    'y': y,
    'kind': kind.name,
    'hp': hp,
    'maxHp': maxHp,
    'sp': sp,
    'combat': combat,
    'defense': defense,
    'damage': damage,
    'note': note,
    if (longNotes.isNotEmpty) 'longNotes': longNotes,
    if (role.isNotEmpty) 'role': role,
    if (weaponName.isNotEmpty) 'weaponName': weaponName,
    if (rof > 1) 'rof': rof,
    if (eurobucks > 0) 'eurobucks': eurobucks,
    if (loot.isNotEmpty) 'loot': loot,
    if (refBonus != 6) 'refBonus': refBonus,
    if (initiativeRoll != null) 'initiativeRoll': initiativeRoll,
    'groupId': groupId,
    'createdAt': createdAt,
  };

  static MapToken fromJson(Map<String, Object?> json) => MapToken(
    id: readString(json['id']),
    name: readString(json['name']),
    x: readDouble(json['x']).clamp(0, 1).toDouble(),
    y: readDouble(json['y']).clamp(0, 1).toDouble(),
    kind: TokenKind.fromName(readString(json['kind'])),
    hp: readInt(json['hp']),
    maxHp: readInt(json['maxHp']),
    sp: readInt(json['sp']),
    combat: readInt(json['combat']),
    defense: readInt(json['defense']),
    damage: readString(json['damage']),
    note: readString(json['note']),
    longNotes: readString(json['longNotes']),
    role: readString(json['role']),
    weaponName: readString(json['weaponName']),
    rof: readInt(json['rof'], 1),
    eurobucks: readInt(json['eurobucks']),
    loot: readString(json['loot']),
    refBonus: readInt(json['refBonus'], 6),
    initiativeRoll: json['initiativeRoll'] != null ? readInt(json['initiativeRoll']) : null,
    groupId: readString(json['groupId']),
    createdAt: readString(json['createdAt']),
  );
}

/// Genera un identificativo per un token.
///
/// Con prefisso diverso da quello dei waypoint: i due elenchi vivono nello
/// stesso documento, e un identificativo che si confonde fra i due farebbe
/// selezionare il segnaposto sbagliato al momento peggiore.
String newTokenId([int? counter]) {
  final int now = DateTime.now().microsecondsSinceEpoch;
  return counter == null ? 'tok-$now' : 'tok-$now-$counter';
}

/// Dove mettere un gruppo di token appena arrivato sulla mappa.
///
/// Un cerchio stretto attorno a un centro, perche' otto segnaposti impilati
/// nello stesso pixel sono un segnaposto solo. Il raggio e' in coordinate
/// normalizzate (0..1), quindi non dipende dall'ingrandimento.
List<Offset> tokenCluster({required int count, required Offset center, double radius = 0.045}) {
  if (count <= 0) return const <Offset>[];
  if (count == 1) return <Offset>[center];
  final List<Offset> spots = <Offset>[];
  for (int i = 0; i < count; i++) {
    // Dal primo in alto e poi in senso orario: due gruppi consecutivi non
    // finiscono sovrapposti nello stesso ordine, quindi non sembrano lo stesso
    // gruppo spostato.
    final double angle = (-math.pi / 2) + (2 * math.pi * i / count);
    spots.add(
      Offset(
        (center.dx + radius * math.cos(angle)).clamp(0, 1).toDouble(),
        (center.dy + radius * math.sin(angle)).clamp(0, 1).toDouble(),
      ),
    );
  }
  return spots;
}
