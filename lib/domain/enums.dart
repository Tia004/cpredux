/// Tipi del dominio applicativo.
///
/// Questo file **non dipende da Flutter**, ed e' una regola, non un dettaglio:
/// gli stessi tipi servono all'applicazione, ai test e allo script che genera
/// il catalogo oggetti (`tool/build_catalog.dart`, che gira sulla VM Dart senza
/// motore grafico). Il colore di una rarita' e' una scelta di presentazione e
/// vive in `lib/design/`.
library;

/// Categorie di cyberware, con l'id stabile del vecchio database.
enum CyberwareCategory {
  fashionware(0, 'Fashionware'),
  neuralware(1, 'Neuralware'),
  cyberoptics(2, 'Cyberottiche'),
  cyberaudio(3, 'Cyberudito'),
  internalCyberware(4, 'Implanti Interni'),
  externalCyberware(5, 'Implanti Esterni'),
  cyberlimbs(6, 'Cyberarti'),
  borgware(7, 'Borgware');

  const CyberwareCategory(this.id, this.label);

  final int id;
  final String label;

  static CyberwareCategory? fromId(int id) {
    for (final CyberwareCategory c in CyberwareCategory.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Slot di armatura. In CP RED ogni slot copre una parte del corpo e
/// le penalita' si sommano in modo diverso a seconda di cosa indossi.
enum ArmorSlot {
  head(0, 'Testa'),
  body(1, 'Corpo'),
  shield(2, 'Scudo');

  const ArmorSlot(this.id, this.label);

  final int id;
  final String label;

  static ArmorSlot? fromId(int id) {
    for (final ArmorSlot s in ArmorSlot.values) {
      if (s.id == id) return s;
    }
    return null;
  }
}

enum ClothingSlot {
  top('Sopra'),
  bottom('Sotto'),
  jacket('Giacca'),
  shoes('Scarpe'),
  jewels('Gioielli'),
  mirroredGlasses('Occhiali a Specchio'),
  eyeGlasses('Occhiali'),
  contactLenses('Lenti a Contatto'),
  hat('Cappello');

  const ClothingSlot(this.label);

  final String label;

  static ClothingSlot fromOrdinal(int ordinal) =>
      ordinal >= 0 && ordinal < ClothingSlot.values.length
          ? ClothingSlot.values[ordinal]
          : ClothingSlot.top;
}

enum ClothingStyle {
  genericChic('Generic Chic'),
  leisurewear('Leisurewear'),
  urbanFlash('Urban Flash'),
  businessWear('Business Wear'),
  edgerunner('Edgerunner'),
  highFashion('Alta Moda'),
  bagLadyChic('Bag Lady Chic'),
  minimalisticFashion('Minimalistic Fashion'),
  exotics('Exotics'),
  naturalists('Naturalists'),
  gangColours('Gang Colours'),
  bohemian('Bohemian'),
  nomadLeathers('Cuoio da Nomade'),
  asiaPop('Asia Pop'),
  entropism('Entropismo'),
  kitsch('Kitsch'),
  neoMilitarism('Neo-Militarismo'),
  neoKitsch('Neo-Kitsch');

  const ClothingStyle(this.label);

  final String label;

  static ClothingStyle fromOrdinal(int ordinal) =>
      ordinal >= 0 && ordinal < ClothingStyle.values.length
          ? ClothingStyle.values[ordinal]
          : ClothingStyle.genericChic;
}

/// Rarita' di un oggetto.
///
/// L'ordinale e' significativo: e' l'ordine di rarita', ed e' anche il valore
/// salvato nel catalogo e nei documenti. Non riordinare le voci.
enum Rarity {
  common('Comune'),
  uncommon('Non Comune'),
  rare('Raro'),
  veryRare('Molto Raro'),
  legendary('Leggendario'),
  exotic('Esotico');

  const Rarity(this.label);

  final String label;

  static Rarity fromOrdinal(int ordinal) =>
      ordinal >= 0 && ordinal < Rarity.values.length ? Rarity.values[ordinal] : Rarity.common;
}

/// Categoria di un oggetto d'inventario.
enum ItemCategory {
  item(0, 'Oggetto'),
  ammunition(1, 'Munizioni'),
  equipment(2, 'Equipaggiamento'),
  clothing(3, 'Abbigliamento'),
  armor(4, 'Armatura'),
  weapon(5, 'Arma');

  const ItemCategory(this.id, this.label);

  final int id;
  final String label;

  static ItemCategory? fromId(int id) {
    for (final ItemCategory c in ItemCategory.values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Quanto un effetto e' conosciuto dal personaggio.
enum EffectKnowledge {
  unknown(-1, 'Sconosciuto'),
  no(0, 'No'),
  yes(1, 'Si');

  const EffectKnowledge(this.id, this.label);

  final int id;
  final String label;

  static EffectKnowledge? fromId(int id) {
    for (final EffectKnowledge k in EffectKnowledge.values) {
      if (k.id == id) return k;
    }
    return null;
  }
}

/// Stato di carico, con la penalita' che applica a Velocita' e Destrezza.
///
/// Le soglie sono percentuali sul carico massimo. Il progetto originale le
/// applica a MOV e DEX (il commento nel codice dice "MOVE and DEX").
enum LoadStatus {
  light(0, 1, 'Leggero'),
  normal(30, 0, 'Normale'),
  heavy(70, -1, 'Pesante'),
  overload(100, -2, 'Sovraccarico'),
  error(-1, 0, 'Errore');

  const LoadStatus(this.threshold, this.statPenalty, this.label);

  final double threshold;

  /// Correzione applicata a Velocita' e Destrezza.
  final int statPenalty;
  final String label;

  static LoadStatus fromPercentage(double percentage) {
    if (percentage < 0) return LoadStatus.error;
    if (percentage >= LoadStatus.overload.threshold) return LoadStatus.overload;
    if (percentage >= LoadStatus.heavy.threshold) return LoadStatus.heavy;
    if (percentage >= LoadStatus.normal.threshold) return LoadStatus.normal;
    return LoadStatus.light;
  }
}

/// Dadi disponibili nel tiro.
enum DiceType {
  coin(2, 'd2'),
  d4(4, 'd4'),
  d6(6, 'd6'),
  d8(8, 'd8'),
  d10(10, 'd10'),
  d12(12, 'd12'),
  d20(20, 'd20'),
  d100(100, 'd100');

  const DiceType(this.faces, this.label);

  final int faces;
  final String label;
}

/// Tipo di documento aperto. Determina cosa mostra la shell.
enum DocumentKind {
  sheet('Scheda', 'cpred_sheet'),
  campaign('Campagna', 'cpred_campaign');

  const DocumentKind(this.label, this.legacyExtension);

  final String label;

  /// Estensione usata dal vecchio formato Java, necessaria al migratore.
  final String legacyExtension;
}
