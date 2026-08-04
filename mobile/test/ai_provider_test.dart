import 'package:anatomy_atlas/core/ai/medical_ai_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unknown provider modes fail closed to disabled', () {
    expect(parseAIProviderMode('unknown'), AIProviderMode.disabled);
    expect(parseAIProviderMode('platformManaged'), AIProviderMode.platformManaged);
  });

  test('disabled provider returns verified static fallback without network', () async {
    const service = DisabledMedicalAIService();
    final answer = await service.ask(question: 'اشرح القلب', locale: 'ar');
    expect(answer.answer, contains('معطل'));
    expect(answer.confidence, 'high');
    expect(answer.citations, isEmpty);
  });
}
