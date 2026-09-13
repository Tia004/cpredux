import 'package:cpredux/domain/catalog_item.dart';
import 'package:cpredux/domain/cyberware.dart';
import 'package:cpredux/domain/effects.dart';
import 'package:cpredux/domain/enums.dart';
import 'package:cpredux/domain/items.dart';
import 'package:cpredux/domain/modifiers.dart';
import 'package:cpredux/domain/sheet.dart';
import 'package:cpredux/domain/sheet_diff.dart';
import 'package:cpredux/domain/skills.dart';
import 'package:cpredux/domain/stats.dart';
import 'package:flutter_test/flutter_test.dart';

CharacterSheet _sheet({String name = 'Jackie'}) => CharacterSheet.fresh(
      id: 'sheet-test',
      name: name,
      now: '2026-01-01T00:00:00.000',
    );

/// Una copia indipendente: passa da JSON, che e' anche il modo in cui il
/// programma salva davvero. Se il confronto funziona fra originale e copia, il
/// salvataggio non perde niente di quello che si confronta.
CharacterSheet _copy(CharacterSheet sheet) =>
    CharacterSheet.fromJson(sheet.toJson());

InventoryEntry _item(String id, String name, {int quantity = 1, double weight = 1}) {
  final InventoryEntry entry = InventoryEntry.customItem(
    CatalogItem(
      id: 'custom-$id',
      name: name,
      category: ItemCategory.item,
      weight: weight,
      source: 'custom',
    ),
    id: id,
  );
  entry.quantity = quantity;
  return entry;
}

SheetDiff _compare(CharacterSheet before, CharacterSheet after) => SheetDiff.compare(
      before: before,
      after: after,
      beforeLabel: 'prima',
      afterLabel: 'dopo',
    );

/// La riga di una sezione, cercata per etichetta.
DiffRow _row(SheetDiff diff, String group, String label) => diff.groups
    .firstWhere((DiffGroup g) => g.title == group)
    .rows
    .firstWhere((DiffRow r) => r.label == label);

