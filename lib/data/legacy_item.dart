import '../domain/catalog_item.dart';
import '../domain/enums.dart';
import '../domain/items.dart';
import 'catalog.dart';

/// Esito della conversione di una voce.
class LegacyItemResult {
  const LegacyItemResult({
    required this.entry,
    required this.matched,
    required this.personalisationCount,
  });

  final InventoryEntry entry;

  /// True se la voce e' stata riconosciuta nel catalogo.
  final bool matched;

  /// Quante differenze rispetto al catalogo sono state conservate come
  /// personalizzazioni.
  final int personalisationCount;
}

/// Converte una voce d'inventario del **vecchio formato** in una voce leggera.
///
/// La stessa funzione serve due casi che sembrano diversi e non lo sono:
///
/// * i documenti `.cpredux` di formato v1, dove ogni voce conteneva l'oggetto
///   per intero;
/// * le vecchie schede `.cpred_sheet`, lette dal migratore.
///
/// In entrambi i casi c'e' un nome, una categoria, un peso, dei dati specifici
/// e forse un'immagine. Scrivere questa logica due volte significherebbe
/// correggere due volte gli stessi casi limite, e prima o poi dimenticarsene
/// uno: per questo il migratore costruisce una mappa con le stesse chiavi del
/// formato v1 e la passa qui.
///
/// La regola che governa la conversione: **non si perde nulla**. Se l'oggetto
/// non e' nel catalogo diventa personalizzato e si porta dietro la definizione;
/// se c'e' ma l'utente lo aveva modificato, le differenze diventano
/// personalizzazioni esplicite.
abstract final class LegacyItemConverter {
  static LegacyItemResult convert(
    Map<String, Object?> legacy, {
    required String entryId,
    ItemCatalog? catalog,
    String? imagePath,
  }) {
    final String name = _string(legacy['name']) ?? 'Oggetto senza nome';
    final ItemCategory category =
        ItemCategory.fromId(_int(legacy['category']) ?? 0) ?? ItemCategory.item;
    final Rarity rarity = _rarity(legacy['rarity']);
    final int cost = _int(legacy['cost']) ?? 0;
    final String description = _string(legacy['description']) ?? '';
    final double weight = _double(legacy['weight']) ?? 0;
    final int quantity = _int(legacy['quantity']) ?? 1;
    final bool isEquipped = _bool(legacy['isEquipped']);

    final Map<String, Object?>? weapon = _map(legacy['weapon']);
    final Map<String, Object?>? armor = _map(legacy['armor']);
    final Map<String, Object?>? clothing = _map(legacy['clothing']);
    final String? image = imagePath ?? _string(legacy['imagePath']);
    final int currentAmmo = weapon == null ? 0 : _int(weapon['currentAmmo']) ?? 0;

    final CatalogItem? match = catalog?.matchByName(name, category: category);
    if (match == null) {
      // Non e' nel catalogo: la definizione viaggia con la scheda, perche' e'
      // l'unica copia che esiste.
      return LegacyItemResult(
        matched: false,
        personalisationCount: 0,
        entry: InventoryEntry(
          id: entryId,
          custom: CatalogItem(
            id: 'legacy-$entryId',
            name: name,
            category: category,
            rarity: rarity,
            cost: cost,
            description: description,
            weight: weight,
            imageAsset: image,
            source: 'legacy',
            weapon: _weaponFrom(weapon),
            armor: _armorFrom(armor),
            clothing: _clothingFrom(clothing),
          ),
          quantity: quantity,
          isEquipped: isEquipped,
          currentAmmo: currentAmmo,
        ),
      );
    }

    final ItemOverride overrides = _differences(
      match,
      name: name,
      rarity: rarity,
      cost: cost,
      description: description,
      weight: weight,
      image: image,
      weapon: weapon,
      armor: armor,
      clothing: clothing,
    );

    return LegacyItemResult(
      matched: true,
      personalisationCount: overrides.count,
      entry: InventoryEntry(
        id: entryId,
        catalogId: match.id,
        quantity: quantity,
        isEquipped: isEquipped,
        currentAmmo: currentAmmo,
        overrides: overrides,
      ),
    );
  }

