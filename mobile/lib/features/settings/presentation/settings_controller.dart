import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.locale = const Locale('ar'),
    this.themeMode = ThemeMode.system,
    this.textScale = 1,
    this.reducedMotion = false,
    this.wifiOnly = true,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final double textScale;
  final bool reducedMotion;
  final bool wifiOnly;

  AppSettings copyWith({Locale? locale, ThemeMode? themeMode, double? textScale, bool? reducedMotion, bool? wifiOnly}) => AppSettings(
    locale: locale ?? this.locale,
    themeMode: themeMode ?? this.themeMode,
    textScale: textScale ?? this.textScale,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    wifiOnly: wifiOnly ?? this.wifiOnly,
  );
}

final settingsControllerProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setLocale(Locale locale) => state = state.copyWith(locale: locale);
  void setThemeMode(ThemeMode mode) => state = state.copyWith(themeMode: mode);
  void setTextScale(double scale) => state = state.copyWith(textScale: scale);
  void setReducedMotion(bool value) => state = state.copyWith(reducedMotion: value);
  void setWifiOnly(bool value) => state = state.copyWith(wifiOnly: value);
}
