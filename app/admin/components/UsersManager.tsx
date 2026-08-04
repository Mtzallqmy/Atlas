"use client";

import { AlertCircle, RefreshCw, Save, Shield, UserRound } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import type { AppRole, Profile } from "../../lib/supabase-browser";
import { restSelect, rpc } from "../../lib/supabase-browser";

const roles: AppRole[] = ["admin", "editor", "medical_reviewer", "translator", "user"];

export function UsersManager({ currentProfile, locked = false }: { currentProfile: Profile; locked?: boolean }) {
  const [rows, setRows] = useState<Profile[]>([]);
  const [draftRoles, setDraftRoles] = useState<Record<string, AppRole>>({});
  const [draftActive, setDraftActive] = useState<Record<string, boolean>>({});
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const data = await restSelect<Profile[]>("profiles", { select: "id,username,display_name,email,role,locale,must_change_credentials,is_active", deleted_at: "is.null", order: "created_at.desc", limit: 500 });
      setRows(data);
      setDraftRoles(Object.fromEntries(data.map((row) => [row.id, row.role])));
      setDraftActive(Object.fromEntries(data.map((row) => [row.id, row.is_active])));
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setLoading(false); }
  }, []);
  useEffect(() => { void load(); }, [load]);

  const save = async (row: Profile) => {
    if (locked) return setError("غيّر بيانات المالك الأولية أولًا.");
    const nextRole = draftRoles[row.id];
    if (row.role === "owner" || nextRole === "owner") return setError("لا يمكن تعديل دور المالك من هذه الشاشة.");
    try { await rpc("admin_update_user_access", { p_target_user_id: row.id, p_role: nextRole, p_is_active: draftActive[row.id] ?? row.is_active }); await load(); }
    catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  return (
    <section className="admin-page">
      <header className="admin-page-header"><div><em>الوصول والصلاحيات</em><h1>المستخدمون</h1><p>إدارة الأدوار التشغيلية. يبقى دور owner محميًا وغير قابل للتعديل من CRUD العام.</p></div><button className="secondary-admin-button" onClick={load}><RefreshCw size={16} /> تحديث</button></header>
      {error && <div className="admin-inline-error"><AlertCircle size={18} /><span>{error}</span><button onClick={() => setError("")}>إغلاق</button></div>}
      <div className="admin-table-card users-table">
        {loading ? <div className="admin-list-loading">جارٍ تحميل المستخدمين…</div> : rows.map((row) => <article key={row.id}><span className="user-avatar"><UserRound size={18} /></span><div><h3>{row.username}</h3><p>{row.email || "لا يوجد بريد"}</p></div><select value={draftRoles[row.id] || row.role} disabled={row.role === "owner" || currentProfile.role !== "owner"} onChange={(event) => setDraftRoles((current) => ({ ...current, [row.id]: event.target.value as AppRole }))}>{row.role === "owner" && <option value="owner">owner</option>}{roles.map((role) => <option key={role} value={role}>{role}</option>)}</select><label className={`account-state ${draftActive[row.id] ?? row.is_active ? "active" : "disabled"}`}><input type="checkbox" checked={draftActive[row.id] ?? row.is_active} disabled={row.role === "owner" || currentProfile.role !== "owner"} onChange={(event) => setDraftActive((current) => ({ ...current, [row.id]: event.target.checked }))} />{draftActive[row.id] ?? row.is_active ? "نشط" : "معطل"}</label><button className="secondary-admin-button" disabled={row.role === "owner" || ((draftRoles[row.id] ?? row.role) === row.role && (draftActive[row.id] ?? row.is_active) === row.is_active) || currentProfile.role !== "owner"} onClick={() => save(row)}><Save size={15} /> حفظ</button><Shield size={17} /></article>)}
      </div>
    </section>
  );
}
