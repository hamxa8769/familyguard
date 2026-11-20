import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// FamilyGuard design tokens.
///
/// One accent (electric blue) plus three meaning colours that are used for
/// nothing else: safe (teal), warn (amber), danger (red). Surfaces are flat —
/// no blur or glass — so the UI stays fast on low-end Android phones.
@immutable
class FgColors extends ThemeExtension<FgColors> {
  const FgColors({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
    required this.safe,
    required this.warn,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surfaceHigh;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color accent;
  final Color safe;
  final Color warn;
  final Color danger;

  static const dark = FgColors(
    bg: Color(0xFF080C12),
    surface: Color(0xFF10161F),
    surfaceHigh: Color(0xFF17202C),
    border: Color(0xFF223042),
    text: Color(0xFFE8EEF7),
    textMuted: Color(0xFF8A99AE),
    accent: Color(0xFF4C8DFF),
    safe: Color(0xFF1FC7A6),
    warn: Color(0xFFF5A524),
    danger: Color(0xFFFF4D5E),
  );

  static const light = FgColors(
    bg: Color(0xFFF4F6FA),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFEDF1F7),
    border: Color(0xFFDDE4EE),
    text: Color(0xFF0B1220),
    textMuted: Color(0xFF5B677A),
    accent: Color(0xFF2563EB),
    safe: Color(0xFF0E9F87),
    warn: Color(0xFFB97100),
    danger: Color(0xFFE0283C),
  );

  static FgColors of(BuildContext context) =>
      Theme.of(context).extension<FgColors>() ?? dark;

  /// Soft tint of a colour for chips, banners and icon wells.
  Color tint(Color c) => c.withValues(alpha: 0.14);

  @override
  FgColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceHigh,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? accent,
    Color? safe,
    Color? warn,
    Color? danger,
  }) =>
      FgColors(
        bg: bg ?? this.bg,
        surface: surface ?? this.surface,
        surfaceHigh: surfaceHigh ?? this.surfaceHigh,
        border: border ?? this.border,
        text: text ?? this.text,
        textMuted: textMuted ?? this.textMuted,
        accent: accent ?? this.accent,
        safe: safe ?? this.safe,
        warn: warn ?? this.warn,
        danger: danger ?? this.danger,
      );

  @override
  FgColors lerp(ThemeExtension<FgColors>? other, double t) {
    if (other is! FgColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return FgColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      border: l(border, other.border),
      text: l(text, other.text),
      textMuted: l(textMuted, other.textMuted),
      accent: l(accent, other.accent),
      safe: l(safe, other.safe),
      warn: l(warn, other.warn),
      danger: l(danger, other.danger),
    );
  }
}

/// Spacing and radius scale — use these instead of ad-hoc numbers.
class FgSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const radius = 18.0;
  static const radiusSm = 12.0;
}

class AppTheme {
  static ThemeData dark() => _build(FgColors.dark, Brightness.dark);
  static ThemeData light() => _build(FgColors.light, Brightness.light);

  static ThemeData _build(FgColors c, Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: c.accent, brightness: b)
        .copyWith(
      primary: c.accent,
      onPrimary: Colors.white,
      surface: c.surface,
      onSurface: c.text,
      onSurfaceVariant: c.textMuted,
      error: c.danger,
      outline: c.border,
      outlineVariant: c.border,
      surfaceContainerHighest: c.surfaceHigh,
      surfaceContainerHigh: c.surfaceHigh,
      surfaceContainer: c.surface,
      secondaryContainer: c.tint(c.accent),
      onSecondaryContainer: c.text,
      errorContainer: c.tint(c.danger),
      onErrorContainer: c.danger,
    );
    final base = ThemeData(useMaterial3: true, brightness: b);
    final text = base.textTheme.apply(bodyColor: c.text, displayColor: c.text);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.5),
        titleLarge: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3),
        titleMedium:
            text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        foregroundColor: c.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: c.text,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.4,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FgSpace.radius),
          side: BorderSide(color: c.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.tint(c.accent),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w400,
              color: s.contains(WidgetState.selected) ? c.text : c.textMuted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? c.accent : c.textMuted,
            )),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      listTileTheme: ListTileThemeData(iconColor: c.textMuted),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgSpace.radiusSm),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgSpace.radiusSm),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgSpace.radiusSm),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FgSpace.radiusSm)),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.surfaceHigh,
        side: BorderSide(color: c.border),
        shape: const StadiumBorder(),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FgSpace.radiusSm)),
      ),
      // One consistent, GPU-cheap transition on every platform.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.windows: ZoomPageTransitionsBuilder(),
        TargetPlatform.linux: ZoomPageTransitionsBuilder(),
        TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
