import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../services/story_share.dart';
import '../ui/app_theme.dart';
import 'splash_screen.dart' show InfinityLogoPainter;

/// Ancho del lienzo logico del sticker.
const double _canvasWidth = 360;

/// 360 * 3 = 1080, el ancho nativo de una story.
const double _canvasPixelRatio = 3.0;

class _StoryStat {
  final String id;
  final String label;
  final String value;
  final String unit;

  const _StoryStat(this.id, this.label, this.value, {this.unit = ''});
}

/// Arma el sticker de stats que se manda a Instagram Stories, como hace Strava.
///
/// No tocamos la foto: exportamos un PNG **transparente** con las metricas y se
/// lo pasamos a Instagram como `interactive_asset_uri`. La historia la arma el
/// usuario dentro de Instagram, con su foto del recital atras y el sticker
/// donde quiera moverlo.
///
/// El sticker se dibuja siempre en un lienzo logico de 360 de ancho y se captura
/// a pixelRatio 3 => 1080 reales, asi sale igual en cualquier telefono.
class ShareStoryScreen extends StatefulWidget {
  final Map<String, dynamic> stats;
  final String? eventName;

  const ShareStoryScreen({
    super.key,
    required this.stats,
    this.eventName,
  });

  @override
  State<ShareStoryScreen> createState() => _ShareStoryScreenState();
}

