import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShakalApp());
}

class ShakalApp extends StatelessWidget {
  const ShakalApp({super.key});

  static const _fallbackSeed = Color(0xFF7B61FF);
  static const _appTitle = '\u0428\u041a\u041b';

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme =
            (lightDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: _fallbackSeed,
                      brightness: Brightness.light,
                    ))
                .harmonized();
        final darkScheme =
            (darkDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: _fallbackSeed,
                      brightness: Brightness.dark,
                    ))
                .harmonized();

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: _appTitle,
          theme: _buildTheme(lightScheme, Brightness.light),
          darkTheme: _buildTheme(darkScheme, Brightness.dark),
          home: const ShakalHomePage(),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Color.alphaBlend(
        scheme.primary.withValues(
          alpha: brightness == Brightness.light ? 0.05 : 0.12,
        ),
        scheme.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 14,
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primaryContainer.withValues(
          alpha: brightness == Brightness.light ? 0.72 : 0.42,
        ),
        thumbColor: scheme.onPrimary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: -1.8,
          height: 1.0,
        ),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ShakalHomePage extends StatefulWidget {
  const ShakalHomePage({super.key});

  @override
  State<ShakalHomePage> createState() => _ShakalHomePageState();
}

class _ShakalHomePageState extends State<ShakalHomePage> {
  static const _albumName = 'Zybuchiy Shakal';
  static const _pickPhoto =
      '\u0412\u044b\u0431\u0440\u0430\u0442\u044c \u0444\u043e\u0442\u043e';
  static const _changePhoto =
      '\u0421\u043c\u0435\u043d\u0438\u0442\u044c \u0444\u043e\u0442\u043e';
  static const _openGallery =
      '\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u0433\u0430\u043b\u0435\u0440\u0435\u044e';
  static const _replace = '\u0417\u0430\u043c\u0435\u043d\u0438\u0442\u044c';
  static const _process =
      '\u0417\u0410\u0428\u0410\u041a\u0410\u041b\u0418\u0422\u042c';
  static const _processing = '\u0428\u0410\u041a\u0410\u041b\u0418\u041c...';
  static const _save = '\u0421\u041e\u0425\u0420\u0410\u041d\u0418\u0422\u042c';
  static const _saving =
      '\u0421\u041e\u0425\u0420\u0410\u041d\u042f\u0415\u041c...';

  final ImagePicker _picker = ImagePicker();

  Uint8List? _sourceBytes;
  Uint8List? _processedBytes;
  String? _fileName;
  int? _sourceWidth;
  int? _sourceHeight;
  int? _processedWidth;
  int? _processedHeight;
  double _quality = 48;
  double _downscaleFactor = 2.4;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _needsRefresh = false;

  bool get _hasImage => _sourceBytes != null;
  Uint8List? get _previewBytes => _processedBytes ?? _sourceBytes;
  String get _qualityLabel => '${_quality.round()}%';
  String get _downscaleLabel => 'x${_downscaleFactor.toStringAsFixed(1)}';
  String get _sourceSizeLabel => _dimensionsLabel(_sourceWidth, _sourceHeight);
  String get _processedSizeLabel =>
      _dimensionsLabel(_processedWidth, _processedHeight);

