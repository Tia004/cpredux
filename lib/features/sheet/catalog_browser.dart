import 'package:flutter/material.dart';

import '../../data/catalog.dart';
import '../../design/motion.dart';
import '../../design/palette.dart';
import '../../design/rarity_color.dart';
import '../../design/typography.dart';
import '../../domain/catalog_item.dart';
import '../../domain/enums.dart';
import '../../widgets/inputs.dart';
import '../../widgets/tech_background.dart';
import '../../widgets/tech_button.dart';

/// Apre il selettore del catalogo. Restituisce `null` se l'utente annulla.
///
/// Il selettore **non** modifica nulla: scegliere un oggetto non significa
/// averlo, e questa distinzione serve a poter guardare il catalogo senza
/// riempire l'inventario per sbaglio. L'aggiunta la fa chi chiama.
Future<CatalogItem?> showCatalogPicker(
  BuildContext context, {
  required ItemCatalog catalog,
}) {
  return showDialog<CatalogItem>(
    context: context,
    barrierColor: CprPalette.veil(CprPalette.voidBlack, 0.75),
    builder: (BuildContext context) => _CatalogPickerDialog(catalog: catalog),
  );
}

class _CatalogPickerDialog extends StatefulWidget {
  const _CatalogPickerDialog({required this.catalog});

  final ItemCatalog catalog;

  @override
  State<_CatalogPickerDialog> createState() => _CatalogPickerDialogState();
}

