import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/rarity_color.dart';
import '../../design/typography.dart';
import '../../domain/catalog_item.dart';
import '../../domain/enums.dart';
import '../../domain/items.dart';
import '../../domain/rules.dart';
import '../../domain/skills.dart';
import '../../widgets/chamfer_panel.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/dice_roll_dialog.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_button.dart';
import '../../widgets/wallet_terminal.dart';
import 'catalog_browser.dart';
import 'editors.dart';

String _entryId() => 'item-${DateTime.now().microsecondsSinceEpoch}';

/// Aggiunge una voce di catalogo all'inventario.
///
/// Due copie della stessa arma restano due righe distinte: hanno caricatori
/// diversi, e fondere le quantita' renderebbe impossibile dire quanti colpi
/// restano nell'arma che hai in mano.
InventoryEntry addFromCatalog(CatalogItem item) =>
    InventoryEntry.fromCatalog(item, id: _entryId());

/// Aggiunge un oggetto inventato dall'utente.
InventoryEntry addCustom(CatalogItem item) =>
    InventoryEntry.customItem(item, id: _entryId());

class InventoryTab extends StatefulWidget {
  const InventoryTab({super.key});

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  ItemCategory? _filter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final sheet = state.sheet!;
    final totals = state.totals!;

    // Si filtra sull'**oggetto risolto**, non sulla voce grezza: cercare
    // "kevlar" deve trovare anche una voce di catalogo il cui nome e' stato
    // personalizzato, e viceversa.
    final List<ResolvedItem> inventory = state.resolvedInventory;
    final List<ResolvedItem> visible = inventory.where((ResolvedItem item) {
      if (_filter != null && item.category != _filter) return false;
      if (_query.isEmpty) return true;
      return item.name.toLowerCase().contains(_query);
    }).toList();

