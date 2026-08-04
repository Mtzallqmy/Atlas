import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l10n.appName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(l10n.educationalDisclaimer, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                ])),
                const CircleAvatar(child: Icon(Icons.person_outline)),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList.list(children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(gradient: LinearGradient(colors: [scheme.primaryContainer, scheme.surfaceContainerHighest])),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l10n.bodyExplorer, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Text(l10n.heartSummary, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.55)),
                      const SizedBox(height: 18),
                      FilledButton.icon(onPressed: () => context.go('/explore'), icon: const Icon(Icons.view_in_ar_outlined), label: Text(l10n.openExplorer)),
                    ])),
                    const SizedBox(width: 16),
                    Hero(tag: 'heart-image', child: Image.asset('assets/images/heart.webp', width: 130, height: 150, fit: BoxFit.contain)),
                  ]),
                ),
              ),
              const SizedBox(height: 22),
              Text(l10n.continueLearning, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => context.push('/organs/heart'),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(children: [
                      Container(width: 58, height: 58, decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(18)), child: const Icon(Icons.favorite, size: 30)),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.heart, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), Text(l10n.heartLatin, style: TextStyle(color: scheme.onSurfaceVariant)), const SizedBox(height: 8), const LinearProgressIndicator(value: .35)])),
                      const Icon(Icons.chevron_right),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(l10n.systems, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 700 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: const [
                  _SystemCard(icon: Icons.favorite_outline, ar: 'القلبي الوعائي', en: 'Cardiovascular'),
                  _SystemCard(icon: Icons.psychology_outlined, ar: 'العصبي', en: 'Nervous'),
                  _SystemCard(icon: Icons.air, ar: 'التنفسي', en: 'Respiratory'),
                  _SystemCard(icon: Icons.accessibility_new, ar: 'الهيكلي', en: 'Skeletal'),
                ],
              ),
              const SizedBox(height: 20),
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(Icons.verified_outlined, color: scheme.primary), const SizedBox(width: 12), Expanded(child: Text(l10n.aiDisabled, style: const TextStyle(height: 1.55)))]))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  const _SystemCard({required this.icon, required this.ar, required this.en});
  final IconData icon; final String ar; final String en;
  @override Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 30), const Spacer(), Text(ar, style: const TextStyle(fontWeight: FontWeight.w800)), Text(en, style: Theme.of(context).textTheme.bodySmall)])));
}
