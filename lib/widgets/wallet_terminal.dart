import 'package:flutter/material.dart';

import '../design/palette.dart';
import '../design/typography.dart';
import 'tech_button.dart';

/// Terminale finanziario Cyberpunk per la gestione avanzata di Eurodollari (Eddies).
class WalletTerminal extends StatelessWidget {
  const WalletTerminal({
    super.key,
    required this.eurobucks,
    required this.equippedValue,
    required this.inventoryValue,
    required this.onChanged,
  });

  final int eurobucks;
  final int equippedValue;
  final int inventoryValue;
  final ValueChanged<int> onChanged;

  int get netWorth => eurobucks + equippedValue + inventoryValue;

  Future<void> _showCustomAmountDialog(BuildContext context) async {
    final TextEditingController controller =
        TextEditingController(text: '$eurobucks');

    final int? result = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: CprPalette.surface,
          shape: const BeveledRectangleBorder(
            side: BorderSide(color: CprPalette.yellow, width: 1.2),
          ),
          title: Row(
            children: <Widget>[
              Container(width: 3, height: 16, color: CprPalette.yellow),
              const SizedBox(width: 8),
              Text(
                'MODIFICA SALDO EURODOLLARI',
                style: CprType.label.copyWith(color: CprPalette.yellow, fontSize: 12),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Imposta direttamente la quantita\' di Eurodollari (eb):',
                style: CprType.caption.copyWith(color: CprPalette.inkMuted),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: CprType.numeral.copyWith(color: CprPalette.yellow, fontSize: 24),
                decoration: InputDecoration(
                  suffixText: 'eb',
                  suffixStyle: CprType.label.copyWith(color: CprPalette.inkFaint),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: CprPalette.hairline),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: CprPalette.yellow, width: 1.5),
                  ),
                  filled: true,
                  fillColor: CprPalette.surfaceSunken,
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TechButton(
              label: 'Annulla',
              variant: TechButtonVariant.ghost,
              compact: true,
              onPressed: () => Navigator.of(ctx).pop(null),
            ),
            TechButton(
              label: 'Conferma',
              variant: TechButtonVariant.primary,
              compact: true,
              onPressed: () {
                final int? parsed = int.tryParse(controller.text.trim());
                if (parsed != null && parsed >= 0) {
                  Navigator.of(ctx).pop(parsed);
                }
              },
            ),
          ],
        );
      },
    );

    if (result != null) {
      onChanged(result);
    }
  }

  Future<void> _showTransactionDialog(BuildContext context) async {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController reasonController = TextEditingController();
    bool isIncome = true;

    final int? delta = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: CprPalette.surface,
              shape: const BeveledRectangleBorder(
                side: BorderSide(color: CprPalette.cyan, width: 1.2),
              ),
              title: Row(
                children: <Widget>[
                  Container(width: 3, height: 16, color: CprPalette.cyan),
                  const SizedBox(width: 8),
                  Text(
                    'NUOVA TRANSAZIONE',
                    style: CprType.label.copyWith(color: CprPalette.cyan, fontSize: 12),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            '+ ENTRATA',
                            style: CprType.label.copyWith(
                              color: isIncome ? CprPalette.success : CprPalette.inkMuted,
                              fontSize: 10,
                            ),
                          ),
                          selected: isIncome,
                          selectedColor: CprPalette.veil(CprPalette.success, 0.20),
                          backgroundColor: CprPalette.surfaceSunken,
                          side: BorderSide(
                            color: isIncome ? CprPalette.success : CprPalette.hairline,
                          ),
                          onSelected: (bool sel) => setState(() => isIncome = true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: Text(
                            '- USCITA',
                            style: CprType.label.copyWith(
                              color: !isIncome ? CprPalette.danger : CprPalette.inkMuted,
                              fontSize: 10,
                            ),
                          ),
                          selected: !isIncome,
                          selectedColor: CprPalette.veil(CprPalette.danger, 0.20),
                          backgroundColor: CprPalette.surfaceSunken,
                          side: BorderSide(
                            color: !isIncome ? CprPalette.danger : CprPalette.hairline,
                          ),
                          onSelected: (bool sel) => setState(() => isIncome = false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: CprType.numeral.copyWith(
                      color: isIncome ? CprPalette.success : CprPalette.danger,
                      fontSize: 22,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Importo (eb)',
                      labelStyle: CprType.label.copyWith(color: CprPalette.inkFaint),
                      suffixText: 'eb',
                      enabledBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: CprPalette.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isIncome ? CprPalette.success : CprPalette.danger,
                          width: 1.5,
                        ),
                      ),
                      filled: true,
                      fillColor: CprPalette.surfaceSunken,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasonController,
                    style: CprType.body.copyWith(color: CprPalette.ink, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Causale (es. Mancia fixer, acquisto armi)',
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: CprPalette.hairline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: CprPalette.cyan, width: 1.5),
                      ),
                      filled: true,
                      fillColor: CprPalette.surfaceSunken,
                    ),
                  ),
                ],
              ),
              actions: <Widget>[
                TechButton(
                  label: 'Annulla',
                  variant: TechButtonVariant.ghost,
                  compact: true,
                  onPressed: () => Navigator.of(ctx).pop(null),
                ),
                TechButton(
                  label: 'Registra',
                  variant: isIncome ? TechButtonVariant.primary : TechButtonVariant.danger,
                  compact: true,
                  onPressed: () {
                    final int? amt = int.tryParse(amountController.text.trim());
                    if (amt != null && amt > 0) {
                      Navigator.of(ctx).pop(isIncome ? amt : -amt);
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (delta != null) {
      final int newTotal = (eurobucks + delta).clamp(0, 99999999);
      onChanged(newTotal);
    }
  }

  void _addDelta(int delta) {
    final int newTotal = (eurobucks + delta).clamp(0, 99999999);
    onChanged(newTotal);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(color: CprPalette.veil(CprPalette.yellow, 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Riga principale: Saldo e Patrimonio
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Saldo Eurodollari
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          'PORTAFOGLIO EDDIES',
                          style: CprType.label.copyWith(
                            color: CprPalette.yellow,
                            fontSize: 10,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _showCustomAmountDialog(context),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: Icon(
                              Icons.edit_outlined,
                              size: 13,
                              color: CprPalette.veil(CprPalette.yellow, 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _showCustomAmountDialog(context),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: <Widget>[
                          Text(
                            _formatCurrency(eurobucks),
                            style: CprType.numeral.copyWith(
                              fontSize: 28,
                              color: CprPalette.yellow,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'eb',
                            style: CprType.label.copyWith(
                              color: CprPalette.inkFaint,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Patrimonio Netto
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'PATRIMONIO TOTALE',
                      style: CprType.label.copyWith(
                        color: CprPalette.inkFaint,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_formatCurrency(netWorth)} eb',
                      style: CprType.numeralSmall.copyWith(
                        fontSize: 17,
                        color: CprPalette.cyan,
                      ),
                    ),
                    Text(
                      'Equip: ${_formatCurrency(equippedValue)} eb · Zaino: ${_formatCurrency(inventoryValue)} eb',
                      style: CprType.caption.copyWith(color: CprPalette.inkMuted, fontSize: 9.5),
                    ),
                  ],
                ),
              ),

              // Pulsante Transazione
              TechButton(
                label: 'Transazione',
                icon: Icons.payments_outlined,
                variant: TechButtonVariant.secondary,
                compact: true,
                onPressed: () => _showTransactionDialog(context),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Chips per modifiche rapide (+100, +500, +1000, -50, -100, -500)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _QuickChip(label: '+100 eb', isPlus: true, onTap: () => _addDelta(100)),
              _QuickChip(label: '+500 eb', isPlus: true, onTap: () => _addDelta(500)),
              _QuickChip(label: '+1.000 eb', isPlus: true, onTap: () => _addDelta(1000)),
              _QuickChip(label: '-50 eb', isPlus: false, onTap: () => _addDelta(-50)),
              _QuickChip(label: '-100 eb', isPlus: false, onTap: () => _addDelta(-100)),
              _QuickChip(label: '-500 eb', isPlus: false, onTap: () => _addDelta(-500)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatCurrency(int value) {
    if (value < 1000) return '$value';
    final String s = value.toString();
    final StringBuffer sb = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      sb.write(s[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        sb.write('.');
      }
    }
    return sb.toString().split('').reversed.join('');
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.label,
    required this.isPlus,
    required this.onTap,
  });

  final String label;
  final bool isPlus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isPlus ? CprPalette.success : CprPalette.danger;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: CprPalette.veil(color, 0.08),
            border: Border.all(color: CprPalette.veil(color, 0.40)),
          ),
          child: Text(
            label,
            style: CprType.label.copyWith(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
