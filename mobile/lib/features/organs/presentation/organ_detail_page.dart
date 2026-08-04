import 'package:anatomy_atlas/features/organs/domain/organ.dart';
import 'package:anatomy_atlas/features/organs/presentation/organ_providers.dart';
import 'package:anatomy_atlas/features/study/data/local_study_repository.dart';
import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrganDetailPage extends ConsumerWidget {
  const OrganDetailPage({required this.slug, super.key});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organ = ref.watch(organBySlugProvider(slug));
    final bookmark = ref.watch(bookmarkStateProvider(slug));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anatomy Atlas'),
        actions: [
          IconButton(
            tooltip: 'Bookmark',
            onPressed: () => ref.read(localStudyRepositoryProvider).toggleBookmark('organ', slug),
            icon: Icon(bookmark.valueOrNull == true ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(onPressed: () {}, icon: const Icon(Icons.share_outlined)),
        ],
      ),
      body: organ.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorState(error: error, onRetry: () => ref.invalidate(organBySlugProvider(slug))),
        data: (value) => value == null ? const Center(child: Text('Organ not found')) : _OrganContent(organ: value),
      ),
    );
  }
}

class _OrganContent extends ConsumerWidget {
  const _OrganContent({required this.organ});
  final Organ organ;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(noteStateProvider(organ.slug));
    final l10n = AppLocalizations.of(context);
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final name = ar ? organ.nameAr : organ.nameEn;
    final scheme = Theme.of(context).colorScheme;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Container(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [scheme.primaryContainer.withValues(alpha: .65), scheme.surface])),
        child: Column(children: [
          Hero(tag: 'heart-image', child: Image.asset(organ.fallbackAsset ?? 'assets/images/heart.webp', height: 220)),
          Text(name, style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
          Text('${organ.nameEn} · ${organ.latinName ?? ''}', style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Text(ar ? organ.summaryAr : organ.summaryEn, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.7)),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [Chip(avatar: const Icon(Icons.offline_pin, size: 16), label: Text(l10n.offlineAvailable)), const Chip(avatar: Icon(Icons.verified_outlined, size: 16), label: Text('Medically reviewed'))]),
        ]),
      )),
      SliverPadding(
        padding: const EdgeInsets.all(18),
        sliver: SliverList.list(children: [
          _Section(icon: Icons.monitor_heart_outlined, title: l10n.function, body: ar ? organ.functionAr : organ.functionEn),
          _Section(icon: Icons.location_on_outlined, title: l10n.location, body: ar ? organ.locationAr : organ.locationEn),
          _Section(icon: Icons.bloodtype_outlined, title: l10n.bloodSupply, body: ar ? organ.bloodSupplyAr : organ.bloodSupplyEn),
          _Section(icon: Icons.electric_bolt_outlined, title: l10n.innervation, body: ar ? organ.innervationAr : organ.innervationEn),
          _Section(icon: Icons.medical_information_outlined, title: l10n.clinicalImportance, body: ar ? organ.clinicalAr : organ.clinicalEn),
          Card(
            child: ListTile(
              leading: const Icon(Icons.note_alt_outlined),
              title: Text(ar ? 'ملاحظتي' : 'My note'),
              subtitle: Text(note.valueOrNull?.isNotEmpty == true ? note.valueOrNull! : (ar ? 'أضف ملاحظة شخصية محفوظة محليًا' : 'Add a private note stored locally')),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editNote(context, ref, organ.slug, note.valueOrNull ?? '', ar),
            ),
          ),
          Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l10n.references, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 12), const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.menu_book_outlined), title: Text("Gray's Anatomy: The Anatomical Basis of Clinical Practice"), subtitle: Text('42nd ed. · Thorax: Heart')), const ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.account_balance_outlined), title: Text('Terminologia Anatomica, Second Edition'), subtitle: Text('FIPAT · Cardiovascular system'))]))),
          const SizedBox(height: 12),
          Card(color: scheme.errorContainer.withValues(alpha: .55), child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Icon(Icons.info_outline), const SizedBox(width: 10), Expanded(child: Text(l10n.educationalDisclaimer, style: const TextStyle(height: 1.6)))]))),
        ]),
      ),
    ]);
  }
}

Future<void> _editNote(BuildContext context, WidgetRef ref, String organId, String current, bool ar) async {
  final controller = TextEditingController(text: current);
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(ar ? 'ملاحظة خاصة' : 'Private note'),
      content: TextField(
        controller: controller,
        minLines: 4,
        maxLines: 10,
        autofocus: true,
        decoration: InputDecoration(hintText: ar ? 'اكتب ملاحظتك…' : 'Write your note…'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(ar ? 'إلغاء' : 'Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(ar ? 'حفظ' : 'Save')),
      ],
    ),
  );
  controller.dispose();
  if (result != null) await ref.read(localStudyRepositoryProvider).saveNote('organ', organId, result);
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.body});
  final IconData icon; final String title; final String body;
  @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(child: Icon(icon)), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text(body, style: const TextStyle(height: 1.65))]))]))));
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});
  final Object error; final VoidCallback onRetry;
  @override Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.error_outline, size: 42), const SizedBox(height: 12), Text(error.toString(), textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(AppLocalizations.of(context).retry))])));
}
