import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/geometry.dart';
import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Contenitore comune dei campi: angoli tagliati e bordo che si accende al
/// fuoco. Centralizzarlo qui evita che ogni campo della scheda reinventi la
/// propria decorazione e finisca per avere un bordo diverso dagli altri.
class _FieldShell extends StatelessWidget {
  const _FieldShell({
    required this.child,
    required this.focused,
    required this.accent,
    this.height,
  });

  final Widget child;
  final bool focused;
  final Color accent;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: CprMotion.hover,
      height: height,
      decoration: BoxDecoration(
        color: CprPalette.surfaceSunken,
        border: Border.all(
          color: focused ? accent : CprPalette.hairline,
          width: focused ? 1.4 : 1,
        ),
      ),
      child: child,
    );
  }
}

/// Campo di testo con etichetta tecnica.
class TechField extends StatefulWidget {
  const TechField({
    super.key,
    required this.label,
    this.value = '',
    this.onChanged,
    this.controller,
    this.hint,
    this.numeric = false,
    this.maxLines = 1,
    this.suffix,
    this.accent,
    this.enabled = true,
  });

  final String label;
  final String value;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final String? hint;

  /// I campi numerici usano la tastiera numerica e filtrano i caratteri non
  /// ammessi: in una scheda si inseriscono centinaia di numeri, e ogni volta
  /// che il campo accetta una lettera l'utente scopre l'errore solo dopo.
  final bool numeric;
  final int maxLines;
  final Widget? suffix;
  final Color? accent;
  final bool enabled;

  @override
  State<TechField> createState() => _TechFieldState();
}

