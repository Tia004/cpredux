import 'package:flutter/animation.dart';

/// Token di movimento. Un'unica fonte di verita' per il "come si muove" l'app:
/// se domani vuoi rallentare tutto o renderlo piu' secco, tocchi solo qui.
///
/// Le durate sono raggruppate per *intenzione*, non per lunghezza:
/// la domanda non e' "quanto dura?", ma "cosa sta comunicando?".
abstract final class CprMotion {
  /// Feedback immediato: hover, press, tick di un toggle.
  static const Duration hover = Duration(milliseconds: 110);
  static const Duration press = Duration(milliseconds: 90);

  /// Cambi di valore: numeri che scorrono, barre che si riempiono.
  static const Duration value = Duration(milliseconds: 360);

  /// Ingresso/uscite di elementi.
  static const Duration fast = Duration(milliseconds: 220);
  static const Duration normal = Duration(milliseconds: 380);
  static const Duration slow = Duration(milliseconds: 620);

  /// Momenti scenici: cambio scena, apertura del comando rapido,
  /// animazione del tiro di dadi.
  static const Duration deliberate = Duration(milliseconds: 900);
  static const Duration cinematic = Duration(milliseconds: 1600);

  // Curve. `enter` e' il default: parte rapida e frena dolcemente, che e'
  // quello che rende un'interfaccia "reattiva" invece che "lenta".
  static const Curve enter = Cubic(0.16, 1.00, 0.30, 1.00);
  static const Curve exit = Cubic(0.50, 0.00, 0.75, 0.00);
  static const Curve snap = Cubic(0.34, 1.45, 0.64, 1.00);
  static const Curve step = Cubic(0.85, 0.00, 0.15, 1.00);
  static const Curve linear = Curves.linear;

  // Molle per le animazioni guidate da fisica (il cuore, i pannelli che si
  // assestano). Sono qui e non nei widget perche' un'app che usa tre molle
  // diverse in tre punti diversi "sembra" fatta da tre persone diverse.
  /// Per valori che devono *assestarsi* con un rimbalzo: cura, danno, punti.
  static const SpringDescription valueSpring =
      SpringDescription(mass: 1, stiffness: 190, damping: 20);

  /// Per contenitori che si aprono: rimbalzo minimo, si sente appena.
  static const SpringDescription containerSpring =
      SpringDescription(mass: 1, stiffness: 250, damping: 30);

  /// Per masse grandi (pannelli interi, scena): si muovono con peso.
  static const SpringDescription heavySpring =
      SpringDescription(mass: 2.4, stiffness: 150, damping: 26);
}