void main() {
  group('schede identiche', () {
    test('una copia non ha differenze', () {
      final SheetDiff diff = _compare(_sheet(), _copy(_sheet()));

      expect(diff.identical, isTrue);
      expect(diff.changes, 0);
      expect(diff.changedGroups, 0);
    });

    test('senza differenze, la vista "solo differenze" non mostra sezioni', () {
      final SheetDiff diff = _compare(_sheet(), _copy(_sheet()));

      expect(diff.groupsWith(onlyDifferences: true), isEmpty);
      // La vista "tutto" invece resta piena: e' li' che si guarda cosa *non* e'
      // cambiato.
      expect(diff.groupsWith(onlyDifferences: false), isNotEmpty);
    });

    test('il confronto tocca tutte le sezioni della scheda', () {
      final SheetDiff diff = _compare(_sheet(), _copy(_sheet()));

      final List<String> titles = diff.groups.map((DiffGroup g) => g.title).toList();
      expect(titles, contains('Personaggio'));
      expect(titles, contains('Caratteristiche'));
      expect(titles, contains('Abilita'));
      expect(titles, contains('Inventario'));
      expect(titles, contains('Cyberware'));
      expect(titles, contains('Effetti'));
      expect(titles, contains('Note'));
      expect(titles, contains('Background'));
      expect(titles, contains('Valori calcolati'));
      expect(titles, contains('Descrizione fisica'));

      // Tutte le 68 abilita' e le 10 caratteristiche sono righe confrontabili.
      expect(_group(diff, 'Abilita').rows.length, Skill.values.length);
      expect(_group(diff, 'Caratteristiche').rows.length, Stat.values.length);
    });
  });

  group('caratteristiche e abilita', () {
    test('una caratteristica cambiata si vede nel totale e nella base', () {
      final CharacterSheet before = _sheet();
      final CharacterSheet after = _copy(before);
      after.statBase[Stat.dexterity] = 7;

      final SheetDiff diff = _compare(before, after);
      final DiffRow dexterity = _row(diff, 'Caratteristiche', 'Destrezza');

      expect(dexterity.state, DiffState.changed);
      // Il valore mostrato e' il **totale**, non la base: 1 e 7 con il +1 di
      // carico leggero che il progetto applica a Destrezza e Velocita'.
      expect(dexterity.before, '2');
      expect(dexterity.after, '8');
      expect(dexterity.detail, 'base 1 → 7');

      // Le altre nove caratteristiche non sono cambiate.
      expect(_group(diff, 'Caratteristiche').changes, 1);
    });

    test('una base cambiata con lo stesso totale resta una differenza', () {
      // Il caso piu' insidioso: il numero che si legge al tavolo non cambia,
      // quindi una correzione a occhio direbbe "identiche". Ma la scheda e'
      // diversa, e nasconderlo renderebbe il confronto inutile proprio quando
      // serve.
      final CharacterSheet before = _sheet();
      before.statBase[Stat.dexterity] = 5;

      final CharacterSheet after = _copy(before);
      after.statBase[Stat.dexterity] = 7;
      after.statModifiers.add(StatModifier(target: Stat.dexterity, value: -2));

      final SheetDiff diff = _compare(before, after);
      final DiffRow dexterity = _row(diff, 'Caratteristiche', 'Destrezza');

      expect(dexterity.before, '6');
      expect(dexterity.after, '6');
      expect(dexterity.state, DiffState.changed);
      expect(dexterity.detail, 'base 5 → 7');
    });

    test('un livello di abilita cambiato si vede, e solo quello', () {
      final CharacterSheet before = _sheet();
      final CharacterSheet after = _copy(before);
      after.skillLevels[Skill.handgun] = 6;

      final SheetDiff diff = _compare(before, after);

      expect(_row(diff, 'Abilita', 'Pistole').after, '6');
      expect(_group(diff, 'Abilita').changes, 1);
    });

    test('una correzione manuale disattivata risulta cambiata', () {
      final CharacterSheet before = _sheet();
      before.statModifiers.add(StatModifier(target: Stat.reflexes, value: 2));

      final CharacterSheet after = _copy(before);
      after.statModifiers.first.isActive = false;

      final SheetDiff diff = _compare(before, after);
      final DiffRow row = _row(diff, 'Correzioni manuali', 'Riflessi');

      expect(row.before, '+2');
      expect(row.after, '+2 · disattivata');
      expect(row.state, DiffState.changed);
    });
  });

  group('inventario', () {
    test('un oggetto aggiunto e uno tolto', () {
      final CharacterSheet before = _sheet()..inventory.add(_item('a', 'Pistola'));
      final CharacterSheet after = _copy(before)
        ..inventory.add(_item('b', 'Giacca corazzata', weight: 7))
        ..inventory.removeWhere((InventoryEntry i) => i.id == 'a');

      final SheetDiff diff = _compare(before, after);

      final DiffRow jacket = _row(diff, 'Inventario', 'Giacca corazzata');
      expect(jacket.state, DiffState.added);
      expect(jacket.before, isNull);
      expect(jacket.after, isNotNull);

      final DiffRow pistol = _row(diff, 'Inventario', 'Pistola');
      expect(pistol.state, DiffState.removed);
      expect(pistol.after, isNull);
    });

    test('la quantita cambiata si legge nella riga', () {
      final CharacterSheet before = _sheet()..inventory.add(_item('a', 'Munizioni', quantity: 20));
      final CharacterSheet after = _copy(before)
        ..inventory.first.quantity = 50;

      final DiffRow row = _row(_compare(before, after), 'Inventario', 'Munizioni');

      expect(row.before, '×20 · scritto a mano');
      expect(row.after, '×50 · scritto a mano');
      expect(row.state, DiffState.changed);
    });

    test('equipaggiare un oggetto e una differenza', () {
      final CharacterSheet before = _sheet()..inventory.add(_item('a', 'Giacca corazzata'));
      final CharacterSheet after = _copy(before)
        ..inventory.first.isEquipped = true;

      final DiffRow row = _row(_compare(before, after), 'Inventario', 'Giacca corazzata');

      expect(row.before, '×1 · scritto a mano');
      expect(row.after, '×1 · equipaggiato · scritto a mano');
      expect(row.state, DiffState.changed);
    });

    test("l'ordine dell'elenco non e' una differenza", () {
      // Spostare una riga in fondo all'inventario e' il tipo di modifica che
      // nessuno considera una modifica. Con gli indici come chiave, il
      // confronto la segnalerebbe: qui no.
      final CharacterSheet before = _sheet()
        ..inventory.add(_item('a', 'Pistola'))
        ..inventory.add(_item('b', 'Giacca'));

      final CharacterSheet after = _copy(before);
      after.inventory.insert(0, after.inventory.removeAt(1));

      final SheetDiff diff = _compare(before, after);

      expect(_group(diff, 'Inventario').changes, 0);
      expect(diff.changes, 0);
    });

    test('punteggiatura diversa nello stesso nome non crea due voci', () {
      // E' il caso vero: una scheda vecchia scrive "Armorjack leggero !", il
      // catalogo dice "Armorjack leggero". Sono lo stesso oggetto.
      // Identificativi diversi e nome diverso: quello che le unisce e' il nome
      // *normalizzato*, che e' l'unica cosa che l'utente riconosce.
      final CharacterSheet before = _sheet()..inventory.add(_item('a', 'Armorjack leggero !'));
      final CharacterSheet after = _sheet()..inventory.add(_item('b', 'armorjack  leggero'));

      final SheetDiff diff = _compare(before, after);

      expect(_group(diff, 'Inventario').rows.length, 1);
      expect(_group(diff, 'Inventario').changes, 0);
    });

    test('due voci con lo stesso nome si contano', () {
      final CharacterSheet before = _sheet()..inventory.add(_item('a', 'Granata'));
      final CharacterSheet after = _copy(before)
        ..inventory.add(_item('b', 'Granata'));

      final DiffRow row = _row(_compare(before, after), 'Inventario', 'Granata');

      expect(row.state, DiffState.changed);
      expect(row.detail, 'voci: 1 → 2');
      expect(row.note, contains('stesso nome'));
    });
  });

  group('cyberware, effetti e valori calcolati', () {
    test('un impianto nuovo cambia anche i valori calcolati', () {
      final CharacterSheet before = _sheet();
      before.statBase[Stat.empathy] = 6;
      before.identity.currentHumanity = 60;

      final CharacterSheet after = _copy(before);
      after.cyberware.add(
        Cyberware(
          id: 'cw-1',
          name: 'Interfaccia Neurale',
          category: CyberwareCategory.neuralware,
          humanityLost: 7,
          isFoundational: true,
        ),
      );

      final SheetDiff diff = _compare(before, after);

      final DiffRow implant = _row(diff, 'Cyberware', 'Interfaccia Neurale');
      expect(implant.state, DiffState.added);
      expect(implant.after, contains('Neuralware'));
      expect(implant.after, contains('7 umanita'));

      // L'umanita' persa e' un valore calcolato: chi legge il confronto deve
      // vedere *perche* e' cambiata senza doverlo dedurre.
      expect(_row(diff, 'Valori calcolati', 'Umanita persa').after, '7');
    });

    test('un effetto disattivato resta una differenza', () {
      final CharacterSheet before = _sheet();
      before.effects.add(Effect(id: 'e-1', name: 'Veleno', intensity: 2, isActive: true));

      final CharacterSheet after = _copy(before);
      after.effects.first.isActive = false;

      final DiffRow row = _row(_compare(before, after), 'Effetti', 'Veleno');

      expect(row.before, contains('attivo'));
      expect(row.after, contains('archiviato'));
      expect(row.state, DiffState.changed);
    });
  });

  group('testi', () {
    test('una nota cambiata si vede, con la lunghezza dichiarata', () {
      final String long = 'x' * 200;
      final CharacterSheet before = _sheet()
        ..notes.add(Note(id: 'n-1', title: 'Piano', content: 'Entrare dal tetto'));
      final CharacterSheet after = _copy(before);

      final SheetDiff shortDiff = _compare(before, after);
      expect(_row(shortDiff, 'Note', 'Piano').state, DiffState.unchanged);

      after.notes.first.content = long;
      final DiffRow row = _row(_compare(before, after), 'Note', 'Piano');

      expect(row.state, DiffState.changed);
      expect(row.after!.length, lessThan(100));
      expect(row.after, endsWith('…'));
      expect(row.note, contains('200 caratteri'));
    });

    test('un campo svuotato e un campo mai compilato si distinguono', () {
      final CharacterSheet before = _sheet()..background.personality = 'Diretto';
      final CharacterSheet after = _copy(before)..background.personality = '';

      final DiffRow row = _row(_compare(before, after), 'Background', 'Personalita');

      // "(vuoto)" e non "—": il campo esiste ed e' stato svuotato, che e' una
      // cosa diversa da un campo mai compilato.
      expect(row.before, 'Diretto');
      expect(row.after, '(vuoto)');
      expect(row.state, DiffState.changed);
    });

    test("l'immagine si confronta per presenza, non per percorso", () {
      final CharacterSheet before = _sheet();
      before.physical.imagePath = '/Users/tia/Immagini/ritratto.png';

      final CharacterSheet after = _copy(before);
      after.physical.imagePath = '/home/marco/ritratti/ritratto.png';

      final SheetDiff diff = _compare(before, after);

      // Stessa immagine su due computer: il percorso cambia, la scheda no.
      expect(_row(diff, 'Descrizione fisica', 'Immagine').state, DiffState.unchanged);

      after.physical.imagePath = null;
      expect(
        _row(_compare(before, after), 'Descrizione fisica', 'Immagine').state,
        DiffState.changed,
      );
    });

    test('un amico in piu e una storia tragica tolt', () {
      final CharacterSheet before = _sheet()
        ..background.friends.add(Friend(id: 'f-1', name: 'Kerry'))
        ..background.tragicStories.add(TragicStory(id: 't-1', name: 'Il fratello'));

      final CharacterSheet after = _copy(before)
        ..background.friends.add(Friend(id: 'f-2', name: 'Rogue'))
        ..background.tragicStories.clear();

      final SheetDiff diff = _compare(before, after);

      expect(_row(diff, 'Background', 'Rogue').state, DiffState.added);
      expect(_row(diff, 'Background', 'Il fratello').state, DiffState.removed);
      expect(_row(diff, 'Background', 'Kerry').state, DiffState.unchanged);
    });
  });

  group('filtro delle sezioni', () {
    test('la vista "solo differenze" toglie le righe identiche e le sezioni vuote', () {
      final CharacterSheet before = _sheet();
      final CharacterSheet after = _copy(before);
      after.identity.tag = 'Jackie Nova';

      final SheetDiff diff = _compare(before, after);
      final List<DiffGroup> only = diff.groupsWith(onlyDifferences: true);

      expect(only.length, 1);
      expect(only.single.title, 'Personaggio');
      expect(only.single.rows.length, 1);
      expect(only.single.rows.single.label, 'Nome del personaggio');
      expect(only.single.rows.single.after, 'Jackie Nova');

      // La vista "tutto" conserva anche quello che non e' cambiato.
      final DiffGroup full =
          diff.groupsWith(onlyDifferences: false).firstWhere((DiffGroup g) => g.title == 'Personaggio');
      expect(full.rows.length, greaterThan(1));
    });
  });
}

DiffGroup _group(SheetDiff diff, String title) =>
    diff.groups.firstWhere((DiffGroup g) => g.title == title);
