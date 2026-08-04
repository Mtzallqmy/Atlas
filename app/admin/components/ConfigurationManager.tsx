"use client";

import { AlertCircle, FileText, ListTree, Plus, RefreshCw, Save, Settings2 } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import type { AppRole } from "../../lib/supabase-browser";
import { restInsert, restSelect, restUpdate } from "../../lib/supabase-browser";

type Tab = "settings" | "navigation" | "pages";
type SettingRow = { key: string; value: unknown; is_public: boolean; description?: string | null; updated_at?: string };
type NavigationRow = { id: string; slug: string; route: string; icon?: string | null; sort_order: number; required_role?: string | null; is_enabled: boolean };
type PageRow = { id: string; slug: string; template: string; status: string; metadata: unknown };

function JsonArea({ value, onChange }: { value: string; onChange: (value: string) => void }) {
  return <textarea dir="ltr" rows={8} value={value} onChange={(event) => onChange(event.target.value)} spellCheck={false} />;
}

export function ConfigurationManager({ role, locked = false }: { role: AppRole; locked?: boolean }) {
  const [tab, setTab] = useState<Tab>("settings");
  const [settings, setSettings] = useState<SettingRow[]>([]);
  const [navigation, setNavigation] = useState<NavigationRow[]>([]);
  const [pages, setPages] = useState<PageRow[]>([]);
  const [editing, setEditing] = useState<Record<string, unknown> | null>(null);
  const [isNew, setIsNew] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const [settingsRows, navRows, pageRows] = await Promise.all([
        restSelect<SettingRow[]>("app_settings", { select: "key,value,is_public,description,updated_at", order: "key.asc" }),
        restSelect<NavigationRow[]>("navigation_items", { select: "id,slug,route,icon,sort_order,required_role,is_enabled", deleted_at: "is.null", order: "sort_order.asc" }),
        restSelect<PageRow[]>("content_pages", { select: "id,slug,template,status,metadata", deleted_at: "is.null", order: "updated_at.desc" }),
      ]);
      setSettings(settingsRows); setNavigation(navRows); setPages(pageRows);
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setLoading(false); }
  }, []);

  useEffect(() => { void load(); }, [load]);

  const openNew = () => {
    setIsNew(true);
    if (tab === "settings") setEditing({ key: "", valueText: "{}", is_public: false, description: "" });
    if (tab === "navigation") setEditing({ slug: "", route: "/", icon: "", sort_order: 0, required_role: "", is_enabled: true });
    if (tab === "pages") setEditing({ slug: "", template: "article", status: "draft", metadataText: "{}" });
  };

  const openEdit = (row: SettingRow | NavigationRow | PageRow) => {
    setIsNew(false);
    if (tab === "settings") {
      const item = row as SettingRow;
      setEditing({ ...item, valueText: JSON.stringify(item.value, null, 2) });
    } else if (tab === "pages") {
      const item = row as PageRow;
      setEditing({ ...item, metadataText: JSON.stringify(item.metadata, null, 2) });
    } else setEditing({ ...row });
  };

  const save = async () => {
    if (!editing || !canEdit) return;
    setError("");
    try {
      if (tab === "settings") {
        const key = String(editing.key || "").trim();
        if (!key) throw new Error("مفتاح الإعداد مطلوب.");
        const payload = {
          key,
          value: JSON.parse(String(editing.valueText || "{}")),
          is_public: Boolean(editing.is_public),
          description: String(editing.description || "").trim() || null,
        };
        if (isNew) await restInsert("app_settings", payload);
        else await restUpdate("app_settings", `key=eq.${encodeURIComponent(key)}`, payload);
      } else if (tab === "navigation") {
        const payload = {
          slug: String(editing.slug || "").trim(), route: String(editing.route || "").trim(),
          icon: String(editing.icon || "").trim() || null, sort_order: Number(editing.sort_order || 0),
          required_role: String(editing.required_role || "").trim() || null, is_enabled: Boolean(editing.is_enabled),
        };
        if (!payload.slug || !payload.route) throw new Error("المعرّف والمسار مطلوبان.");
        if (isNew) await restInsert("navigation_items", payload);
        else await restUpdate("navigation_items", `id=eq.${editing.id}`, payload);
      } else {
        const payload = {
          slug: String(editing.slug || "").trim(), template: String(editing.template || "article").trim(),
          status: String(editing.status || "draft"), metadata: JSON.parse(String(editing.metadataText || "{}")),
        };
        if (!payload.slug) throw new Error("معرّف الصفحة مطلوب.");
        if (isNew) await restInsert("content_pages", payload);
        else await restUpdate("content_pages", `id=eq.${editing.id}`, payload);
      }
      setEditing(null); await load();
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  const canEdit = !locked && (tab === "settings" ? role === "owner" : role === "owner" || role === "admin");
  const rows: Array<SettingRow | NavigationRow | PageRow> = tab === "settings" ? settings : tab === "navigation" ? navigation : pages;
  return <section className="admin-page">
    <header className="admin-page-header"><div><em>تشغيل التطبيق</em><h1>الإعدادات والقوائم والصفحات</h1><p>إدارة الإعدادات العامة ومسارات التنقل والصفحات القابلة للنشر مع تسجيل كامل للتغييرات.</p></div><div className="admin-header-actions"><button className="secondary-admin-button" onClick={load}><RefreshCw size={16}/> تحديث</button><button className="primary-admin-button" disabled={!canEdit} onClick={openNew}><Plus size={16}/> إضافة</button></div></header>
    {error && <div className="admin-inline-error"><AlertCircle size={18}/><span>{error}</span><button onClick={() => setError("")}>إغلاق</button></div>}
    <div className="admin-segmented-tabs" role="tablist">
      <button className={tab === "settings" ? "active" : ""} onClick={() => { setTab("settings"); setEditing(null); }}><Settings2 size={16}/> إعدادات التطبيق</button>
      <button className={tab === "navigation" ? "active" : ""} onClick={() => { setTab("navigation"); setEditing(null); }}><ListTree size={16}/> القوائم</button>
      <button className={tab === "pages" ? "active" : ""} onClick={() => { setTab("pages"); setEditing(null); }}><FileText size={16}/> الصفحات</button>
    </div>
    <div className="admin-table-card">
      {loading ? <div className="admin-list-loading">جارٍ تحميل الإعدادات…</div> : <div className="admin-record-list">{rows.map((row) => {
        const id = "key" in row ? row.key : row.id;
        const title = "key" in row ? row.key : row.slug;
        const subtitle = "route" in row ? row.route : "template" in row ? `${row.template} · ${row.status}` : row.description || JSON.stringify(row.value);
        return <article key={id} className="clickable-record" onClick={() => openEdit(row)}><div className="record-copy"><h3>{title}</h3><p>{subtitle}</p></div><span className="configuration-edit-label">تعديل</span></article>;
      })}</div>}
    </div>
    {editing && <div className="admin-modal-backdrop"><section className="admin-modal"><header><div><em>{isNew ? "سجل جديد" : "تحرير"}</em><h2>{tab === "settings" ? "إعداد التطبيق" : tab === "navigation" ? "عنصر قائمة" : "صفحة"}</h2></div><button onClick={() => setEditing(null)}>×</button></header><div className="admin-form-grid one-column">
      {tab === "settings" && <><label><span>المفتاح</span><input dir="ltr" disabled={!isNew} value={String(editing.key || "")} onChange={(e) => setEditing({...editing, key:e.target.value})}/></label><label><span>القيمة JSON</span><JsonArea value={String(editing.valueText || "{}")} onChange={(value) => setEditing({...editing, valueText:value})}/></label><label className="admin-check"><input type="checkbox" checked={Boolean(editing.is_public)} onChange={(e) => setEditing({...editing, is_public:e.target.checked})}/><span>متاح للقراءة العامة</span></label><label><span>الوصف</span><textarea rows={3} value={String(editing.description || "")} onChange={(e) => setEditing({...editing, description:e.target.value})}/></label></>}
      {tab === "navigation" && <><label><span>المعرّف</span><input dir="ltr" value={String(editing.slug || "")} onChange={(e) => setEditing({...editing, slug:e.target.value})}/></label><label><span>المسار</span><input dir="ltr" value={String(editing.route || "")} onChange={(e) => setEditing({...editing, route:e.target.value})}/></label><label><span>الأيقونة</span><input dir="ltr" value={String(editing.icon || "")} onChange={(e) => setEditing({...editing, icon:e.target.value})}/></label><label><span>الترتيب</span><input type="number" value={Number(editing.sort_order || 0)} onChange={(e) => setEditing({...editing, sort_order:e.target.value})}/></label><label><span>الدور المطلوب (اختياري)</span><select value={String(editing.required_role || "")} onChange={(e) => setEditing({...editing, required_role:e.target.value})}><option value="">عام</option><option>owner</option><option>admin</option><option>editor</option><option>medical_reviewer</option><option>translator</option><option>user</option></select></label><label className="admin-check"><input type="checkbox" checked={Boolean(editing.is_enabled)} onChange={(e) => setEditing({...editing, is_enabled:e.target.checked})}/><span>مفعّل</span></label></>}
      {tab === "pages" && <><label><span>المعرّف</span><input dir="ltr" value={String(editing.slug || "")} onChange={(e) => setEditing({...editing, slug:e.target.value})}/></label><label><span>القالب</span><input dir="ltr" value={String(editing.template || "article")} onChange={(e) => setEditing({...editing, template:e.target.value})}/></label><label><span>الحالة</span><select value={String(editing.status || "draft")} onChange={(e) => setEditing({...editing, status:e.target.value})}>{["draft","under_review","medically_reviewed","published","archived"].map(s => <option key={s}>{s}</option>)}</select></label><label><span>Metadata JSON</span><JsonArea value={String(editing.metadataText || "{}")} onChange={(value) => setEditing({...editing, metadataText:value})}/></label></>}
    </div><footer><button className="secondary-admin-button" onClick={() => setEditing(null)}>إلغاء</button><button className="primary-admin-button" disabled={!canEdit} onClick={save}><Save size={16}/> حفظ</button></footer></section></div>}
  </section>;
}
