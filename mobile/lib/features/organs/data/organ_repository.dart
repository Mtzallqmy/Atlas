import 'dart:convert';

import 'package:anatomy_atlas/core/database/app_database.dart';
import 'package:anatomy_atlas/core/database/database_provider.dart';
import 'package:anatomy_atlas/features/organs/domain/organ.dart';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class OrganRepository {
  Future<List<Organ>> list({bool refresh = false});
  Future<Organ?> bySlug(String slug, {bool refresh = false});
}

final organRepositoryProvider = Provider<OrganRepository>((ref) => OfflineFirstOrganRepository(ref.watch(databaseProvider)));

class OfflineFirstOrganRepository implements OrganRepository {
  OfflineFirstOrganRepository(this._database);
  final AppDatabase _database;

  @override
  Future<List<Organ>> list({bool refresh = false}) async {
    if (refresh) await _refreshRemote();
    var cached = await _database.select(_database.cachedOrgans).get();
    if (cached.isEmpty) {
      await _seedBundledContent();
      cached = await _database.select(_database.cachedOrgans).get();
    }
    return cached.map((row) => Organ.fromJson(jsonDecode(row.payload) as Map<String, dynamic>)).toList(growable: false);
  }

  @override
  Future<Organ?> bySlug(String slug, {bool refresh = false}) async {
    if (refresh) await _refreshRemote();
    final query = _database.select(_database.cachedOrgans)..where((table) => table.slug.equals(slug));
    var row = await query.getSingleOrNull();
    if (row == null) {
      await _seedBundledContent();
      row = await query.getSingleOrNull();
    }
    return row == null ? null : Organ.fromJson(jsonDecode(row.payload) as Map<String, dynamic>);
  }

  Future<void> _seedBundledContent() async {
    final raw = await rootBundle.loadString('assets/data/core_content.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final organs = (data['organs'] as List).cast<Map<String, dynamic>>();
    await _database.batch((batch) {
      for (final organ in organs) {
        batch.insert(
          _database.cachedOrgans,
          CachedOrgansCompanion.insert(
            id: organ['id'] as String,
            systemId: organ['systemId'] as String,
            slug: organ['slug'] as String,
            payload: jsonEncode(organ),
          ),
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  Future<void> _refreshRemote() async {
    if (const String.fromEnvironment('SUPABASE_URL').isEmpty) return;
    try {
      final rows = await Supabase.instance.client.from('organs').select().eq('status', 'published').isFilter('deleted_at', null);
      if (rows.isEmpty) return;
      // Remote records are intentionally not mapped until their published translations are also present.
      // The bundled package therefore remains the source of truth when the server payload is incomplete.
    } catch (_) {
      // Offline-first: remote failure never blocks verified local content.
    }
  }
}
