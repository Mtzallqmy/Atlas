"use client";

import { AlertCircle, CheckCircle2, RefreshCw, ShieldAlert, Wrench, X } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { rpc } from "../../lib/supabase-browser";

type Issue = { issue_key: string; severity: "info" | "warning" | "error" | "critical"; entity_type: string; entity_id: string; message: string; suggested_action: string };

export function IntegrityPanel({ locked = false }: { locked?: boolean }) {
  const [issues, setIssues] = useState<Issue[]>([]);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [repairing, setRepairing] = useState<Issue | null>(null);
  const [patch, setPatch] = useState("{}");

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try { setIssues(await rpc<Issue[]>("content_integrity_report", { p_limit: 500 })); }
    catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);

  const apply = async () => {
    if (!repairing) return;
    try {
      const parsed = JSON.parse(patch);
      await rpc("apply_safe_content_patch", { p_entity_type: repairing.entity_type, p_entity_id: repairing.entity_id, p_patch: parsed });
      setRepairing(null); setPatch("{}"); await load();
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  return (
    <section className="admin-page">
      <header className="admin-page-header"><div><em>فحص غير إتلافي</em><h1>سلامة المحتوى والملفات</h1><p>يكشف الحقول والمراجع والترجمات والـ manifests الناقصة دون تعديلها تلقائيًا.</p></div><button className="secondary-admin-button" onClick={load}><RefreshCw size={16} /> إعادة الفحص</button></header>
      {error && <div className="admin-inline-error"><AlertCircle size={18} /><span>{error}</span><button onClick={() => setError("")}>إغلاق</button></div>}
      {loading ? <div className="admin-list-loading">جارٍ تنفيذ فحوص سلامة البيانات…</div> : issues.length === 0 ? <div className="integrity-success"><CheckCircle2 size={38} /><h2>لا توجد مشكلات معروفة</h2><p>اجتازت السجلات الحالية قواعد التحقق المفعلة.</p></div> : (
        <div className="integrity-list">{issues.map((issue) => <article key={issue.issue_key} className={issue.severity}><span><ShieldAlert size={19} /></span><div><header><b>{issue.message}</b><small>{issue.severity}</small></header><p>{issue.suggested_action}</p><code>{issue.entity_type} / {issue.entity_id}</code></div>{["organs", "diseases", "media_assets"].includes(issue.entity_type) && <button disabled={locked} onClick={() => { setRepairing(issue); setPatch("{}"); }}><Wrench size={15} /> إصلاح آمن</button>}</article>)}</div>
      )}
      {repairing && <div className="admin-modal-backdrop"><section className="admin-modal compact"><header><div><em>Patch مقيد الحقول</em><h2>إصلاح السجل</h2></div><button onClick={() => setRepairing(null)}><X size={20} /></button></header><p className="repair-note">أدخل JSON للحقول المسموح بها فقط. تُرفض الحقول العلائقية أو الحساسة، ويُحفظ قبل/بعد في سجل التدقيق.</p><textarea className="json-editor" value={patch} onChange={(event) => setPatch(event.target.value)} rows={12} spellCheck={false} /><footer><button className="secondary-admin-button" onClick={() => setRepairing(null)}>إلغاء</button><button className="primary-admin-button" onClick={apply}><Wrench size={16} /> تطبيق الإصلاح</button></footer></section></div>}
    </section>
  );
}
