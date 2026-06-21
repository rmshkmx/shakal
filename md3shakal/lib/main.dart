import 'dart:math' as math;
import 'dart:ui' show FontVariation, lerpDouble;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShakalApp());
}

class ShakalApp extends StatelessWidget {
  const ShakalApp({super.key});

  static const _fallbackSeed = Color(0xFFB59CFF);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme =
            lightDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.light,
            );
        final darkScheme =
            darkDynamic?.harmonized() ??
            ColorScheme.fromSeed(
              seedColor: _fallbackSeed,
              brightness: Brightness.dark,
            );
        final lightTheme = _buildTheme(lightScheme);
        final darkTheme = _buildTheme(darkScheme);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ШКЛ',
          theme: lightTheme,
          darkTheme: darkTheme,
          home: ShakalHomePage(lightTheme: lightTheme, darkTheme: darkTheme),
        );
      },
    );
  }

  ThemeData _buildTheme(ColorScheme scheme) {
    final brightness = scheme.brightness;

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      iconTheme: IconThemeData(color: scheme.primary),
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.4,
          height: 1.0,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -1.0,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.25),
      ),
    );
  }
}

class ShakalHomePage extends StatefulWidget {
  const ShakalHomePage({
    super.key,
    required this.lightTheme,
    required this.darkTheme,
  });

  final ThemeData lightTheme;
  final ThemeData darkTheme;

  @override
  State<ShakalHomePage> createState() => _ShakalHomePageState();
}

