import 'package:anatomy_atlas/core/medical_content/arabic_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes Arabic diacritics and common letter variants', () {
    expect(normalizeArabic('القَلْبُ'), 'القلب');
    expect(normalizeArabic('إِصابة الأوعية'), 'اصابه الاوعيه');
    expect(normalizeArabic('فتى  ورئة'), 'فتي ورئه');
  });
}