class _ShareStoryScreenState extends State<ShareStoryScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();

  bool _busy = false;
  /// Solo para el preview: deja probar como se lee el sticker sobre una foto
  /// clara o una oscura. No se captura.
  bool _lightBackdrop = false;

  late final List<_StoryStat> _allStats;
  late final Set<String> _visible;
  late final List<double> _intensities;

  @override
  void initState() {
    super.initState();
    _allStats = _buildStats();
    _intensities = _readIntensities();
    // Arrancamos mostrando todo lo que tenga un valor real, hasta 6: mas que
    // eso y el sticker tapa media foto.
    _visible = _allStats.where(_hasValue).take(6).map((s) => s.id).toSet();
    // Los puntos siempre van, aunque la sesion haya sido de cero.
    _visible.add('points');
  }

  // ----------------------------------------------------------------- datos

  bool _hasValue(_StoryStat s) {
    final digits = s.value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isNotEmpty && int.parse(digits) != 0;
  }

  List<double> _readIntensities() {
    final motion = widget.stats['motion_stats'] as Map<String, dynamic>?;
    final raw = motion?['intensity_history'] as List<dynamic>? ?? const [];
    return raw.whereType<num>().map((v) => v.toDouble()).toList();
  }

  List<_StoryStat> _buildStats() {
    final stats = widget.stats;
    final motion = stats['motion_stats'] as Map<String, dynamic>?;

    final points = (stats['points'] as num?)?.toInt() ?? 0;
    final durationSec =
        ((stats['duration_seconds'] ?? stats['duration_sec'] ?? 0) as num)
            .toInt();

    return [
      _StoryStat('points', 'PUNTOS', _formatNumber(points)),
      _StoryStat('duration', 'DURACION', _formatDuration(durationSec)),
      _StoryStat(
        'steps',
        'PASOS',
        _formatNumber(int.tryParse('${stats['steps'] ?? 0}') ?? 0),
      ),
      _StoryStat('calories', 'CALORIAS', '${stats['calories'] ?? 0}',
          unit: 'cal'),
      _StoryStat('distance', 'DISTANCIA', '${stats['distanceKm'] ?? '0.00'}',
          unit: 'km'),
      _StoryStat('speed', 'VEL. MEDIA', '${stats['speedKmh'] ?? '0.0'}',
          unit: 'km/h'),
      _StoryStat('pace', 'RITMO', '${stats['pace'] ?? '0'}', unit: 'min/km'),
      _StoryStat('elevation', 'ELEVACION', '${stats['elevation'] ?? 0}',
          unit: 'm'),
      _StoryStat(
        'intensity',
        'INTENSIDAD MAX',
        '${(motion?['max_intensity'] as num?)?.toInt() ?? 0}',
      ),
      _StoryStat('pps', 'PUNTOS/MIN', _pointsPerMinute(points, durationSec)),
    ];
  }

  static String _formatNumber(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
      buffer.write(s[i]);
    }
    return buffer.toString();
  }

  static String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final mm = ((seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  static String _pointsPerMinute(int points, int seconds) {
    if (seconds <= 0) return '0';
    return (points / (seconds / 60)).toStringAsFixed(0);
  }

  // --------------------------------------------------------------- acciones

  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      // El RepaintBoundary se rasteriza a su tamano de layout por el pixelRatio,
      // sin importar cuanto lo achique el FittedBox del preview. Como no hay
      // ningun color de fondo pintado, el PNG conserva el alfa.
      final Uint8List? bytes =
          await _screenshotController.capture(pixelRatio: _canvasPixelRatio);
      if (bytes == null) {
        _toast('No se pudo generar la imagen');
        return;
      }
      final file = await StoryShare.writeTempStory(bytes);
      final hasInstagram = await StoryShare.isInstagramInstalled();
      if (!mounted) return;
      _openShareSheet(file, hasInstagram: hasInstagram);
    } catch (e) {
      _toast('Error al preparar: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _systemShare(File file) async {
    try {
      final points = widget.stats['points'] ?? 0;
      final event = widget.eventName ?? 'Dance Session';
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'Hice $points puntos en $event! 🎵🕺 #LoopedApp',
      );
    } catch (e) {
      _toast('Error al compartir: $e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ------------------------------------------------------------ share sheet

  void _openShareSheet(File file, {required bool hasInstagram}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.share, color: AppTheme.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'COMPARTIR SESION',
                    style: AppTheme.labelLarge.copyWith(
                      color: Colors.white,
                      letterSpacing: 2,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (hasInstagram) ...[
                _sheetOption(
                  title: 'Instagram Stories',
                  subtitle: 'Se abre tu historia con el sticker puesto',
                  icon: Icons.camera_alt,
                  borderColor: const Color(0xFFC13584),
                  gradient: const [
                    Color(0xFFFCAF45),
                    Color(0xFFE1306C),
                    Color(0xFFC13584),
                  ],
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final ok = await StoryShare.shareToInstagramStory(file);
                    // Instagram puede rechazar el intent (version vieja, o una
                    // cuenta sin stories). No dejamos al usuario sin salida.
                    if (!ok) await _systemShare(file);
                  },
                ),
                const SizedBox(height: 16),
              ],
              _sheetOption(
                title: 'Otras aplicaciones',
                subtitle: 'WhatsApp, feed de Instagram, X, Mensajes...',
                icon: Icons.grid_view_rounded,
                borderColor: AppTheme.accent,
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _systemShare(file);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _sheetOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color borderColor,
    required Future<void> Function() onTap,
    List<Color>? gradient,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: gradient == null ? AppTheme.accent.withOpacity(0.08) : null,
            gradient: gradient == null
                ? null
                : LinearGradient(
                    colors: [
                      gradient.first.withOpacity(0.15),
                      gradient.last.withOpacity(0.15),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor.withOpacity(0.4), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      gradient == null ? AppTheme.accent.withOpacity(0.2) : null,
                  gradient: gradient == null
                      ? null
                      : LinearGradient(
                          colors: gradient,
                          begin: Alignment.bottomLeft,
                          end: Alignment.topRight,
                        ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: gradient == null ? AppTheme.accent : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- sticker

  /// Sombra bajo cada texto: es lo unico que sostiene la legibilidad cuando el
  /// sticker cae sobre una foto clara, porque atras no hay fondo propio.
  static const List<Shadow> _textShadows = [
    Shadow(color: Color(0xB3000000), blurRadius: 12, offset: Offset(0, 2)),
    Shadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
  ];

  Widget _buildSticker() {
    final visible =
        _allStats.where((s) => _visible.contains(s.id)).toList(growable: false);

    // Sin color de fondo en ningun lado: el PNG sale con alfa y en Instagram se
    // ve la foto del usuario a traves.
    return SizedBox(
      width: _canvasWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          if (widget.eventName != null) ...[
            Text(
              widget.eventName!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                shadows: _textShadows,
              ),
            ),
            const SizedBox(height: 18),
          ],
          _buildStatGrid(visible),
          if (_intensities.isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildIntensityStrip(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        CustomPaint(
          size: const Size(30, 15),
          painter: InfinityLogoPainter(
            progress: 1,
            color: Colors.white,
            strokeWidth: 3.4,
          ),
        ),
        const SizedBox(width: 9),
        const Text(
          'LOOPED',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.5,
            shadows: _textShadows,
          ),
        ),
      ],
    );
  }

  /// El equivalente al mapa de ruta de Strava: aca el "recorrido" es como subio
  /// y bajo la intensidad a lo largo de la sesion.
  Widget _buildIntensityStrip() {
    // Una sesion larga trae mas muestras de las que entran a lo ancho: las
    // promediamos en cubetas para que las barras sigan siendo legibles.
    final values = _bucket(_intensities, 34);
    final peak = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((v) {
          final factor = peak <= 0 ? 0.08 : (v / peak).clamp(0.08, 1.0);
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.4),
              child: Container(
                height: 40 * factor,
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x73000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static List<double> _bucket(List<double> values, int maxBars) {
    if (values.length <= maxBars) return values;
    final size = (values.length / maxBars).ceil();
    final out = <double>[];
    for (int i = 0; i < values.length; i += size) {
      final end = i + size < values.length ? i + size : values.length;
      final slice = values.sublist(i, end);
      out.add(slice.reduce((a, b) => a + b) / slice.length);
    }
    return out;
  }

  Widget _buildStatGrid(List<_StoryStat> visible) {
    if (visible.isEmpty) return const SizedBox.shrink();

    // Dos columnas, como la story de Strava.
    const columnGap = 22.0;
    const itemWidth = (_canvasWidth - columnGap) / 2;

    return Wrap(
      spacing: columnGap,
      runSpacing: 18,
      children: visible
          .map((s) => SizedBox(width: itemWidth, child: _buildStatItem(s)))
          .toList(),
    );
  }

  Widget _buildStatItem(_StoryStat stat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          stat.label,
          style: const TextStyle(
            color: Color(0xE6FFFFFF),
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
            shadows: _textShadows,
          ),
        ),
        const SizedBox(height: 3),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            children: [
              TextSpan(
                text: stat.value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  shadows: _textShadows,
                ),
              ),
              if (stat.unit.isNotEmpty)
                TextSpan(
                  text: ' ${stat.unit}',
                  style: const TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: _textShadows,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- editor

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'Compartir sesion',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Probar sobre fondo claro',
            icon: Icon(
              _lightBackdrop ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              color: Colors.white,
            ),
            onPressed: () => setState(() => _lightBackdrop = !_lightBackdrop),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildPreview()),
            const Padding(
              padding: EdgeInsets.fromLTRB(28, 12, 28, 0),
              child: Text(
                'La foto la ponés en Instagram: nosotros mandamos solo el sticker con tus stats.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              ),
            ),
            _buildStatToggles(),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  /// Muestra el sticker sobre un fondo de mentira, solo para ver como queda.
  /// El fondo vive fuera del Screenshot, asi que no entra en el PNG.
  Widget _buildPreview() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _lightBackdrop
                      ? const [Color(0xFFE9E2D6), Color(0xFFB9A88F)]
                      : const [Color(0xFF1B2430), Color(0xFF05070A)],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FittedBox(
                    child: Screenshot(
                      controller: _screenshotController,
                      child: _buildSticker(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatToggles() {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        itemCount: _allStats.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final stat = _allStats[i];
          final on = _visible.contains(stat.id);
          return GestureDetector(
            onTap: () => setState(() {
              if (on) {
                _visible.remove(stat.id);
              } else {
                _visible.add(stat.id);
              }
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on
                    ? AppTheme.accent.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: on
                      ? AppTheme.accent.withOpacity(0.6)
                      : Colors.white.withOpacity(0.12),
                ),
              ),
              child: Text(
                stat.label,
                style: TextStyle(
                  color: on ? AppTheme.accent : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: CtaButton(
        label: 'COMPARTIR',
        icon: Icons.ios_share,
        loading: _busy,
        onPressed: _busy ? null : _share,
      ),
    );
  }
}
