"use client";

import { AlertCircle, ClipboardCheck, RefreshCw, Send } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import type { Profile } from "../../lib/supabase-browser";
import { restSelect, rpc } from "../../lib/supabase-browser";

type Review = { id: string; entity_type: string; entity_id: string; reviewer_id: string; decision: string; notes?: string | null; reviewed_version?: number | null; created_at: string };

export function MedicalReviewsManager({ profile, locked = false }: { profile: Profile; locked?: boolean }) {
  const [rows, setRows] = useState<Review[]>([]);
  const [entityType, setEntityType] = useState("organs");
  const [entityId, setEntityId] = useState("");
  const [decision, setDecision] = useState("approved");
  const [notes, setNotes] = useState("");
  const [version, setVersion] = useState("");
  const [error, setError] = useState("");
  const canReview = profile.role === "owner" || profile.role === "medical_reviewer";

  const load = useCallback(async () => {
    try { setRows(await restSelect<Review[]>("medical_reviews", { select: "*", order: "created_at.desc", limit: 300 })); }
    catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  }, []);
  useEffect(() => { void load(); }, [load]);

  const submit = async () => {
    if (!canReview || locked) return;
    setError("");
    try {
      await rpc("submit_medical_review", { p_entity_type: entityType, p_entity_id: entityId.trim(), p_decision: decision, p_notes: notes || null, p_reviewed_version: version ? Number(version) : null });
      setEntityId(""); setNotes(""); setVersion(""); await load();
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  return <section className="admin-page">
    <header className="admin-page-header"><div><em>بوابة الاعتماد</em><h1>المراجعات الطبية</h1><p>قرارات المراجعين مرتبطة بنسخة المحتوى وتُسجل في سجل التدقيق قبل السماح بالنشر.</p></div><button className="secondary-admin-button" onClick={load}><RefreshCw size={16}/> تحديث</button></header>
    {error && <div className="admin-inline-error"><AlertCircle size={18}/><span>{error}</span><button onClick={() => setError("")}>إغلاق</button></div>}
    <div className="review-layout">
      <article className="admin-panel-card"><header><div><em>قرار جديد</em><h2>اعتماد محتوى</h2></div><ClipboardCheck size={20}/></header>
        {!canReview && <p className="admin-empty-copy">حسابك يستطيع عرض المراجعات فقط. يلزم دور medical_reviewer أو owner لإصدار قرار.</p>}
        <div className="admin-form-grid one-column"><label><span>نوع المحتوى</span><select value={entityType} onChange={(e) => setEntityType(e.target.value)}>{["anatomical_systems","organs","organ_parts","tissues","cell_types","pathology_topics","diseases","lessons","quizzes","content_pages"].map(t => <option key={t}>{t}</option>)}</select></label><label><span>معرّف السجل UUID</span><input dir="ltr" value={entityId} onChange={(e) => setEntityId(e.target.value)}/></label><label><span>القرار</span><select value={decision} onChange={(e) => setDecision(e.target.value)}><option value="approved">approved</option><option value="changes_requested">changes_requested</option><option value="rejected">rejected</option><option value="pending">pending</option></select></label><label><span>رقم الإصدار</span><input type="number" min="1" value={version} onChange={(e) => setVersion(e.target.value)}/></label><label><span>ملاحظات المراجع</span><textarea rows={5} value={notes} onChange={(e) => setNotes(e.target.value)}/></label></div>
        <button className="primary-admin-button wide-button" disabled={!canReview || locked || !entityId.trim()} onClick={submit}><Send size={16}/> حفظ قرار المراجعة</button>
      </article>
      <article className="admin-panel-card"><header><div><em>السجل</em><h2>آخر القرارات</h2></div><ClipboardCheck size={20}/></header><div className="review-list">{rows.length ? rows.map(row => <div key={row.id}><span className={`review-decision ${row.decision}`}>{row.decision}</span><p><b>{row.entity_type}</b><code>{row.entity_id}</code><small>{new Date(row.created_at).toLocaleString("ar")} · v{row.reviewed_version || "—"}</small>{row.notes && <em>{row.notes}</em>}</p></div>) : <p className="admin-empty-copy">لا توجد مراجعات بعد.</p>}</div></article>
    </div>
  </section>;
}
