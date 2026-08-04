import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class CachedOrgans extends Table {
  TextColumn get id => text()();
  TextColumn get systemId => text()();
  TextColumn get slug => text().unique()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {id};
}

class SearchDocuments extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get slug => text()();
  TextColumn get locale => text()();
  TextColumn get title => text()();
  TextColumn get normalizedTitle => text()();
  TextColumn get body => text().nullable()();
  @override Set<Column> get primaryKey => {id, locale};
}

class DownloadedPackages extends Table {
  TextColumn get packageId => text()();
  IntColumn get version => integer()();
  TextColumn get locale => text()();
  TextColumn get state => text()();
  IntColumn get bytesDownloaded => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().withDefault(const Constant(0))();
  TextColumn get checksum => text()();
  TextColumn get localPath => text().nullable()();
  TextColumn get error => text().nullable()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {packageId, version, locale};
}

class LocalBookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {id};
}

class LocalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get body => text()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(true))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  @override Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [CachedOrgans, SearchDocuments, DownloadedPackages, LocalBookmarks, LocalNotes])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override int get schemaVersion => 1;

  Future<void> replaceSearchDocuments(List<SearchDocumentsCompanion> documents) => transaction(() async {
    await delete(searchDocuments).go();
    await batch((batch) => batch.insertAll(searchDocuments, documents, mode: InsertMode.insertOrReplace));
  });
}

LazyDatabase _openConnection() => LazyDatabase(() async {
  final directory = await getApplicationSupportDirectory();
  return NativeDatabase.createInBackground(File(p.join(directory.path, 'anatomy_atlas.sqlite')));
});
