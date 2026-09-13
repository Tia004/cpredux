import 'package:flutter/material.dart';

import '../design/motion.dart';
import '../design/palette.dart';
import '../design/typography.dart';

/// Numero che si anima quando cambia, come i contatori del sito.
///
/// Perche' un widget dedicato invece di un semplice `Text`: su un foglio
/// personaggio i numeri cambiano in continuazione (danno, cura, peso, punti
/// spesa). Un numero che "salta" istantaneamente non comunica *quanto* e'
/// cambiato; uno che scorre e lampeggia nel colore giusto lo comunica senza
/// che l'occhio debba confrontare due schermate mentali.
class AnimatedNumber extends StatefulWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.duration = CprMotion.value,
    this.animateOnMount = true,
    this.format,
    this.upColor = CprPalette.success,
    this.downColor = CprPalette.danger,
  });

  final num value;
  final TextStyle? style;
  final Duration duration;

  /// Se true il primo valore viene contato da zero. Utile nei vitals, che
  /// devono "accendersi" quando apri la scheda.
  final bool animateOnMount;
  final String Function(num value)? format;
  final Color upColor;
  final Color downColor;

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> with TickerProviderStateMixin {
  late final AnimationController _value;
  late final AnimationController _flash;
  late double _from;
  late double _to;
  Color? _flashColor;

  @override
  void initState() {
    super.initState();
    _to = widget.value.toDouble();
    _from = widget.animateOnMount ? 0 : _to;
    _value = AnimationController(vsync: this, duration: widget.duration, value: _from == _to ? 1 : 0);
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 520), value: 1);
    if (_from != _to) _value.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      // Si riparte dal valore *attualmente disegnato*, non dal vecchio valore
      // target: senza questo, cambi rapidi (10 colpi in un turno) farebbero
      // saltare il contatore all'indietro prima di andare avanti.
      _from = _displayed;
      _to = widget.value.toDouble();
      _value.forward(from: 0);
      _flashColor = widget.value > oldWidget.value ? widget.upColor : widget.downColor;
      _flash.forward(from: 0);
    }
  }

  double get _displayed {
    final double t = widget.duration == Duration.zero ? 1 : _value.value;
    final double eased = CprMotion.enter.transform(t);
    return _from + (_to - _from) * eased;
  }

  @override
  void dispose() {
    _value.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle base = widget.style ?? CprType.numeral.copyWith(color: CprPalette.ink);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_value, _flash]),
      builder: (BuildContext context, _) {
        final double amount = 1 - CprMotion.enter.transform(_flash.value);
        final Color color = _flashColor == null || amount <= 0.01
            ? base.color ?? CprPalette.ink
            : Color.lerp(base.color ?? CprPalette.ink, _flashColor!, amount)!;

        final num shown = widget.value is int ? _displayed.round() : _displayed;
        final String text = widget.format?.call(shown) ?? shown.toString();

        return Transform.translate(
          offset: Offset(0, -2.5 * amount),
          child: Text(text, style: base.copyWith(color: color)),
        );
      },
    );
  }
}

/// Etichetta tecnica in maiuscolo, con eventuale unita' di misura.
class CprLabel extends StatelessWidget {
  const CprLabel(this.text, {super.key, this.color, this.units});

  final String text;
  final Color? color;
  final String? units;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Text(text.toUpperCase(), style: CprType.label.copyWith(color: color ?? CprPalette.inkFaint)),
        if (units != null) ...<Widget>[
          const SizedBox(width: 5),
          Text(units!, style: CprType.label.copyWith(color: color ?? CprPalette.inkFaint, letterSpacing: 0.6)),
        ],
      ],
    );
  }
}
