import 'enums.dart';
import 'items.dart';
import 'json_support.dart';

/// Una voce del **catalogo**: sola lettura, spedita con l'app.
///
/// Il motivo per cui esiste, in una riga: una scheda deve pesare pochi KB e
/// un oggetto deve potersi correggere una volta sola per tutte. Nel formato
/// precedente ogni oggetto era copiato dentro la scheda, immagine Base64
/// inclusa — cinquanta oggetti significavano una scheda da decine di MB, e
/// correggere un refuso nel nome di un'arma non correggeva le schede gia'
/// create.
///
/// La scheda, adesso, salva solo il **riferimento** a una voce di catalogo piu'
/// le sue personalizzazioni. Gli oggetti creati a mano dall'utente restano
/// definiti per intero dentro la scheda: sono l'unica cosa che il catalogo non
/// puo' conoscere.
class CatalogItem {
  CatalogItem({
    required this.id,
    required this.name,
    required this.category,
    this.rarity = Rarity.common,
    this.cost = 0,
    this.description = '',
    this.weight = 0,
    this.imageAsset,
    this.source = '',
    this.weapon,
    this.armor,
    this.clothing,
  });

  /// Identificativo stabile della voce, es. `wpn-heavy-pistol`.
  ///
  /// Stabile perche' finisce dentro le schede salvate: rinominarlo
  /// scollegherebbe tutte le schede che lo usano.
  final String id;
  final String name;
  final ItemCategory category;
  final Rarity rarity;
  final int cost;
  final String description;

  /// Peso di una singola unita'.
  final double weight;

  /// Immagine inclusa negli asset dell'app. Nullo significa "slot immagine
  /// vuoto": l'artwork ufficiale di Cyberpunk RED non viene spedito, quindi la
  /// maggior parte delle voci non ha un'immagine e l'utente puo' aggiungerne
  /// una propria (che resta nella scheda come personalizzazione).
  final String? imageAsset;

  /// Da dove viene la voce (`core` = manuale base, `custom` = creata
  /// dall'utente). Serve a poter dire all'utente quanto e' verificabile un
  /// dato invece di presentare tutto come ugualmente autorevole.
  final String source;

  WeaponData? weapon;
  ArmorData? armor;
  ClothingData? clothing;

  bool get isWeapon => weapon != null;
  bool get isArmor => armor != null;
  bool get isClothing => clothing != null;

  /// Chiave di confronto per riconoscere lo stesso oggetto fra catalogo e
  /// vecchie schede: nome senza spazi doppi, senza maiuscole, senza
  /// punteggiatura di contorno.
  static String matchKey(String name) =>
      name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'name': name,
        'category': category.id,
        'rarity': rarity.name,
        'cost': cost,
        'description': description,
        'weight': weight,
        'imageAsset': imageAsset,
        'source': source,
        if (weapon != null) 'weapon': weapon!.toJson(),
        if (armor != null) 'armor': armor!.toJson(),
        if (clothing != null) 'clothing': clothing!.toJson(),
      };

  static CatalogItem fromJson(Map<String, Object?> json) => CatalogItem(
        id: readString(json['id']),
        name: readString(json['name']),
        category: ItemCategory.fromId(readInt(json['category'])) ?? ItemCategory.item,
        rarity: Rarity.values.firstWhere(
          (Rarity r) => r.name == readString(json['rarity']),
          orElse: () => Rarity.common,
        ),
        cost: readInt(json['cost']),
        description: readString(json['description']),
        weight: readDouble(json['weight']),
        imageAsset: readNullableString(json['imageAsset']),
        source: readString(json['source']),
        weapon: json['weapon'] is Map
            ? WeaponData.fromJson(_map(json['weapon']))
            : null,
        armor: json['armor'] is Map ? ArmorData.fromJson(_map(json['armor'])) : null,
        clothing: json['clothing'] is Map
            ? ClothingData.fromJson(_map(json['clothing']))
            : null,
      );

  static Map<String, Object?> _map(Object? value) =>
      (value! as Map<Object?, Object?>).map((Object? k, Object? v) => MapEntry(k.toString(), v));
}

/// Le personalizzazioni dell'utente su una voce di catalogo.
///
/// Sono **solo i campi modificati**, non una copia della voce: cosi' una
/// correzione futura del catalogo (un prezzo sbagliato, un danno errato)
/// aggiorna tutte le schede tranne i campi che l'utente ha deliberatamente
/// cambiato. Copiare la voce intera avrebbe riprodotto, in piccolo, lo stesso
/// problema del formato precedente.
class ItemOverride {
  ItemOverride({
    this.name,
    this.description,
    this.cost,
    this.weight,
    this.rarity,
    this.imagePath,
    this.damage,
    this.sp,
    this.penalties,
    this.style,
  });

  String? name;
  String? description;
  int? cost;
  double? weight;
  Rarity? rarity;

  /// Immagine scelta dall'utente per *questo* oggetto in *questa* scheda.
  String? imagePath;

  // Sovrascritture dei dati specifici, limitate ai campi che si correggono
  // davvero al tavolo: il danno di un'arma, la protezione di un'armatura, lo
  // stile di un capo. Munizioni e quantita' sono stato d'istanza e vivono nella
  // voce d'inventario, non qui.
  String? damage;
  int? sp;
  int? penalties;
  ClothingStyle? style;

  bool get isEmpty =>
      name == null &&
      description == null &&
      cost == null &&
      weight == null &&
      rarity == null &&
      imagePath == null &&
      damage == null &&
      sp == null &&
      penalties == null &&
      style == null;

