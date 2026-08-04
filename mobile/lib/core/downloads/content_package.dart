import 'package:freezed_annotation/freezed_annotation.dart';

part 'content_package.freezed.dart';
part 'content_package.g.dart';

@freezed
abstract class ContentPackage with _$ContentPackage {
  const factory ContentPackage({
    required String packageId,
    required int version,
    required String locale,
    required int size,
    required String checksum,
    required String minimumAppVersion,
    required String downloadUrl,
    @Default(<Map<String, dynamic>>[]) List<Map<String, dynamic>> assets,
  }) = _ContentPackage;

  factory ContentPackage.fromJson(Map<String, dynamic> json) => _$ContentPackageFromJson(json);
}

void validateContentPackageManifest(ContentPackage package) {
  if (!RegExp(r'^[a-z0-9][a-z0-9._-]{2,100}$').hasMatch(package.packageId)) {
    throw const FormatException('Invalid content package identifier.');
  }
  if (package.version < 1) {
    throw const FormatException('Content package version must be positive.');
  }
  if (!RegExp(r'^[a-z]{2}(-[A-Z]{2})?$').hasMatch(package.locale)) {
    throw const FormatException('Invalid content package locale.');
  }
  if (package.size <= 0) {
    throw const FormatException('Content package size must be positive.');
  }
  if (!RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(package.checksum)) {
    throw const FormatException('Content package checksum must be SHA-256.');
  }
  if (!RegExp(r'^\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')
      .hasMatch(package.minimumAppVersion)) {
    throw const FormatException('Invalid minimum application version.');
  }
  final uri = Uri.tryParse(package.downloadUrl);
  if (uri == null || !uri.hasAuthority || !const {'https', 'http'}.contains(uri.scheme)) {
    throw const FormatException('Content package download URL must be HTTP(S).');
  }
}
