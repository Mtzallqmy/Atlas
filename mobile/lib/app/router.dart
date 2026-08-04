import 'package:anatomy_atlas/core/widgets/adaptive_shell.dart';
import 'package:anatomy_atlas/features/anatomy_explorer/presentation/explorer_page.dart';
import 'package:anatomy_atlas/features/downloads/presentation/downloads_page.dart';
import 'package:anatomy_atlas/features/home/presentation/home_page.dart';
import 'package:anatomy_atlas/features/organs/presentation/organ_detail_page.dart';
import 'package:anatomy_atlas/features/search/presentation/search_page.dart';
import 'package:anatomy_atlas/features/settings/presentation/settings_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) => GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => AdaptiveShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: [GoRoute(path: '/', builder: (context, state) => const HomePage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/explore', builder: (context, state) => const ExplorerPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/search', builder: (context, state) => const SearchPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/downloads', builder: (context, state) => const DownloadsPage())]),
        StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (context, state) => const SettingsPage())]),
      ],
    ),
    GoRoute(
      path: '/organs/:slug',
      name: 'organ',
      builder: (context, state) => OrganDetailPage(slug: state.pathParameters['slug']!),
    ),
  ],
));
