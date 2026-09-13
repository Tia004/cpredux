import 'catalog_item.dart';
import 'enums.dart';
import 'json_support.dart';

/// Dati specifici di un'arma.
class WeaponData {
  WeaponData({
    required this.skillId,
    this.handsRequired = '1',
    this.damage = '',
    this.currentAmmo = 0,
    this.maxAmmo = 0,
    this.rof = 1,
    this.isConcealable = false,
    this.properties = '',
  });

  int skillId;
  String handsRequired;
  String damage;
  int currentAmmo;
  int maxAmmo;
  int rof;
  bool isConcealable;
  String properties;

  Map<String, Object?> toJson() => <String, Object?>{
        'skillId': skillId,
        'handsRequired': handsRequired,
        'damage': damage,
        'currentAmmo': currentAmmo,
        'maxAmmo': maxAmmo,
        'rof': rof,
        'isConcealable': isConcealable,
        'properties': properties,
      };

  static WeaponData fromJson(Map<String, Object?> json) => WeaponData(
        skillId: readInt(json['skillId'], 12),
        handsRequired: readString(json['handsRequired'], '1'),
        damage: readString(json['damage']),
        currentAmmo: readInt(json['currentAmmo']),
        maxAmmo: readInt(json['maxAmmo']),
        rof: readInt(json['rof'], 1),
        isConcealable: readBool(json['isConcealable']),
        properties: readString(json['properties']),
      );
}

/// Dati specifici di un'armatura.
class ArmorData {
  ArmorData({
    this.slot = ArmorSlot.body,
    this.sp = 0,
    this.penalties = 0,
  });

  ArmorSlot slot;

  /// Stopping Power: quanto danno assorbe.
  int sp;

  /// Penalita' applicata a Riflessi, Destrezza e Velocita'.
  int penalties;

  Map<String, Object?> toJson() => <String, Object?>{
        'slot': slot.id,
        'sp': sp,
        'penalties': penalties,
      };

  static ArmorData fromJson(Map<String, Object?> json) => ArmorData(
        slot: ArmorSlot.fromId(readInt(json['slot'], 1)) ?? ArmorSlot.body,
        sp: readInt(json['sp']),
        penalties: readInt(json['penalties']),
      );
}

class ClothingData {
  ClothingData({
    this.slot = ClothingSlot.top,
    this.style = ClothingStyle.genericChic,
  });

  ClothingSlot slot;
  ClothingStyle style;

  Map<String, Object?> toJson() => <String, Object?>{
        'slot': slot.name,
        'style': style.name,
      };

  static ClothingData fromJson(Map<String, Object?> json) => ClothingData(
        slot: ClothingSlot.values.firstWhere(
          (ClothingSlot s) => s.name == readString(json['slot']),
          orElse: () => ClothingSlot.top,
        ),
        style: ClothingStyle.values.firstWhere(
          (ClothingStyle s) => s.name == readString(json['style']),
          orElse: () => ClothingStyle.genericChic,
        ),
      );
}

/// Una voce d'inventario.
///
/// E' volutamente **leggera**: quasi sempre contiene solo il riferimento a una
/// voce di catalogo, la quantita' e le personalizzazioni. Il vecchio formato
/// copiava dentro ogni scheda l'oggetto intero, immagine Base64 compresa: con
/// cinquanta oggetti erano schede da decine di MB, e correggere un prezzo nel
/// catalogo non correggeva le schede gia' create.
///
/// `custom` resta per l'unico caso in cui il catalogo non puo' aiutare: un
/// oggetto inventato dall'utente. In quel caso la definizione **deve** viaggiare
/// con la scheda, altrimenti l'oggetto esisterebbe solo su questa macchina.
class InventoryEntry {
  InventoryEntry({
    required this.id,
    this.catalogId,
    this.custom,
    this.quantity = 1,
    this.isEquipped = false,
    this.currentAmmo = 0,
    ItemOverride? overrides,
  })  : overrides = overrides ?? ItemOverride(),
        assert(catalogId != null || custom != null,
            'Una voce senza riferimento di catalogo deve portare la propria definizione.');

  /// Identificativo della riga dentro la scheda.
  final String id;

  /// Riferimento al catalogo. Nullo per gli oggetti creati a mano.
  final String? catalogId;

  /// Definizione completa, presente solo per gli oggetti personalizzati.
  ///
  /// Modificabile perche' un oggetto creato a mano e' l'unica copia che esiste:
  /// correggerne il danno non significa "personalizzarlo rispetto a", significa
  /// riscriverlo.
  CatalogItem? custom;

  int quantity;
  bool isEquipped;

  /// Munizioni attuali: stato d'istanza, non una proprieta' dell'oggetto.
  /// Due copie della stessa arma possono avere caricatori diversi.
  int currentAmmo;

  /// Solo i campi modificati rispetto al catalogo, per questa scheda.
  ///
  /// Sostituibile in blocco: l'editor delle personalizzazioni restituisce un
  /// nuovo insieme di differenze, e applicarlo e' un'assegnazione e non una
  /// fusione campo per campo (che lascerebbe in giro valori appena rimossi).
  ItemOverride overrides;

  bool get isCustom => catalogId == null;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        if (catalogId != null) 'catalogId': catalogId,
        if (custom != null) 'custom': custom!.toJson(),
        'quantity': quantity,
        'isEquipped': isEquipped,
        if (currentAmmo != 0) 'currentAmmo': currentAmmo,
        if (!overrides.isEmpty) 'overrides': overrides.toJson(),
      };

  static InventoryEntry fromJson(Map<String, Object?> json) => InventoryEntry(
        id: readString(json['id']),
        catalogId: readNullableString(json['catalogId']),
        custom: json['custom'] is Map
            ? CatalogItem.fromJson(
                (json['custom']! as Map<Object?, Object?>)
                    .map((Object? k, Object? v) => MapEntry(k.toString(), v)),
              )
            : null,
        quantity: readInt(json['quantity'], 1),
        isEquipped: readBool(json['isEquipped']),
        currentAmmo: readInt(json['currentAmmo']),
        overrides: json['overrides'] is Map
            ? ItemOverride.fromJson(
                (json['overrides']! as Map<Object?, Object?>)
                    .map((Object? k, Object? v) => MapEntry(k.toString(), v)),
              )
            : null,
      );

  /// Costruisce una voce da una voce di catalogo.
  factory InventoryEntry.fromCatalog(CatalogItem item, {required String id}) =>
      InventoryEntry(id: id, catalogId: item.id);

  /// Costruisce una voce per un oggetto inventato dall'utente.
  factory InventoryEntry.customItem(CatalogItem item, {required String id}) =>
      InventoryEntry(id: id, custom: item);
}