class _ShakalHomePageState extends State<ShakalHomePage>
    with TickerProviderStateMixin {
  static const _albumName = 'Zybuchiy Shakal';

  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = TrackingScrollController();

  late final AnimationController _themeRevealController;

  Uint8List? _sourceBytes;
  Uint8List? _processedBytes;
  String? _fileName;
  int? _sourceWidth;
  int? _sourceHeight;
  double _quality = 50;
  double _downscaleFactor = 5.2;
  bool _isProcessing = false;
  bool _isSaving = false;
  bool _needsRefresh = false;

  bool _isDark = true;
  bool _isRevealActive = false;
  bool _pendingDarkValue = false;
  Offset _revealCenter = Offset.zero;

  bool get _hasImage => _sourceBytes != null;
  Uint8List? get _previewBytes => _processedBytes ?? _sourceBytes;

  ThemeData get _activeTheme => _isDark ? widget.darkTheme : widget.lightTheme;

  ThemeData get _targetTheme =>
      _pendingDarkValue ? widget.darkTheme : widget.lightTheme;

  String get _qualityLabel => '${_quality.round()}%';

  String get _artifactLabel {
    if (_downscaleFactor < 2.4) {
      return 'Низкая';
    }
    if (_downscaleFactor < 4.4) {
      return 'Средняя';
    }
    if (_downscaleFactor < 6.4) {
      return 'Высокая';
    }
    return 'Жёсткая';
  }

  String get _previewBadge =>
      _processedBytes == null ? 'Оригинал' : 'Результат';

  String get _previewDimensions {
    if (_sourceWidth == null || _sourceHeight == null) {
      return 'Без размера';
    }
    final width = _processedBytes == null
        ? _sourceWidth!
        : math.max(1, (_sourceWidth! / _downscaleFactor).round());
    final height = _processedBytes == null
        ? _sourceHeight!
        : math.max(1, (_sourceHeight! / _downscaleFactor).round());
    return '${width}x$height';
  }

  @override
  void initState() {
    super.initState();
    _themeRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _themeRevealController.dispose();
    super.dispose();
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
        _showSnack('Не удалось прочитать выбранное изображение.');
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
        _needsRefresh = false;
      });

      _showSnack('Фото загружено.');
    } catch (_) {
      _showSnack('Не удалось открыть галерею.');
    }
  }

  Future<void> _processImage() async {
    if (_sourceBytes == null) {
      _showSnack('Сначала выбери фото.');
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
              interpolation: _downscaleFactor >= 4.8
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
        _needsRefresh = false;
      });

      _showSnack('Шакализация завершена.');
    } catch (_) {
      _showSnack('Не удалось обработать изображение.');
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
      _showSnack('Сначала нажми «Зашакалить».');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final hasAccess = await Gal.requestAccess(toAlbum: true);
      if (!hasAccess) {
        _showSnack('Нет доступа к галерее.');
        return;
      }

      await Gal.putImageBytes(
        _processedBytes!,
        album: _albumName,
        name: 'shkl_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) {
        return;
      }

      _showSnack('Изображение сохранено.');
    } catch (_) {
      _showSnack('Не удалось сохранить изображение.');
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

  Future<void> _toggleTheme(Offset globalPosition) async {
    if (_isRevealActive) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _revealCenter = renderBox.globalToLocal(globalPosition);
      _pendingDarkValue = !_isDark;
      _isRevealActive = true;
    });

    await _themeRevealController.forward(from: 0);
    if (!mounted) {
      return;
    }

    setState(() {
      _isDark = _pendingDarkValue;
      _isRevealActive = false;
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

  double _maxRevealRadius(Size size, Offset center) {
    final dx = math.max(center.dx, size.width - center.dx);
    final dy = math.max(center.dy, size.height - center.dy);
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _ThemedLayer(
              theme: _activeTheme,
              ignorePointer: false,
              child: _PageContent(
                scrollController: _scrollController,
                hasImage: _hasImage,
                previewBytes: _previewBytes,
                previewBadge: _previewBadge,
                previewDimensions: _previewDimensions,
                fileName: _fileName,
                quality: _quality,
                qualityLabel: _qualityLabel,
                downscaleFactor: _downscaleFactor,
                artifactLabel: _artifactLabel,
                isDark: _isDark,
                needsRefresh: _needsRefresh,
                onPickImage: _pickImage,
                onReplaceImage: _pickImage,
                onThemeTap: _toggleTheme,
                onQualityChanged: _updateQuality,
                onDownscaleChanged: _updateDownscale,
              ),
            ),
          ),
          if (_isRevealActive)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _themeRevealController,
                builder: (context, child) {
                  final radius = lerpDouble(
                    0,
                    _maxRevealRadius(size, _revealCenter),
                    Curves.easeOutCubic.transform(_themeRevealController.value),
                  )!;

                  return IgnorePointer(
                    child: ClipPath(
                      clipper: _CircularRevealClipper(
                        center: _revealCenter,
                        radius: radius,
                      ),
                      child: child,
                    ),
                  );
                },
                child: _ThemedLayer(
                  theme: _targetTheme,
                  ignorePointer: true,
                  child: _PageContent(
                    scrollController: _scrollController,
                    hasImage: _hasImage,
                    previewBytes: _previewBytes,
                    previewBadge: _previewBadge,
                    previewDimensions: _previewDimensions,
                    fileName: _fileName,
                    quality: _quality,
                    qualityLabel: _qualityLabel,
                    downscaleFactor: _downscaleFactor,
                    artifactLabel: _artifactLabel,
                    isDark: _pendingDarkValue,
                    needsRefresh: _needsRefresh,
                    onPickImage: _pickImage,
                    onReplaceImage: _pickImage,
                    onThemeTap: _toggleTheme,
                    onQualityChanged: _updateQuality,
                    onDownscaleChanged: _updateDownscale,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Theme(
        data: _activeTheme,
        child: _BottomActionBar(
          hasImage: _hasImage,
          isProcessing: _isProcessing,
          isSaving: _isSaving,
          onProcess: _processImage,
          onSave: _saveImage,
        ),
      ),
    );
  }
}

class _ThemedLayer extends StatelessWidget {
  const _ThemedLayer({
    required this.theme,
    required this.child,
    required this.ignorePointer,
  });

  final ThemeData theme;
  final Widget child;
  final bool ignorePointer;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: IgnorePointer(
        ignoring: ignorePointer,
        child: Material(color: theme.scaffoldBackgroundColor, child: child),
      ),
    );
  }
}