class _TechFieldState extends State<TechField> {
  TextEditingController? _internalController;
  TextEditingController get _controller => widget.controller ?? _internalController!;
  final FocusNode _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController(text: widget.value);
    }
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void didUpdateWidget(covariant TechField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null) {
      if (_internalController == null) {
        _internalController = TextEditingController(text: widget.value);
      } else if (widget.value != _internalController!.text) {
        _internalController!.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length),
        );
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = widget.accent ?? CprPalette.yellow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          widget.label.toUpperCase(),
          style: CprType.label.copyWith(color: _focused ? accent : CprPalette.inkFaint),
        ),
        const SizedBox(height: 5),
        _FieldShell(
          focused: _focused,
          accent: accent,
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: widget.enabled,
                  maxLines: widget.maxLines,
                  style: CprType.body.copyWith(
                    color: CprPalette.ink,
                    fontFamilyFallback: widget.numeric ? CprType.monoFamily : CprType.sansFamily,
                  ),
                  keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
                  inputFormatters: widget.numeric
                      ? <TextInputFormatter>[FilteringTextInputFormatter.allow(RegExp(r'^-?\d*'))]
                      : null,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    hintText: widget.hint,
                    hintStyle: CprType.body.copyWith(color: CprPalette.inkFaint),
                  ),
                  onChanged: widget.onChanged,
                ),
              ),
              if (widget.suffix != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: widget.suffix,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Campo numerico con pulsanti di incremento.
///
/// I pulsanti non sono un vezzo: in sessione si modificano gli stessi valori
/// decine di volte (punti vita, munizioni, punti fortuna) e dover selezionare
/// il testo e riscriverlo ogni volta e' la differenza tra una scheda usabile e
/// una scheda che si finisce per abbandonare.
class TechNumberStepper extends StatelessWidget {
  const TechNumberStepper({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.accent,
    this.compact = false,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final Color? accent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = accent ?? CprPalette.yellow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint)),
        const SizedBox(height: 5),
        _FieldShell(
          focused: false,
          accent: accentColor,
          child: Row(
            children: <Widget>[
              _StepButton(
                icon: Icons.remove,
                enabled: value > min,
                onTap: () => onChanged((value - 1).clamp(min, max)),
                color: accentColor,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '$value',
                    style: CprType.numeral.copyWith(
                      color: accentColor,
                      fontSize: compact ? 18 : 22,
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                enabled: value < max,
                onTap: () => onChanged((value + 1).clamp(min, max)),
                color: accentColor,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    required this.color,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: 34,
          height: 38,
          alignment: Alignment.center,
          color: Colors.transparent,
          child: Icon(
            icon,
            size: 15,
            color: enabled ? color : CprPalette.inkFaint,
          ),
        ),
      ),
    );
  }
}

/// Tendina tematizzata.
class TechDropdown<T> extends StatelessWidget {
  const TechDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.accent,
    this.colorOf,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T item) labelOf;
  final ValueChanged<T> onChanged;
  final Color? accent;

  /// Colore del testo della voce selezionata, per la rarita' degli oggetti.
  final Color Function(T item)? colorOf;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = accent ?? CprPalette.yellow;
    final Color textColor = colorOf?.call(value) ?? CprPalette.ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label.toUpperCase(), style: CprType.label.copyWith(color: CprPalette.inkFaint)),
        const SizedBox(height: 5),
        _FieldShell(
          focused: false,
          accent: accentColor,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                isDense: true,
                dropdownColor: CprPalette.surfaceRaised,
                borderRadius: BorderRadius.zero,
                icon: Icon(Icons.expand_more, size: 16, color: accentColor),
                style: CprType.body.copyWith(color: textColor),
                items: <DropdownMenuItem<T>>[
                  for (final T item in items)
                    DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        labelOf(item),
                        style: CprType.body.copyWith(
                          color: colorOf?.call(item) ?? CprPalette.ink,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
                onChanged: (T? selected) {
                  if (selected != null) onChanged(selected);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Selettore a segmenti per insiemi piccoli di opzioni (2-4).
///
/// Preferito alla tendina quando le opzioni sono poche e si confrontano fra
/// loro: vedere tutte le scelte contemporaneamente costa meno di aprirne una.
class TechSegmented<T> extends StatelessWidget {
  const TechSegmented({
    super.key,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.accent,
  });

  final T value;
  final List<T> items;
  final String Function(T item) labelOf;
  final ValueChanged<T> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = accent ?? CprPalette.yellow;

    final Widget row = Row(
      children: <Widget>[
        for (final T item in items)
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => onChanged(item),
                child: AnimatedContainer(
                  duration: CprMotion.hover,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item == value
                        ? CprPalette.veil(accentColor, 0.14)
                        : CprPalette.surfaceSunken,
                    border: Border.all(
                      color: item == value ? accentColor : CprPalette.hairline,
                    ),
                  ),
                  child: Text(
                    labelOf(item).toUpperCase(),
                    style: CprType.label.copyWith(
                      fontSize: 10,
                      color: item == value ? accentColor : CprPalette.inkMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    // `Expanded` significa "riempi lo spazio che avanza". In una Row un figlio
    // non flessibile riceve larghezza **illimitata**, e una Row con figli
    // flessibili sotto un vincolo illimitato non e' impaginabile: solleva
    // un'eccezione invece di adattarsi. E' per questo che le impostazioni
    // facevano cadere l'applicazione — il selettore Attivo/Spento sta accanto a
    // un'etichetta, non dentro una colonna.
    //
    // Con la larghezza limitata il controllo la occupa, che e' l'aspetto voluto
    // nelle colonne della scheda; senza, si stringe sul contenuto tenendo i
    // segmenti **della stessa larghezza** (quella dell'etichetta piu' lunga),
    // perche' segmenti di misure diverse non si leggono piu' come una scelta
    // sola.
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          constraints.hasBoundedWidth ? row : IntrinsicWidth(child: row),
    );
  }
}

/// Riquadro di testo multiriga con etichetta.
class TechTextArea extends StatelessWidget {
  const TechTextArea({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.lines = 4,
    this.accent,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final int lines;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return TechField(
      label: label,
      value: value,
      onChanged: onChanged,
      hint: hint,
      maxLines: lines,
      accent: accent,
    );
  }
}

/// Intestazione di sezione dentro una schermata.
class TechSection extends StatelessWidget {
  const TechSection({
    super.key,
    required this.title,
    required this.children,
    this.accent,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Color? accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color accentColor = accent ?? CprPalette.yellow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(width: 3, height: 13, color: accentColor),
            const SizedBox(width: 8),
            // Il titolo prende lo spazio che avanza invece di reclamare la sua
            // larghezza naturale. Senza `Expanded`, un titolo lungo come
            // "PROGRAMMI DIFENSIVI ATTIVI" accanto a un pulsante sfonda la riga
            // e la sezione va in overflow.
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: CprType.label.copyWith(color: accentColor),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

/// Riquadro decorativo con angoli tagliati, per i contenuti liberi.
class TechWell extends StatelessWidget {
  const TechWell({super.key, required this.child, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ChamferPainter(cut: 10, fill: CprPalette.surfaceSunken),
      foregroundPainter: ChamferPainter(cut: 10, stroke: CprPalette.hairline),
      child: ClipPath(
        clipper: const ChamferClipper(cut: 10),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
