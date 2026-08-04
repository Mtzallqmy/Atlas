import 'package:anatomy_atlas/core/downloads/content_package.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ContentPackage validPackage() => ContentPackage.fromJson({
    'packageId': 'cardiovascular-ar-v1',
    'version': 1,
    'locale': 'ar',
    'size': 24500000,
    'checksum': List.filled(64, 'a').join(),
    'minimumAppVersion': '1.0.0',
    'downloadUrl': 'https://cdn.example.test/package.zip',
    'assets': <Map<String, dynamic>>[],
  });

  test('parses and validates a versioned package manifest', () {
    final package = validPackage();
    expect(package.packageId, 'cardiovascular-ar-v1');
    expect(package.version, 1);
    expect(package.locale, 'ar');
    expect(() => validateContentPackageManifest(package), returnsNormally);
  });

  test('rejects a non-SHA-256 checksum before download', () {
    final package = validPackage().copyWith(checksum: 'invalid');
    expect(
      () => validateContentPackageManifest(package),
      throwsA(isA<FormatException>()),
    );
  });
}
