/// Conversione fra coordinate della mappa (0..1) e coordinate del canvas.
///
/// Vive in un file suo e non dentro il painter perche' la usano **due** posti
/// che devono restare d'accordo: chi disegna e chi ascolta i clic. Se le due
/// conversioni fossero scritte due volte, un giorno divergerebbero di un
/// margine e i waypoint comparirebbero spostati rispetto a dove si clicca.
library;

import 'dart:ui' show Offset, Rect, Size;

/// Il quadrato in cui sta la mappa, centrato nello spazio disponibile.
///
/// La mappa e' quadrata (0..1 su entrambi gli assi) e la finestra quasi mai:
/// senza questa funzione verrebbe schiacciata in un rettangolo, e Night City
/// sarebbe piu' larga che alta.
Rect mapRectIn(Size size, {double padding = 8}) {
  final double side = (size.shortestSide - padding * 2).clamp(1, double.infinity);
  return Rect.fromCenter(
    center: Offset(size.width / 2, size.height / 2),
    width: side,
    height: side,
  );
}

/// Da coordinate mappa (0..1) a coordinate canvas.
Offset mapToLocal(Offset map, Rect rect) =>
    Offset(rect.left + map.dx * rect.width, rect.top + map.dy * rect.height);

/// Da coordinate canvas a coordinate mappa (0..1), **non** limitate.
///
/// Non limita di proposito: chi chiama deve poter distinguere "ho cliccato
/// sulla mappa" da "ho cliccato fuori", e un valore saturato a 0 o 1 renderebbe
/// le due cose identiche.
Offset localToMap(Offset local, Rect rect) =>
    Offset((local.dx - rect.left) / rect.width, (local.dy - rect.top) / rect.height);

/// True se un punto e' dentro la mappa.
bool isInsideMap(Offset map) =>
    map.dx >= 0 && map.dx <= 1 && map.dy >= 0 && map.dy <= 1;
