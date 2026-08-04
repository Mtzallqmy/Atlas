import { authenticatedUser, corsHeaders, env, HttpError, jsonResponse, requireProfile, supabaseFetch } from "../_shared/http.ts";

type ProviderMode = "disabled" | "platformManaged" | "openAICompatible" | "userProvidedKey" | "puterWeb";
interface Payload {
  question?: string;
  locale?: string;
  contextEntityType?: string;
  contextEntityId?: string;
  stream?: boolean;
  providerKey?: string;
}
interface SearchHit { entity_type: string; entity_id: string; slug: string; title: string; subtitle?: string | null; rank: number }
interface Citation { referenceId: string; title: string; locator?: string | null }

const encoder = new TextEncoder();

function optionalEnv(name: string, fallback = "") { return Deno.env.get(name) || fallback; }
function emergencyLike(question: string) {
  return /(chest pain|can't breathe|cannot breathe|unconscious|stroke|overdose|نزيف شديد|ألم صدر|لا أستطيع التنفس|فقد الوعي|سكتة|جرعة زائدة)/i.test(question);
}
function personalMedicalLike(question: string) {
  return /(I have|my symptoms|my medication|my dose|diagnose me|لدي|أعراضي|دوائي|جرعتي|شخّص|شخص حالتي)/i.test(question);
}
function normalizeMode(value: string): ProviderMode {
  return (["disabled", "platformManaged", "openAICompatible", "userProvidedKey", "puterWeb"] as const).includes(value as ProviderMode)
    ? value as ProviderMode : "disabled";
}

async function referencesFor(hits: SearchHit[]): Promise<Citation[]> {
  const citations: Citation[] = [];
  const tableName: Record<string, string> = { organ: "organs", disease: "diseases", lesson: "lessons", term: "medical_terms" };
  for (const hit of hits.slice(0, 6)) {
    const entityType = tableName[hit.entity_type] || hit.entity_type;
    const links = await supabaseFetch<Array<{ locator?: string | null; reference: { id: string; title: string } | null }>>(
      `/rest/v1/content_references?entity_type=eq.${encodeURIComponent(entityType)}&entity_id=eq.${encodeURIComponent(hit.entity_id)}&select=locator,reference:references(id,title)&limit=4`,
    );
    for (const link of links) {
      if (!link.reference || citations.some((item) => item.referenceId === link.reference!.id && item.locator === link.locator)) continue;
      citations.push({ referenceId: link.reference.id, title: link.reference.title, locator: link.locator });
    }
  }
  return citations.slice(0, 10);
}

function parseOutputText(payload: Record<string, unknown>): string {
  if (typeof payload.output_text === "string") return payload.output_text;
  const output = Array.isArray(payload.output) ? payload.output : [];
  const texts: string[] = [];
  for (const item of output) {
    if (!item || typeof item !== "object") continue;
    const content = Array.isArray((item as Record<string, unknown>).content) ? (item as Record<string, unknown>).content as unknown[] : [];
    for (const part of content) {
      if (part && typeof part === "object" && typeof (part as Record<string, unknown>).text === "string") texts.push((part as Record<string, unknown>).text as string);
    }
  }
  return texts.join("\n");
}

async function recordUsage(userId: string, mode: ProviderMode, model: string, startedAt: number, response?: Record<string, unknown>) {
  const usage = response?.usage && typeof response.usage === "object" ? response.usage as Record<string, unknown> : {};
  try {
    await supabaseFetch("/rest/v1/ai_usage", {
      method: "POST",
      headers: { Prefer: "return=minimal" },
      body: {
        user_id: userId,
        provider_mode: mode,
        model_name: model,
        input_tokens: Number(usage.input_tokens || 0),
        output_tokens: Number(usage.output_tokens || 0),
        latency_ms: Date.now() - startedAt,
        request_id: typeof response?.id === "string" ? response.id : null,
      },
    });
  } catch (error) {
    console.error("ai usage recording failed", error instanceof Error ? error.message : "unknown");
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);
  const startedAt = Date.now();
  try {
    const { user } = await authenticatedUser(req);
    await requireProfile(user.id, ["owner", "admin", "editor", "medical_reviewer", "translator", "user"]);
    const payload = await req.json() as Payload;
    const question = String(payload.question || "").trim();
    const locale = /^[a-z]{2}(-[A-Z]{2})?$/.test(String(payload.locale || "")) ? String(payload.locale) : "en";
    if (question.length < 2 || question.length > 4000) throw new HttpError(400, "Question must contain 2–4000 characters.");

    const mode = normalizeMode(optionalEnv("AI_PROVIDER_MODE", "disabled"));
    if (mode === "disabled") {
      return jsonResponse({
        answer: locale.startsWith("ar") ? "المدرس الذكي معطل. اعتمد على المحتوى الطبي المنشور والمراجع الظاهرة داخل الأطلس." : "The AI tutor is disabled. Use the published medical content and references in the atlas.",
        summary: locale.startsWith("ar") ? "لم يُرسل السؤال إلى أي نموذج." : "The question was not sent to a model.",
        keyPoints: [], relatedTerms: [], citations: [], confidence: "high", requiresMedicalProfessional: personalMedicalLike(question), providerMode: mode,
      });
    }
    if (mode === "puterWeb") throw new HttpError(400, "puterWeb is available only through the isolated web adapter.");

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();
    const usageRows = await supabaseFetch<Array<{ id: string }>>(`/rest/v1/ai_usage?user_id=eq.${encodeURIComponent(user.id)}&created_at=gte.${encodeURIComponent(since)}&select=id&limit=101`);
    const quota = Number(optionalEnv("AI_DAILY_USER_QUOTA", "20"));
    if (usageRows.length >= quota) throw new HttpError(429, "Daily AI quota reached.");

    const hits = await supabaseFetch<SearchHit[]>("/rest/v1/rpc/search_medical_content", {
      method: "POST",
      body: { p_query: question, p_locale: locale, p_limit: 8 },
    });
    const citations = await referencesFor(hits);
    const context = hits.slice(0, 8).map((hit, index) => `[${index + 1}] ${hit.entity_type}/${hit.slug}: ${hit.title}\n${hit.subtitle || ""}`).join("\n\n");
    if (!context.trim()) {
      return jsonResponse({
        answer: locale.startsWith("ar") ? "لا توجد معلومات كافية في المحتوى الطبي المنشور للإجابة بثقة." : "There is not enough published medical content to answer this confidently.",
        summary: locale.startsWith("ar") ? "المحتوى المعتمد غير كافٍ." : "Approved content is insufficient.",
        keyPoints: [], relatedTerms: [], citations: [], confidence: "low", requiresMedicalProfessional: personalMedicalLike(question), providerMode: mode,
      });
    }

    let apiKey = optionalEnv("OPENAI_API_KEY");
    if (mode === "userProvidedKey") {
      if (optionalEnv("ALLOW_USER_PROVIDED_KEY", "false") !== "true") throw new HttpError(403, "User-provided keys are disabled by the server.");
      apiKey = String(payload.providerKey || "");
      if (!apiKey) throw new HttpError(400, "A session-only provider key is required.");
    }
    if (!apiKey) throw new HttpError(503, "AI provider credentials are not configured.");
    const baseUrl = optionalEnv("OPENAI_BASE_URL", "https://api.openai.com/v1").replace(/\/$/, "");
    const model = optionalEnv("OPENAI_MODEL", "gpt-5-mini");
    const requiresProfessional = personalMedicalLike(question) || emergencyLike(question);
    const outputInstruction = payload.stream
      ? "Return only the conversational answer text. Do not wrap it in JSON or Markdown fences."
      : "Return strict JSON with answer, summary, keyPoints (array), relatedTerms (array), confidence (high|medium|low), and requiresMedicalProfessional (boolean).";
    const instructions = `You are the optional educational tutor for Anatomy Atlas. Answer only from APPROVED_CONTEXT. Do not diagnose, prescribe, set doses, stop medicines, or invent facts or citations. If context is insufficient, say so. For personal medical questions provide general education and advise a qualified professional. For emergency-like symptoms advise local emergency services. Respond in ${locale}. ${outputInstruction} Do not add citations; the server attaches verified citations.

APPROVED_CONTEXT:
${context}`;
    const providerBody = {
      model,
      instructions,
      input: question,
      stream: Boolean(payload.stream),
      temperature: 0.2,
      text: payload.stream ? undefined : {
        format: {
          type: "json_schema",
          name: "medical_tutor_answer",
          strict: true,
          schema: {
            type: "object", additionalProperties: false,
            properties: {
              answer: { type: "string" }, summary: { type: "string" },
              keyPoints: { type: "array", items: { type: "string" } },
              relatedTerms: { type: "array", items: { type: "string" } },
              confidence: { type: "string", enum: ["high", "medium", "low"] },
              requiresMedicalProfessional: { type: "boolean" },
            },
            required: ["answer", "summary", "keyPoints", "relatedTerms", "confidence", "requiresMedicalProfessional"],
          },
        },
      },
    };
    const callProvider = () => fetch(`${baseUrl}/responses`, {
      method: "POST",
      headers: { "Authorization": `Bearer ${apiKey}`, "Content-Type": "application/json" },
      body: JSON.stringify(providerBody),
      signal: AbortSignal.timeout(45_000),
    });
    let providerResponse = await callProvider();
    if (providerResponse.status === 429 || providerResponse.status >= 500) {
      await new Promise((resolve) => setTimeout(resolve, 500));
      providerResponse = await callProvider();
    }
    if (!providerResponse.ok) {
      const providerError = await providerResponse.text();
      console.error("AI provider request failed", { status: providerResponse.status, message: providerError.slice(0, 500) });
      throw new HttpError(502, "AI provider request failed.");
    }

    if (payload.stream) {
      if (!providerResponse.body) throw new HttpError(502, "AI provider returned no stream.");
      const reader = providerResponse.body.getReader();
      const decoder = new TextDecoder();
      let buffer = "";
      const stream = new ReadableStream({
        async pull(controller) {
          const { value, done } = await reader.read();
          if (done) {
            controller.enqueue(encoder.encode(`event: citations\ndata: ${JSON.stringify({ citations, requiresMedicalProfessional: requiresProfessional })}\n\ndata: [DONE]\n\n`));
            controller.close();
            await recordUsage(user.id, mode, model, startedAt);
            return;
          }
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() || "";
          for (const line of lines) {
            if (!line.startsWith("data:")) continue;
            const raw = line.slice(5).trim();
            if (!raw || raw === "[DONE]") continue;
            try {
              const event = JSON.parse(raw) as Record<string, unknown>;
              if (event.type === "response.output_text.delta" && typeof event.delta === "string") {
                controller.enqueue(encoder.encode(`event: delta\ndata: ${JSON.stringify({ delta: event.delta })}\n\n`));
              }
            } catch { /* Ignore non-JSON provider heartbeats. */ }
          }
        },
        cancel() { reader.cancel(); },
      });
      return new Response(stream, { status: 200, headers: { ...corsHeaders, "Content-Type": "text/event-stream", "Cache-Control": "no-store", "X-Accel-Buffering": "no" } });
    }

    const providerJson = await providerResponse.json() as Record<string, unknown>;
    const outputText = parseOutputText(providerJson);
    let structured: Record<string, unknown>;
    try { structured = JSON.parse(outputText) as Record<string, unknown>; }
    catch { structured = { answer: outputText, summary: "", keyPoints: [], relatedTerms: [], confidence: "low", requiresMedicalProfessional: requiresProfessional }; }
    structured.citations = citations;
    structured.requiresMedicalProfessional = Boolean(structured.requiresMedicalProfessional) || requiresProfessional;
    structured.providerMode = mode;
    await recordUsage(user.id, mode, model, startedAt, providerJson);
    return jsonResponse(structured);
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : "Unexpected server error.";
    console.error("ai-tutor failed", { status, message });
    return jsonResponse({ error: message }, status);
  }
});
