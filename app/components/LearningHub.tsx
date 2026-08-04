"use client";

import { useEffect, useMemo, useState } from "react";
import { ArrowRight, BookOpenCheck, Brain, CheckCircle2, Clock3, RefreshCw, Sparkles } from "lucide-react";
import type { Locale } from "../lib/i18n";

type Lesson = {
  id: string;
  slug: string;
  organ: string;
  difficulty: string;
  minutes: number;
  summary: string;
  function: string;
  location: string;
  sections: number;
  questions: number;
};

type ApiResponse = {
  data?: Lesson[];
  meta?: { lessons: number; sections: number; quizzes: number; questions: number };
  error?: { message: string };
};

const organNames: Record<string, { en: string; ar: string }> = {
  heart: { en: "Heart", ar: "القلب" }, brain: { en: "Brain", ar: "الدماغ" }, lungs: { en: "Lungs", ar: "الرئتان" },
  liver: { en: "Liver", ar: "الكبد" }, kidneys: { en: "Kidneys", ar: "الكليتان" }, eyeball: { en: "Eye", ar: "العين" },
  intestine: { en: "Intestine", ar: "الأمعاء" }, pancreas: { en: "Pancreas", ar: "البنكرياس" }, skin: { en: "Skin", ar: "الجلد" },
};

const copy = {
  en: {
    eyebrow: "Structured learning",
    title: "Turn exploration into lasting knowledge",
    description: "Short lessons, clear clinical context, and focused knowledge checks connected to every 3D specimen.",
    lessons: "Published lessons", sections: "Learning sections", quizzes: "Knowledge checks", questions: "Questions",
    loading: "Loading the learning library…", retry: "Try again", unavailable: "The learning library is temporarily unavailable.",
    minutes: "min", sectionsLabel: "sections", questionsLabel: "questions", open: "Start lesson", beginner: "Beginner",
    pathTitle: "Recommended study path", pathText: "Explore the model, review the key structures, then complete the short knowledge check.",
  },
  ar: {
    eyebrow: "تعلّم منظّم",
    title: "حوّل الاستكشاف إلى معرفة راسخة",
    description: "دروس قصيرة وسياق سريري واضح واختبارات مركزة مرتبطة بكل نموذج تشريحي ثلاثي الأبعاد.",
    lessons: "الدروس المنشورة", sections: "الأقسام التعليمية", quizzes: "اختبارات المعرفة", questions: "الأسئلة",
    loading: "جارٍ تحميل المكتبة التعليمية…", retry: "إعادة المحاولة", unavailable: "المكتبة التعليمية غير متاحة مؤقتًا.",
    minutes: "د", sectionsLabel: "أقسام", questionsLabel: "أسئلة", open: "ابدأ الدرس", beginner: "مبتدئ",
    pathTitle: "مسار الدراسة المقترح", pathText: "استكشف النموذج، وراجع التراكيب الأساسية، ثم أكمل اختبار المعرفة القصير.",
  },
} as const;

export function LearningHub({ locale, activeOrgan }: { locale: Locale; activeOrgan: string }) {
  const t = copy[locale];
  const [response, setResponse] = useState<ApiResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    let cancelled = false;
    setLoading(true);
    fetch("/api/learning", { headers: { Accept: "application/json" } })
      .then(async (result) => {
        const body = await result.json() as ApiResponse;
        if (!result.ok) throw new Error(body.error?.message || "Learning API failed");
        return body;
      })
      .then((body) => { if (!cancelled) setResponse(body); })
      .catch((error) => { if (!cancelled) setResponse({ error: { message: error instanceof Error ? error.message : String(error) } }); })
      .finally(() => { if (!cancelled) setLoading(false); });
    return () => { cancelled = true; };
  }, [attempt]);

  const lessons = response?.data ?? [];
  const ordered = useMemo(() => {
    const preferred = lessons.filter((lesson) => lesson.organ === activeOrgan);
    return [...preferred, ...lessons.filter((lesson) => lesson.organ !== activeOrgan)].slice(0, 4);
  }, [activeOrgan, lessons]);

  return (
    <section className="learning-hub" aria-labelledby="learning-hub-title">
      <div className="learning-hub-intro">
        <span className="section-eyebrow"><Sparkles size={15} /> {t.eyebrow}</span>
        <h2 id="learning-hub-title">{t.title}</h2>
        <p>{t.description}</p>
      </div>

      {loading ? (
        <div className="learning-hub-state" role="status"><RefreshCw className="spin" size={22} /><span>{t.loading}</span></div>
      ) : response?.error ? (
        <div className="learning-hub-state error" role="alert"><span>{t.unavailable}</span><button onClick={() => setAttempt((value) => value + 1)}><RefreshCw size={15} /> {t.retry}</button></div>
      ) : (
        <>
          <div className="learning-metrics" aria-label={locale === "ar" ? "إحصاءات المحتوى التعليمي" : "Learning content metrics"}>
            <Metric icon={<BookOpenCheck size={20} />} value={response?.meta?.lessons ?? lessons.length} label={t.lessons} />
            <Metric icon={<Brain size={20} />} value={response?.meta?.sections ?? 0} label={t.sections} />
            <Metric icon={<CheckCircle2 size={20} />} value={response?.meta?.quizzes ?? 0} label={t.quizzes} />
            <Metric icon={<Sparkles size={20} />} value={response?.meta?.questions ?? 0} label={t.questions} />
          </div>

          <div className="learning-path-card">
            <div><span>01</span><strong>{t.pathTitle}</strong><p>{t.pathText}</p></div>
            <ol aria-label={t.pathTitle}>
              <li>{locale === "ar" ? "استكشف النموذج" : "Explore the model"}</li>
              <li>{locale === "ar" ? "راجع الحقائق والتراكيب" : "Review facts and structures"}</li>
              <li>{locale === "ar" ? "اختبر فهمك" : "Check your understanding"}</li>
            </ol>
          </div>

          <div className="lesson-grid">
            {ordered.map((lesson) => {
              const name = organNames[lesson.organ]?.[locale] ?? lesson.organ;
              return (
                <article key={lesson.id} className={`lesson-card ${lesson.organ === activeOrgan ? "featured" : ""}`}>
                  <div className="lesson-card-top"><span>{name}</span><small>{locale === "ar" ? t.beginner : lesson.difficulty}</small></div>
                  <h3>{locale === "ar" ? `أساسيات ${name}` : `${name} foundations`}</h3>
                  <p>{lesson.summary}</p>
                  <div className="lesson-meta">
                    <span><Clock3 size={14} /> {lesson.minutes} {t.minutes}</span>
                    <span>{lesson.sections} {t.sectionsLabel}</span>
                    <span>{lesson.questions} {t.questionsLabel}</span>
                  </div>
                  <a href={`/learn/${lesson.slug}`} aria-label={`${t.open}: ${name}`}>{t.open} <ArrowRight size={15} /></a>
                </article>
              );
            })}
          </div>
        </>
      )}
    </section>
  );
}

function Metric({ icon, value, label }: { icon: React.ReactNode; value: number; label: string }) {
  return <article><span>{icon}</span><div><strong>{value}</strong><small>{label}</small></div></article>;
}
