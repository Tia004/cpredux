import 'package:cpredux/app/app_state.dart';
import 'package:cpredux/domain/campaign.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Multi-ruolo & Abilità di Ruolo', () {
    test('SheetIdentity supporta ruoli multipli con add/remove e sincronizzazione stringa', () {
      final SheetIdentity identity = SheetIdentity(role: 'Solo');
      expect(identity.roles, equals(<String>['Solo']));

      identity.addRole('Netrunner');
      expect(identity.roles, containsAll(<String>['Solo', 'Netrunner']));
      expect(identity.role, contains('Solo'));
      expect(identity.role, contains('Netrunner'));

      // Non aggiunge duplicati case-insensitive
      identity.addRole('solo');
      expect(identity.roles.length, equals(2));

      // Rimozione ruolo
      identity.removeRole('Solo');
      expect(identity.roles, equals(<String>['Netrunner']));
      expect(identity.role, equals('Netrunner'));

      // Aggiunge Tech
      identity.addRole('Tech');
      expect(identity.roles, equals(<String>['Netrunner', 'Tech']));
    });

    test('SheetIdentity supporta abilità di ruolo multiple con add/remove', () {
      final SheetIdentity identity = SheetIdentity();
      expect(identity.roleAbilities, isEmpty);

      identity.addRoleAbility('Interfaccia');
      identity.addRoleAbility('Fabbricazione / Riparazione');
      expect(identity.roleAbilities, equals(<String>['Interfaccia', 'Fabbricazione / Riparazione']));
      expect(identity.roleAbility, contains('Interfaccia'));
      expect(identity.roleAbility, contains('Fabbricazione / Riparazione'));

      // Rimozione
      identity.removeRoleAbility('Interfaccia');
      expect(identity.roleAbilities, equals(<String>['Fabbricazione / Riparazione']));
    });

    test('Serializzazione e deserializzazione JSON conserva ruoli e abilità', () {
      final SheetIdentity original = SheetIdentity(
        tag: 'Johnny Silverhand',
        role: 'Rockerboy, Solo',
        roleAbility: 'Impatto Carismatico, Consapevolezza del Combattimento',
      );
      final Map<String, Object?> json = original.toJson();
      final SheetIdentity parsed = SheetIdentity.fromJson(json);

      expect(parsed.roles, equals(<String>['Rockerboy', 'Solo']));
      expect(parsed.roleAbilities, equals(<String>['Impatto Carismatico', 'Consapevolezza del Combattimento']));
    });
  });

  group('Background Story & Biografia', () {
    test('Background supporta il campo story in JSON e memoria', () {
      final Background bg = Background(
        culturalOrigins: 'Night City',
        story: 'Nato nelle periferie di Heywood da una famiglia di techie nomadi...',
      );
      expect(bg.story, contains('Heywood'));

      final Map<String, Object?> json = bg.toJson();
      expect(json['story'], equals(bg.story));

      final Background fromJson = Background.fromJson(json);
      expect(fromJson.story, equals(bg.story));
    });
  });

  group('SessionEvent & Whisper System', () {
    test('SessionEvent serializza e deserializza campi whisper', () {
      final SessionEvent event = SessionEvent(
        id: 'ev-1',
        timestamp: DateTime.now().toIso8601String(),
        playerId: 'master',
        description: '[Sussurro a Jackie] Stai allerta.',
        delta: 'MASTER',
        whisperTo: 'Jackie, V',
        isWhisper: true,
      );

      expect(event.isWhisper, isTrue);
      expect(event.whisperTargets, equals(<String>['Jackie', 'V']));

      final Map<String, Object?> json = event.toJson();
      expect(json['isWhisper'], isTrue);
      expect(json['whisperTo'], equals('Jackie, V'));

      final SessionEvent parsed = SessionEvent.fromJson(json);
      expect(parsed.isWhisper, isTrue);
      expect(parsed.whisperTo, equals('Jackie, V'));
      expect(parsed.whisperTargets, equals(<String>['Jackie', 'V']));
    });

    test('AppState.masterChat gestisce comandi /help, /clear e /whisper', () {
      final AppState state = AppState();
      addTearDown(state.dispose);

      // Comando /help aggiunge nota di sistema
      state.masterChat('/help');
      expect(state.sessionLog, isNotEmpty);
      expect(state.sessionLog.last.delta, equals('SISTEMA'));
      expect(state.sessionLog.last.description, contains('COMANDI CHAT DEL TAVOLO'));

      // Comando /clear svuota il registro
      state.masterChat('/clear');
      expect(state.sessionLog, isEmpty);

      // Invio sussurro con sintassi /w "Nome" Messaggio
      state.masterChat('/w "Panam Palmer" Ho pronto il pezzo per il veicolo.');
      expect(state.sessionLog, isNotEmpty);
      final SessionEvent whisperEvent = state.sessionLog.last;
      expect(whisperEvent.isWhisper, isTrue);
      expect(whisperEvent.whisperTo, equals('Panam Palmer'));
      expect(whisperEvent.description, contains('Ho pronto il pezzo'));
    });
  });
}
