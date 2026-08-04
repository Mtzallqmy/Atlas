import 'package:anatomy_atlas/core/medical_content/arabic_normalizer.dart';
import 'package:anatomy_atlas/features/organs/presentation/organ_providers.dart';
import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final SearchController _searchController = SearchController();
  String query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final organs = ref.watch(organsProvider);
    return SafeArea(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l10n.search, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      SearchBar(controller: _searchController, autoFocus: false, leading: const Icon(Icons.search), hintText: l10n.searchHint, onChanged: (value) => setState(() => query = value), trailing: query.isEmpty ? null : [IconButton(onPressed: () { _searchController.clear(); setState(() => query = ''); }, icon: const Icon(Icons.close))]),
      const SizedBox(height: 18),
      Expanded(child: organs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (items) {
          final q = normalizeArabic(query);
          final ar = Localizations.localeOf(context).languageCode == 'ar';
          final results = q.isEmpty ? items : items.where((organ) => normalizeArabic('${organ.nameAr} ${organ.nameEn} ${organ.latinName} ${organ.summaryAr} ${organ.summaryEn}').contains(q)).toList();
          if (results.isEmpty) return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.search_off, size: 42), const SizedBox(height: 10), Text(l10n.noResults)]));
          return ListView.separated(itemCount: results.length, separatorBuilder: (_, __) => const SizedBox(height: 9), itemBuilder: (context, index) {
            final organ = results[index];
            return Card(child: ListTile(contentPadding: const EdgeInsets.all(12), leading: Image.asset(organ.fallbackAsset ?? 'assets/images/heart.webp', width: 56, height: 56), title: Text(ar ? organ.nameAr : organ.nameEn, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${organ.nameEn} · ${organ.latinName ?? ''}'), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/organs/${organ.slug}')));
          });
        },
      )),
    ])));
  }
}
