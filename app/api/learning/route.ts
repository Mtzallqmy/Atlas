import { NextResponse } from "next/server";

export const revalidate = 300;

const DEFAULT_SUPABASE_URL = "https://jiczgqgukspkklvttwdo.supabase.co";
const DEFAULT_SUPABASE_PUBLISHABLE_KEY = "sb_publishable_SYMVGQqiq7Mx09Fz-hokNw_cy9lAGcf";

type LessonRow = { id: string; slug: string; difficulty: string | null; estimated_minutes: number | null; summary: string | null; organ_id: string | null };
type OrganRow = { id: string; slug: string; definition: string | null; function_summary: string | null; location_summary: string | null };

function configuration() {
  return {
    url: (process.env.NEXT_PUBLIC_SUPABASE_URL || DEFAULT_SUPABASE_URL).replace(/\/$/, ""),
    key: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || DEFAULT_SUPABASE_PUBLISHABLE_KEY,
  };
}

async function supabaseGet<T>(path: string): Promise<T> {
  const config = configuration();
  const response = await fetch(`${config.url}/rest/v1/${path}`, {
    headers: { apikey: config.key, Authorization: `Bearer ${config.key}` },
    next: { revalidate: 300 },
  });
  if (!response.ok) {
    const detail = await response.text();
    throw new Error(`Supabase request failed (${response.status}): ${detail.slice(0, 240)}`);
  }
  return response.json() as Promise<T>;
}

export async function GET() {
  const startedAt = Date.now();
  try {
    const [lessons, organs, sections, quizzes, questions] = await Promise.all([
      supabaseGet<LessonRow[]>("lessons?select=id,slug,difficulty,estimated_minutes,summary,organ_id&status=eq.published&deleted_at=is.null&order=created_at.asc"),
      supabaseGet<OrganRow[]>("organs?select=id,slug,definition,function_summary,location_summary&status=eq.published&deleted_at=is.null&order=sort_order.asc"),
      supabaseGet<Array<{ lesson_id: string }>>("lesson_sections?select=lesson_id"),
      supabaseGet<Array<{ id: string; lesson_id: string }>>("quizzes?select=id,lesson_id&status=eq.published&deleted_at=is.null"),
      supabaseGet<Array<{ quiz_id: string }>>("questions?select=quiz_id"),
    ]);

    const organById = new Map(organs.map((organ) => [organ.id, organ]));
    const sectionCount = new Map<string, number>();
    sections.forEach((section) => sectionCount.set(section.lesson_id, (sectionCount.get(section.lesson_id) ?? 0) + 1));
    const quizByLesson = new Map(quizzes.map((quiz) => [quiz.lesson_id, quiz.id]));
    const questionCount = new Map<string, number>();
    questions.forEach((question) => questionCount.set(question.quiz_id, (questionCount.get(question.quiz_id) ?? 0) + 1));

    const data = lessons.map((lesson) => {
      const organ = lesson.organ_id ? organById.get(lesson.organ_id) : undefined;
      const quizId = quizByLesson.get(lesson.id);
      return {
        id: lesson.id,
        slug: lesson.slug,
        difficulty: lesson.difficulty ?? "beginner",
        minutes: lesson.estimated_minutes ?? 8,
        summary: lesson.summary ?? organ?.definition ?? "",
        organ: organ?.slug ?? lesson.slug.replace(/-foundations$/, ""),
        function: organ?.function_summary ?? "",
        location: organ?.location_summary ?? "",
        sections: sectionCount.get(lesson.id) ?? 0,
        questions: quizId ? questionCount.get(quizId) ?? 0 : 0,
      };
    });

    return NextResponse.json({
      data,
      meta: { lessons: data.length, sections: sections.length, quizzes: quizzes.length, questions: questions.length, generatedInMs: Date.now() - startedAt },
    }, { headers: { "Cache-Control": "public, s-maxage=300, stale-while-revalidate=600" } });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected learning API error.";
    return NextResponse.json({ error: { code: "LEARNING_DATA_UNAVAILABLE", message } }, { status: 503 });
  }
}
