import 'package:anatomy_atlas/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destinations = [
      NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l10n.home),
      NavigationDestination(icon: const Icon(Icons.accessibility_new_outlined), selectedIcon: const Icon(Icons.accessibility_new), label: l10n.explore),
      NavigationDestination(icon: const Icon(Icons.search), selectedIcon: const Icon(Icons.manage_search), label: l10n.search),
      NavigationDestination(icon: const Icon(Icons.download_outlined), selectedIcon: const Icon(Icons.download), label: l10n.downloads),
      NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l10n.settings),
    ];

    void select(int index) => navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 840) {
        return Scaffold(
          body: Row(children: [
            SafeArea(
              child: NavigationRail(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: select,
                extended: constraints.maxWidth >= 1180,
                labelType: constraints.maxWidth >= 1180 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Semantics(label: l10n.appName, child: const CircleAvatar(radius: 24, child: Icon(Icons.biotech_outlined))),
                ),
                destinations: destinations.map((item) => NavigationRailDestination(icon: item.icon, selectedIcon: item.selectedIcon, label: Text(item.label))).toList(),
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: navigationShell),
          ]),
        );
      }
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(selectedIndex: navigationShell.currentIndex, onDestinationSelected: select, destinations: destinations),
      );
    });
  }
}
