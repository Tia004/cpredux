import 'package:flutter/material.dart';

import '../design/motion.dart';

/// Ingresso scaglionato di un elemento.
///
/// Il ritardo non e' un vezzo: quando una schermata complessa compare tutta
/// insieme, l'occhio non sa dove guardare. Scaglionando di 40-60 ms per
/// pannello si crea una gerarchia di lettura, dall'alto verso il basso, che e'
/// esattamente l'ordine in cui l'utente deve leggere la scheda.
///
/// Nota: l'animazione e' puramente visiva (`IgnorePointer` non serve, il
/// widget resta interattivo durante la transizione) perche' bloccare l'input
/// per 400 ms a ogni cambio di schermata e' percepito come lentezza, non come
/// eleganza.
class Entrance extends StatefulWidget {
  const Entrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 16),
    this.duration = CprMotion.normal,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _curve = CurvedAnimation(parent: _controller, curve: CprMotion.enter);
    _start();
  }

  Future<void> _start() async {
    if (widget.delay > Duration.zero) {
      await Future<void>.delayed(widget.delay);
      if (!mounted) return;
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (BuildContext context, Widget? child) => Opacity(
        opacity: _curve.value.clamp(0.0, 1.0),
        child: FractionalTranslation(
          translation: Offset(
            widget.offset.dx / 100 * (1 - _curve.value),
            widget.offset.dy / 100 * (1 - _curve.value),
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}