class _CatalogPickerDialogState extends State<_CatalogPickerDialog> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  ItemCategory? _category;
  Rarity? _rarity;
  CatalogItem? _selected;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CatalogItem> get _results => widget.catalog.search(
        query: _query,
        category: _category,
        rarity: _rarity,
      );

  @override
  Widget build(BuildContext context) {
    final List<CatalogItem> results = _results;
    final Map<ItemCategory, int> counts = widget.catalog.categories();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 700),
        child: SizedBox(
          width: 1000,
          height: 700,
          child: TechBackground(
            gridSize: 28,
            showVignette: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: CprPalette.surface,
                border: Border.all(color: CprPalette.veil(CprPalette.cyan, 0.5)),
              ),
              child: Column(
                children: <Widget>[
                  _header(counts),
                  _filters(),
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Expanded(flex: 3, child: _list(results)),
                        VerticalDivider(width: 1, color: CprPalette.hairline),
                        Expanded(flex: 2, child: _details()),
                      ],
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(Map<ItemCategory, int> counts) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Container(width: 3, height: 16, color: CprPalette.cyan),
          const SizedBox(width: 10),
          Text(
            'CATALOGO OGGETTI',
            style: CprType.label.copyWith(fontSize: 12.5, color: CprPalette.ink),
          ),
          const SizedBox(width: 12),
          Text(
            '${widget.catalog.itemCount} voci · schema v${widget.catalog.version}',
            style: CprType.caption.copyWith(color: CprPalette.inkFaint),
          ),
          const Spacer(),
          Tooltip(
            message: 'Il catalogo e\' in sola lettura: gli oggetti si correggono\n'
                'dentro la scheda, come personalizzazioni.',
            child: Icon(Icons.lock_outline, size: 15, color: CprPalette.inkFaint),
          ),
          const SizedBox(width: 10),
          TechButton(
            label: '',
            icon: Icons.close,
            variant: TechButtonVariant.ghost,
            compact: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: TechField(
                  label: 'Cerca',
                  value: _search.text,
                  hint: 'Pistola, kevlar, medkit…',
                  accent: CprPalette.cyan,
                  onChanged: (String v) => setState(() {
                    _query = v;
                    _selected = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TechDropdown<ItemCategory?>(
                  label: 'Categoria',
                  value: _category,
                  items: <ItemCategory?>[null, ...ItemCategory.values],
                  labelOf: (ItemCategory? c) => c?.label ?? 'Tutte',
                  accent: CprPalette.cyan,
                  onChanged: (ItemCategory? c) => setState(() {
                    _category = c;
                    _selected = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TechDropdown<Rarity?>(
                  label: 'Rarita',
                  value: _rarity,
                  items: <Rarity?>[null, ...Rarity.values],
                  labelOf: (Rarity? r) => r?.label ?? 'Tutte',
                  colorOf: (Rarity? r) => r?.color ?? CprPalette.ink,
                  accent: CprPalette.cyan,
                  onChanged: (Rarity? r) => setState(() {
                    _rarity = r;
                    _selected = null;
                  }),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _list(List<CatalogItem> results) {
    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Nessun oggetto trovato.\n\nSe quello che cerchi non c\'e\', puoi crearlo a mano: '
            'restera\' nella scheda con tutti i suoi dati.',
            textAlign: TextAlign.center,
            style: CprType.body.copyWith(color: CprPalette.inkFaint),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: results.length,
      itemBuilder: (BuildContext context, int index) {
        final CatalogItem item = results[index];
        final bool selected = _selected?.id == item.id;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => setState(() => _selected = item),
            onDoubleTap: () => Navigator.of(context).pop(item),
            child: AnimatedContainer(
              duration: CprMotion.hover,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? CprPalette.veil(CprPalette.cyan, 0.10) : null,
                border: Border(
                  left: BorderSide(
                    width: 3,
                    color: selected ? CprPalette.cyan : CprPalette.veil(item.rarity.color, 0.9),
                  ),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                item.name,
                                overflow: TextOverflow.ellipsis,
                                style: CprType.body.copyWith(
                                  color: selected ? CprPalette.cyan : CprPalette.ink,
                                ),
                              ),
                            ),
                            if (item.source != 'core') ...<Widget>[
                              const SizedBox(width: 8),
                              _Chip(label: item.source.toUpperCase(), color: CprPalette.violet),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _summary(item),
                          overflow: TextOverflow.ellipsis,
                          style: CprType.caption.copyWith(
                            color: CprPalette.inkFaint,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        '${item.cost} eb',
                        style: CprType.numeralSmall.copyWith(color: CprPalette.yellow, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_weight(item.weight)} kg',
                        style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _details() {
    final CatalogItem? item = _selected;
    if (item == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Scegli un oggetto per vedere le statistiche complete.',
            textAlign: TextAlign.center,
            style: CprType.caption.copyWith(color: CprPalette.inkFaint),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  item.name,
                  style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 17),
                ),
              ),
              _Chip(label: item.rarity.label.toUpperCase(), color: item.rarity.color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.category.label} · ${item.id}',
            style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
          ),
          const SizedBox(height: 16),
          _DetailRow(label: 'Costo', value: '${item.cost} eb'),
          _DetailRow(label: 'Peso', value: '${_weight(item.weight)} kg'),
          if (item.weapon != null) ...<Widget>[
            _DetailRow(label: 'Danno', value: item.weapon!.damage),
            _DetailRow(label: 'Colpi per caricatore', value: '${item.weapon!.maxAmmo}'),
            _DetailRow(label: 'Cadenza di tiro', value: '${item.weapon!.rof}'),
            _DetailRow(
              label: 'Mani',
              value: item.weapon!.handsRequired == '2' ? 'Due mani' : 'Una mano',
            ),
            _DetailRow(
              label: 'Nascondibile',
              value: item.weapon!.isConcealable ? 'Si' : 'No',
            ),
          ],
          if (item.armor != null) ...<Widget>[
            _DetailRow(label: 'Slot', value: item.armor!.slot.label),
            _DetailRow(label: 'Protezione (SP)', value: '${item.armor!.sp}'),
            _DetailRow(
              label: 'Penalita a Riflessi, Destrezza e Velocita',
              value: '${item.armor!.penalties}',
            ),
          ],
          if (item.clothing != null) ...<Widget>[
            _DetailRow(label: 'Slot', value: item.clothing!.slot.label),
            _DetailRow(label: 'Stile', value: item.clothing!.style.label),
          ],
          if (item.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              item.description,
              style: CprType.caption.copyWith(color: CprPalette.inkMuted, height: 1.55),
            ),
          ],
          const SizedBox(height: 18),
          Text(
            'Cosa succede quando lo aggiungi',
            style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Nella scheda finisce solo il riferimento a questa voce, piu\' la quantita\' e le '
            'personalizzazioni che deciderai di fare. Se il catalogo verra\' corretto in futuro, '
            'i tuoi oggetti si aggiorneranno da soli.',
            style: CprType.caption.copyWith(color: CprPalette.inkFaint, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: CprPalette.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              _selected == null
                  ? 'Nessuna selezione'
                  : 'Selezionato: ${_selected!.name}',
              overflow: TextOverflow.ellipsis,
              style: CprType.caption.copyWith(color: CprPalette.inkMuted),
            ),
          ),
          TechButton(
            label: 'Annulla',
            variant: TechButtonVariant.ghost,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          TechButton(
            label: 'Aggiungi all\'inventario',
            icon: Icons.add,
            variant: TechButtonVariant.primary,
            onPressed: _selected == null ? null : () => Navigator.of(context).pop(_selected),
          ),
        ],
      ),
    );
  }

  static String _summary(CatalogItem item) {
    final List<String> parts = <String>[item.category.label];
    if (item.weapon != null) {
      parts.add('Danno ${item.weapon!.damage}');
      parts.add('CdT ${item.weapon!.rof}');
    }
    if (item.armor != null) parts.add('SP ${item.armor!.sp}');
    if (item.clothing != null) parts.add(item.clothing!.style.label);
    return parts.join(' · ');
  }

  static String _weight(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      color: CprPalette.veil(color, 0.14),
      child: Text(
        label,
        style: CprType.label.copyWith(color: color, fontSize: 8.5),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: CprType.label.copyWith(color: CprPalette.inkFaint, fontSize: 9),
            ),
          ),
          const SizedBox(width: 10),
          Text(value, style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 12.5)),
        ],
      ),
    );
  }
}
