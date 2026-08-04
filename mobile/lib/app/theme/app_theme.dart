import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seed = Color(0xFF225E50);
  static const _accent = Color(0xFFC28749);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: brightness == Brightness.light ? const Color(0xFFF4F7F5) : const Color(0xFF101815),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .55))),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)))),
      extensions: const [AtlasColors(accent: _accent)],
    );
  }
}

@immutable
class AtlasColors extends ThemeExtension<AtlasColors> {
  const AtlasColors({required this.accent});
  final Color accent;
  @override
  AtlasColors copyWith({Color? accent}) => AtlasColors(accent: accent ?? this.accent);
  @override
  AtlasColors lerp(covariant AtlasColors? other, double t) => AtlasColors(accent: Color.lerp(accent, other?.accent, t) ?? accent);
}
