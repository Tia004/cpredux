import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/typography.dart';
import '../../domain/sheet.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';

/// Note della scheda.
///
/// Le note sono un elenco e non un unico campo di testo: in gioco si scrivono
/// appunti di natura diversa ("piano del colpo", "chi mi deve dei soldi",
/// "codici del fixer"), e tenerli tutti in un blocco unico significa perderli
/// dentro un muro di testo. Ogni nota si intitola e si ritrova.
class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  int? _expanded;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet;
    if (sheet == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ChamferPanel(
            title: 'Note',
            accent: CprPalette.yellow,
            trailing: TechButton(
              label: 'Nuova nota',
              icon: Icons.add,
              variant: TechButtonVariant.primary,
              compact: true,
              onPressed: () => _addNote(state),
            ),
            child: sheet.notes.isEmpty
                ? const TechWell(
                    child: Text(
                      'Nessuna nota.\n\nLe note sono appunti liberi: un piano, un nome, un debito.'
                      ' Restano dentro la scheda e non vengono toccati dal calcolo dei valori.',
                      style: TextStyle(color: CprPalette.inkFaint, height: 1.6),
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (int i = 0; i < sheet.notes.length; i++)
                        _NoteTile(
                          key: ValueKey<String>(sheet.notes[i].id),
                          note: sheet.notes[i],
                          expanded: _expanded == i,
                          onToggle: () => setState(() => _expanded = _expanded == i ? null : i),
                          onDelete: () => _deleteNote(state, i),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _addNote(AppState state) async {
    final String id = 'note-${DateTime.now().microsecondsSinceEpoch}';
    state.mutate((s) {
      s.notes.insert(
        0,
        Note(id: id, title: '', content: '', createdAt: AppState.now(), updatedAt: AppState.now()),
      );
    });
    setState(() => _expanded = 0);
  }

  Future<void> _deleteNote(AppState state, int index) async {
    final bool confirmed = await showTechConfirm(
      context,
      title: 'Eliminare la nota?',
      message: "La nota verra' rimossa dalla scheda. Il salvataggio automatico la "
          "rendera' definitiva al prossimo salvataggio.",
      confirmLabel: 'Elimina',
      danger: true,
    );
    if (!confirmed) return;
    state.mutate((s) => s.notes.removeAt(index));
    setState(() => _expanded = null);
  }
}

class _NoteTile extends StatefulWidget {
  const _NoteTile({
    super.key,
    required this.note,
    required this.expanded,
    required this.onToggle,
    required this.onDelete,
  });

  final Note note;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  State<_NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<_NoteTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final String title = widget.note.title.trim().isEmpty
        ? (widget.note.content.trim().isEmpty
            ? 'Nota senza titolo'
            : widget.note.content.trim().split('\n').first)
        : widget.note.title;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: widget.expanded ? CprPalette.surfaceSunken : Colors.transparent,
          border: Border(
            left: BorderSide(
              width: 2,
              color: widget.expanded || _hover ? CprPalette.yellow : CprPalette.hairline,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 9, 8, 9),
                  child: Row(
                    children: <Widget>[
                      AnimatedRotation(
                        duration: CprMotion.fast,
                        turns: widget.expanded ? 0.25 : 0,
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: widget.expanded ? CprPalette.yellow : CprPalette.inkFaint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: CprType.body.copyWith(
                            color: widget.note.title.trim().isEmpty
                                ? CprPalette.inkFaint
                                : CprPalette.ink,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (_hover)
                        TechButton(
                          label: '',
                          icon: Icons.delete_outline,
                          variant: TechButtonVariant.ghost,
                          compact: true,
                          tooltip: 'Elimina nota',
                          onPressed: widget.onDelete,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedCrossFade(
              duration: CprMotion.normal,
              crossFadeState:
                  widget.expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 12),
                child: Column(
                  children: <Widget>[
                    TechField(
                      label: 'Titolo',
                      value: widget.note.title,
                      hint: 'Piano del colpo',
                      onChanged: (String v) => state.mutate((s) => widget.note.title = v),
                    ),
                    const SizedBox(height: 10),
                    TechTextArea(
                      label: 'Contenuto',
                      value: widget.note.content,
                      lines: 7,
                      hint: 'Scrivi qui…',
                      onChanged: (String v) => state.mutate((s) => widget.note.content = v),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Background: il "Lifepath" del regolamento.
///
/// E' organizzato in due colonne di blocchi invece che in un'unica lista di
/// campi: il lifepath si compila "per famiglia di domande" (chi sei, cosa
/// possiedi, chi ti vuole male), e raggrupparli rende evidente cosa manca
/// invece di lasciare una sfilza di caselle tutte uguali.
class BackgroundTab extends StatelessWidget {
  const BackgroundTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet;
    if (sheet == null) return const SizedBox.shrink();
    final Background bg = sheet.background;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final Widget left = Column(
                    children: <Widget>[
                      _Block(
                        title: 'Chi sei',
                        accent: CprPalette.yellow,
                        children: <Widget>[
                          _Field(bg.culturalOrigins, 'Origini culturali',
                              (String v) => bg.culturalOrigins = v, state),
                          _Field(bg.personality, "Personalita'", (String v) => bg.personality = v, state),
                          _Field(bg.favouriteClothingStyle, 'Stile di abbigliamento preferito',
                              (String v) => bg.favouriteClothingStyle = v, state),
                          _Field(bg.favouriteHairStyle, 'Taglio di capelli preferito',
                              (String v) => bg.favouriteHairStyle = v, state),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Block(
                        title: 'Cosa conta per te',
                        accent: CprPalette.cyan,
                        children: <Widget>[
                          _Field(bg.whatDoYouValueMost, "Cosa apprezzi di piu'",
                              (String v) => bg.whatDoYouValueMost = v, state),
                          _Field(bg.feelingsAboutPeople, 'Cosa pensi delle persone',
                              (String v) => bg.feelingsAboutPeople = v, state),
                          _Field(bg.mostValuedPerson, "Persona piu' importante",
                              (String v) => bg.mostValuedPerson = v, state),
                          _Field(bg.mostValuedPossession, "Possesso piu' importante",
                              (String v) => bg.mostValuedPossession = v, state),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Block(
                        title: 'Famiglia',
                        accent: CprPalette.violet,
                        children: <Widget>[
                          _Field(bg.familyBackground, 'Background familiare',
                              (String v) => bg.familyBackground = v, state),
                          _Field(bg.childhoodEnvironment, "Ambiente dell'infanzia",
                              (String v) => bg.childhoodEnvironment = v, state),
                          _Field(bg.familyCrisis, 'Crisi familiare',
                              (String v) => bg.familyCrisis = v, state),
                        ],
                      ),
                    ],
                  );

                  final Widget right = Column(
                    children: <Widget>[
                      _Block(
                        title: 'Dove vivi',
                        accent: CprPalette.success,
                        children: <Widget>[
                          _Field(bg.housing, 'Abitazione', (String v) => bg.housing = v, state),
                          _Field(bg.housingRent, 'Affitto', (String v) => bg.housingRent = v, state),
                          _Field(bg.lifestyle, 'Stile di vita', (String v) => bg.lifestyle = v, state),
                          _Field(bg.lifestyleCost, 'Costo dello stile di vita',
                              (String v) => bg.lifestyleCost = v, state),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Block(
                        title: 'Dove stai andando',
                        accent: CprPalette.warning,
                        children: <Widget>[
                          _Field(bg.lifeGoals, 'Obiettivi di vita', (String v) => bg.lifeGoals = v,
                              state, lines: 3),
                          _Field(bg.reputationEvents, 'Eventi di reputazione',
                              (String v) => bg.reputationEvents = v, state, lines: 3),
                          _Field(bg.roleSpecificLifepath, 'Lifepath di ruolo',
                              (String v) => bg.roleSpecificLifepath = v, state, lines: 3),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _Block(
                        title: 'Vecchie conoscenze',
                        accent: CprPalette.inkMuted,
                        children: <Widget>[
                          _Field(sheet.oldConnections, 'Contatti e conoscenze',
                              (String v) => sheet.oldConnections = v, state, lines: 4),
                        ],
                      ),
                    ],
                  );

                  if (c.maxWidth < 900) {
                    return Column(children: <Widget>[left, const SizedBox(height: 14), right]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: left),
                      const SizedBox(width: 14),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              _Relations(
                title: 'Amici',
                accent: CprPalette.success,
                icon: Icons.person_outline,
                addLabel: 'Aggiungi amico',
                names: <String>[for (final Friend f in bg.friends) f.name],
                hint: 'Chip',
                onAdd: () => bg.friends.add(
                  Friend(id: 'friend-${DateTime.now().microsecondsSinceEpoch}', name: ''),
                ),
                onRename: (int i, String v) => bg.friends[i].name = v,
                onRemove: (int i) => bg.friends.removeAt(i),
                state: state,
              ),
              const SizedBox(height: 14),
              _Relations(
                title: 'Storie tragiche',
                accent: CprPalette.warning,
                icon: Icons.menu_book_outlined,
                addLabel: 'Aggiungi storia',
                names: <String>[for (final TragicStory t in bg.tragicStories) t.name],
                hint: 'Titolo',
                onAdd: () => bg.tragicStories.add(
                  TragicStory(id: 'story-${DateTime.now().microsecondsSinceEpoch}', name: ''),
                ),
                onRename: (int i, String v) => bg.tragicStories[i].name = v,
                onRemove: (int i) => bg.tragicStories.removeAt(i),
                state: state,
              ),
              const SizedBox(height: 14),
              _Enemies(state: state, enemies: bg.enemies),
            ],
          ),
        ),
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.accent, required this.children});

  final String title;
  final Color accent;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: title,
      accent: accent,
      child: Column(
        children: <Widget>[
          for (int i = 0; i < children.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.value, this.label, this.setter, this.state, {this.lines = 1});

  final String value;
  final String label;
  final void Function(String) setter;
  final AppState state;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return TechField(
      label: label,
      value: value,
      maxLines: lines,
      onChanged: (String v) => state.mutate((_) => setter(v)),
    );
  }
}

class _Relations extends StatelessWidget {
  const _Relations({
    required this.title,
    required this.accent,
    required this.icon,
    required this.addLabel,
    required this.names,
    required this.hint,
    required this.onAdd,
    required this.onRename,
    required this.onRemove,
    required this.state,
  });

  final String title;
  final Color accent;
  final IconData icon;
  final String addLabel;
  final List<String> names;
  final String hint;
  final VoidCallback onAdd;
  final void Function(int, String) onRename;
  final void Function(int) onRemove;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: title,
      accent: accent,
      trailing: TechButton(
        label: addLabel,
        icon: Icons.add,
        variant: TechButtonVariant.secondary,
        compact: true,
        onPressed: () => state.mutate((_) => onAdd()),
      ),
      child: names.isEmpty
          ? Text(
              'Nessuna voce.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            )
          : Column(
              children: <Widget>[
                for (int i = 0; i < names.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: <Widget>[
                        Icon(icon, size: 15, color: accent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: '',
                            value: names[i],
                            hint: hint,
                            accent: accent,
                            onChanged: (String v) => state.mutate((_) => onRename(i, v)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TechButton(
                          label: '',
                          icon: Icons.close,
                          variant: TechButtonVariant.ghost,
                          compact: true,
                          tooltip: 'Rimuovi',
                          onPressed: () => state.mutate((_) => onRemove(i)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// I nemici hanno quattro campi ciascuno, non un nome: nel lifepath sono una
/// scheda dentro la scheda ("chi e', cosa ha causato il conflitto, cosa puo'
/// lanciarti addosso, cosa succedera'"), e ridurli a una riga sola
/// costringerebbe a ricordare a memoria il resto.
class _Enemies extends StatelessWidget {
  const _Enemies({required this.state, required this.enemies});

  final AppState state;
  final List<Enemy> enemies;

  @override
  Widget build(BuildContext context) {
    return ChamferPanel(
      title: 'Nemici',
      accent: CprPalette.danger,
      trailing: TechButton(
        label: 'Aggiungi nemico',
        icon: Icons.add,
        variant: TechButtonVariant.secondary,
        compact: true,
        onPressed: () => state.mutate(
          (_) => enemies.add(Enemy(id: 'enemy-${DateTime.now().microsecondsSinceEpoch}')),
        ),
      ),
      child: enemies.isEmpty
          ? Text('Nessun nemico. Goditi la quiete.',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint))
          : Column(
              children: <Widget>[
                for (int i = 0; i < enemies.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    color: CprPalette.surfaceSunken,
                    child: Column(
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(width: 3, height: 14, color: CprPalette.danger),
                            const SizedBox(width: 8),
                            Text('NEMICO ${i + 1}',
                                style: CprType.label.copyWith(color: CprPalette.danger, fontSize: 10)),
                            const Spacer(),
                            TechButton(
                              label: '',
                              icon: Icons.close,
                              variant: TechButtonVariant.ghost,
                              compact: true,
                              tooltip: 'Rimuovi',
                              onPressed: () => state.mutate((_) => enemies.removeAt(i)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _Field(enemies[i].who, "Chi e'",
                            (String v) => enemies[i].who = v, state),
                        const SizedBox(height: 10),
                        _Field(enemies[i].whatCausedIt, 'Cosa ha causato il conflitto',
                            (String v) => enemies[i].whatCausedIt = v, state, lines: 2),
                        const SizedBox(height: 10),
                        _Field(enemies[i].whatCanTheyThrowAtYou, "Cosa puo' lanciarti addosso",
                            (String v) => enemies[i].whatCanTheyThrowAtYou = v, state, lines: 2),
                        const SizedBox(height: 10),
                        _Field(enemies[i].whatsGonnaHappen, "Cosa succedera'",
                            (String v) => enemies[i].whatsGonnaHappen = v, state, lines: 2),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Descrizione fisica: anagrafica e ritratto.
class DescriptionTab extends StatefulWidget {
  const DescriptionTab({super.key});

  @override
  State<DescriptionTab> createState() => _DescriptionTabState();
}

class _DescriptionTabState extends State<DescriptionTab> {
  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet;
    if (sheet == null) return const SizedBox.shrink();
    final PhysicalDescription ph = sheet.physical;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) {
              final Widget portrait = _Portrait(state: state, path: ph.imagePath);
              final Widget form = ChamferPanel(
                title: 'Anagrafica',
                accent: CprPalette.cyan,
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechField(
                            label: "Eta'",
                            value: ph.age,
                            onChanged: (String v) => state.mutate((_) => ph.age = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: 'Altezza',
                            value: ph.height,
                            onChanged: (String v) => state.mutate((_) => ph.height = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: 'Peso',
                            value: ph.weight,
                            onChanged: (String v) => state.mutate((_) => ph.weight = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TechField(
                            label: 'Occhi',
                            value: ph.eyes,
                            onChanged: (String v) => state.mutate((_) => ph.eyes = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: 'Cute',
                            value: ph.skin,
                            onChanged: (String v) => state.mutate((_) => ph.skin = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TechField(
                            label: 'Capelli',
                            value: ph.hair,
                            onChanged: (String v) => state.mutate((_) => ph.hair = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TechTextArea(
                      label: 'Descrizione',
                      value: ph.description,
                      lines: 6,
                      hint: 'Cicatrici, tatuaggi, modo di vestire…',
                      onChanged: (String v) => state.mutate((_) => ph.description = v),
                    ),
                  ],
                ),
              );

              if (c.maxWidth < 860) {
                return Column(children: <Widget>[portrait, const SizedBox(height: 16), form]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(width: 320, child: portrait),
                  const SizedBox(width: 16),
                  Expanded(child: form),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Ritratto del personaggio.
///
/// Il percorso dell'immagine viene salvato **relativo** quando possibile: una
/// scheda che punta a `/Users/tizio/Desktop/ritratto.png` si rompe appena
/// viene aperta su un altro computer, e una scheda condivisa con il master e'
/// esattamente il caso d'uso di questa applicazione.
class _Portrait extends StatelessWidget {
  const _Portrait({required this.state, required this.path});

  final AppState state;
  final String? path;

  Future<void> _choose(BuildContext context) async {
    final String? picked = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Scegli il ritratto',
      extensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
      initialDirectory: state.documentPath == null
          ? null
          : p.dirname(state.documentPath!),
      description: 'Immagini',
      showAllFilesToggle: true,
    );
    if (picked == null) return;

    // Il percorso viene salvato **relativo** quando l'immagine sta accanto al
    // documento, cosi' spostare la scheda (o passarla al master) porta con se'
    // il ritratto. Se l'immagine e' altrove resta un percorso assoluto: e'
    // meglio un riferimento che si rompe di un file copiato a nostra insaputa.
    state.mutate((s) => s.physical.imagePath = _relativise(picked, state));
  }

  String _relativise(String picked, AppState state) {
    final String? doc = state.documentPath;
    if (doc == null) return picked;
    final String dir = p.dirname(doc);
    if (!p.isWithin(dir, picked)) return picked;
    return p.relative(picked, from: dir);
  }

  @override
  Widget build(BuildContext context) {
    final String? stored = path;
    final File? file = stored == null ? null : _resolve(stored, state);
    final bool exists = file != null && file.existsSync();

    return ChamferPanel(
      title: 'Ritratto',
      accent: CprPalette.cyan,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              color: CprPalette.surfaceSunken,
              child: exists
                  ? Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(height: 12),
          TechButton(
            label: exists ? 'Cambia immagine' : 'Carica immagine',
            icon: Icons.image_outlined,
            variant: TechButtonVariant.secondary,
            onPressed: () => _choose(context),
          ),
          if (exists) ...<Widget>[
            const SizedBox(height: 8),
            TechButton(
              label: 'Rimuovi',
              icon: Icons.delete_outline,
              variant: TechButtonVariant.ghost,
              onPressed: () => state.mutate((s) => s.physical.imagePath = null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const Icon(Icons.person_outline, size: 42, color: CprPalette.inkFaint),
          const SizedBox(height: 10),
          Text(
            'Nessuna immagine',
            style: CprType.caption.copyWith(color: CprPalette.inkFaint),
          ),
        ],
      ),
    );
  }

  /// Risolve il percorso salvato rispetto alla cartella del documento.
  File _resolve(String stored, AppState state) {
    if (p.isAbsolute(stored)) return File(stored);
    final String? doc = state.documentPath;
    if (doc == null) return File(stored);
    return File(p.normalize(p.join(p.dirname(doc), stored)));
  }
}