  static String _dimensionsLabel(int? width, int? height) {
    if (width == null || height == null) {
      return '\u0411\u0435\u0437 \u0440\u0430\u0437\u043c\u0435\u0440\u0430';
    }
    return '${width}x$height';
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) {
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        _showSnack(
          '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c '
          '\u043f\u0440\u043e\u0447\u0438\u0442\u0430\u0442\u044c '
          '\u0432\u044b\u0431\u0440\u0430\u043d\u043d\u043e\u0435 '
          '\u0438\u0437\u043e\u0431\u0440\u0430\u0436\u0435\u043d\u0438\u0435.',
        );
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _sourceBytes = bytes;
        _processedBytes = null;
        _fileName = pickedFile.name;
        _sourceWidth = decoded.width;
        _sourceHeight = decoded.height;
        _processedWidth = null;
        _processedHeight = null;
        _needsRefresh = false;
      });

      _showSnack(
        '\u0424\u043e\u0442\u043e \u0437\u0430\u0433\u0440\u0443\u0436\u0435\u043d\u043e. '
        '\u0422\u0435\u043f\u0435\u0440\u044c \u043c\u043e\u0436\u043d\u043e '
        '\u0437\u0430\u0448\u0430\u043a\u0430\u043b\u0438\u0442\u044c.',
      );
    } catch (_) {
      _showSnack(
        '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c '
        '\u043e\u0442\u043a\u0440\u044b\u0442\u044c \u0433\u0430\u043b\u0435\u0440\u0435\u044e.',
      );
    }
  }

  Future<void> _processImage() async {
    if (_sourceBytes == null) {
      _showSnack(
        '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 '
        '\u0432\u044b\u0431\u0435\u0440\u0438\u0442\u0435 \u0444\u043e\u0442\u043e.',
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final decoded = img.decodeImage(_sourceBytes!);
      if (decoded == null) {
        throw const FormatException('decode failed');
      }

      final targetWidth = math.max(
        1,
        (decoded.width / _downscaleFactor).round(),
      );
      final targetHeight = math.max(
        1,
        (decoded.height / _downscaleFactor).round(),
      );

      final resized = _downscaleFactor > 1.01
          ? img.copyResize(
              decoded,
              width: targetWidth,
              height: targetHeight,
              interpolation: _downscaleFactor >= 2.5
                  ? img.Interpolation.nearest
                  : img.Interpolation.linear,
            )
          : decoded;

      final jpgBytes = Uint8List.fromList(
        img.encodeJpg(resized, quality: math.max(1, _quality.round())),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _processedBytes = jpgBytes;
        _processedWidth = resized.width;
        _processedHeight = resized.height;
        _needsRefresh = false;
      });

      _showSnack(
        '\u0428\u0430\u043a\u0430\u043b\u0438\u0437\u0430\u0446\u0438\u044f '
        '\u0437\u0430\u0432\u0435\u0440\u0448\u0435\u043d\u0430.',
      );
    } catch (_) {
      _showSnack(
        '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c '
        '\u043e\u0431\u0440\u0430\u0431\u043e\u0442\u0430\u0442\u044c '
        '\u0438\u0437\u043e\u0431\u0440\u0430\u0436\u0435\u043d\u0438\u0435.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _saveImage() async {
    if (_processedBytes == null) {
      _showSnack(
        '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u0430\u0436\u043c\u0438\u0442\u0435 '
        '\u00ab$_process\u00bb.',
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final hasAccess = await Gal.requestAccess(toAlbum: true);
      if (!hasAccess) {
        _showSnack(
          '\u041d\u0435\u0442 \u0434\u043e\u0441\u0442\u0443\u043f\u0430 '
          '\u043a \u0433\u0430\u043b\u0435\u0440\u0435\u0435.',
        );
        return;
      }

      final imageName = 'shakal_${DateTime.now().millisecondsSinceEpoch}';
      await Gal.putImageBytes(
        _processedBytes!,
        album: _albumName,
        name: imageName,
      );

      if (!mounted) {
        return;
      }

      _showSnack(
        '\u0418\u0437\u043e\u0431\u0440\u0430\u0436\u0435\u043d\u0438\u0435 '
        '\u0441\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u043e '
        '\u0432 \u0433\u0430\u043b\u0435\u0440\u0435\u044e.',
      );
    } catch (_) {
      _showSnack(
        '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c '
        '\u0441\u043e\u0445\u0440\u0430\u043d\u0438\u0442\u044c '
        '\u0438\u0437\u043e\u0431\u0440\u0430\u0436\u0435\u043d\u0438\u0435.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _updateQuality(double value) {
    setState(() {
      _quality = value;
      _needsRefresh = _processedBytes != null;
    });
  }

  void _updateDownscale(double value) {
    setState(() {
      _downscaleFactor = value;
      _needsRefresh = _processedBytes != null;
    });
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final heroPurple = const Color(
      0xFFAC8FFF,
    ).harmonizeWith(colorScheme.primary);

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              Color.alphaBlend(
                heroPurple.withValues(alpha: 0.08),
                colorScheme.surface,
              ),
              Color.alphaBlend(
                colorScheme.primary.withValues(alpha: 0.06),
                colorScheme.surface,
              ),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeroHeader(onPickImage: _pickImage, hasImage: _hasImage),
                const SizedBox(height: 22),
                _PreviewCard(
                  imageBytes: _previewBytes,
                  fileName: _fileName,
                  originalSize: _sourceSizeLabel,
                  processedSize: _processedSizeLabel,
                  hasProcessedVersion: _processedBytes != null,
                  needsRefresh: _needsRefresh,
                  onPickImage: _pickImage,
                ),
                const SizedBox(height: 22),
                _SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SliderSection(
                        title: 'Compression Quality',
                        valueLabel: _qualityLabel,
                        caption:
                            '\u041d\u0438\u0436\u0435 \u043a\u0430\u0447\u0435\u0441\u0442\u0432\u043e JPG '
                            '\u2014 \u0431\u043e\u043b\u044c\u0448\u0435 '
                            '\u0430\u0440\u0442\u0435\u0444\u0430\u043a\u0442\u043e\u0432 '
                            '\u0438 \u0441\u0438\u043b\u044c\u043d\u0435\u0435 '
                            '\u0448\u0430\u043a\u0430\u043b-\u044d\u0444\u0444\u0435\u043a\u0442.',
                        value: _quality,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        onChanged: _updateQuality,
                      ),
                      const SizedBox(height: 18),
                      Divider(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.35,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SliderSection(
                        title: 'Downscale factor',
                        valueLabel: _downscaleLabel,
                        caption:
                            '\u0423\u043c\u0435\u043d\u044c\u0448\u0430\u0435\u0442 '
                            '\u0440\u0430\u0437\u0440\u0435\u0448\u0435\u043d\u0438\u0435 '
                            '\u043f\u0435\u0440\u0435\u0434 \u0441\u0436\u0430\u0442\u0438\u0435\u043c '
                            '\u0438 \u0434\u043e\u0431\u0430\u0432\u043b\u044f\u0435\u0442 '
                            '\u0445\u0430\u0440\u0430\u043a\u0442\u0435\u0440\u043d\u0443\u044e '
                            '\u043f\u0438\u043a\u0441\u0435\u043b\u0438\u0437\u0430\u0446\u0438\u044e.',
                        value: _downscaleFactor,
                        min: 1,
                        max: 8,
                        divisions: 70,
                        onChanged: _updateDownscale,
                      ),
                      if (_needsRefresh) ...[
                        const SizedBox(height: 18),
                        const _HintPill(
                          text:
                              '\u041d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0438 '
                              '\u0438\u0437\u043c\u0435\u043d\u0435\u043d\u044b. '
                              '\u041d\u0430\u0436\u043c\u0438\u0442\u0435 '
                              '\u00ab\u0417\u0410\u0428\u0410\u041a\u0410\u041b\u0418\u0422\u042c\u00bb, '
                              '\u0447\u0442\u043e\u0431\u044b \u043e\u0431\u043d\u043e\u0432\u0438\u0442\u044c '
                              '\u043f\u0440\u0435\u0432\u044c\u044e.',
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _processImage,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        child: _ButtonLabel(
                          text: _isProcessing ? _processing : _process,
                          busy: _isProcessing,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveImage,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: colorScheme.secondaryContainer,
                          foregroundColor: colorScheme.onSecondaryContainer,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                        child: _ButtonLabel(
                          text: _isSaving ? _saving : _save,
                          busy: _isSaving,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.onPickImage, required this.hasImage});

  final VoidCallback onPickImage;
  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final heroPurple = const Color(
      0xFF7A54FF,
    ).harmonizeWith(colorScheme.primary);
    final heroLavender = const Color(
      0xFFD8C4FF,
    ).harmonizeWith(colorScheme.primary);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              heroPurple.withValues(alpha: 0.92),
              colorScheme.primaryContainer,
            ),
            Color.alphaBlend(
              heroLavender.withValues(alpha: 0.95),
              colorScheme.tertiaryContainer,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: heroPurple.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '\u0428\u041a\u041b',
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              FilledButton.tonal(
                onPressed: onPickImage,
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.18),
                  foregroundColor: colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                ),
                child: Text(
                  hasImage
                      ? _ShakalHomePageState._changePhoto
                      : _ShakalHomePageState._pickPhoto,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\u041e\u0434\u043d\u043e\u0441\u0442\u0440\u0430\u043d\u0438\u0447\u043d\u044b\u0439 '
            '\u043a\u043e\u043c\u043f\u0440\u0435\u0441\u0441\u043e\u0440 '
            '\u0432 \u0434\u0443\u0445\u0435 \u043b\u0435\u0433\u0435\u043d\u0434\u0430\u0440\u043d\u043e\u0433\u043e '
            '\u0448\u0430\u043a\u0430\u043b-\u0440\u0435\u0436\u0438\u043c\u0430: '
            '\u0443\u043c\u0435\u043d\u044c\u0448\u0430\u0435\u043c '
            '\u0440\u0430\u0437\u0440\u0435\u0448\u0435\u043d\u0438\u0435, '
            '\u0434\u0430\u0432\u0438\u043c JPEG \u0438 \u043f\u043e\u043b\u0443\u0447\u0430\u0435\u043c '
            '\u0447\u0435\u0441\u0442\u043d\u044b\u0439 '
            '\u0438\u043d\u0442\u0435\u0440\u043d\u0435\u0442-\u0432\u0430\u0439\u0431.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimaryContainer.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.imageBytes,
    required this.fileName,
    required this.originalSize,
    required this.processedSize,
    required this.hasProcessedVersion,
    required this.needsRefresh,
    required this.onPickImage,
  });

  final Uint8List? imageBytes;
  final String? fileName;
  final String originalSize;
  final String processedSize;
  final bool hasProcessedVersion;
  final bool needsRefresh;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return _SurfaceCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: imageBytes == null
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primaryContainer.withValues(alpha: 0.22),
                        colorScheme.tertiaryContainer.withValues(alpha: 0.16),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.photo_size_select_large_rounded,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '\u041f\u0440\u0435\u0432\u044c\u044e '
                            '\u043f\u043e\u044f\u0432\u0438\u0442\u0441\u044f '
                            '\u0437\u0434\u0435\u0441\u044c',
                            style: theme.textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '\u0412\u044b\u0431\u0435\u0440\u0438\u0442\u0435 '
                            '\u0444\u043e\u0442\u043e \u0438\u0437 '
                            '\u0433\u0430\u043b\u0435\u0440\u0435\u0438 '
                            '\u0438 \u043d\u0430\u0441\u0442\u0440\u043e\u0439\u0442\u0435 '
                            '\u0443\u0440\u043e\u0432\u0435\u043d\u044c '
                            '\u0448\u0430\u043a\u0430\u043b\u0438\u0437\u0430\u0446\u0438\u0438.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 22),
                          FilledButton.tonal(
                            onPressed: onPickImage,
                            child: const Text(
                              _ShakalHomePageState._openGallery,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.memory(imageBytes!, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        children: [
                          _InfoChip(
                            text: hasProcessedVersion
                                ? '\u0417\u0430\u0448\u0430\u043a\u0430\u043b\u0435\u043d\u043e'
                                : '\u041e\u0440\u0438\u0433\u0438\u043d\u0430\u043b',
                          ),
                          const Spacer(),
                          _InfoChip(
                            text: hasProcessedVersion
                                ? processedSize
                                : originalSize,
                          ),
                        ],
                      ),
                    ),
                    if (fileName != null)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 16,
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface.withValues(
                                    alpha: 0.92,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  fileName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            FilledButton.tonal(
                              onPressed: onPickImage,
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                              ),
                              child: const Text(_ShakalHomePageState._replace),
                            ),
                          ],
                        ),
                      ),
                    if (needsRefresh)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: fileName != null ? 82 : 16,
                        child: const _HintPill(
                          text:
                              '\u0422\u0435\u043a\u0443\u0449\u0435\u0435 '
                              '\u043f\u0440\u0435\u0432\u044c\u044e '
                              '\u0435\u0449\u0435 \u043d\u0435 '
                              '\u043e\u0431\u043d\u043e\u0432\u043b\u0435\u043d\u043e '
                              '\u043d\u043e\u0432\u044b\u043c\u0438 '
                              '\u043d\u0430\u0441\u0442\u0440\u043e\u0439\u043a\u0430\u043c\u0438.',
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SliderSection extends StatelessWidget {
  const _SliderSection({
    required this.title,
    required this.valueLabel,
    required this.caption,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String title;
  final String valueLabel;
  final String caption;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.44),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                valueLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 14),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: valueLabel,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.24),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({required this.text, required this.busy});

  final String text;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: DefaultTextStyle.of(context).style.color,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(text, textAlign: TextAlign.center)),
      ],
    );
  }
}