    final int equippedValue = inventory
        .where((ResolvedItem i) => i.entry.isEquipped)
        .fold<int>(0, (int a, ResolvedItem i) => a + (i.cost * i.entry.quantity));
    final int backpackValue = inventory
        .where((ResolvedItem i) => !i.entry.isEquipped)
        .fold<int>(0, (int a, ResolvedItem i) => a + (i.cost * i.entry.quantity));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChamferPanel(
            title: 'Carico e risorse',
            accent: totals.loadStatus == LoadStatus.overload
                ? CprPalette.danger
                : totals.loadStatus == LoadStatus.heavy
                    ? CprPalette.warning
                    : CprPalette.cyan,
            child: Column(
              children: <Widget>[
                _LoadBar(totals: totals),
                const SizedBox(height: 14),
                WalletTerminal(
                  eurobucks: sheet.eurobucks,
                  equippedValue: equippedValue,
                  inventoryValue: backpackValue,
                  onChanged: (int v) => state.mutate((s) => s.eurobucks = v),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _SummaryTile(
                        label: 'Oggetti Totali',
                        value: '${inventory.length}',
                        hint: '${inventory.fold<int>(0, (int a, ResolvedItem i) => a + i.entry.quantity)} pezzi',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryTile(
                        label: 'Equipaggiati',
                        value: '${inventory.where((ResolvedItem i) => i.entry.isEquipped).length}',
                        hint: 'armi, armature, vestiti',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryTile(
                        label: 'Nello Zaino',
                        value: '${inventory.where((ResolvedItem i) => !i.entry.isEquipped).length}',
                        hint: 'scorte, materiali, attrezzi',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChamferPanel(
            title: 'Inventario',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TechButton(
                  label: 'Personalizzato',
                  icon: Icons.edit_note,
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  onPressed: () async {
                    final CatalogItem? created = await showCustomItemEditor(context);
                    if (created == null) return;
                    state.mutate((s) => s.inventory.add(addCustom(created)));
                  },
                ),
                const SizedBox(width: 8),
                TechButton(
                  label: 'Dal catalogo',
                  icon: Icons.library_add_outlined,
                  variant: TechButtonVariant.primary,
                  compact: true,
                  onPressed: () async {
                    final CatalogItem? picked = await showCatalogPicker(
                      context,
                      catalog: state.catalog,
                    );
                    if (picked == null) return;
                    state.mutate((s) => s.inventory.add(addFromCatalog(picked)));
                  },
                ),
              ],
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TechField(
                        label: '',
                        value: _search.text,
                        hint: 'Cerca per nome…',
                        onChanged: (String v) => setState(() => _query = v.toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: TechDropdown<ItemCategory?>(
                        label: '',
                        value: _filter,
                        items: <ItemCategory?>[null, ...ItemCategory.values],
                        labelOf: (ItemCategory? c) => c?.label ?? 'Tutte le categorie',
                        accent: CprPalette.cyan,
                        onChanged: (ItemCategory? c) => setState(() => _filter = c),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CatalogStatus(state: state),
                if (visible.isEmpty)
                  TechWell(
                    child: Text(
                      'Nessun oggetto.\n'
                      'Aggiungi armi, armature, vestiti, munizioni ed equipaggiamento: '
                      'il peso totale e il carico si aggiornano da soli.',
                      style: TextStyle(color: CprPalette.inkFaint, height: 1.5, fontSize: 12),
                    ),
                  )
                else
                  for (final ResolvedItem item in visible)
                    _ItemRow(
                      item: item,
                      onEdit: () => _edit(state, item),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Apre l'editor giusto per la voce.
  ///
  /// Una voce di catalogo si **personalizza**; un oggetto creato a mano si
  /// **modifica**. Sono due operazioni diverse e non vanno confuse: la prima
  /// scrive solo le differenze, la seconda riscrive l'unica copia che esiste.
  Future<void> _edit(AppState state, ResolvedItem item) async {
    if (item.isCustom) {
      final CatalogItem? updated = await showCustomItemEditor(context, existing: item);
      if (updated == null) return;
      state.mutate((s) {
        final int index = s.inventory.indexWhere((InventoryEntry e) => e.id == item.entry.id);
        if (index >= 0) s.inventory[index].custom = updated;
      });
      return;
    }

    final ItemOverride? overrides = await showItemOverrideEditor(context, item: item);
    if (overrides == null) return;
    state.mutate((s) {
      final int index = s.inventory.indexWhere((InventoryEntry e) => e.id == item.entry.id);
      if (index >= 0) s.inventory[index].overrides = overrides;
    });
  }
}

/// Dice da dove arrivano gli oggetti in scheda.
///
/// Serve a rispondere alla domanda che si fa quando qualcosa non torna: "questo
/// prezzo e' quello vero o l'ho cambiato io?". Senza, il catalogo e' un
/// meccanismo invisibile e l'utente non sa di cosa fidarsi.
class _CatalogStatus extends StatelessWidget {
  const _CatalogStatus({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final int catalogItems = state.catalog.itemCount;
    final String? catalogError = state.catalog.loadError;
    final int personalised =
        state.resolvedInventory.where((ResolvedItem i) => i.isPersonalised).length;
    final int custom = state.resolvedInventory.where((ResolvedItem i) => i.isCustom).length;

    // Quando il catalogo non c'e', il motivo sta nel suggerimento: e' l'unico
    // posto in cui chi usa l'app puo' vederlo senza aprire un log.
    if (catalogError != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Tooltip(
          message: catalogError,
          child: Row(
            children: <Widget>[
              const Icon(Icons.warning_amber_outlined, size: 13, color: CprPalette.warning),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Catalogo non disponibile: gli oggetti restano nella scheda, ma non si agganciano '
                  'al catalogo. Passa il mouse qui per il motivo.',
                  overflow: TextOverflow.ellipsis,
                  style: CprType.caption.copyWith(color: CprPalette.warning, fontSize: 10.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Icon(
            catalogItems > 0 ? Icons.storage_outlined : Icons.warning_amber_outlined,
            size: 13,
            color: catalogItems > 0 ? CprPalette.inkFaint : CprPalette.warning,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              catalogItems > 0
                  ? 'Catalogo: $catalogItems voci'
                      '${personalised > 0 ? ' · $personalised personalizzate' : ''}'
                      '${custom > 0 ? ' · $custom create a mano' : ''}'
                  : 'Catalogo vuoto: gli oggetti restano comunque nella scheda.',
              overflow: TextOverflow.ellipsis,
              style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadBar extends StatelessWidget {
  const _LoadBar({required this.totals});

  final SheetTotals totals;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (totals.loadStatus) {
      LoadStatus.overload => CprPalette.danger,
      LoadStatus.heavy => CprPalette.warning,
      _ => CprPalette.cyan,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('STATO DI CARICO', style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
            const Spacer(),
            Text(
              totals.loadStatus.label,
              style: CprType.label.copyWith(color: color, fontSize: 10),
            ),
            if (totals.loadStatus.statPenalty != 0) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                '${totals.loadStatus.statPenalty} a VEL e DES',
                style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: (totals.loadPercentage / 100).clamp(0, 1)),
          duration: CprMotion.value,
          curve: CprMotion.enter,
          builder: (BuildContext context, double value, _) => Stack(
            children: <Widget>[
              Container(height: 14, color: CprPalette.surfaceSunken),
              FractionallySizedBox(
                widthFactor: value,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[CprPalette.veil(color, 0.6), color],
                    ),
                  ),
                ),
              ),
              // Tacche alle soglie di regola: senza di esse la barra dice
              // "quanto" ma non "quanto manca al prossimo scatto".
              for (final double threshold in <double>[0.30, 0.70, 1.0])
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: threshold.clamp(0.0, 1.0),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(width: 1, color: CprPalette.veil(CprPalette.voidBlack, 0.55)),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: <Widget>[
            Text(
              '${totals.currentLoad.toStringAsFixed(2)} kg',
              style: CprType.numeralSmall.copyWith(color: color, fontSize: 13),
            ),
            Text(
              ' / ${totals.maxLoad.toStringAsFixed(1)} kg',
              style: CprType.caption.copyWith(color: CprPalette.inkFaint),
            ),
            const Spacer(),
            Text(
              '${totals.loadPercentage.toStringAsFixed(1)}%',
              style: CprType.numeralSmall.copyWith(color: CprPalette.inkMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.hint});

  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9)),
        const SizedBox(height: 3),
        Text(value, style: CprType.numeral.copyWith(fontSize: 20)),
        Text(hint, style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10)),
      ],
    );
  }
}

class _ItemRow extends StatefulWidget {
  const _ItemRow({required this.item, required this.onEdit});

  final ResolvedItem item;
  final Future<void> Function() onEdit;

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final ResolvedItem item = widget.item;
    final InventoryEntry entry = item.entry;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onEdit,
        child: AnimatedContainer(
          duration: CprMotion.hover,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          margin: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            color: _hover ? CprPalette.veil(CprPalette.cyan, 0.06) : null,
            border: Border(
              left: BorderSide(color: CprPalette.veil(item.rarity.color, 0.9), width: 3),
            ),
          ),
          child: Row(
            children: <Widget>[
              _Thumbnail(path: item.imagePath),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                            style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13),
                          ),
                        ),
                        if (item.isCustom) ...<Widget>[
                          const SizedBox(width: 7),
                          _Tag(label: 'A MANO', color: CprPalette.violet),
                        ] else if (item.isPersonalised) ...<Widget>[
                          const SizedBox(width: 7),
                          const _Tag(label: 'PERS.', color: CprPalette.warning),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle(item),
                      overflow: TextOverflow.ellipsis,
                      style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(
                  item.rarity.label,
                  overflow: TextOverflow.ellipsis,
                  style: CprType.label.copyWith(color: item.rarity.color, fontSize: 9),
                ),
              ),
              _Cell(label: 'QTA', value: '${entry.quantity}', width: 54),
              _Cell(
                label: 'PESO',
                value: item.totalWeight.toStringAsFixed(2),
                width: 74,
                color: CprPalette.cyan,
              ),
              _Cell(label: 'COSTO', value: '${item.cost}', width: 80),
              const SizedBox(width: 6),
              if (item.weapon != null) ...<Widget>[
                TechButton(
                  label: 'Attacca',
                  icon: Icons.sports_kabaddi,
                  variant: TechButtonVariant.primary,
                  compact: true,
                  tooltip: 'Tira per colpire (1d10 + Stat + Abilità)',
                  onPressed: () {
                    final Skill weaponSkill = Skill.fromId(item.weapon!.skillId) ?? Skill.handgun;
                    final int skillMod = state.totals?.skillCheck(weaponSkill) ?? 0;
                    showCombatOrSkillRollDialog(
                      context,
                      title: 'Attacco: ${item.name}',
                      die: DiceType.d10,
                      count: 1,
                      modifier: skillMod,
                      modifierLabel: '${weaponSkill.stat.short} + ${weaponSkill.name}',
                      skill: weaponSkill,
                      weapon: item.weapon,
                      item: item,
                      onAmmoChanged: () => setState(() {}),
                    );
                  },
                ),
                const SizedBox(width: 4),
                TechButton(
                  label: 'Danno',
                  icon: Icons.local_fire_department,
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  tooltip: 'Tira i dadi danno dell\'arma con calcolo ferita grave',
                  onPressed: () {
                    final String dmg = item.weapon!.damage.isNotEmpty ? item.weapon!.damage : '3d6';
                    final RegExp match = RegExp(r'(\d+)d(\d+)', caseSensitive: false);
                    final RegExpMatch? m = match.firstMatch(dmg);
                    int count = 3;
                    DiceType die = DiceType.d6;
                    if (m != null) {
                      count = int.tryParse(m.group(1) ?? '3') ?? 3;
                      final int faces = int.tryParse(m.group(2) ?? '6') ?? 6;
                      die = faces == 10 ? DiceType.d10 : DiceType.d6;
                    }
                    showCombatOrSkillRollDialog(
                      context,
                      title: 'Danno: ${item.name} ($dmg)',
                      die: die,
                      count: count,
                      modifier: 0,
                      modifierLabel: '',
                      weapon: item.weapon,
                      item: item,
                      onAmmoChanged: () => setState(() {}),
                    );
                  },
                ),
                const SizedBox(width: 4),
              ],
              if (item.armor != null) ...<Widget>[
                TechButton(
                  label: '-1 SP',
                  icon: Icons.shield_outlined,
                  variant: TechButtonVariant.danger,
                  compact: true,
                  tooltip: 'Ablazione armatura: subisci penetrazione (-1 SP)',
                  onPressed: () => state.mutate((s) {
                    final InventoryEntry target = s.inventory.firstWhere((InventoryEntry e) => e.id == entry.id);
                    final int currentSp = item.armor!.sp;
                    final int newSp = (currentSp - 1).clamp(0, 99);
                    target.overrides = target.overrides.copy()..sp = newSp;
                  }),
                ),
                if (item.armor!.sp < (item.base?.armor?.sp ?? item.armor!.sp)) ...<Widget>[
                  const SizedBox(width: 4),
                  TechButton(
                    label: 'Ripara',
                    icon: Icons.build_circle_outlined,
                    variant: TechButtonVariant.ghost,
                    compact: true,
                    tooltip: 'Ripristina SP originale (${item.base?.armor?.sp ?? item.armor!.sp})',
                    onPressed: () => state.mutate((s) {
                      final InventoryEntry target = s.inventory.firstWhere((InventoryEntry e) => e.id == entry.id);
                      target.overrides = target.overrides.copy()..sp = item.base?.armor?.sp;
                    }),
                  ),
                ],
                const SizedBox(width: 4),
              ],
              TechButton(
                label: entry.isEquipped ? 'Equip.' : 'Zaino',
                icon: entry.isEquipped ? Icons.check_circle_outline : Icons.backpack_outlined,
                variant: entry.isEquipped ? TechButtonVariant.primary : TechButtonVariant.ghost,
                compact: true,
                onPressed: () => state.mutate((s) {
                  final InventoryEntry target =
                      s.inventory.firstWhere((InventoryEntry e) => e.id == entry.id);
                  target.isEquipped = !target.isEquipped;
                }),
              ),
              const SizedBox(width: 6),
              TechButton(
                label: '',
                icon: Icons.delete_outline,
                variant: TechButtonVariant.danger,
                compact: true,
                onPressed: () async {
                  final bool ok = await showTechConfirm(
                    context,
                    title: 'Rimuovere l\'oggetto?',
                    message: '${item.name} verra\' tolto dall\'inventario.',
                    confirmLabel: 'Rimuovi',
                    danger: true,
                  );
                  if (ok) {
                    state.mutate(
                      (s) => s.inventory.removeWhere((InventoryEntry e) => e.id == entry.id),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _subtitle(ResolvedItem item) {
    final List<String> parts = <String>[item.category.label];
    final WeaponData? weapon = item.weapon;
    if (weapon != null) {
      parts.add('Danno ${weapon.damage}');
      parts.add('${weapon.currentAmmo}/${weapon.maxAmmo} colpi');
      parts.add('CdT ${weapon.rof}');
    }
    final ArmorData? armor = item.armor;
    if (armor != null) {
      final int baseSp = item.base?.armor?.sp ?? armor.sp;
      final String spDisplay = armor.sp < baseSp
          ? 'SP ${armor.sp}/$baseSp (Ablata!)'
          : 'SP ${armor.sp}';
      parts.add('${armor.slot.label} · $spDisplay');
    }
    final ClothingData? clothing = item.clothing;
    if (clothing != null) {
      parts.add('${clothing.slot.label} · ${clothing.style.label}');
    }
    return parts.join('  ·  ');
  }
}

/// Marcatore di provenienza di una voce: creata a mano o personalizzata.
class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      color: CprPalette.veil(color, 0.14),
      child: Text(label, style: CprType.label.copyWith(color: color, fontSize: 7.5)),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    required this.width,
    this.color,
  });

  final String label;
  final String value;
  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label, style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 8)),
          const SizedBox(height: 1),
          Text(
            value,
            style: CprType.numeralSmall.copyWith(color: color ?? CprPalette.ink, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Miniatura con riempimento automatico dello slot vuoto.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    if (path == null) {
      return Container(
        width: 34,
        height: 34,
        color: CprPalette.surfaceSunken,
        child: Icon(Icons.inventory_2_outlined, size: 14, color: CprPalette.inkFaint),
      );
    }
    return Container(
      width: 34,
      height: 34,
      color: CprPalette.surfaceSunken,
      child: Image.file(
        File(path!),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(
          Icons.broken_image_outlined,
          size: 14,
          color: CprPalette.danger,
        ),
      ),
    );
  }
}

/// Equipaggiamento: vista derivata degli oggetti equipaggiati.
///
/// Non e' una seconda copia dei dati. Nel vecchio progetto equipaggiamento e
/// inventario potevano divergere, perche' erano due schermate che scrivevano
/// su campi vicini; qui l'equipaggiamento e' *una lettura filtrata*
/// dell'inventario, quindi non esiste uno stato in cui i due non concordano.
class EquipmentTab extends StatelessWidget {
  const EquipmentTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final List<ResolvedItem> equipped =
        state.resolvedInventory.where((ResolvedItem i) => i.entry.isEquipped).toList();

    final List<ResolvedItem> armor = equipped.where((ResolvedItem i) => i.armor != null).toList();
    final List<ResolvedItem> weapons = equipped.where((ResolvedItem i) => i.weapon != null).toList();
    final List<ResolvedItem> clothing = equipped.where((ResolvedItem i) => i.clothing != null).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ChamferPanel(
            title: 'Armatura indossata',
            accent: CprPalette.cyan,
            child: armor.isEmpty
                ? const _EmptyHint('Niente armatura equipaggiata. Segna "Equip." su un\'armatura in inventario.')
                : Column(
                    children: <Widget>[
                      for (final ResolvedItem item in armor)
                        _EquippedRow(
                          item: item,
                          detail: '${item.armor!.slot.label} · SP ${item.armor!.sp}'
                              '${item.armor!.penalties != 0 ? ' · ${item.armor!.penalties} di penalita' : ''}',
                          extra: '${item.entry.quantity} pezzi',
                          onUnequip: () => _unequip(state, item),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          ChamferPanel(
            title: 'Armi impugnate',
            accent: CprPalette.magenta,
            child: weapons.isEmpty
                ? const _EmptyHint('Nessuna arma equipaggiata.')
                : Column(
                    children: <Widget>[
                      for (final ResolvedItem item in weapons)
                        _EquippedRow(
                          item: item,
                          detail: 'Danno ${item.weapon!.damage} · ${item.weapon!.currentAmmo}/${item.weapon!.maxAmmo} colpi · CdT ${item.weapon!.rof}'
                              '${item.weapon!.isConcealable ? ' · occultabile' : ''}',
                          extra: item.weapon!.properties,
                          onUnequip: () => _unequip(state, item),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
          ChamferPanel(
            title: 'Abbigliamento indossato',
            accent: CprPalette.inkMuted,
            child: clothing.isEmpty
                ? const _EmptyHint('Nessun capo equipaggiato.')
                : Column(
                    children: <Widget>[
                      for (final ResolvedItem item in clothing)
                        _EquippedRow(
                          item: item,
                          detail: '${item.clothing!.slot.label} · ${item.clothing!.style.label}',
                          extra: '',
                          onUnequip: () => _unequip(state, item),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static void _unequip(AppState state, ResolvedItem item) => state.mutate((s) {
        s.inventory.firstWhere((InventoryEntry e) => e.id == item.entry.id).isEquipped = false;
      });
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return TechWell(
      child: Text(
        text,
        style: TextStyle(color: CprPalette.inkFaint, height: 1.5, fontSize: 12),
      ),
    );
  }
}

class _EquippedRow extends StatelessWidget {
  const _EquippedRow({
    required this.item,
    required this.detail,
    required this.extra,
    required this.onUnequip,
  });

  final ResolvedItem item;
  final String detail;
  final String extra;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          _Thumbnail(path: item.imagePath),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name, style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13)),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: CprType.caption.copyWith(
                    color: CprPalette.inkMuted,
                    fontFamilyFallback: CprType.monoFamily,
                    fontSize: 11,
                  ),
                ),
                if (extra.trim().isNotEmpty)
                  Text(
                    extra,
                    style: CprType.caption.copyWith(color: CprPalette.inkFaint, fontSize: 10.5),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TechButton(
            label: 'Riponi',
            icon: Icons.backpack_outlined,
            variant: TechButtonVariant.ghost,
            compact: true,
            onPressed: onUnequip,
          ),
        ],
      ),
    );
  }
}
