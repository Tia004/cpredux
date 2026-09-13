import 'dart:io';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/startup.dart';
import 'data/catalog.dart';
import 'features/update/apply_update_screen.dart';

/// Avvio dell'applicazione.
///
/// Il programma si avvia in tre modi, e la differenza la decide la riga di
/// comando, non un file di stato: cosi' non esiste un avvio in cui "sembra
/// normale ma sta aggiornando", che sarebbe il modo piu' rapido per corrompere
/// l'installazione.
///
/// * **normale** — l'applicazione, con il catalogo caricato prima di costruire
///   l'interfaccia: se il catalogo arrivasse dopo, la prima scheda aperta
///   verrebbe calcolata senza, e il carico risulterebbe sbagliato fino al primo
///   ricalcolo;
/// * `--apply-update` — una copia del programma che installa un aggiornamento e
///   riapre l'applicazione. E' la copia che il programma in esecuzione avvia
///   quando l'utente ha scelto "alla chiusura": l'esecuzione principale esce e
///   non tocca mai i propri file;
/// * `--just-updated` — l'applicazione, che deve dire una volta sola che
///   l'aggiornamento e' andato a buon fine.
void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final StartupRequest request = StartupRequest.parse(args);

  if (request.mode == StartupMode.applyUpdate) {
    runApp(ApplyUpdateApp(request: request));
    return;
  }

  _startApp(request);
}

Future<void> _startApp(StartupRequest request) async {
  final ItemCatalog catalog = await ItemCatalog.loadBundled();

  // Il catalogo che non si carica non blocca l'avvio, ma va detto: su stderr per
  // chi guarda i log, e nell'inventario (che mostra "catalogo non disponibile")
  // per chi usa il programma.
  final String? catalogError = catalog.loadError;
  if (catalogError != null) stderr.writeln(catalogError);

  runApp(CpredApp(catalog: catalog, startup: request));
}
