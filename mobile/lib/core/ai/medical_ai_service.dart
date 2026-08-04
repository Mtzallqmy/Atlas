import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AIProviderMode { disabled, platformManaged, openAICompatible, userProvidedKey, puterWeb }

AIProviderMode parseAIProviderMode(String value) => AIProviderMode.values.firstWhere(
  (mode) => mode.name == value,
  orElse: () => AIProviderMode.disabled,
);

class MedicalAICitation {
  const MedicalAICitation({required this.referenceId, required this.title, this.locator});
  final String referenceId;
  final String title;
  final String? locator;

  factory MedicalAICitation.fromJson(Map<String, dynamic> json) => MedicalAICitation(
    referenceId: json['referenceId'] as String? ?? '',
    title: json['title'] as String? ?? '',
    locator: json['locator'] as String?,
  );
}

class MedicalAIAnswer {
  const MedicalAIAnswer({
    required this.answer,
    required this.summary,
    required this.keyPoints,
    required this.relatedTerms,
    required this.citations,
    required this.confidence,
    required this.requiresMedicalProfessional,
  });

  final String answer;
  final String summary;
  final List<String> keyPoints;
  final List<String> relatedTerms;
  final List<MedicalAICitation> citations;
  final String confidence;
  final bool requiresMedicalProfessional;

  factory MedicalAIAnswer.fromJson(Map<String, dynamic> json) => MedicalAIAnswer(
    answer: json['answer'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    keyPoints: (json['keyPoints'] as List? ?? const []).whereType<String>().toList(growable: false),
    relatedTerms: (json['relatedTerms'] as List? ?? const []).whereType<String>().toList(growable: false),
    citations: (json['citations'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(MedicalAICitation.fromJson)
        .toList(growable: false),
    confidence: json['confidence'] as String? ?? 'low',
    requiresMedicalProfessional: json['requiresMedicalProfessional'] as bool? ?? false,
  );
}

abstract interface class MedicalAIService {
  AIProviderMode get mode;
  Future<MedicalAIAnswer> ask({required String question, required String locale, String? contextEntityType, String? contextEntityId});
  Stream<String> streamAnswer({required String question, required String locale, String? contextEntityType, String? contextEntityId});
}

class DisabledMedicalAIService implements MedicalAIService {
  const DisabledMedicalAIService();
  @override AIProviderMode get mode => AIProviderMode.disabled;

  @override
  Future<MedicalAIAnswer> ask({required String question, required String locale, String? contextEntityType, String? contextEntityId}) async => MedicalAIAnswer(
    answer: locale == 'ar' ? 'المدرس الذكي معطل حاليًا. استخدم الشرح الطبي المراجع داخل صفحة المحتوى.' : 'The AI tutor is disabled. Use the medically reviewed explanation on the content page.',
    summary: locale == 'ar' ? 'الذكاء الاصطناعي غير مستخدم.' : 'AI is not in use.',
    keyPoints: const [], relatedTerms: const [], citations: const [], confidence: 'high', requiresMedicalProfessional: false,
  );

  @override
  Stream<String> streamAnswer({required String question, required String locale, String? contextEntityType, String? contextEntityId}) async* {
    yield (await ask(question: question, locale: locale, contextEntityType: contextEntityType, contextEntityId: contextEntityId)).answer;
  }
}

class SupabaseMedicalAIService implements MedicalAIService {
  SupabaseMedicalAIService({required this.mode, Dio? dio}) : _dio = dio ?? Dio();
  @override final AIProviderMode mode;
  final Dio _dio;

  Map<String, dynamic> _payload({required String question, required String locale, String? contextEntityType, String? contextEntityId, bool stream = false}) => {
    'question': question,
    'locale': locale,
    'contextEntityType': contextEntityType,
    'contextEntityId': contextEntityId,
    'stream': stream,
  };

  @override
  Future<MedicalAIAnswer> ask({required String question, required String locale, String? contextEntityType, String? contextEntityId}) async {
    final response = await Supabase.instance.client.functions.invoke('ai-tutor', body: _payload(question: question, locale: locale, contextEntityType: contextEntityType, contextEntityId: contextEntityId));
    if (response.status < 200 || response.status >= 300) throw StateError('AI tutor request failed (${response.status}).');
    final data = response.data is String ? jsonDecode(response.data as String) : response.data;
    return MedicalAIAnswer.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Stream<String> streamAnswer({required String question, required String locale, String? contextEntityType, String? contextEntityId}) async* {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (url.isEmpty || key.isEmpty || token == null) throw StateError('A signed-in Supabase session is required for AI streaming.');
    final response = await _dio.post<ResponseBody>(
      '$url/functions/v1/ai-tutor',
      data: jsonEncode(_payload(question: question, locale: locale, contextEntityType: contextEntityType, contextEntityId: contextEntityId, stream: true)),
      options: Options(responseType: ResponseType.stream, headers: {'apikey': key, 'Authorization': 'Bearer $token', 'Content-Type': 'application/json'}),
    );
    final lines = response.data!.stream.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter());
    for await (final line in lines) {
      if (!line.startsWith('data:')) continue;
      final value = line.substring(5).trim();
      if (value == '[DONE]') break;
      try {
        final event = jsonDecode(value) as Map<String, dynamic>;
        final delta = event['delta'] as String? ?? event['text'] as String?;
        if (delta != null && delta.isNotEmpty) yield delta;
      } catch (_) {
        // Ignore provider heartbeat and non-text events.
      }
    }
  }
}

final aiProviderModeProvider = Provider<AIProviderMode>((ref) => parseAIProviderMode(const String.fromEnvironment('AI_PROVIDER_MODE', defaultValue: 'disabled')));
final medicalAIServiceProvider = Provider<MedicalAIService>((ref) {
  final mode = ref.watch(aiProviderModeProvider);
  return mode == AIProviderMode.disabled || mode == AIProviderMode.puterWeb
      ? const DisabledMedicalAIService()
      : SupabaseMedicalAIService(mode: mode);
});
