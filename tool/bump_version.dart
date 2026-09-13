// Cambia la versione del programma in un posto solo, aggiornando entrambi i
// file che la dichiarano.
//
// Uso:
//   dart run tool/bump_version.dart 0.3.0
//   dart run tool/bump_version.dart 0.3.0 --dry-run
//
// Perche' un comando e non due modifiche a mano: la versione vive in
// `lib/version.dart` (la legge il programma, il titolo della finestra, la
// presenza Discord) e in `pubspec.yaml` (la legge il pacchetto). Un test
// verifica che coincidano, e la ragione e' che se divergono l'aggiornamento
// automatico confronta il numero sbagliato e **non trova mai** la versione
// giusta: il sintomo e' "non ci sono aggiornamenti", che non si collega a una
// svista fatta due mesi prima in un altro file.
//
// Il numero di build dopo il `+` in pubspec (`0.3.0+7`) viene conservato: e' il
// contatore delle compilazioni, non fa parte della versione pubblicata, e
// cambiarlo qui non servirebbe a niente.

import 'dart:io';

void main(List<String> arguments) {
  final List<String> args =
      arguments.where((String a) => a != '--dry-run').toList(growable: false);
  final bool dryRun = arguments.contains('--dry-run');

  if (args.length != 1) {
    stderr.writeln('Uso: dart run tool/bump_version.dart X.Y.Z [--dry-run]');
    exitCode = 2;
    return;
  }

  final String next = args.single.trim();
  final RegExpMatch? parsed = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(next);
  if (parsed == null) {
    // Le versioni si confrontano numericamente, quindi `0.3` e `0.3.0-beta`
    // sarebbero confronti diversi da quelli che il manifesto sa fare. Meglio
    // rifiutarle qui che scoprirlo in un confronto sbagliato.
    stderr.writeln('Versione non valida: "$next". Serve la forma X.Y.Z.');
    exitCode = 2;
    return;
  }

  final File versionFile = File('lib/version.dart');
  final File pubspecFile = File('pubspec.yaml');

  final String versionSource = versionFile.readAsStringSync();
  final RegExpMatch? current = RegExp(r"appVersion = '([^']+)'").firstMatch(versionSource);
  if (current == null) {
    stderr.writeln('Non trovo `appVersion` in lib/version.dart.');
    exitCode = 1;
    return;
  }

  final String pubspec = pubspecFile.readAsStringSync();
  final RegExpMatch? declared = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec);
  if (declared == null) {
    stderr.writeln('Non trovo il campo `version` in pubspec.yaml.');
    exitCode = 1;
    return;
  }

  // Se i due file sono gia' disallineati non si "aggiusta" niente: si dice, e
  // si lascia decidere. Allinearli in silenzio nasconderebbe che qualcuno ha
  // cambiato una versione a mano, e la prossima volta succederebbe di nuovo.
  final String pubspecVersion = declared.group(1)!;
  final String pubspecBase = pubspecVersion.split('+').first;
  if (pubspecBase != current.group(1)) {
    stderr.writeln('I due file sono gia\' disallineati: lib/version.dart dice '
        '${current.group(1)}, pubspec.yaml dice $pubspecBase. Allineali prima.');
    exitCode = 1;
    return;
  }

  final String buildSuffix =
      pubspecVersion.contains('+') ? '+${pubspecVersion.split('+').last}' : '';

  final String nextVersionSource =
      versionSource.replaceFirst(current.group(0)!, "appVersion = '$next'");
  final String nextPubspec = pubspec.replaceFirst(
    RegExp(r'^version:\s*\S+', multiLine: true),
    'version: $next$buildSuffix',
  );

  if (dryRun) {
    stdout.writeln('lib/version.dart: ${current.group(1)} -> $next');
    stdout.writeln('pubspec.yaml:    $pubspecVersion -> $next$buildSuffix');
    return;
  }

  versionFile.writeAsStringSync(nextVersionSource, flush: true);
  pubspecFile.writeAsStringSync(nextPubspec, flush: true);
  stdout.writeln('Versione: ${current.group(1)} -> $next');
}
