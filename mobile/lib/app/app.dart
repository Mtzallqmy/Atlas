import 'package:anatomy_atlas/app/router.dart';
import 'package:anatomy_atlas/app/theme/app_theme.dart';
import 'package:anatomy_atlas/features/settings/presentation/settings_controller.dart';
import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnatomyAtlasApp extends ConsumerWidget {
  const AnatomyAtlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Anatomy Atlas',
      routerConfig: router,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(settings.textScale),
          disableAnimations: settings.reducedMotion,
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