class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.scrollController,
    required this.hasImage,
    required this.previewBytes,
    required this.previewBadge,
    required this.previewDimensions,
    required this.fileName,
    required this.quality,
    required this.qualityLabel,
    required this.downscaleFactor,
    required this.artifactLabel,
    required this.isDark,
    required this.needsRefresh,
    required this.onPickImage,
    required this.onReplaceImage,
    required this.onThemeTap,
    required this.onQualityChanged,
    required this.onDownscaleChanged,
  });

  final ScrollController scrollController;
  final bool hasImage;
  final Uint8List? previewBytes;
  final String previewBadge;
  final String previewDimensions;
  final String? fileName;
  final double quality;
  final String qualityLabel;
  final double downscaleFactor;
  final String artifactLabel;
  final bool isDark;
  final bool needsRefresh;
  final Future<void> Function() onPickImage;
  final Future<void> Function() onReplaceImage;
  final ValueChanged<Offset> onThemeTap;
  final ValueChanged<double> onQualityChanged;
  final ValueChanged<double> onDownscaleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final buttonSize = size.width * 0.88;
    final buttonHeight = size.width * 1.0;
    final topGlow = isDark
        ? colorScheme.primary.withValues(alpha: 0.14)
        : colorScheme.primary.withValues(alpha: 0.10);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.95),
          radius: 1.3,
          colors: [topGlow, colorScheme.surface, colorScheme.surface],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'ШКЛ',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  _ThemeSwitchIconButton(isDark: isDark, onTapDown: onThemeTap),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Выбери фото, задай качество и выкрути артефакты до нужного уровня.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 520),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 0.92,
                          end: 1,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: hasImage
                      ? _PhotoPreviewStage(
                          key: const ValueKey('preview-stage'),
                          imageBytes: previewBytes!,
                          badge: previewBadge,
                          dimensions: previewDimensions,
                          fileName: fileName,
                          needsRefresh: needsRefresh,
                          onTap: onReplaceImage,
                        )
                      : SizedBox(
                          key: const ValueKey('picker-stage'),
                          width: buttonSize,
                          height: buttonHeight,
                          child: _MorphingPhotoButton(
                            onTap: onPickImage,
                            label: 'Выбрать фото',
                            accentColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 26),
              _ControlCard(
                title: 'Степень сжатия',
                badgeText: qualityLabel,
                badgeColor: colorScheme.primary.withValues(alpha: 0.18),
                badgeTextColor: colorScheme.primaryContainer,
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 36,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 16,
                          disabledThumbRadius: 16,
                        ),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                        activeTrackColor: colorScheme.primary,
                        inactiveTrackColor: colorScheme.surfaceContainerHighest,
                        thumbColor: colorScheme.onPrimary,
                        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
                        trackShape: const RoundedRectSliderTrackShape(),
                      ),
                      child: Slider(
                        value: quality / 100,
                        onChanged: (value) => onQualityChanged(value * 100),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Text(
                          'Минимум',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Максимум',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ControlCard(
                title: 'Интенсивность\nартефактов',
                badgeText: artifactLabel,
                badgeColor: colorScheme.secondaryContainer,
                badgeTextColor: colorScheme.onSecondaryContainer,
                child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 36,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 16,
                            disabledThumbRadius: 16,
                          ),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
                          activeTrackColor: colorScheme.secondary,
                          inactiveTrackColor: colorScheme.surfaceContainerHighest,
                          thumbColor: colorScheme.onSecondary,
                          overlayColor: colorScheme.secondary.withValues(alpha: 0.12),
                          trackShape: const RoundedRectSliderTrackShape(),
                        ),
                        child: Slider(
                          value: (downscaleFactor - 1) / 7,
                          onChanged: (value) => onDownscaleChanged(1 + value * 7),
                        ),
                      ),
              ),
              if (needsRefresh) ...[
                const SizedBox(height: 18),
                Text(
                  'Превью ещё не обновлено новыми настройками. Нажми «Зашакалить».',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.hasImage,
    required this.isProcessing,
    required this.isSaving,
    required this.onProcess,
    required this.onSave,
  });

  final bool hasImage;
  final bool isProcessing;
  final bool isSaving;
  final Future<void> Function() onProcess;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(22, 10, 22, hasImage ? 16 : 10),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.center,
            child: hasImage
                ? Row(
                    children: [
                      Expanded(
                        child: _BottomActionButton(
                          expanded: true,
                          icon: Icons.auto_fix_high_rounded,
                          label: isProcessing ? 'Шакалим...' : 'Зашакалить',
                          busy: isProcessing,
                          onPressed: isProcessing ? null : onProcess,
                          style: _BottomActionStyle.filled,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _BottomActionButton(
                          expanded: true,
                          icon: Icons.save_alt_rounded,
                          label: isSaving ? 'Сохраняем...' : 'Сохранить',
                          busy: isSaving,
                          onPressed: isSaving ? null : onSave,
                          style: _BottomActionStyle.tonal,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BottomActionButton(
                        expanded: false,
                        icon: Icons.auto_fix_high_rounded,
                        label: 'Зашакалить',
                        busy: isProcessing,
                        onPressed: isProcessing ? null : onProcess,
                        style: _BottomActionStyle.filled,
                      ),
                      const SizedBox(width: 12),
                      _BottomActionButton(
                        expanded: false,
                        icon: Icons.save_alt_rounded,
                        label: 'Сохранить',
                        busy: isSaving,
                        onPressed: isSaving ? null : onSave,
                        style: _BottomActionStyle.tonal,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

enum _BottomActionStyle { filled, tonal }

class _BottomActionButton extends StatelessWidget {
  const _BottomActionButton({
    required this.expanded,
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
    required this.style,
  });

  final bool expanded;
  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback? onPressed;
  final _BottomActionStyle style;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: expanded ? const Size.fromHeight(56) : const Size(52, 52),
      padding: EdgeInsets.symmetric(horizontal: expanded ? 18 : 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: style == _BottomActionStyle.filled
          ? colorScheme.primaryContainer
          : null,
      foregroundColor: style == _BottomActionStyle.filled
          ? colorScheme.onPrimaryContainer
          : null,
    );

    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: expanded
          ? _BusyLabel(
              key: ValueKey<String>('expanded-$label-$busy'),
              text: label,
              busy: busy,
              leading: Icon(icon),
            )
          : Icon(key: ValueKey<IconData>(icon), icon),
    );

    final button = style == _BottomActionStyle.filled
        ? FilledButton(onPressed: onPressed, style: buttonStyle, child: child)
        : FilledButton.tonal(
            onPressed: onPressed,
            style: buttonStyle,
            child: child,
          );

    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        width: expanded ? double.infinity : 52,
        height: expanded ? 58 : 52,
        child: button,
      ),
    );
  }
}

class _PhotoPreviewStage extends StatelessWidget {
  const _PhotoPreviewStage({
    super.key,
    required this.imageBytes,
    required this.badge,
    required this.dimensions,
    required this.fileName,
    required this.needsRefresh,
    required this.onTap,
  });

  final Uint8List imageBytes;
  final String badge;
  final String dimensions;
  final String? fileName;
  final bool needsRefresh;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = math.min(MediaQuery.sizeOf(context).width - 44, 340.0);

    return Semantics(
      button: true,
      label: 'Выбранное фото',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: width,
          height: width * 1.04,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.24),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                      ),
                      child: Image.memory(imageBytes, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              Positioned(top: 18, left: 18, child: _PreviewBadge(text: badge)),
              Positioned(
                top: 18,
                right: 18,
                child: _PreviewBadge(text: dimensions),
              ),
              Positioned(
                right: 18,
                bottom: 18,
                child: IconButton.filledTonal(
                  onPressed: onTap,
                  icon: const Icon(Icons.add_a_photo_outlined),
                ),
              ),
              if (fileName != null)
                Positioned(
                  left: 18,
                  right: 78,
                  bottom: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              if (needsRefresh)
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: fileName == null ? 78 : 68,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.92,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      'Фото на экране ещё не пересчитано.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewBadge extends StatelessWidget {
  const _PreviewBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ControlCard extends StatelessWidget {
  const _ControlCard({
    required this.title,
    required this.badgeText,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.child,
  });

  final String title;
  final String badgeText;
  final Color badgeColor;
  final Color badgeTextColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: 28,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: badgeTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          child,
        ],
      ),
    );
  }
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel({
    super.key,
    required this.text,
    required this.busy,
    this.leading,
  });

  final String text;
  final bool busy;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        if (busy) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(text)),
      ],
    );
  }
}

