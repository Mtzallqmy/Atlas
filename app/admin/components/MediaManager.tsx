"use client";

import { AlertCircle, Box, FileImage, FileText, RefreshCw, Trash2, UploadCloud } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import type { AppRole } from "../../lib/supabase-browser";
import { restInsert, restSelect, restUpdate, uploadMedicalAsset } from "../../lib/supabase-browser";

type MediaRow = {
  id: string;
  storage_path: string;
  asset_type: string;
  mime_type?: string;
  byte_size?: number;
  checksum_sha256?: string;
  status: string;
  created_at: string;
};

function bytes(value = 0) {
  if (value < 1024) return `${value} B`;
  if (value < 1024 ** 2) return `${(value / 1024).toFixed(1)} KB`;
  return `${(value / 1024 ** 2).toFixed(1)} MB`;
}

const acceptedTypes = new Set([
  "image/png", "image/jpeg", "image/webp", "image/avif",
  "model/gltf-binary", "model/gltf+json", "application/octet-stream",
  "audio/mpeg", "audio/ogg", "video/mp4", "application/pdf",
]);

function validateFile(file: File) {
  if (file.size <= 0) throw new Error("الملف فارغ.");
  if (file.size > 500 * 1024 * 1024) throw new Error("حجم الملف يتجاوز الحد الأقصى 500MB.");
  if (file.type && !acceptedTypes.has(file.type)) throw new Error(`نوع الملف غير مسموح: ${file.type}`);
  if (file.name.includes("..") || /[\\/]/.test(file.name)) throw new Error("اسم الملف غير آمن.");
}

async function sha256(file: File) {
  const digest = await crypto.subtle.digest("SHA-256", await file.arrayBuffer());
  return Array.from(new Uint8Array(digest)).map((value) => value.toString(16).padStart(2, "0")).join("");
}

export function MediaManager({ role, locked = false }: { role: AppRole; locked?: boolean }) {
  const canEdit = !locked && ["owner", "admin", "editor"].includes(role);
  const [rows, setRows] = useState<MediaRow[]>([]);
  const [file, setFile] = useState<File | null>(null);
  const [assetType, setAssetType] = useState("image");
  const [altText, setAltText] = useState("");
  const [license, setLicense] = useState("");
  const [attribution, setAttribution] = useState("");
  const [uploading, setUploading] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    setError("");
    try {
      setRows(await restSelect<MediaRow[]>("media_assets", { select: "id,storage_path,asset_type,mime_type,byte_size,checksum_sha256,status,created_at", deleted_at: "is.null", order: "created_at.desc", limit: 200 }));
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  }, []);
  useEffect(() => { void load(); }, [load]);

  const upload = async () => {
    if (!file) return setError("اختر ملفًا أولًا.");
    if (!canEdit) return setError("لا يملك هذا الدور صلاحية رفع الملفات.");
    setUploading(true); setError("");
    try {
      validateFile(file);
      const checksum = await sha256(file);
      const safeName = file.name.replace(/[^A-Za-z0-9_.-]+/g, "-").toLowerCase();
      const path = `draft/${assetType}/${Date.now()}-${safeName}`;
      await uploadMedicalAsset(path, file);
      await restInsert("media_assets", {
        storage_bucket: "medical-content",
        storage_path: path,
        asset_type: assetType,
        mime_type: file.type || "application/octet-stream",
        byte_size: file.size,
        checksum_sha256: checksum,
        alt_text: altText || null,
        license_name: license || null,
        attribution: attribution || null,
        status: "draft",
        metadata: { originalName: file.name, uploadedFrom: "admin-panel" },
      });
      setFile(null); setAltText(""); setLicense(""); setAttribution("");
      const input = document.getElementById("medical-asset-input") as HTMLInputElement | null;
      if (input) input.value = "";
      await load();
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setUploading(false); }
  };

  const archive = async (row: MediaRow) => {
    if (!confirm("سيتم أرشفة سجل الملف فقط. لا تُحذف البايتات تلقائيًا لتجنب كسر الإصدارات والحزم القديمة.")) return;
    try { await restUpdate("media_assets", `id=eq.${row.id}`, { status: "archived", deleted_at: new Date().toISOString() }); await load(); }
    catch (value) { setError(value instanceof Error ? value.message : String(value)); }
  };

  return (
    <section className="admin-page">
      <header className="admin-page-header"><div><em>مكتبة الأصول</em><h1>الصور والنماذج والملفات</h1><p>رفع آمن مع checksum وبيانات الترخيص وحالة نشر مستقلة.</p></div><button className="secondary-admin-button" onClick={load}><RefreshCw size={16} /> تحديث</button></header>
      {error && <div className="admin-inline-error"><AlertCircle size={18} /><span>{error}</span><button onClick={() => setError("")}>إغلاق</button></div>}
      <div className="media-layout">
        <article className="admin-panel-card media-upload-card">
          <header><div><em>رفع أصل جديد</em><h2>بيانات الملف</h2></div><UploadCloud size={20} /></header>
          <label className="drop-zone" htmlFor="medical-asset-input">
            <UploadCloud size={30} /><b>{file ? file.name : "اختر ملفًا أو اسحبه هنا"}</b><small>{file ? bytes(file.size) : "صور، GLB/GLTF، صوت، فيديو، PDF — حتى 500MB حسب إعداد bucket"}</small>
            <input id="medical-asset-input" type="file" onChange={(event) => setFile(event.target.files?.[0] || null)} />
          </label>
          <div className="admin-form-grid one-column">
            <label><span>نوع الأصل</span><select value={assetType} onChange={(event) => setAssetType(event.target.value)}><option value="image">صورة</option><option value="microscopy">صورة مجهرية</option><option value="model_3d">نموذج ثلاثي الأبعاد</option><option value="audio">صوت</option><option value="video">فيديو</option><option value="document">مستند</option><option value="thumbnail">صورة مصغرة</option><option value="fallback">صورة بديلة</option></select></label>
            <label><span>النص البديل</span><input value={altText} onChange={(event) => setAltText(event.target.value)} /></label>
            <label><span>الترخيص</span><input value={license} onChange={(event) => setLicense(event.target.value)} placeholder="CC BY 4.0" /></label>
            <label><span>نسبة المصدر</span><textarea value={attribution} onChange={(event) => setAttribution(event.target.value)} rows={3} /></label>
          </div>
          <button className="primary-admin-button wide-button" disabled={!file || uploading || !canEdit} onClick={upload}><UploadCloud size={17} /> {uploading ? "جارٍ التحقق والرفع…" : "رفع وحفظ البيانات"}</button>
        </article>
        <article className="admin-panel-card media-library-card">
          <header><div><em>آخر الملفات</em><h2>الأصول المسجلة</h2></div><Box size={20} /></header>
          <div className="media-list">{rows.length ? rows.map((row) => <div key={row.id}><span>{row.asset_type === "model_3d" ? <Box /> : row.asset_type === "document" ? <FileText /> : <FileImage />}</span><p><b>{row.storage_path.split("/").at(-1)}</b><small>{row.asset_type} · {bytes(row.byte_size)} · {row.status}</small><code>{row.checksum_sha256?.slice(0, 18) || "checksum missing"}…</code></p>{canEdit && <button onClick={() => archive(row)} title="أرشفة"><Trash2 size={16} /></button>}</div>) : <p className="admin-empty-copy">لم تُرفع ملفات بعد.</p>}</div>
        </article>
      </div>
    </section>
  );
}
