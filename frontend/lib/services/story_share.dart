import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Puente con el intent nativo de Instagram Stories.
///
/// Instagram no acepta la story por el share sheet del sistema: hay que
/// mandarle `com.instagram.share.ADD_TO_STORY` con un content:// que le
/// hayamos dado permiso de leer. Eso vive en MainActivity.kt.
///
/// Todo lo de acá devuelve false en vez de tirar: si Instagram no está,
/// la app cae al share sheet normal.
class StoryShare {
  static const MethodChannel _channel = MethodChannel('com.looped.app/story');

  /// Guarda el PNG de la story en el cache para poder pasárselo a otra app.
  ///
  /// Siempre el mismo nombre: la story anterior no tiene por qué sobrevivir.
  static Future<File> writeTempStory(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/looped_story.png');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static Future<bool> isInstagramInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isInstagramInstalled') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      // iOS todavía no implementa el canal.
      return false;
    }
  }

  /// Abre Instagram con la imagen ya cargada como fondo de la story.
  ///
  /// [topColor]/[bottomColor] son el degradé que Instagram pinta detrás si la
  /// imagen no cubre toda la pantalla. Devuelve false si no pudo abrirlo.
  static Future<bool> shareToInstagramStory(
    File image, {
    String topColor = '#000000',
    String bottomColor = '#00D9A5',
  }) async {
    try {
      final ok = await _channel.invokeMethod<bool>('shareToInstagramStory', {
        'path': image.path,
        'topColor': topColor,
        'bottomColor': bottomColor,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