class _ThemeSwitchIconButton extends StatelessWidget {
  const _ThemeSwitchIconButton({required this.isDark, required this.onTapDown});

  final bool isDark;
  final ValueChanged<Offset> onTapDown;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (details) => onTapDown(details.globalPosition),
      child: IconButton.filledTonal(
        tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
        onPressed: () {},
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey<bool>(isDark),
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _MorphingPhotoButton extends StatefulWidget {
  const _MorphingPhotoButton({
    required this.onTap,
    required this.label,
    required this.accentColor,
    required this.foregroundColor,
  });

  final Future<void> Function() onTap;
  final String label;
  final Color accentColor;
  final Color foregroundColor;

  @override
  State<_MorphingPhotoButton> createState() => _MorphingPhotoButtonState();
}

class _MorphingPhotoButtonState extends State<_MorphingPhotoButton>
    with TickerProviderStateMixin {
  final _MorphPreset _chosenPreset =
      _MorphPreset.values[math.Random().nextInt(_MorphPreset.values.length)];

  late final AnimationController _rotationController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  )..repeat();

  late final AnimationController _pressController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );

  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void dispose() {
    _rotationController.dispose();
    _pressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    HapticFeedback.selectionClick();
    _pressController.forward(from: 0);
    _glowController.forward(from: 0);
    await widget.onTap();
    if (mounted) {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationController,
        _pressController,
        _glowController,
      ]),
      builder: (context, _) {
        final rotation = _rotationController.value * 2 * math.pi;
        final press = Curves.easeOutBack.transform(_pressController.value);
        final glow = Curves.easeOut.transform(1 - _glowController.value);
        final scale = 1 - 0.06 * press;

        return Semantics(
          button: true,
          label: widget.label,
          child: GestureDetector(
            onTap: _handleTap,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                IgnorePointer(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.85,
                        colors: [
                          widget.accentColor.withValues(alpha: 0.26 * glow),
                          widget.accentColor.withValues(alpha: 0.08 * glow),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Transform.scale(
                  scale: scale,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Transform.rotate(
                          angle: rotation,
                          child: CustomPaint(
                            painter: _StaticShapePainter(
                              preset: _chosenPreset,
                              fillColor: widget.accentColor,
                              outlineColor: widget.foregroundColor.withValues(
                                alpha: 0.18,
                              ),
                              shadowColor: widget.accentColor.withValues(
                                alpha: 0.34,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: Center(
                          child: Text(
                            widget.label.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.robotoFlex(
                              textStyle: TextStyle(
                                fontSize: 58,
                                color: widget.foregroundColor,
                                fontVariations: const [
                                  FontVariation('wght', 900),
                                  FontVariation('wdth', 150),
                                ],
                                height: 0.95,
                                letterSpacing: -1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _MorphPreset {
  circle,
  softSquare,
  rounded,
  verySunny,
  fourSidedCookie,
  scallop,
  blossom,
  gem,
}

class _StaticShapePainter extends CustomPainter {
  const _StaticShapePainter({
    required this.preset,
    required this.fillColor,
    required this.outlineColor,
    required this.shadowColor,
  });

  final _MorphPreset preset;
  final Color fillColor;
  final Color outlineColor;
  final Color shadowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildShapePath(size: size, preset: preset);

    canvas.drawShadow(path, shadowColor, 24, false);

    final rect = Offset.zero & size;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(Colors.white.withValues(alpha: 0.06), fillColor),
          fillColor,
          Color.alphaBlend(Colors.black.withValues(alpha: 0.07), fillColor),
        ],
      ).createShader(rect);

    final outlinePaint = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, outlinePaint);
  }

  Path _buildShapePath({required Size size, required _MorphPreset preset}) {
    const points = 96;
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = math.min(size.width, size.height) * 0.39;
    final path = Path();

    for (var index = 0; index <= points; index++) {
      final progress = index / points;
      final angle = -math.pi / 2 + progress * math.pi * 2;
      final radius = baseRadius * _radiusFor(preset, angle);
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();
    return path;
  }

  double _superellipseRadius(double angle, double exponent) {
    final cosine = math.cos(angle).abs();
    final sine = math.sin(angle).abs();
    return math
        .pow(
          math.pow(cosine, exponent) + math.pow(sine, exponent),
          -1 / exponent,
        )
        .toDouble();
  }

  double _radiusFor(_MorphPreset preset, double angle) {
    switch (preset) {
      case _MorphPreset.circle:
        return 1;
      case _MorphPreset.softSquare:
        return 0.92 * _superellipseRadius(angle, 4);
      case _MorphPreset.rounded:
        return 1.0 +
            0.08 * math.sin(2 * angle - 0.7) +
            0.06 * math.cos(3 * angle + 1.1);
      case _MorphPreset.verySunny:
        return 0.98 + 0.12 * math.cos(8 * angle) + 0.035 * math.cos(16 * angle);
      case _MorphPreset.fourSidedCookie:
        return 0.99 +
            0.10 * math.cos(4 * angle + math.pi / 4) -
            0.03 * math.cos(8 * angle);
      case _MorphPreset.scallop:
        return 0.98 +
            0.075 * math.cos(12 * angle) +
            0.025 * math.cos(24 * angle);
      case _MorphPreset.blossom:
        return 0.94 + 0.14 * math.cos(6 * angle);
      case _MorphPreset.gem:
        return 0.96 + 0.10 * math.cos(6 * angle) - 0.08 * math.cos(2 * angle);
    }
  }

  @override
  bool shouldRepaint(covariant _StaticShapePainter oldDelegate) {
    return oldDelegate.preset != preset ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.shadowColor != shadowColor;
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  const _CircularRevealClipper({required this.center, required this.radius});

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircularRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}
