import 'dart:io';

import 'package:flutter/material.dart';

import '../../design/palette.dart';
import '../../design/rarity_color.dart';
import '../../design/typography.dart';
import '../../domain/catalog_item.dart';
import '../../domain/cyberware.dart';
import '../../domain/effects.dart';
import '../../domain/enums.dart';
import '../../domain/items.dart';
import '../../domain/modifiers.dart';
import '../../domain/skills.dart';
import '../../domain/stats.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../files/file_browser.dart';

String _newId(String prefix) => '$prefix-${DateTime.now().microsecondsSinceEpoch}';

/// Apre l'editor di un oggetto. Restituisce `null` se l'utente annulla.
/// Apre l'editor delle **personalizzazioni** di una voce di catalogo.
///
/// Si modificano solo i campi che servono, e solo per questa scheda: il catalogo
/// resta la base condivisa. Ogni campo mostra qual e' il valore di catalogo e si
/// puo' riportare a quello, e un campo lasciato identico **non viene salvato**
/// come personalizzazione: cosi' la voce continua a seguire gli aggiornamenti
/// del catalogo.
Future<ItemOverride?> showItemOverrideEditor(
  BuildContext context, {
  required ResolvedItem item,
}) {
  return showDialog<ItemOverride>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.75),
    builder: (BuildContext context) => _ItemOverrideEditor(item: item),
  );
}

/// Apre l'editor completo di un oggetto **creato a mano**.
///
/// Serve per gli oggetti che nel catalogo non ci sono e non ci saranno: qui si
/// definisce tutto, e la definizione resta dentro la scheda perche' e' l'unica
/// copia che esiste.
Future<CatalogItem?> showCustomItemEditor(BuildContext context, {ResolvedItem? existing}) {
  return showDialog<CatalogItem>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.75),
    builder: (BuildContext context) => _CustomItemEditor(existing: existing),
  );
}
/// Apre l'editor di un impianto cyberware.
Future<Cyberware?> showCyberwareEditor(
  BuildContext context, {
  Cyberware? existing,
  List<Cyberware> allInstalled = const <Cyberware>[],
  String? initialBodyZone,
  String? initialParentFoundationId,
}) {
  return showDialog<Cyberware>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => _CyberwareEditor(
      existing: existing,
      allInstalled: allInstalled,
      initialBodyZone: initialBodyZone,
      initialParentFoundationId: initialParentFoundationId,
    ),
  );
}

/// Apre l'editor di un effetto.
Future<Effect?> showEffectEditor(BuildContext context, {Effect? existing}) {
  return showDialog<Effect>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.7),
    builder: (BuildContext context) => _EffectEditor(existing: existing),
  );
}

/// Struttura comune degli editor: intestazione, corpo scorrevole, azioni.
class _EditorFrame extends StatelessWidget {
  const _EditorFrame({
    required this.title,
    required this.accent,
    required this.children,
    required this.onSave,
    this.saveLabel = 'Salva',
    this.saveEnabled = true,
    this.width = 660,
  });

