import 'package:anatomy_atlas/core/database/app_database.dart';
import 'package:anatomy_atlas/core/database/database_provider.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final localStudyRepositoryProvider = Provider<LocalStudyRepository>((ref) {
  return LocalStudyRepository(ref.watch(databaseProvider));
});

final bookmarkStateProvider = StreamProvider.family<bool, String>((ref, entityId) {
  return ref.watch(localStudyRepositoryProvider).watchBookmark('organ', entityId);
});

final noteStateProvider = StreamProvider.family<String?, String>((ref, entityId) {
  return ref.watch(localStudyRepositoryProvider).watchNote('organ', entityId);
});

class LocalStudyRepository {
  LocalStudyRepository(this._database);

  final AppDatabase _database;
  static const _uuid = Uuid();

  Stream<bool> watchBookmark(String entityType, String entityId) {
    final query = _database.select(_database.localBookmarks)
      ..where((row) => row.entityType.equals(entityType) & row.entityId.equals(entityId));
    return query.watch().map((rows) => rows.isNotEmpty);
  }

  Future<void> toggleBookmark(String entityType, String entityId) async {
    final query = _database.select(_database.localBookmarks)
      ..where((row) => row.entityType.equals(entityType) & row.entityId.equals(entityId));
    final current = await query.getSingleOrNull();
    if (current != null) {
      await (_database.delete(_database.localBookmarks)..where((row) => row.id.equals(current.id))).go();
      return;
    }
    await _database.into(_database.localBookmarks).insert(
      LocalBookmarksCompanion.insert(
        id: _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
      ),
    );
  }

  Stream<String?> watchNote(String entityType, String entityId) {
    final query = _database.select(_database.localNotes)
      ..where((row) => row.entityType.equals(entityType) & row.entityId.equals(entityId));
    return query.watch().map((rows) => rows.isEmpty ? null : rows.first.body);
  }

  Future<void> saveNote(String entityType, String entityId, String body) async {
    final query = _database.select(_database.localNotes)
      ..where((row) => row.entityType.equals(entityType) & row.entityId.equals(entityId));
    final current = await query.getSingleOrNull();
    final normalized = body.trim();
    if (normalized.isEmpty) {
      if (current != null) {
        await (_database.delete(_database.localNotes)..where((row) => row.id.equals(current.id))).go();
      }
      return;
    }
    await _database.into(_database.localNotes).insertOnConflictUpdate(
      LocalNotesCompanion.insert(
        id: current?.id ?? _uuid.v4(),
        entityType: entityType,
        entityId: entityId,
        body: normalized,
        pendingSync: const Value(true),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
