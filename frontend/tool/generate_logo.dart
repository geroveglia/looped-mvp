// Genera los PNG del logo que consume flutter_launcher_icons.
//
// No es un test: vive fuera de test/ para que `flutter test` no lo corra.
// Se ejecuta a mano cuando cambia el logo:
//
//   flutter test tool/generate_logo.dart
//   dart run flutter_launcher_icons
//
// Dibuja el mismo InfinityLogoPainter del splash, así el icono del launcher
// no es una copia hecha a ojo sino el logo real.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:looped_app/screens/splash_screen.dart';
import 'package:looped_app/ui/app_theme.dart';

/// Medidas del logo tal como lo dibuja el splash. El trazo se sale de la caja
/// media pincelada por lado, así que la caja real es un poco mas grande.
const Size _logoBox = Size(120, 60);
const double _strokeWidth = 10.0;

const int _size = 1024;

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('genera assets/logo.png y assets/logo_foreground.png', () async {
    // Icono completo (iOS y launchers viejos): fondo negro, como el splash.
    await _write(
      'assets/logo.png',
      background: AppTheme.background,
      logoWidthFraction: 0.68,
    );

    // Capa de frente del adaptive icon de Android: transparente. El launcher
    // recorta la capa con la mascara del sistema y ademas el XML generado le
    // mete un inset del 16%, asi que 0.65 de la capa deja el logo ocupando
    // ~2/3 del icono visible, holgado dentro de la zona segura.
    await _write(
      'assets/logo_foreground.png',
      background: null,
      logoWidthFraction: 0.65,
    );
  });
}

Future<void> _write(
  String path, {
  required Color? background,
  required double logoWidthFraction,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final canvasSize = Size(_size.toDouble(), _size.toDouble());

  if (background != null) {
    canvas.drawRect(Offset.zero & canvasSize, Paint()..color = background);
  }

  // El trazo redondeado desborda la caja del path media pincelada por lado.
  final drawnWidth = _logoBox.width + _strokeWidth;
  final drawnHeight = _logoBox.height + _strokeWidth;
  final scale = (_size * logoWidthFraction) / drawnWidth;

  canvas.save();
  canvas.translate(
    (_size - drawnWidth * scale) / 2,
    (_size - drawnHeight * scale) / 2,
  );
  canvas.scale(scale);
  // Corre el origen media pincelada para que el trazo entre entero.
  canvas.translate(_strokeWidth / 2, _strokeWidth / 2);

  InfinityLogoPainter(progress: 1.0).paint(canvas, _logoBox);
  canvas.restore();

  final image = await recorder.endRecording().toImage(_size, _size);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path);
  await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
  expect(await file.length(), greaterThan(0));
  // ignore: avoid_print
  print('escrito ${file.path} (${await file.length()} bytes)');
}