  final String title;
  final Color accent;
  final List<Widget> children;
  final VoidCallback onSave;
  final String saveLabel;
  final bool saveEnabled;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CprPalette.surface,
      shape: const RoundedRectangleBorder(),
      insetPadding: const EdgeInsets.all(32),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: CprPalette.hairline)),
              ),
              child: Row(
                children: <Widget>[
                  Container(width: 3, height: 15, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title.toUpperCase(),
                      style: CprType.label.copyWith(color: accent, fontSize: 12),
                    ),
                  ),
                  TechButton(
                    label: '',
                    icon: Icons.close,
                    variant: TechButtonVariant.ghost,
                    compact: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: CprPalette.hairline)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TechButton(
                    label: 'Annulla',
                    variant: TechButtonVariant.ghost,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 10),
                  TechButton(
                    label: saveLabel,
                    icon: Icons.check,
                    variant: TechButtonVariant.primary,
                    onPressed: saveEnabled ? onSave : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Riga etichetta + campo, per non ripetere il layout in ogni editor.
class _Row2 extends StatelessWidget {
  const _Row2({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _ItemOverrideEditor extends StatefulWidget {
  const _ItemOverrideEditor({required this.item});

  final ResolvedItem item;

  @override
  State<_ItemOverrideEditor> createState() => _ItemOverrideEditorState();
}

/// Editor delle personalizzazioni.
///
/// La regola che lo governa: un campo **identico al catalogo non e' una
/// personalizzazione**. Non e' un dettaglio estetico — e' cio' che permette a
/// una correzione futura del catalogo di arrivare su questa scheda. Se ogni
/// salvataggio copiasse tutti i valori, la scheda si aggancerebbe al catalogo
/// solo di nome.
class _ItemOverrideEditorState extends State<_ItemOverrideEditor> {
  late final ItemOverride _draft = widget.item.overrides.copy();

  CatalogItem? get _base => widget.item.catalog;

  String get _name => _draft.name ?? _base?.name ?? widget.item.name;
  String get _description => _draft.description ?? _base?.description ?? '';
  int get _cost => _draft.cost ?? _base?.cost ?? 0;
  double get _weight => _draft.weight ?? _base?.weight ?? 0;
  Rarity get _rarity => _draft.rarity ?? _base?.rarity ?? Rarity.common;
  String? get _imagePath => _draft.imagePath;
  String? get _damage => _draft.damage ?? _base?.weapon?.damage;

  Future<void> _pickImage() async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Immagine dell oggetto',
      extensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
      description: 'L immagine resta nella scheda, non nel catalogo',
      showAllFilesToggle: true,
    );
    if (path != null) setState(() => _draft.imagePath = path);
  }

  @override
  Widget build(BuildContext context) {
    final CatalogItem? base = _base;

    return _EditorFrame(
      title: 'Personalizza ${widget.item.name}',
      accent: CprPalette.cyan,
      saveLabel: 'Salva',
      onSave: () => Navigator.of(context).pop(_draft),
      children: <Widget>[
        if (base != null)
          _CatalogNote(
            text: 'Stai modificando una voce di catalogo solo dentro questa scheda. '
                '${_draft.count == 0 ? "Non hai ancora cambiato nulla." : "${_draft.count} campi personalizzati."}',
          ),
        const SizedBox(height: 14),
        _OverrideField(
          label: 'Nome',
          isOverridden: _draft.name != null,
          catalogValue: base?.name,
          onReset: () => setState(() => _draft.name = null),
          child: TechField(
            label: '',
            value: _name,
            onChanged: (String v) =>
                setState(() => _draft.name = v.trim() == (base?.name ?? '') ? null : v),
          ),
        ),
        const SizedBox(height: 12),
        _Row2(
          left: _OverrideField(
            label: 'Costo (eb)',
            isOverridden: _draft.cost != null,
            catalogValue: base == null ? null : '${base.cost}',
            onReset: () => setState(() => _draft.cost = null),
            child: TechNumberStepper(
              label: '',
              value: _cost,
              max: 999999,
              accent: CprPalette.cyan,
              onChanged: (int v) =>
                  setState(() => _draft.cost = v == (base?.cost ?? 0) ? null : v),
            ),
          ),
          right: _OverrideField(
            label: 'Rarita',
            isOverridden: _draft.rarity != null,
            catalogValue: base?.rarity.label,
            onReset: () => setState(() => _draft.rarity = null),
            child: TechDropdown<Rarity>(
              label: '',
              value: _rarity,
              items: Rarity.values,
              labelOf: (Rarity r) => r.label,
              colorOf: (Rarity r) => r.color,
              accent: CprPalette.cyan,
              onChanged: (Rarity r) =>
                  setState(() => _draft.rarity = r == (base?.rarity ?? Rarity.common) ? null : r),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _OverrideField(
          label: 'Peso per unita (kg)',
          isOverridden: _draft.weight != null,
          catalogValue: base?.weight.toStringAsFixed(2),
          onReset: () => setState(() => _draft.weight = null),
          child: TechField(
            label: '',
            value: _weight.toStringAsFixed(2),
            numeric: true,
            onChanged: (String v) {
              final double? parsed = double.tryParse(v.replaceAll(',', '.'));
              if (parsed == null) return;
              setState(() => _draft.weight =
                  (parsed - (base?.weight ?? 0)).abs() < 0.001 ? null : parsed);
            },
          ),
        ),
        if (widget.item.isWeapon) ...<Widget>[
          const SizedBox(height: 12),
          _OverrideField(
            label: 'Danno',
            isOverridden: _draft.damage != null,
            catalogValue: base?.weapon?.damage,
            onReset: () => setState(() => _draft.damage = null),
            child: TechField(
              label: '',
              value: _damage ?? '',
              hint: '3d6',
              onChanged: (String v) => setState(
                () => _draft.damage = v.trim() == (base?.weapon?.damage ?? '') ? null : v.trim(),
              ),
            ),
          ),
        ],
        if (widget.item.isArmor) ...<Widget>[
          const SizedBox(height: 12),
          _Row2(
            left: _OverrideField(
              label: 'Protezione (SP)',
              isOverridden: _draft.sp != null,
              catalogValue: base?.armor == null ? null : '${base!.armor!.sp}',
              onReset: () => setState(() => _draft.sp = null),
              child: TechNumberStepper(
                label: '',
                value: _draft.sp ?? base?.armor?.sp ?? 0,
                max: 30,
                accent: CprPalette.cyan,
                onChanged: (int v) =>
                    setState(() => _draft.sp = v == (base?.armor?.sp ?? 0) ? null : v),
              ),
            ),
            right: _OverrideField(
              label: 'Penalita',
              isOverridden: _draft.penalties != null,
              catalogValue: base?.armor == null ? null : '${base!.armor!.penalties}',
              onReset: () => setState(() => _draft.penalties = null),
              child: TechNumberStepper(
                label: '',
                value: _draft.penalties ?? base?.armor?.penalties ?? 0,
                max: 20,
                accent: CprPalette.cyan,
                onChanged: (int v) => setState(
                  () => _draft.penalties = v == (base?.armor?.penalties ?? 0) ? null : v,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TechTextArea(
          label: 'Descrizione',
          value: _description,
          lines: 3,
          hint: base?.description ?? '',
          accent: CprPalette.cyan,
          onChanged: (String v) => setState(
            () => _draft.description =
                v.trim() == (base?.description ?? '') ? null : v,
          ),
        ),
        const SizedBox(height: 14),
        _ImageRow(
          path: _imagePath,
          onPick: _pickImage,
          onClear: () => setState(() => _draft.imagePath = null),
        ),
        if (_draft.count > 0) ...<Widget>[
          const SizedBox(height: 14),
          TechButton(
            label: 'Ripristina tutti i valori di catalogo',
            icon: Icons.restart_alt,
            variant: TechButtonVariant.ghost,
            onPressed: () => setState(_draft.clear),
          ),
        ],
      ],
    );
  }
}

/// Una nota esplicativa dentro un editor.
class _CatalogNote extends StatelessWidget {
  const _CatalogNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      color: CprPalette.veil(CprPalette.cyan, 0.07),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.info_outline, size: 14, color: CprPalette.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo che sa di essere una personalizzazione.
///
/// Dice qual e' il valore di catalogo e offre di riportarcisi: senza questa
/// informazione l'utente non saprebbe se sta guardando il valore vero o uno che
/// ha cambiato mesi fa, ed e' la differenza fra uno strumento fidato e uno di
/// cui non ci si fida.
class _OverrideField extends StatelessWidget {
  const _OverrideField({
    required this.label,
    required this.isOverridden,
    required this.catalogValue,
    required this.onReset,
    required this.child,
  });

  final String label;
  final bool isOverridden;
  final String? catalogValue;
  final VoidCallback onReset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            if (label.isNotEmpty) ...<Widget>[
              Text(
                label.toUpperCase(),
                style: CprType.label.copyWith(
                  color: isOverridden ? CprPalette.warning : CprPalette.inkFaint,
                  fontSize: 9,
                ),
              ),
              if (isOverridden) ...<Widget>[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  color: CprPalette.veil(CprPalette.warning, 0.14),
                  child: Text(
                    'PERSONALIZZATO',
                    style: CprType.label.copyWith(color: CprPalette.warning, fontSize: 7.5),
                  ),
                ),
              ],
              const Spacer(),
              if (isOverridden && catalogValue != null)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: onReset,
                    child: Text(
                      'riporta a $catalogValue',
                      style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 8.5),
                    ),
                  ),
                ),
            ],
          ],
        ),
        if (label.isNotEmpty) const SizedBox(height: 5),
        child,
      ],
    );
  }
}

class _CustomItemEditor extends StatefulWidget {
  const _CustomItemEditor({this.existing});

  final ResolvedItem? existing;

  @override
  State<_CustomItemEditor> createState() => _CustomItemEditorState();
}

class _CustomItemEditorState extends State<_CustomItemEditor> {  /// La definizione di partenza: quella incorporata nella scheda per un
  /// oggetto creato a mano. Per una voce di catalogo il dialogo non si apre
  /// nemmeno (si usa l'editor delle personalizzazioni), quindi qui `base` e'
  /// sempre valorizzato.
  late final CatalogItem _base = widget.existing?.base ??
      CatalogItem(
        id: _newId('custom-item'),
        name: '',
        category: ItemCategory.item,
        source: 'custom',
      );

  late String _name = _base.name;
  late ItemCategory _category = _base.category;
  late Rarity _rarity = _base.rarity;
  late int _cost = _base.cost;
  late double _weight = _base.weight;
  late String _description = _base.description;
  late String? _imagePath = _base.imageAsset;

  late int _weaponSkill = _base.weapon?.skillId ?? Skill.handgun.id;
  late String _handsRequired = _base.weapon?.handsRequired ?? '1';
  late String _damage = _base.weapon?.damage ?? '';
  late int _maxAmmo = _base.weapon?.maxAmmo ?? 0;
  late int _rof = _base.weapon?.rof ?? 1;
  late bool _concealable = _base.weapon?.isConcealable ?? false;
  late String _weaponProperties = _base.weapon?.properties ?? '';

  late ArmorSlot _armorSlot = _base.armor?.slot ?? ArmorSlot.body;
  late int _sp = _base.armor?.sp ?? 0;
  late int _armorPenalties = _base.armor?.penalties ?? 0;

  late ClothingSlot _clothingSlot = _base.clothing?.slot ?? ClothingSlot.top;
  late ClothingStyle _clothingStyle = _base.clothing?.style ?? ClothingStyle.genericChic;

  Future<void> _pickImage() async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Immagine dell oggetto',
      extensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
      description: 'L immagine resta dentro la scheda',
      showAllFilesToggle: true,
    );
    if (path != null) setState(() => _imagePath = path);
  }

  void _save() {
    Navigator.of(context).pop(
      CatalogItem(
        id: _base.id,
        name: _name.trim().isEmpty ? 'Oggetto senza nome' : _name.trim(),
        category: _category,
        rarity: _rarity,
        cost: _cost,
        description: _description,
        weight: _weight,
        imageAsset: _imagePath,
        source: 'custom',
        weapon: _category == ItemCategory.weapon
            ? WeaponData(
                skillId: _weaponSkill,
                handsRequired: _handsRequired,
                damage: _damage,
                currentAmmo: 0,
                maxAmmo: _maxAmmo,
                rof: _rof,
                isConcealable: _concealable,
                properties: _weaponProperties,
              )
            : null,
        armor: _category == ItemCategory.armor
            ? ArmorData(slot: _armorSlot, sp: _sp, penalties: _armorPenalties)
            : null,
        clothing: _category == ItemCategory.clothing
            ? ClothingData(slot: _clothingSlot, style: _clothingStyle)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorFrame(
      title: widget.existing == null ? 'Nuovo oggetto personalizzato' : 'Modifica oggetto',
      accent: CprPalette.violet,
      saveLabel: widget.existing == null ? 'Crea' : 'Salva',
      onSave: _save,
      children: <Widget>[
        const _CatalogNote(
          text: 'Un oggetto che non e\' nel catalogo resta definito dentro la scheda, con tutti '
              'i suoi dati: e\' l\'unica copia che esiste, quindi non seguir? aggiornamenti.',
        ),
        const SizedBox(height: 14),
        TechField(
          label: 'Nome',
          value: _name,
          hint: 'Es. Malorian Arms 3516',
          accent: CprPalette.violet,
          onChanged: (String v) => setState(() => _name = v),
        ),
        const SizedBox(height: 12),
        _Row2(
          left: TechDropdown<ItemCategory>(
            label: 'Categoria',
            value: _category,
            items: ItemCategory.values,
            labelOf: (ItemCategory c) => c.label,
            accent: CprPalette.violet,
            onChanged: (ItemCategory c) => setState(() => _category = c),
          ),
          right: TechDropdown<Rarity>(
            label: 'Rarita',
            value: _rarity,
            items: Rarity.values,
            labelOf: (Rarity r) => r.label,
            colorOf: (Rarity r) => r.color,
            accent: CprPalette.violet,
            onChanged: (Rarity r) => setState(() => _rarity = r),
          ),
        ),
        const SizedBox(height: 12),
        _Row2(
          left: TechNumberStepper(
            label: 'Costo (eb)',
            value: _cost,
            max: 999999,
            accent: CprPalette.violet,
            onChanged: (int v) => setState(() => _cost = v),
          ),
          right: TechField(
            label: 'Peso per unita (kg)',
            value: _weight.toStringAsFixed(2),
            numeric: true,
            accent: CprPalette.violet,
            onChanged: (String v) {
              final double? parsed = double.tryParse(v.replaceAll(',', '.'));
              if (parsed != null) setState(() => _weight = parsed);
            },
          ),
        ),
        if (_category == ItemCategory.weapon) ...<Widget>[
          const _SectionLabel('Arma', CprPalette.violet),
          _Row2(
            left: TechDropdown<Skill>(
              label: 'Abilita',
              value: Skill.fromId(_weaponSkill) ?? Skill.handgun,
              items: Skill.values,
              labelOf: (Skill s) => s.name,
              accent: CprPalette.violet,
              onChanged: (Skill s) => setState(() => _weaponSkill = s.id),
            ),
            right: TechField(
              label: 'Danno',
              value: _damage,
              hint: '3d6',
              accent: CprPalette.violet,
              onChanged: (String v) => setState(() => _damage = v),
            ),
          ),
          const SizedBox(height: 12),
          _Row2(
            left: TechNumberStepper(
              label: 'Caricatore',
              value: _maxAmmo,
              max: 999,
              accent: CprPalette.violet,
              onChanged: (int v) => setState(() => _maxAmmo = v),
            ),
            right: TechNumberStepper(
              label: 'Cadenza di tiro',
              value: _rof,
              min: 1,
              max: 10,
              accent: CprPalette.violet,
              onChanged: (int v) => setState(() => _rof = v),
            ),
          ),
          const SizedBox(height: 12),
          _Row2(
            left: TechDropdown<String>(
              label: 'Mani',
              value: _handsRequired,
              items: const <String>['1', '2'],
              labelOf: (String v) => v == '2' ? 'Due mani' : 'Una mano',
              accent: CprPalette.violet,
              onChanged: (String v) => setState(() => _handsRequired = v),
            ),
            right: TechSegmented<bool>(
              value: _concealable,
              items: const <bool>[true, false],
              labelOf: (bool v) => v ? 'Nascondibile' : 'Visibile',
              accent: CprPalette.violet,
              onChanged: (bool v) => setState(() => _concealable = v),
            ),
          ),
          const SizedBox(height: 12),
          TechField(
            label: 'Proprieta',
            value: _weaponProperties,
            hint: 'Es. Puo essere usata in mischia',
            accent: CprPalette.violet,
            onChanged: (String v) => setState(() => _weaponProperties = v),
          ),
        ],
        if (_category == ItemCategory.armor) ...<Widget>[
          const _SectionLabel('Armatura', CprPalette.violet),
          _Row2(
            left: TechDropdown<ArmorSlot>(
              label: 'Slot',
              value: _armorSlot,
              items: ArmorSlot.values,
              labelOf: (ArmorSlot s) => s.label,
              accent: CprPalette.violet,
              onChanged: (ArmorSlot s) => setState(() => _armorSlot = s),
            ),
            right: TechNumberStepper(
              label: 'Protezione (SP)',
              value: _sp,
              max: 30,
              accent: CprPalette.violet,
              onChanged: (int v) => setState(() => _sp = v),
            ),
          ),
          const SizedBox(height: 12),
          TechNumberStepper(
            label: 'Penalita a Riflessi, Destrezza e Velocita',
            value: _armorPenalties,
            max: 20,
            accent: CprPalette.violet,
            onChanged: (int v) => setState(() => _armorPenalties = v),
          ),
        ],
        if (_category == ItemCategory.clothing) ...<Widget>[
          const _SectionLabel('Abbigliamento', CprPalette.violet),
          _Row2(
            left: TechDropdown<ClothingSlot>(
              label: 'Slot',
              value: _clothingSlot,
              items: ClothingSlot.values,
              labelOf: (ClothingSlot s) => s.label,
              accent: CprPalette.violet,
              onChanged: (ClothingSlot s) => setState(() => _clothingSlot = s),
            ),
            right: TechDropdown<ClothingStyle>(
              label: 'Stile',
              value: _clothingStyle,
              items: ClothingStyle.values,
              labelOf: (ClothingStyle s) => s.label,
              accent: CprPalette.violet,
              onChanged: (ClothingStyle s) => setState(() => _clothingStyle = s),
            ),
          ),
        ],
        const SizedBox(height: 12),
        TechTextArea(
          label: 'Descrizione',
          value: _description,
          lines: 3,
          accent: CprPalette.violet,
          onChanged: (String v) => setState(() => _description = v),
        ),
        const SizedBox(height: 14),
        _ImageRow(path: _imagePath, onPick: _pickImage, onClear: () => setState(() => _imagePath = null)),
      ],
    );
  }
}
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(width: 3, height: 12, color: color),
          const SizedBox(width: 8),
          Text(text.toUpperCase(), style: CprType.label.copyWith(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Selettore dello slot immagine.
///
/// Lo slot vuoto e' lo stato normale, non un errore: il catalogo usa icone
/// generiche, e le immagini "vere" sono qualcosa che l'utente aggiunge se
/// vuole. Mostrare un riquadro vuoto con un invito e' piu' onesto che
/// riempirlo con un'icona segnaposto che sembra un contenuto mancante.
class _ImageRow extends StatelessWidget {
  const _ImageRow({required this.path, required this.onPick, required this.onClear});

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: CprPalette.surfaceSunken,
            border: Border.all(color: CprPalette.hairline),
          ),
          child: path == null
              ? const Icon(Icons.image_outlined, size: 18, color: CprPalette.inkFaint)
              : ClipRect(
                  child: Image.file(
                    File(path!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 18, color: CprPalette.danger),
                  ),
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('IMMAGINE', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5)),
              const SizedBox(height: 4),
              Text(
                path ?? 'Slot vuoto',
                overflow: TextOverflow.ellipsis,
                style: CprType.caption.copyWith(
                  color: path == null ? CprPalette.inkFaint : CprPalette.inkMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TechButton(
          label: 'Scegli',
          icon: Icons.folder_open,
          variant: TechButtonVariant.ghost,
          compact: true,
          onPressed: onPick,
        ),
        if (path != null) ...<Widget>[
          const SizedBox(width: 6),
          TechButton(
            label: '',
            icon: Icons.close,
            variant: TechButtonVariant.danger,
            compact: true,
            onPressed: onClear,
          ),
        ],
      ],
    );
  }

}

class _CyberwareEditor extends StatefulWidget {
  const _CyberwareEditor({
    this.existing,
    this.allInstalled = const <Cyberware>[],
    this.initialBodyZone,
    this.initialParentFoundationId,
  });

  final Cyberware? existing;
  final List<Cyberware> allInstalled;
  final String? initialBodyZone;
  final String? initialParentFoundationId;

  @override
  State<_CyberwareEditor> createState() => _CyberwareEditorState();
}

class _CyberwareEditorState extends State<_CyberwareEditor> {
  late String _name = widget.existing?.name ?? '';
  late CyberwareCategory _category = widget.existing?.category ?? CyberwareCategory.neuralware;
  late Rarity _rarity = widget.existing?.rarity ?? Rarity.common;
  late bool _foundational = widget.existing?.isFoundational ?? (widget.initialParentFoundationId != null ? false : false);
  late int _optionSlots = widget.existing?.optionSlots != null && widget.existing!.optionSlots > 0
      ? widget.existing!.optionSlots
      : defaultFoundationSlotsFor(_category, widget.existing?.name);
  late int _slotsRequired = widget.existing?.slotsRequired ?? 1;
  late String? _parentFoundationId = widget.existing?.parentFoundationId ?? widget.initialParentFoundationId;
  late bool _bodyZoneExplicit = widget.existing != null || widget.initialBodyZone != null;
  late String _bodyZone = widget.existing?.bodyZone ?? widget.initialBodyZone ?? defaultBodyZoneFor(_category, widget.existing?.name);
  late String _description = widget.existing?.description ?? '';
  late String? _imagePath = widget.existing?.imagePath;
  late int _humanityLost = widget.existing?.humanityLost ?? 0;
  late double _weight = widget.existing?.weight ?? 0;
  late int _cost = widget.existing?.cost ?? 0;
  late int _lifeEffect = widget.existing?.lifeEffect ?? 0;
  late double _lifePercent = widget.existing?.lifePercentEffect ?? 0;
  late double _loadEffect = widget.existing?.loadEffect ?? 0;
  late double _loadPercent = widget.existing?.loadPercentEffect ?? 0;

  late final List<StatModifier> _statMods = List<StatModifier>.from(
    widget.existing?.statModifiers ?? const <StatModifier>[],
  );
  late final List<SkillModifier> _skillMods = List<SkillModifier>.from(
    widget.existing?.skillModifiers ?? const <SkillModifier>[],
  );
  late final List<ProficiencyModifier> _proficiencyMods = List<ProficiencyModifier>.from(
    widget.existing?.proficiencyModifiers ?? const <ProficiencyModifier>[],
  );

  Future<void> _pickImage() async {
    final String? path = await showFileBrowser(
      context,
      mode: FileBrowserMode.open,
      title: 'Immagine dell\'impianto',
      extensions: const <String>['png', 'jpg', 'jpeg', 'webp', 'gif'],
    );
    if (path != null) setState(() => _imagePath = path);
  }

  void _save() {
    Navigator.of(context).pop(
      Cyberware(
        id: widget.existing?.id ?? _newId('cyberware'),
        name: _name.trim(),
        category: _category,
        rarity: _rarity,
        isFoundational: _foundational,
        optionSlots: _foundational ? _optionSlots : 0,
        slotsRequired: _foundational ? 0 : _slotsRequired,
        parentFoundationId: _foundational ? null : _parentFoundationId,
        bodyZone: _bodyZone,
        description: _description,
        imagePath: _imagePath,
        installedAt: widget.existing?.installedAt ?? DateTime.now().toIso8601String().substring(0, 10),
        humanityLost: _humanityLost,
        weight: _weight,
        cost: _cost,
        lifeEffect: _lifeEffect,
        lifePercentEffect: _lifePercent,
        loadEffect: _loadEffect,
        loadPercentEffect: _loadPercent,
        statModifiers: _statMods,
        skillModifiers: _skillMods,
        proficiencyModifiers: _proficiencyMods,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Cyberware> foundations = widget.allInstalled
        .where((Cyberware c) => c.isFoundational && c.id != widget.existing?.id)
        .toList();

    Cyberware? selectedFoundation;
    int usedSlots = 0;
    int maxSlots = 0;
    bool isSlotOvercapacity = false;

    if (!_foundational && _parentFoundationId != null) {
      for (final Cyberware f in foundations) {
        if (f.id == _parentFoundationId) {
          selectedFoundation = f;
          break;
        }
      }
      if (selectedFoundation != null) {
        maxSlots = selectedFoundation.optionSlots;
        usedSlots = widget.allInstalled
            .where((Cyberware c) => c.parentFoundationId == selectedFoundation!.id && c.id != widget.existing?.id)
            .fold<int>(0, (int sum, Cyberware c) => sum + c.slotsRequired);
        if (usedSlots + _slotsRequired > maxSlots) {
          isSlotOvercapacity = true;
        }
      }
    }

    final bool saveEnabled = _name.trim().isNotEmpty && !isSlotOvercapacity;

    return _EditorFrame(
      title: widget.existing == null ? 'Nuovo impianto' : 'Modifica impianto',
      accent: CprPalette.magenta,
      saveLabel: widget.existing == null ? 'Installa' : 'Salva',
      saveEnabled: saveEnabled,
      onSave: _save,
      width: 720,
      children: <Widget>[
        TechField(
          label: 'Nome',
          value: _name,
          hint: 'Es. Interfaccia Neurale, Cyberbraccio, ecc.',
          accent: CprPalette.magenta,
          onChanged: (String v) => setState(() {
            _name = v;
            if (_foundational && widget.existing == null) {
              _optionSlots = defaultFoundationSlotsFor(_category, _name);
            }
          }),
        ),
        const SizedBox(height: 12),
        _Row2(
          left: TechDropdown<CyberwareCategory>(
            label: 'Categoria',
            value: _category,
            items: CyberwareCategory.values,
            labelOf: (CyberwareCategory c) => c.label,
            accent: CprPalette.magenta,
            onChanged: (CyberwareCategory c) => setState(() {
              _category = c;
              if (widget.existing == null) {
                if (!_bodyZoneExplicit) _bodyZone = defaultBodyZoneFor(c, _name);
                if (_foundational) {
                  _optionSlots = defaultFoundationSlotsFor(c, _name);
                }
              }
            }),
          ),
          right: TechDropdown<Rarity>(
            label: 'Rarita',
            value: _rarity,
            items: Rarity.values,
            labelOf: (Rarity r) => r.label,
            colorOf: (Rarity r) => r.color,
            accent: CprPalette.magenta,
            onChanged: (Rarity r) => setState(() => _rarity = r),
          ),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Costo in umanita', CprPalette.humanityEroded),
        TechNumberStepper(
          label: 'Umanita persa',
          value: _humanityLost,
          max: 200,
          accent: CprPalette.humanityEroded,
          onChanged: (int v) => setState(() => _humanityLost = v),
        ),
        const SizedBox(height: 10),
        _Row2(
          left: TechField(
            label: 'Peso (kg)',
            value: _weight == 0 ? '0' : _weight.toString(),
            numeric: true,
            accent: CprPalette.magenta,
            onChanged: (String v) => setState(() => _weight = double.tryParse(v) ?? 0),
          ),
          right: TechField(
            label: 'Costo (eb)',
            value: '$_cost',
            numeric: true,
            accent: CprPalette.magenta,
            onChanged: (String v) => setState(() => _cost = int.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Effetti su punti vita e carico', CprPalette.cyan),
        _Row2(
          left: TechNumberStepper(
            label: 'PV fissi',
            value: _lifeEffect,
            min: -50,
            max: 50,
            accent: CprPalette.cyan,
            onChanged: (int v) => setState(() => _lifeEffect = v),
          ),
          right: TechField(
            label: 'PV percentuali',
            value: _lifePercent.toString(),
            numeric: true,
            accent: CprPalette.cyan,
            onChanged: (String v) => setState(() => _lifePercent = double.tryParse(v) ?? 0),
          ),
        ),
        _Row2(
          left: TechField(
            label: 'Carico fisso (kg)',
            value: _loadEffect.toString(),
            numeric: true,
            accent: CprPalette.cyan,
            onChanged: (String v) => setState(() => _loadEffect = double.tryParse(v) ?? 0),
          ),
          right: TechField(
            label: 'Carico percentuale',
            value: _loadPercent.toString(),
            numeric: true,
            accent: CprPalette.cyan,
            onChanged: (String v) => setState(() => _loadPercent = double.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(height: 16),
        _ModifierList(
          accent: CprPalette.magenta,
          statModifiers: _statMods,
          skillModifiers: _skillMods,
          onAddStat: () => setState(
            () => _statMods.add(StatModifier(target: Stat.intelligence, value: 1)),
          ),
          onAddSkill: () => setState(
            () => _skillMods.add(SkillModifier(skillId: Skill.perception.id, value: 1)),
          ),
          onRemoveStat: (int i) => setState(() => _statMods.removeAt(i)),
          onRemoveSkill: (int i) => setState(() => _skillMods.removeAt(i)),
          onStatChanged: (int i, Stat s, int v) => setState(() {
            _statMods[i] = StatModifier(target: s, value: v, isActive: _statMods[i].isActive);
          }),
          onSkillChanged: (int i, int skillId, int v) => setState(() {
            _skillMods[i] = SkillModifier(skillId: skillId, value: v, isActive: _skillMods[i].isActive);
          }),
        ),
        const SizedBox(height: 16),
        TechTextArea(
          label: 'Descrizione',
          value: _description,
          lines: 3,
          accent: CprPalette.magenta,
          onChanged: (String v) => setState(() => _description = v),
        ),
        const SizedBox(height: 12),
        _ImageRow(path: _imagePath, onPick: _pickImage, onClear: () => setState(() => _imagePath = null)),
        const SizedBox(height: 18),
        // Checkbox Componente Fondamentale
        InkWell(
          onTap: () {
            setState(() {
              _foundational = !_foundational;
              if (_foundational) {
                _parentFoundationId = null;
                _slotsRequired = 0;
                if (_optionSlots <= 0) {
                  _optionSlots = defaultFoundationSlotsFor(_category, _name);
                }
              } else {
                if (_slotsRequired <= 0) _slotsRequired = 1;
              }
            });
          },
          borderRadius: BorderRadius.circular(2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _foundational ? CprPalette.veil(CprPalette.magenta, 0.12) : CprPalette.surfaceRaised,
              border: Border.all(
                color: _foundational ? CprPalette.magenta : CprPalette.hairline,
                width: _foundational ? 1.6 : 1.0,
              ),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _foundational ? CprPalette.magenta : Colors.transparent,
                    border: Border.all(
                      color: _foundational ? CprPalette.magenta : CprPalette.inkMuted,
                      width: 1.6,
                    ),
                  ),
                  child: _foundational
                      ? const Icon(Icons.check, size: 16, color: CprPalette.surface)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Componente Fondamentale',
                        style: CprType.body.copyWith(
                          color: _foundational ? CprPalette.magenta : CprPalette.ink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _foundational
                            ? 'Base strutturale (es. Collegamento Neuronale, Cyberocchio, Cyberbraccio) che fornisce slot per opzioni secondarie.'
                            : 'Opzione/innesto (consuma slot all\'interno di una base fondamentale o installabile come modulo libero).',
                        style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (_foundational) ...<Widget>[
          _SectionLabel('Configurazione Base Strutturale', CprPalette.magenta),
          _Row2(
            left: TechNumberStepper(
              label: 'Slot Opzioni Forniti',
              value: _optionSlots,
              min: 1,
              max: 10,
              accent: CprPalette.magenta,
              onChanged: (int v) => setState(() => _optionSlots = v),
            ),
            right: TechDropdown<CyberBodyZone>(
              label: 'Zona Corporea',
              value: CyberBodyZone.fromId(_bodyZone),
              items: CyberBodyZone.values,
              labelOf: (CyberBodyZone z) => z.label,
              accent: CprPalette.magenta,
              onChanged: (CyberBodyZone z) => setState(() { _bodyZone = z.id; _bodyZoneExplicit = true; }),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: CprPalette.veil(CprPalette.magenta, 0.07),
              border: Border.all(color: CprPalette.veil(CprPalette.magenta, 0.3)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.hub_outlined, size: 16, color: CprPalette.magenta),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Questa base ospitera\' fino a $_optionSlots opzioni/innesti aggiuntivi. '
                    '(Da manuale: Collegamento Neuronale 5, Cyberocchio 3, Cyberaudio 3, Cyberbraccio 4, Cybergamba 3).',
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
        ] else ...<Widget>[
          _SectionLabel('Installazione Opzione & Slot', CprPalette.cyan),
          _Row2(
            left: TechNumberStepper(
              label: 'Slot Richiesti',
              value: _slotsRequired,
              min: 1,
              max: 5,
              accent: CprPalette.cyan,
              onChanged: (int v) => setState(() => _slotsRequired = v),
            ),
            right: TechDropdown<CyberBodyZone>(
              label: 'Zona Corporea',
              value: CyberBodyZone.fromId(_bodyZone),
              items: CyberBodyZone.values,
              labelOf: (CyberBodyZone z) => z.label,
              accent: CprPalette.cyan,
              onChanged: (CyberBodyZone z) => setState(() { _bodyZone = z.id; _bodyZoneExplicit = true; }),
            ),
          ),
          const SizedBox(height: 10),
          if (foundations.isNotEmpty) ...<Widget>[
            TechDropdown<String?>(
              label: 'Componente Fondamentale di Riferimento',
              value: _parentFoundationId,
              items: <String?>[
                null,
                ...foundations.map((Cyberware f) => f.id),
              ],
              labelOf: (String? id) {
                if (id == null) return '[Nessuna base / Modulo Indipendente]';
                final Cyberware? f = foundations.where((Cyberware c) => c.id == id).firstOrNull;
                if (f == null) return 'Base sconosciuta';
                final int used = widget.allInstalled
                    .where((Cyberware c) => c.parentFoundationId == f.id && c.id != widget.existing?.id)
                    .fold<int>(0, (int sum, Cyberware c) => sum + c.slotsRequired);
                return '${f.name} ($used/${f.optionSlots} slot occupati)';
              },
              accent: isSlotOvercapacity ? CprPalette.danger : CprPalette.cyan,
              onChanged: (String? val) => setState(() {
                _parentFoundationId = val;
                final Cyberware? base = foundations.where((Cyberware c) => c.id == val).firstOrNull;
                if (base != null) {
                  _bodyZone = base.bodyZone;
                  _bodyZoneExplicit = true;
                }
              }),
            ),
            if (isSlotOvercapacity && selectedFoundation != null) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CprPalette.veil(CprPalette.danger, 0.18),
                  border: Border.all(color: CprPalette.danger, width: 2),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.error, color: CprPalette.danger, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'TUTTI GLI SLOT OCCUPATI',
                            style: CprType.title.copyWith(
                              color: CprPalette.danger,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'La base fondamentale "${selectedFoundation.name}" ha gia\' esaurito la capacita\' '
                            '($usedSlots/${selectedFoundation.optionSlots} slot occupati, richiesti: $_slotsRequired). '
                            'Impossibile installare ulteriori opzioni.',
                            style: CprType.caption.copyWith(color: CprPalette.ink, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else ...<Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CprPalette.veil(CprPalette.warning, 0.10),
                border: Border.all(color: CprPalette.veil(CprPalette.warning, 0.4)),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.info_outline, size: 16, color: CprPalette.warning),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Nessun componente fondamentale installato nella scheda (es. Collegamento Neuronale, Cyberocchio, Cyberbraccio). '
                      'Questo cyberware verra\' installato come modulo autonomo o indipendente.',
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ModifierList extends StatelessWidget {
  const _ModifierList({
    required this.accent,
    required this.statModifiers,
    required this.skillModifiers,
    required this.onAddStat,
    required this.onAddSkill,
    required this.onRemoveStat,
    required this.onRemoveSkill,
    required this.onStatChanged,
    required this.onSkillChanged,
  });

  final Color accent;
  final List<StatModifier> statModifiers;
  final List<SkillModifier> skillModifiers;
  final VoidCallback onAddStat;
  final VoidCallback onAddSkill;
  final ValueChanged<int> onRemoveStat;
  final ValueChanged<int> onRemoveSkill;
  final void Function(int index, Stat stat, int value) onStatChanged;
  final void Function(int index, int skillId, int value) onSkillChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SectionLabel('Correzioni a caratteristiche e abilita', accent),
        for (int i = 0; i < statModifiers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TechDropdown<Stat>(
                    label: '',
                    value: statModifiers[i].target,
                    items: Stat.values,
                    labelOf: (Stat s) => s.label,
                    accent: accent,
                    onChanged: (Stat s) => onStatChanged(i, s, statModifiers[i].value),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TechField(
                    label: '',
                    value: '${statModifiers[i].value}',
                    numeric: true,
                    accent: accent,
                    onChanged: (String v) => onStatChanged(i, statModifiers[i].target, int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 6),
                TechButton(
                  label: '',
                  icon: Icons.close,
                  variant: TechButtonVariant.danger,
                  compact: true,
                  onPressed: () => onRemoveStat(i),
                ),
              ],
            ),
          ),
        for (int i = 0; i < skillModifiers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: TechDropdown<int>(
                    label: '',
                    value: skillModifiers[i].skillId,
                    items: Skill.values.map((Skill s) => s.id).toList(),
                    labelOf: (int id) => Skill.fromId(id)?.name ?? 'Sconosciuta',
                    accent: accent,
                    onChanged: (int id) => onSkillChanged(i, id, skillModifiers[i].value),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 90,
                  child: TechField(
                    label: '',
                    value: '${skillModifiers[i].value}',
                    numeric: true,
                    accent: accent,
                    onChanged: (String v) => onSkillChanged(i, skillModifiers[i].skillId, int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 6),
                TechButton(
                  label: '',
                  icon: Icons.close,
                  variant: TechButtonVariant.danger,
                  compact: true,
                  onPressed: () => onRemoveSkill(i),
                ),
              ],
            ),
          ),
        Row(
          children: <Widget>[
            TechButton(
              label: 'Correzione a una caratteristica',
              icon: Icons.add,
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: onAddStat,
            ),
            const SizedBox(width: 8),
            TechButton(
              label: 'Correzione a un\'abilita',
              icon: Icons.add,
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: onAddSkill,
            ),
          ],
        ),
      ],
    );
  }
}

class _EffectEditor extends StatefulWidget {
  const _EffectEditor({this.existing});

  final Effect? existing;

  @override
  State<_EffectEditor> createState() => _EffectEditorState();
}

class _EffectEditorState extends State<_EffectEditor> {
  late String _name = widget.existing?.name ?? '';
  late String _duration = widget.existing?.duration ?? '';
  late int _intensity = widget.existing?.intensity ?? 0;
  late EffectKnowledge _treatable = widget.existing?.isTreatable ?? EffectKnowledge.unknown;
  late EffectKnowledge _curable = widget.existing?.isCurable ?? EffectKnowledge.unknown;
  late EffectKnowledge _lethal = widget.existing?.isLethal ?? EffectKnowledge.unknown;
  late int _lifeEffect = widget.existing?.lifeEffect ?? 0;
  late double _lifePercent = widget.existing?.lifePercentEffect ?? 0;
  late double _loadEffect = widget.existing?.loadEffect ?? 0;
  late double _loadPercent = widget.existing?.loadPercentEffect ?? 0;
  late String _otherEffects = widget.existing?.otherEffects ?? '';
  late String _description = widget.existing?.description ?? '';
  late bool _active = widget.existing?.isActive ?? true;

  late final List<StatModifier> _statMods = List<StatModifier>.from(
    widget.existing?.statModifiers ?? const <StatModifier>[],
  );
  late final List<SkillModifier> _skillMods = List<SkillModifier>.from(
    widget.existing?.skillModifiers ?? const <SkillModifier>[],
  );

  void _save() {
    Navigator.of(context).pop(
      Effect(
        id: widget.existing?.id ?? _newId('effect'),
        name: _name.trim(),
        duration: _duration,
        intensity: _intensity,
        isTreatable: _treatable,
        isCurable: _curable,
        isLethal: _lethal,
        lifeEffect: _lifeEffect,
        lifePercentEffect: _lifePercent,
        loadEffect: _loadEffect,
        loadPercentEffect: _loadPercent,
        otherEffects: _otherEffects,
        description: _description,
        isActive: _active,
        statModifiers: _statMods,
        skillModifiers: _skillMods,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorFrame(
      title: widget.existing == null ? 'Nuovo effetto' : 'Modifica effetto',
      accent: CprPalette.magenta,
      saveLabel: widget.existing == null ? 'Crea' : 'Salva',
      saveEnabled: _name.trim().isNotEmpty,
      onSave: _save,
      width: 720,
      children: <Widget>[
        TechField(
          label: 'Nome',
          value: _name,
          hint: 'Es. Ferita da arma da fuoco, Sbornia',
          accent: CprPalette.magenta,
          onChanged: (String v) => setState(() => _name = v),
        ),
        const SizedBox(height: 12),
        _Row2(
          left: TechField(
            label: 'Durata',
            value: _duration,
            hint: '2 giorni, fino a cura',
            accent: CprPalette.magenta,
            onChanged: (String v) => setState(() => _duration = v),
          ),
          right: TechNumberStepper(
            label: 'Intensita',
            value: _intensity,
            max: 20,
            accent: CprPalette.magenta,
            onChanged: (int v) => setState(() => _intensity = v),
          ),
        ),
        const SizedBox(height: 16),
        // Tre stati, non due: "Sconosciuto" e "Si" sono informazioni diverse
        // per il master. E' la ragione per cui il valore nel vecchio database
        // era -1/0/1 e non un booleano.
        _SectionLabel('Conoscenza dell\'effetto', CprPalette.yellow),
        Text('CURABILE', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
        const SizedBox(height: 5),
        TechSegmented<EffectKnowledge>(
          value: _curable,
          items: EffectKnowledge.values,
          labelOf: (EffectKnowledge k) => k.label,
          accent: CprPalette.yellow,
          onChanged: (EffectKnowledge k) => setState(() => _curable = k),
        ),
        const SizedBox(height: 10),
        Text('TRATTABILE', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
        const SizedBox(height: 5),
        TechSegmented<EffectKnowledge>(
          value: _treatable,
          items: EffectKnowledge.values,
          labelOf: (EffectKnowledge k) => k.label,
          accent: CprPalette.yellow,
          onChanged: (EffectKnowledge k) => setState(() => _treatable = k),
        ),
        const SizedBox(height: 10),
        Text('LETALE', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
        const SizedBox(height: 5),
        TechSegmented<EffectKnowledge>(
          value: _lethal,
          items: EffectKnowledge.values,
          labelOf: (EffectKnowledge k) => k.label,
          accent: CprPalette.danger,
          onChanged: (EffectKnowledge k) => setState(() => _lethal = k),
        ),
        const SizedBox(height: 16),
        _SectionLabel('Effetti su punti vita e carico', CprPalette.cyan),
        _Row2(
          left: TechNumberStepper(
            label: 'PV fissi',
            value: _lifeEffect,
            min: -50,
            max: 50,
            accent: CprPalette.cyan,
            onChanged: (int v) => setState(() => _lifeEffect = v),
          ),
          right: TechField(
            label: 'PV percentuali',
            value: _lifePercent.toString(),
            numeric: true,
            accent: CprPalette.cyan,
            onChanged: (String v) => setState(() => _lifePercent = double.tryParse(v) ?? 0),
          ),
        ),
        _Row2(
          left: TechField(
            label: 'Carico fisso (kg)',
            value: _loadEffect.toString(),
            numeric: true,
            accent: CprPalette.cyan,
            onChanged: (String v) => setState(() => _loadEffect = double.tryParse(v) ?? 0),
          ),
          right: TechField(
            label: 'Carico percentuale',
            value: _loadPercent.toString(),
            numeric: true,
            accent: CprPalette.cyan,
            onChanged: (String v) => setState(() => _loadPercent = double.tryParse(v) ?? 0),
          ),
        ),
        const SizedBox(height: 16),
        _ModifierList(
          accent: CprPalette.magenta,
          statModifiers: _statMods,
          skillModifiers: _skillMods,
          onAddStat: () => setState(
            () => _statMods.add(StatModifier(target: Stat.reflexes, value: -1)),
          ),
          onAddSkill: () => setState(
            () => _skillMods.add(SkillModifier(skillId: Skill.perception.id, value: -1)),
          ),
          onRemoveStat: (int i) => setState(() => _statMods.removeAt(i)),
          onRemoveSkill: (int i) => setState(() => _skillMods.removeAt(i)),
          onStatChanged: (int i, Stat s, int v) => setState(() {
            _statMods[i] = StatModifier(target: s, value: v, isActive: _statMods[i].isActive);
          }),
          onSkillChanged: (int i, int skillId, int v) => setState(() {
            _skillMods[i] = SkillModifier(skillId: skillId, value: v, isActive: _skillMods[i].isActive);
          }),
        ),
        const SizedBox(height: 16),
        TechTextArea(
          label: 'Altri effetti',
          value: _otherEffects,
          lines: 2,
          accent: CprPalette.magenta,
          onChanged: (String v) => setState(() => _otherEffects = v),
        ),
        const SizedBox(height: 12),
        TechTextArea(
          label: 'Descrizione',
          value: _description,
          lines: 3,
          accent: CprPalette.magenta,
          onChanged: (String v) => setState(() => _description = v),
        ),
        const SizedBox(height: 18),
        TechSegmented<bool>(
          value: _active,
          items: const <bool>[true, false],
          labelOf: (bool v) => v ? 'Attivo' : 'Archiviato',
          accent: CprPalette.yellow,
          onChanged: (bool v) => setState(() => _active = v),
        ),
      ],
    );
  }
}
