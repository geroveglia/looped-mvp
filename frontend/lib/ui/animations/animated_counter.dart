import 'package:flutter/material.dart';

/// Contador que recorre la diferencia hasta el valor nuevo en vez de saltar.
///
/// El podómetro de Android entrega los pasos en tandas: el contador puede
/// pasar de 23 a 59 de un frame al otro. Verlo subir se lee como "se puso al
/// día"; verlo teletransportarse se lee como que la app contó mal.
class AnimatedCounter extends StatefulWidget {
  final int value;
  final TextStyle style;

  /// Formato opcional del número (por ejemplo, separador de miles).
  final String Function(int)? format;
  final Duration duration;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.format,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _count;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.duration);
    _count = AlwaysStoppedAnimation(widget.value.toDouble());
    // Un pulso que vuelve solo, para que el salto se note sin quedar grande.
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 3),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      // Arranca desde donde se esté mostrando ahora: si entra un valor nuevo
      // con la animación a mitad de camino, sigue de ahí sin dar un tirón.
      _count = Tween<double>(
        begin: _count.value,
        end: widget.value.toDouble(),
      ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(_controller);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final shown = _count.value.round();
        return Transform.scale(
          scale: _scale.value,
          child: Text(
            widget.format?.call(shown) ?? '$shown',
            style: widget.style,
          ),
        );
      },
    );
  }
}
