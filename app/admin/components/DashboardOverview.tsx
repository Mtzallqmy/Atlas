"use client";

import { AlertCircle, BookOpenCheck, Boxes, Database, FileWarning, Languages, RefreshCw, Stethoscope, Users } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { rpc } from "../../lib/supabase-browser";

interface Summary {
  systems: number;
  organs: number;
  diseases: number;
  lessons: number;
  quizzes: number;
  translationsPending: number;
  reviewQueue: number;
  moderationOpen: number;
  brokenAssets: number;
  users: number;
  recentAudit: Array<{ action?: string; entity_type?: string; created_at?: string; actor_role?: string }>;
}

const cards = [
  ["systems", "الأجهزة", Boxes],
  ["organs", "الأعضاء", Stethoscope],
  ["diseases", "الأمراض", Database],
  ["lessons", "الدروس", BookOpenCheck],
  ["translationsPending", "ترجمات معلقة", Languages],
  ["reviewQueue", "قائمة المراجعة", AlertCircle],
  ["brokenAssets", "ملفات تحتاج فحصًا", FileWarning],
  ["users", "المستخدمون", Users],
] as const;

export function DashboardOverview() {
  const [data, setData] = useState<Summary | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try { setData(await rpc<Summary>("admin_dashboard_summary")); }
    catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { void load(); }, [load]);

  return (
    <section className="admin-page">
      <header className="admin-page-header">
        <div><em>مركز العمليات</em><h1>نظرة عامة</h1><p>حالة المحتوى الطبي، المراجعات، الملفات، والمستخدمين.</p></div>
        <button type="button" className="secondary-admin-button" onClick={load}><RefreshCw size={16} /> تحديث</button>
      </header>
      {loading && <div className="admin-loading-grid">{Array.from({ length: 8 }).map((_, i) => <span key={i} />)}</div>}
      {error && <div className="admin-inline-error"><AlertCircle size={18} /><span>{error}</span><button onClick={load}>إعادة المحاولة</button></div>}
      {data && (
        <>
          <div className="admin-stat-grid">
            {cards.map(([key, label, Icon]) => <article key={key}><span><Icon size={20} /></span><strong>{data[key] ?? 0}</strong><small>{label}</small></article>)}
          </div>
          <div className="admin-two-columns">
            <article className="admin-panel-card">
              <header><div><em>آخر النشاطات</em><h2>سجل التعديلات</h2></div><Database size={19} /></header>
              <div className="audit-list">
                {data.recentAudit?.length ? data.recentAudit.map((entry, index) => (
                  <div key={`${entry.created_at}-${index}`}><span>{entry.actor_role || "system"}</span><p><b>{entry.action || "operation"}</b><small>{entry.entity_type || "—"}</small></p><time>{entry.created_at ? new Date(entry.created_at).toLocaleString("ar") : "—"}</time></div>
                )) : <p className="admin-empty-copy">لا توجد عمليات مسجلة بعد.</p>}
              </div>
            </article>
            <article className="admin-panel-card system-health-card">
              <header><div><em>مؤشرات التشغيل</em><h2>صحة المنصة</h2></div><ActivityIcon /></header>
              <dl>
                <div><dt>قاعدة البيانات</dt><dd className="ok">متصلة</dd></div>
                <div><dt>مشكلات المحتوى المفتوحة</dt><dd>{data.moderationOpen}</dd></div>
                <div><dt>الترجمات قيد العمل</dt><dd>{data.translationsPending}</dd></div>
                <div><dt>ملفات ناقصة البيانات</dt><dd className={data.brokenAssets ? "warn" : "ok"}>{data.brokenAssets}</dd></div>
              </dl>
            </article>
          </div>
        </>
      )}
    </section>
  );
}

function ActivityIcon() {
  return <span className="health-pulse" aria-label="حالة النظام"><i /><i /><i /></span>;
}
