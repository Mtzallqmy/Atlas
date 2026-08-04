import 'dart:io';

import 'package:anatomy_atlas/core/database/app_database.dart';
import 'package:anatomy_atlas/core/database/database_provider.dart';
import 'package:anatomy_atlas/core/downloads/content_package.dart';
import 'package:anatomy_atlas/features/settings/presentation/settings_controller.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

final downloadManagerProvider = Provider<DownloadManager>(
  (ref) => DownloadManager(
    database: ref.watch(databaseProvider),
    dio: Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(minutes: 10),
      ),
    ),
    wifiOnly: () => ref.read(settingsControllerProvider).wifiOnly,
  ),
);

class DownloadManager {
  DownloadManager({
    required AppDatabase database,
    required Dio dio,
    required bool Function() wifiOnly,
  }) : _database = database,
       _dio = dio,
       _wifiOnly = wifiOnly;

  final AppDatabase _database;
  final Dio _dio;
  final bool Function() _wifiOnly;
  final Map<String, CancelToken> _tokens = {};

  String _key(ContentPackage package) =>
      '${package.packageId}:${package.version}:${package.locale}';

  Future<void> download(ContentPackage package) async {
    validateContentPackageManifest(package);
    await _assertNetworkPolicy();
    if (package.downloadUrl.isEmpty) {
      throw StateError('No package URL is configured.');
    }

    final root = await getApplicationSupportDirectory();
    final packageDir = Directory(p.join(root.path, 'content_packages'))
      ..createSync(recursive: true);
    final finalFile = File(
      p.join(
        packageDir.path,
        '${package.packageId}-${package.locale}-${package.version}.zip',
      ),
    );
    final partialFile = File('${finalFile.path}.part');
    final backupFile = File('${finalFile.path}.bak');
    var existing = partialFile.existsSync() ? partialFile.lengthSync() : 0;
    var downloaded = existing;
    IOSink? sink;
    var sinkClosed = false;
    final token = CancelToken();
    _tokens[_key(package)] = token;

    Future<void> closeSink() async {
      if (sink == null || sinkClosed) return;
      sinkClosed = true;
      await sink!.flush();
      await sink!.close();
    }

    await _upsert(
      package,
      state: 'downloading',
      bytes: existing,
      path: partialFile.path,
    );

    try {
      final response = await _dio.get<ResponseBody>(
        package.downloadUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: existing > 0 ? {'Range': 'bytes=$existing-'} : null,
        ),
        cancelToken: token,
      );

      if (existing > 0 && response.statusCode != HttpStatus.partialContent) {
        await partialFile.writeAsBytes(const [], flush: true);
        existing = 0;
        downloaded = 0;
      }

      final stream = response.data?.stream;
      if (stream == null) throw StateError('The package response had no body.');

      sink = partialFile.openWrite(
        mode: existing > 0 ? FileMode.append : FileMode.write,
      );
      await for (final chunk in stream) {
        sink!.add(chunk);
        downloaded += chunk.length;
        await _upsert(
          package,
          state: 'downloading',
          bytes: downloaded,
          path: partialFile.path,
        );
      }
      await closeSink();
      await _upsert(
        package,
        state: 'verifying',
        bytes: downloaded,
        path: partialFile.path,
      );

      if (package.size > 0 && downloaded != package.size) {
        throw FormatException(
          'Package size mismatch: expected ${package.size}, received $downloaded.',
        );
      }
      final digest = await sha256.bind(partialFile.openRead()).first;
      if (digest.toString().toLowerCase() != package.checksum.toLowerCase()) {
        throw const FormatException('Package checksum mismatch.');
      }

      if (backupFile.existsSync()) await backupFile.delete();
      if (finalFile.existsSync()) await finalFile.rename(backupFile.path);
      await partialFile.rename(finalFile.path);
      await _upsert(
        package,
        state: 'installed',
        bytes: downloaded,
        path: finalFile.path,
      );
    } on DioException catch (error) {
      await closeSink();
      if (CancelToken.isCancel(error)) {
        await _upsert(
          package,
          state: 'paused',
          bytes: downloaded,
          path: partialFile.path,
        );
        return;
      }
      await _rollback(
        package,
        finalFile,
        backupFile,
        downloaded,
        error.message,
      );
      rethrow;
    } catch (error) {
      await closeSink();
      await _rollback(
        package,
        finalFile,
        backupFile,
        downloaded,
        error.toString(),
      );
      rethrow;
    } finally {
      _tokens.remove(_key(package));
    }
  }

  void pause(ContentPackage package) {
    _tokens[_key(package)]?.cancel('Paused by user');
  }

  Future<void> delete(ContentPackage package) async {
    final row = await (_database.select(_database.downloadedPackages)
          ..where(
            (table) =>
                table.packageId.equals(package.packageId) &
                table.version.equals(package.version) &
                table.locale.equals(package.locale),
          ))
        .getSingleOrNull();
    if (row?.localPath != null) {
      final file = File(row!.localPath!);
      if (file.existsSync()) await file.delete();
      final backup = File('${file.path}.bak');
      if (backup.existsSync()) await backup.delete();
      final partial = File('${file.path}.part');
      if (partial.existsSync()) await partial.delete();
    }
    await (_database.delete(_database.downloadedPackages)
          ..where(
            (table) =>
                table.packageId.equals(package.packageId) &
                table.version.equals(package.version) &
                table.locale.equals(package.locale),
          ))
        .go();
  }

  Future<void> _assertNetworkPolicy() async {
    if (!_wifiOnly()) return;
    final connectivity = await Connectivity().checkConnectivity();
    final allowed = connectivity.contains(ConnectivityResult.wifi) ||
        connectivity.contains(ConnectivityResult.ethernet);
    if (!allowed) throw StateError('Wi-Fi-only downloads are enabled.');
  }

  Future<void> _rollback(
    ContentPackage package,
    File finalFile,
    File backupFile,
    int bytes,
    String? error,
  ) async {
    var restored = false;
    if (!finalFile.existsSync() && backupFile.existsSync()) {
      await backupFile.rename(finalFile.path);
      restored = true;
    }
    await _upsert(
      package,
      state: restored ? 'rolled_back' : 'failed',
      bytes: bytes,
      path: finalFile.existsSync() ? finalFile.path : null,
      error: error,
    );
  }

  Future<void> _upsert(
    ContentPackage package, {
    required String state,
    required int bytes,
    String? path,
    String? error,
  }) {
    return _database.into(_database.downloadedPackages).insertOnConflictUpdate(
      DownloadedPackagesCompanion.insert(
        packageId: package.packageId,
        version: package.version,
        locale: package.locale,
        state: state,
        bytesDownloaded: Value(bytes),
        totalBytes: Value(package.size),
        checksum: package.checksum,
        localPath: Value(path),
        error: Value(error),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }
}
