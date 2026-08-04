import 'package:anatomy_atlas/features/settings/presentation/settings_controller.dart';
import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final controller = ref.read(settingsControllerProvider.notifier);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(l10n.settings, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          _SettingsSection(
            title: l10n.language,
            icon: Icons.language,
            children: [
              RadioListTile<Locale>(value: const Locale('ar'), groupValue: settings.locale, onChanged: (value) => value == null ? null : controller.setLocale(value), title: Text(l10n.arabic)),
              RadioListTile<Locale>(value: const Locale('en'), groupValue: settings.locale, onChanged: (value) => value == null ? null : controller.setLocale(value), title: Text(l10n.english)),
            ],
          ),
          _SettingsSection(
            title: l10n.theme,
            icon: Icons.palette_outlined,
            children: [
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(value: ThemeMode.system, label: Text(l10n.systemTheme), icon: const Icon(Icons.settings_brightness)),
                  ButtonSegment(value: ThemeMode.light, label: Text(l10n.lightTheme), icon: const Icon(Icons.light_mode_outlined)),
                  ButtonSegment(value: ThemeMode.dark, label: Text(l10n.darkTheme), icon: const Icon(Icons.dark_mode_outlined)),
                ],
                selected: {settings.themeMode},
                onSelectionChanged: (value) => controller.setThemeMode(value.first),
              ),
              const SizedBox(height: 18),
              Text('${Localizations.localeOf(context).languageCode == 'ar' ? 'حجم الخط' : 'Text size'}: ${(settings.textScale * 100).round()}%'),
              Slider(value: settings.textScale, min: .9, max: 1.6, divisions: 7, label: '${(settings.textScale * 100).round()}%', onChanged: controller.setTextScale),
            ],
          ),
          _SettingsSection(
            title: Localizations.localeOf(context).languageCode == 'ar' ? 'إمكانية الوصول والتنزيلات' : 'Accessibility and downloads',
            icon: Icons.accessibility_new,
            children: [
              SwitchListTile(value: settings.reducedMotion, onChanged: controller.setReducedMotion, title: Text(l10n.reducedMotion), secondary: const Icon(Icons.motion_photos_off_outlined)),
              SwitchListTile(value: settings.wifiOnly, onChanged: controller.setWifiOnly, title: Text(l10n.wifiOnly), secondary: const Icon(Icons.wifi)),
            ],
          ),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.privacy_tip_outlined), const SizedBox(width: 12), Expanded(child: Text(l10n.educationalDisclaimer, style: const TextStyle(height: 1.6)))]))),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 14),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icon), const SizedBox(width: 10), Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
        const SizedBox(height: 10),
        ...children,
      ]),
    ),
  );
}
