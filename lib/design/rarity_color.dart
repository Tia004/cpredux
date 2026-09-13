import 'package:flutter/material.dart';

import '../domain/enums.dart';

/// Colore associato a una rarita' di oggetto.
///
/// Vive nel livello di presentazione e non nel dominio per una ragione
/// concreta: il dominio (`lib/domain/`) non importa Flutter, cosi' gli stessi
/// tipi possono essere usati dai test puri e dallo script che genera il
/// catalogo oggetti, che gira sulla VM Dart senza motore grafico.
///
/// I valori sono **quelli del progetto originale**: in una tabella con
/// centinaia di righe il colore e' il canale piu' rapido per riconoscere a
/// colpo d'occhio cosa vale la pena raccogliere, e sono i colori che gli utenti
/// hanno gia' imparato a riconoscere.
extension RarityColor on Rarity {
  Color get color => switch (this) {
        Rarity.common => const Color(0xFFE0E0E0),
        Rarity.uncommon => const Color(0xFF22A318),
        Rarity.rare => const Color(0xFF098CDE),
        Rarity.veryRare => const Color(0xFF285EEB),
        Rarity.legendary => const Color(0xFFB511AB),
        Rarity.exotic => const Color(0xFFE8E409),
      };
}
