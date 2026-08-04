"use client";

import { AlertCircle, ArchiveRestore, ChevronLeft, Clock3, FilePlus2, Pencil, Plus, RefreshCw, Save, Search, Trash2, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { AppRole } from "../../lib/supabase-browser";
import { restInsert, restSelect, restUpdate, rpc } from "../../lib/supabase-browser";
import type { FieldConfig, ResourceConfig } from "../types";

interface Props { config: ResourceConfig; role: AppRole; locked?: boolean }
type Row = Record<string, unknown> & { id: string; updated_at?: string; status?: string };
type Version = { id: string; version_number: number; created_at: string; changed_by?: string; snapshot: Record<string, unknown> };

const statuses = ["draft", "under_review", "medically_reviewed", "published", "archived"];

function initialRecord(config: ResourceConfig) {
  return Object.fromEntries(config.fields.map((field) => [field.key, field.kind === "boolean" ? false : field.key === "status" ? "draft" : field.kind === "number" ? 0 : ""]));
}

function cleanPayload(config: ResourceConfig, value: Record<string, unknown>) {
  const payload: Record<string, unknown> = {};
  for (const field of config.fields) {
    let item = value[field.key];
    if (field.kind === "number") item = item === "" || item == null ? null : Number(item);
    if (field.kind === "boolean") item = Boolean(item);
    if ((field.kind === "uuid" || field.kind === "text" || field.kind === "textarea") && item === "") item = null;
    if (field.required && (item === null || item === undefined || item === "")) throw new Error(`الحقل «${field.label}» مطلوب.`);
    payload[field.key] = item;
  }
  return payload;
}

export function ContentManager({ config, role, locked = false }: Props) {
  const [rows, setRows] = useState<Row[]>([]);
  const [query, setQuery] = useState("");
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [editing, setEditing] = useState<Row | null>(null);
  const [form, setForm] = useState<Record<string, unknown>>(initialRecord(config));
  const [saving, setSaving] = useState(false);
  const [versionsFor, setVersionsFor] = useState<Row | null>(null);
  const [versions, setVersions] = useState<Version[]>([]);
  const canEdit = config.allowedRoles.includes(role) && !locked;

  const load = useCallback(async () => {
    setLoading(true); setError("");
    try {
      const data = await restSelect<Row[]>(config.table, {
        select: "*",
        ...(config.softDelete ? { deleted_at: "is.null" } : {}),
        order: "updated_at.desc.nullslast,created_at.desc.nullslast",
        limit: 250,
      });
      setRows(data);
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setLoading(false); }
  }, [config]);

  useEffect(() => { void load(); }, [load]);

  const filtered = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase("ar");
    if (!normalized) return rows;
    return rows.filter((row) => Object.values(row).some((value) => typeof value === "string" && value.toLocaleLowerCase("ar").includes(normalized)));
  }, [query, rows]);

  const openCreate = () => { setEditing({ id: "" }); setForm(initialRecord(config)); };
  const openEdit = (row: Row) => { setEditing(row); setForm(Object.fromEntries(config.fields.map((field) => [field.key, row[field.key] ?? (field.kind === "boolean" ? false : "")]))); };

  const save = async () => {
    setSaving(true); setError("");
    try {
      const payload = cleanPayload(config, form);
      if (editing?.id) await restUpdate<Row[]>(config.table, `id=eq.${editing.id}`, payload);
      else await restInsert<Row[]>(config.table, payload);
      setEditing(null);
      await load();
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setSaving(false); }
  };

  const remove = async (row: Row) => {
    if (!confirm(`سيتم أرشفة ${config.singular} دون حذف العلاقات أو الإصدارات. هل تريد المتابعة؟`)) return;
    setError("");
    try {
      if (config.softDelete) await restUpdate(config.table, `id=eq.${row.id}`, { deleted_at: new Date().toISOString(), status: "archived" });
      else throw new Error("الحذف المباشر معطل لهذا المورد. استخدم الأرشفة أو أداة العلاقات المخصصة.");
      await load();
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  const openVersions = async (row: Row) => {
    setVersionsFor(row); setVersions([]);
    try {
      setVersions(await restSelect<Version[]>("content_versions", {
        select: "id,version_number,created_at,changed_by,snapshot",
        entity_type: `eq.${config.table}`,
        entity_id: `eq.${row.id}`,
        order: "version_number.desc",
        limit: 50,
      }));
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  const restore = async (version: Version) => {
    if (!confirm(`استعادة الإصدار ${version.version_number}؟ سيُحفظ الوضع الحالي كإصدار جديد تلقائيًا.`)) return;
    try { await rpc("restore_content_version", { p_version_id: version.id }); setVersionsFor(null); await load(); }
    catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  return (
    <section className="admin-page">
      <header className="admin-page-header">
        <div><em>إدارة المحتوى</em><h1>{config.label}</h1><p>إنشاء وتحرير ومراجعة وأرشفة {config.label} مع حفظ سجل الإصدارات.</p></div>
        <div className="admin-header-actions"><button className="secondary-admin-button" onClick={load}><RefreshCw size={16} /> تحديث</button>{canEdit && <button className="primary-admin-button" onClick={openCreate}><Plus size={17} /> إضافة {config.singular}</button>}</div>
      </header>
      {locked && <div className="admin-inline-error"><AlertCircle size={18} /><span>غيّر بيانات المالك الأولية قبل تعديل المحتوى.</span></div>}
      {error && <div className="admin-inline-error"><AlertCircle size={18} /><span>{error}</span><button onClick={() => setError("")}>إغلاق</button></div>}
      <div className="admin-toolbar"><label><Search size={17} /><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder={`بحث في ${config.label}…`} /></label><span>{filtered.length} سجل</span></div>
      <div className="admin-table-card">
        {loading ? <div className="admin-list-loading">جارٍ تحميل البيانات…</div> : filtered.length === 0 ? <div className="admin-empty-state"><FilePlus2 size={31} /><h2>لا توجد بيانات</h2><p>ابدأ بإضافة أول {config.singular} أو غيّر عبارة البحث.</p>{canEdit && <button onClick={openCreate}>إضافة الآن</button>}</div> : (
          <div className="admin-record-list">
            {filtered.map((row) => (
              <article key={row.id}>
                <div className="record-status"><span className={`status-dot ${row.status || "neutral"}`} />{String(row.status || "active")}</div>
                <div className="record-copy"><h3>{String(row[config.titleField] || "بلا عنوان")}</h3><p>{String(row[config.subtitleField || "id"] || row.id)}</p><small><Clock3 size={12} /> {row.updated_at ? new Date(row.updated_at).toLocaleString("ar") : "غير محدد"}</small></div>
                <div className="record-actions">
                  <button type="button" onClick={() => openVersions(row)} title="الإصدارات"><ArchiveRestore size={16} /></button>
                  {canEdit && <button type="button" onClick={() => openEdit(row)} title="تعديل"><Pencil size={16} /></button>}
                  {canEdit && <button type="button" className="danger" onClick={() => remove(row)} title="أرشفة"><Trash2 size={16} /></button>}
                  <ChevronLeft size={17} />
                </div>
              </article>
            ))}
          </div>
        )}
      </div>

      {editing && (
        <div className="admin-modal-backdrop" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && setEditing(null)}>
          <section className="admin-modal" role="dialog" aria-modal="true" aria-label={`تحرير ${config.singular}`}>
            <header><div><em>{editing.id ? "تعديل سجل" : "سجل جديد"}</em><h2>{editing.id ? String(editing[config.titleField] || config.singular) : `إضافة ${config.singular}`}</h2></div><button onClick={() => setEditing(null)} aria-label="إغلاق"><X size={20} /></button></header>
            <div className="admin-form-grid">
              {config.fields.map((field) => <Field key={field.key} field={field} value={form[field.key]} onChange={(value) => setForm((current) => ({ ...current, [field.key]: value }))} />)}
            </div>
            <footer><button className="secondary-admin-button" onClick={() => setEditing(null)}>إلغاء</button><button className="primary-admin-button" onClick={save} disabled={saving}><Save size={16} /> {saving ? "جارٍ الحفظ…" : "حفظ"}</button></footer>
          </section>
        </div>
      )}

      {versionsFor && (
        <div className="admin-modal-backdrop" role="presentation" onMouseDown={(event) => event.target === event.currentTarget && setVersionsFor(null)}>
          <section className="admin-modal compact" role="dialog" aria-modal="true" aria-label="سجل الإصدارات">
            <header><div><em>سجل غير قابل للمحو</em><h2>إصدارات {String(versionsFor[config.titleField])}</h2></div><button onClick={() => setVersionsFor(null)}><X size={20} /></button></header>
            <div className="version-list">{versions.length ? versions.map((version) => <article key={version.id}><span>v{version.version_number}</span><div><b>{new Date(version.created_at).toLocaleString("ar")}</b><small>{Object.keys(version.snapshot).length} حقل محفوظ</small></div>{(role === "owner" || role === "admin") && <button onClick={() => restore(version)}><ArchiveRestore size={15} /> استعادة</button>}</article>) : <p className="admin-empty-copy">لا توجد إصدارات سابقة لهذا السجل.</p>}</div>
          </section>
        </div>
      )}
    </section>
  );
}

function Field({ field, value, onChange }: { field: FieldConfig; value: unknown; onChange: (value: unknown) => void }) {
  if (field.kind === "boolean") return <label className="admin-check-field"><input type="checkbox" checked={Boolean(value)} onChange={(event) => onChange(event.target.checked)} /><span>{field.label}</span></label>;
  if (field.kind === "status") return <label><span>{field.label}{field.required && " *"}</span><select value={String(value ?? "draft")} onChange={(event) => onChange(event.target.value)}>{statuses.map((status) => <option key={status} value={status}>{status}</option>)}</select></label>;
  if (field.kind === "textarea") return <label className="wide"><span>{field.label}{field.required && " *"}</span><textarea value={String(value ?? "")} onChange={(event) => onChange(event.target.value)} placeholder={field.placeholder} rows={5} /></label>;
  return <label><span>{field.label}{field.required && " *"}</span><input type={field.kind === "number" ? "number" : "text"} value={String(value ?? "")} onChange={(event) => onChange(event.target.value)} placeholder={field.placeholder} readOnly={field.readOnly} /></label>;
}
