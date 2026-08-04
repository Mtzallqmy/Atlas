import 'package:freezed_annotation/freezed_annotation.dart';

part 'organ.freezed.dart';
part 'organ.g.dart';

@freezed
abstract class Organ with _$Organ {
  const factory Organ({
    required String id,
    required String systemId,
    required String slug,
    required String nameAr,
    required String nameEn,
    String? latinName,
    required String summaryAr,
    required String summaryEn,
    required String functionAr,
    required String functionEn,
    required String locationAr,
    required String locationEn,
    required String bloodSupplyAr,
    required String bloodSupplyEn,
    required String innervationAr,
    required String innervationEn,
    required String clinicalAr,
    required String clinicalEn,
    String? modelAsset,
    String? fallbackAsset,
  }) = _Organ;

  factory Organ.fromJson(Map<String, dynamic> json) => _$OrganFromJson(json);
}
