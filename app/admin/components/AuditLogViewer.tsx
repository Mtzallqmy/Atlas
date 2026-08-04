"use client";

import { AlertCircle, History, RefreshCw, Search } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { restSelect } from "../../lib/supabase-browser";

type AuditRow = { id: string; actor_id?: string | null; actor_role?: string | null; action: string; entity_type?: string | null; entity_id?: string | null; metadata: unknown; created_at: string };

export function AuditLogViewer() {
  const [rows, setRows] = useState<AuditRow[]>([]);
  const [query, setQuery] = useState("");
  const [error, setError] = useState("");
  const load = useCallback(async () => {
    setError("");
    try { setRows(await restSelect<AuditRow[]>("audit_logs", { select: "id,actor_id,actor_role,action,entity_type,entity_id,metadata,created_at", order: "created_at.desc", limit: 500 })); }
    catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  }, []);
  useEffect(() => { void load(); }, [load]);
  const visible = useMemo(() => rows.filter(row => `${row.action} ${row.entity_type} ${row.entity_id} ${row.actor_role}`.toLowerCase().includes(query.toLowerCase())), [rows, query]);
  return <section className="admin-page"><header className="admin-page-header"><div><em>الأثر الأمني</em><h1>سجل العمليات</h1><p>عرض العمليات الإدارية الحساسة وتغييرات الوصول والمحتوى والإعدادات.</p></div><button className="secondary-admin-button" onClick={load}><RefreshCw size={16}/> تحديث</button></header>
    {error && <div className="admin-inline-error"><AlertCircle size={18}/><span>{error}</span></div>}
    <div className="admin-toolbar"><label><Search size={17}/><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="بحث في العملية أو الكيان أو الدور…"/></label><span>{visible.length} عملية</span></div>
    <div className="admin-table-card"><div className="audit-list">{visible.map(row => <article key={row.id}><span><History size={17}/></span><div><h3>{row.action}</h3><p>{row.entity_type || "system"} {row.entity_id ? `· ${row.entity_id}` : ""}</p><small>{row.actor_role || "service"} · {new Date(row.created_at).toLocaleString("ar")}</small></div><details><summary>metadata</summary><pre>{JSON.stringify(row.metadata, null, 2)}</pre></details></article>)}</div></div>
  </section>;
}