  /// Confronta la voce salvata con quella di catalogo e conserva **solo** le
  /// differenze.
  ///
  /// Il confronto e' sul valore esatto: se il vecchio dato e il catalogo
  /// coincidono non si scrive nulla, e la scheda resta agganciata agli
  /// aggiornamenti futuri del catalogo. Un confronto "approssimativo" qui
  /// produrrebbe una marea di personalizzazioni inutili, che e' esattamente
  /// cio' che il formato a riferimenti vuole evitare.
  static ItemOverride _differences(
    CatalogItem match, {
    required String name,
    required Rarity rarity,
    required int cost,
    required String description,
    required double weight,
    required String? image,
    required Map<String, Object?>? weapon,
    required Map<String, Object?>? armor,
    required Map<String, Object?>? clothing,
  }) {
    final ItemOverride overrides = ItemOverride();

    if (CatalogItem.matchKey(name) != CatalogItem.matchKey(match.name)) overrides.name = name;
    if (rarity != match.rarity) overrides.rarity = rarity;
    if (cost != match.cost) overrides.cost = cost;
    if (description.trim().isNotEmpty && description != match.description) {
      overrides.description = description;
    }
    // Il peso si confronta con una tolleranza: e' un `double` passato per un
    // database, e 2.0000000001 non e' una personalizzazione.
    if ((weight - match.weight).abs() > 0.001) overrides.weight = weight;

    // L'immagine dell'utente **non** si perde mai: il catalogo non spedisce
    // artwork ufficiale, quindi quella scelta o importata dall'utente e' un suo
    // dato, non un duplicato del catalogo.
    if (image != null && image.trim().isNotEmpty) overrides.imagePath = image;

    final String? damage = weapon == null ? null : _string(weapon['damage']);
    if (damage != null && damage != (match.weapon?.damage ?? '')) overrides.damage = damage;

    final int? sp = armor == null ? null : _int(armor['sp']);
    if (sp != null && sp != (match.armor?.sp ?? 0)) overrides.sp = sp;

    final int? penalties = armor == null ? null : _int(armor['penalties']);
    if (penalties != null && penalties != (match.armor?.penalties ?? 0)) {
      overrides.penalties = penalties;
    }

    if (clothing != null && match.clothing != null) {
      final ClothingStyle? style = _clothingStyle(clothing['style']);
      if (style != null && style != match.clothing!.style) overrides.style = style;
    }

    return overrides;
  }

  static WeaponData? _weaponFrom(Map<String, Object?>? weapon) {
    if (weapon == null) return null;
    return WeaponData(
      skillId: _int(weapon['skillId']) ?? 12,
      handsRequired: _string(weapon['handsRequired']) ?? '1',
      damage: _string(weapon['damage']) ?? '',
      currentAmmo: 0,
      maxAmmo: _int(weapon['maxAmmo']) ?? 0,
      rof: _int(weapon['rof']) ?? 1,
      isConcealable: _bool(weapon['isConcealable']),
      properties: _string(weapon['properties']) ?? '',
    );
  }

  static ArmorData? _armorFrom(Map<String, Object?>? armor) {
    if (armor == null) return null;
    return ArmorData(
      slot: ArmorSlot.fromId(_int(armor['slot']) ?? 1) ?? ArmorSlot.body,
      sp: _int(armor['sp']) ?? 0,
      penalties: _int(armor['penalties']) ?? 0,
    );
  }

  static ClothingData? _clothingFrom(Map<String, Object?>? clothing) {
    if (clothing == null) return null;
    final ClothingSlot slot = ClothingSlot.values.firstWhere(
      (ClothingSlot s) => s.name == _string(clothing['slot']),
      orElse: () => ClothingSlot.top,
    );
    final ClothingStyle style = _clothingStyle(clothing['style']) ?? ClothingStyle.genericChic;
    return ClothingData(slot: slot, style: style);
  }

  static ClothingStyle? _clothingStyle(Object? value) {
    final String name = '${value ?? ''}';
    if (name.isEmpty) return null;
    for (final ClothingStyle style in ClothingStyle.values) {
      if (style.name == name || style.label == name) return style;
    }
    return ClothingStyle.fromOrdinal(int.tryParse(name) ?? -1);
  }

  static Rarity _rarity(Object? value) {
    // Nel formato v1 la rarita' era salvata per nome, in quello piu' vecchio
    // per ordinale: si accettano entrambi.
    if (value is num) return Rarity.fromOrdinal(value.toInt());
    final String name = '${value ?? ''}';
    for (final Rarity rarity in Rarity.values) {
      if (rarity.name == name) return rarity;
    }
    final int? ordinal = int.tryParse(name);
    return ordinal == null ? Rarity.common : Rarity.fromOrdinal(ordinal);
  }

  static Map<String, Object?>? _map(Object? value) => value is Map
      ? (value as Map<Object?, Object?>).map((Object? k, Object? v) => MapEntry(k.toString(), v))
      : null;

  static String? _string(Object? value) {
    if (value == null) return null;
    final String text = '$value';
    return text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _double(Object? value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static bool _bool(Object? value) => value == true || value == 1 || value == '1' || value == 'true';
}
