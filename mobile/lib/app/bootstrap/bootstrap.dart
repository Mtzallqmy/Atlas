import 'dart:async';

import 'package:anatomy_atlas/app/app.dart';
import 'package:anatomy_atlas/core/logging/app_error_reporter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorReporter().install();

  await runZonedGuarded(() async {
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty) {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
    }
    runApp(const ProviderScope(child: AnatomyAtlasApp()));
  }, (error, stack) => const DeveloperLogErrorSink().record(error, stack, context: 'Root zone'));
}
