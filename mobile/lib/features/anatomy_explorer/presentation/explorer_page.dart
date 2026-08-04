import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:interactive_3d/interactive_3d.dart';

class ExplorerPage extends StatefulWidget {
  const ExplorerPage({super.key});
  @override State<ExplorerPage> createState() => _ExplorerPageState();
}

class _ExplorerPageState extends State<ExplorerPage> {
  bool _fallback = false;
  int _viewerGeneration = 0;
  int _selectedCount = 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l10n.bodyExplorer, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text('GLB · Filament / SceneKit · offline asset', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ])),
            IconButton.filledTonal(onPressed: () => setState(() => _fallback = !_fallback), tooltip: l10n.showFallback, icon: Icon(_fallback ? Icons.view_in_ar : Icons.image_outlined)),
            IconButton(onPressed: () => setState(() { _viewerGeneration++; _fallback = false; }), tooltip: l10n.retry, icon: const Icon(Icons.refresh)),
          ]),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: Stack(children: [
                Positioned.fill(
                  child: _fallback
                    ? ColoredBox(color: scheme.surfaceContainerLowest, child: Center(child: Hero(tag: 'heart-image', child: Image.asset('assets/images/heart.webp', fit: BoxFit.contain))))
                    : Interactive3d(
                        key: ValueKey(_viewerGeneration),
                        modelPath: 'assets/models/heart.glb',
                        solidBackgroundColor: const [0.96, 0.97, 0.96, 1],
                        selectionColor: const [0.86, 0.19, 0.24, 1],
                        defaultZoom: 1.2,
                        onSelectionChanged: (items) => setState(() => _selectedCount = items.length),
                      ),
                ),
                Positioned(top: 14, left: 14, right: 14, child: Row(children: [
                  _Chip(icon: Icons.layers_outlined, label: 'الأعضاء'),
                  const SizedBox(width: 8),
                  _Chip(icon: Icons.touch_app_outlined, label: _selectedCount == 0 ? 'اضغط لتحديد جزء' : 'تم تحديد $_selectedCount'),
                ])),
                Positioned(bottom: 16, left: 16, right: 16, child: Card(
                  color: scheme.surface.withValues(alpha: .94),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const CircleAvatar(child: Icon(Icons.favorite)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(l10n.heart, style: const TextStyle(fontWeight: FontWeight.w800)), Text(l10n.heartSummary, maxLines: 2, overflow: TextOverflow.ellipsis)])),
                      FilledButton.tonal(onPressed: () => context.push('/organs/heart'), child: const Icon(Icons.arrow_forward)),
                    ]),
                  ),
                )),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(l10n.educationalDisclaimer, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon; final String label;
  @override Widget build(BuildContext context) => Chip(avatar: Icon(icon, size: 16), label: Text(label));
}