  int get count => <Object?>[name, description, cost, weight, rarity, imagePath, damage, sp, penalties, style]
      .where((Object? v) => v != null)
      .length;

  void clear() {
    name = null;
    description = null;
    cost = null;
    weight = null;
    rarity = null;
    imagePath = null;
    damage = null;
    sp = null;
    penalties = null;
    style = null;
  }

  ItemOverride copy() => ItemOverride(
        name: name,
        description: description,
        cost: cost,
        weight: weight,
        rarity: rarity,
        imagePath: imagePath,
        damage: damage,
        sp: sp,
        penalties: penalties,
        style: style,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        if (name != null) 'name': name,
        if (description != null) 'description': description,
        if (cost != null) 'cost': cost,
        if (weight != null) 'weight': weight,
        if (rarity != null) 'rarity': rarity!.name,
        if (imagePath != null) 'imagePath': imagePath,
        if (damage != null) 'damage': damage,
        if (sp != null) 'sp': sp,
        if (penalties != null) 'penalties': penalties,
        if (style != null) 'style': style!.name,
      };

  static ItemOverride fromJson(Map<String, Object?> json) => ItemOverride(
        name: readNullableString(json['name']),
        description: readNullableString(json['description']),
        cost: json['cost'] is num ? (json['cost']! as num).toInt() : null,
        weight: json['weight'] is num ? (json['weight']! as num).toDouble() : null,
        rarity: json['rarity'] == null
            ? null
            : Rarity.values.firstWhere(
                (Rarity r) => r.name == readString(json['rarity']),
                orElse: () => Rarity.common,
              ),
        imagePath: readNullableString(json['imagePath']),
        damage: readNullableString(json['damage']),
        sp: json['sp'] is num ? (json['sp']! as num).toInt() : null,
        penalties: json['penalties'] is num ? (json['penalties']! as num).toInt() : null,
        style: json['style'] == null
            ? null
            : ClothingStyle.values.firstWhere(
                (ClothingStyle s) => s.name == readString(json['style']),
                orElse: () => ClothingStyle.genericChic,
              ),
      );
}

/// Un oggetto d'inventario **risolto**: catalogo e personalizzazioni unite.
///
/// La UI non legge mai direttamente la voce d'inventario: legge questa. E' la
/// regola che rende impossibile mostrare un prezzo senza applicare l'override,
/// o un peso che ignora la personalizzazione — il tipo di incoerenza che nasce
/// quando la fusione viene fatta "a mano" in ogni punto in cui serve.
class ResolvedItem {
  const ResolvedItem({required this.entry, this.catalog});

  final InventoryEntry entry;

  /// La voce di catalogo, oppure null per un oggetto creato a mano.
  final CatalogItem? catalog;

  ItemOverride get overrides => entry.overrides;

  /// La definizione di base: catalogo se c'e', altrimenti quella incorporata
  /// nella scheda.
  CatalogItem? get base => catalog ?? entry.custom;

  bool get isCustom => entry.catalogId == null;

  /// True se l'utente ha modificato qualcosa rispetto al catalogo.
  bool get isPersonalised => !overrides.isEmpty;

  String get name => overrides.name ?? base?.name ?? 'Oggetto senza nome';
  String get description => overrides.description ?? base?.description ?? '';
  int get cost => overrides.cost ?? base?.cost ?? 0;
  double get unitWeight => overrides.weight ?? base?.weight ?? 0;
  double get totalWeight => unitWeight * entry.quantity;
  Rarity get rarity => overrides.rarity ?? base?.rarity ?? Rarity.common;
  ItemCategory get category => base?.category ?? ItemCategory.item;

  String? get imagePath => overrides.imagePath ?? entry.custom?.imageAsset ?? catalog?.imageAsset;

  /// Dati d'arma: la definizione viene dal catalogo, le munizioni dalla voce
  /// d'inventario (sono stato d'istanza, non una proprieta' dell'oggetto).
  WeaponData? get weapon {
    final WeaponData? baseWeapon = base?.weapon;
    if (baseWeapon == null) return null;
    return WeaponData(
      skillId: baseWeapon.skillId,
      handsRequired: baseWeapon.handsRequired,
      damage: overrides.damage ?? baseWeapon.damage,
      currentAmmo: entry.currentAmmo,
      maxAmmo: baseWeapon.maxAmmo,
      rof: baseWeapon.rof,
      isConcealable: baseWeapon.isConcealable,
      properties: baseWeapon.properties,
    );
  }

  ArmorData? get armor {
    final ArmorData? baseArmor = base?.armor;
    if (baseArmor == null) return null;
    return ArmorData(
      slot: baseArmor.slot,
      sp: overrides.sp ?? baseArmor.sp,
      penalties: overrides.penalties ?? baseArmor.penalties,
    );
  }

  ClothingData? get clothing {
    final ClothingData? baseClothing = base?.clothing;
    if (baseClothing == null) return null;
    return ClothingData(
      slot: baseClothing.slot,
      style: overrides.style ?? baseClothing.style,
    );
  }

  bool get isWeapon => weapon != null;
  bool get isArmor => armor != null;
  bool get isClothing => clothing != null;

  /// Risolve una lista intera, che e' l'operazione che serve ovunque.
  static List<ResolvedItem> resolveAll(
    List<InventoryEntry> entries,
    CatalogItem? Function(String catalogId) lookup,
  ) =>
      <ResolvedItem>[
        for (final InventoryEntry entry in entries)
          ResolvedItem(
            entry: entry,
            catalog: entry.catalogId == null ? null : lookup(entry.catalogId!),
          ),
      ];
}
