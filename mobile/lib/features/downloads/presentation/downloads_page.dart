import 'package:anatomy_atlas/core/downloads/content_package.dart';
import 'package:anatomy_atlas/core/downloads/download_manager.dart';
import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});
  @override ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  bool working = false;
  String? error;
  static const baseUrl = String.fromEnvironment('CONTENT_PACKAGE_BASE_URL');
  late final package = ContentPackage(
    packageId: 'cardiovascular-ar-v1',
    version: 1,
    locale: 'ar',
    size: 24500000,
    checksum: const String.fromEnvironment('CARDIOVASCULAR_PACKAGE_SHA256', defaultValue: 'configure-sha256'),
    minimumAppVersion: '1.0.0',
    downloadUrl: baseUrl.isEmpty ? '' : '$baseUrl/cardiovascular-ar-v1.zip',
  );

  @override Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(child: ListView(padding: const EdgeInsets.all(18), children: [
      Text(l10n.downloads, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text('Versioned manifests · resume · SHA-256 · rollback', style: Theme.of(context).textTheme.bodySmall),
      if (error != null) Padding(padding: const EdgeInsets.only(top: 14), child: MaterialBanner(content: Text(error!), actions: [TextButton(onPressed: () => setState(() => error = null), child: const Text('إغلاق'))])),
      const SizedBox(height: 18),
      const _PackageCard(title: 'الحزمة الأساسية', subtitle: 'القلب، أجهزة مختارة، بحث عربي/إنجليزي، صور مصغرة', size: 'مضمّنة في التطبيق', installed: true),
      const SizedBox(height: 12),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const CircleAvatar(child: Icon(Icons.favorite_outline)), const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الجهاز القلبي الوعائي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), Text('نماذج عالية الدقة، دروس، أمراض، واختبارات')]))]),
        const SizedBox(height: 16),
        const LinearProgressIndicator(value: 0),
        const SizedBox(height: 8),
        const Text('24.5 MB · العربية · الإصدار 1'),
        const SizedBox(height: 14),
        Wrap(spacing: 9, children: [
          FilledButton.icon(onPressed: working ? null : () async { setState(() { working = true; error = null; }); try { await ref.read(downloadManagerProvider).download(package); } catch (value) { if (mounted) setState(() => error = value.toString()); } finally { if (mounted) setState(() => working = false); } }, icon: const Icon(Icons.download), label: Text(working ? 'جارٍ التنزيل…' : l10n.downloadCore)),
          OutlinedButton.icon(onPressed: () => ref.read(downloadManagerProvider).pause(package), icon: const Icon(Icons.pause), label: const Text('إيقاف مؤقت')),
        ]),
        if (baseUrl.isEmpty) const Padding(padding: EdgeInsets.only(top: 10), child: Text('اضبط CONTENT_PACKAGE_BASE_URL وCARDIOVASCULAR_PACKAGE_SHA256 لتفعيل التنزيل الفعلي.', style: TextStyle(fontSize: 11))),
      ]))),
    ]));
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({required this.title, required this.subtitle, required this.size, required this.installed});
  final String title, subtitle, size; final bool installed;
  @override Widget build(BuildContext context) => Card(child: ListTile(contentPadding: const EdgeInsets.all(18), leading: CircleAvatar(child: Icon(installed ? Icons.offline_pin : Icons.download_outlined)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('$subtitle\n$size'), isThreeLine: true, trailing: installed ? const Icon(Icons.check_circle, color: Colors.green) : null));
}
