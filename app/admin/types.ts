import type { AppRole } from "../lib/supabase-browser";

export type AdminSection =
  | "overview"
  | "systems"
  | "organs"
  | "parts"
  | "pathology"
  | "diseases"
  | "lessons"
  | "quizzes"
  | "translations"
  | "references"
  | "media"
  | "reviews"
  | "configuration"
  | "audit"
  | "users"
  | "integrity"
  | "settings";

export type FieldKind = "text" | "textarea" | "number" | "boolean" | "status" | "role" | "uuid" | "json";

export interface FieldConfig {
  key: string;
  label: string;
  kind: FieldKind;
  required?: boolean;
  placeholder?: string;
  readOnly?: boolean;
}

export interface ResourceConfig {
  section: AdminSection;
  label: string;
  singular: string;
  table: string;
  titleField: string;
  subtitleField?: string;
  softDelete?: boolean;
  allowedRoles: AppRole[];
  fields: FieldConfig[];
}

const contentRoles: AppRole[] = ["owner", "admin", "editor"];

export const resources: Partial<Record<AdminSection, ResourceConfig>> = {
  systems: {
    section: "systems",
    label: "الأجهزة التشريحية",
    singular: "جهاز تشريحي",
    table: "anatomical_systems",
    titleField: "slug",
    subtitleField: "summary",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true, placeholder: "cardiovascular" },
      { key: "code", label: "الرمز", kind: "text" },
      { key: "summary", label: "الملخص", kind: "textarea" },
      { key: "status", label: "الحالة", kind: "status", required: true },
      { key: "sort_order", label: "الترتيب", kind: "number" },
      { key: "icon_asset_path", label: "مسار الأيقونة", kind: "text" },
    ],
  },
  organs: {
    section: "organs",
    label: "الأعضاء",
    singular: "عضو",
    table: "organs",
    titleField: "slug",
    subtitleField: "latin_name",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "system_id", label: "معرّف الجهاز", kind: "uuid", required: true },
      { key: "body_region_id", label: "معرّف منطقة الجسم", kind: "uuid" },
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true, placeholder: "heart" },
      { key: "latin_name", label: "الاسم اللاتيني", kind: "text" },
      { key: "definition", label: "التعريف", kind: "textarea" },
      { key: "function_summary", label: "الوظيفة", kind: "textarea" },
      { key: "location_summary", label: "الموقع", kind: "textarea" },
      { key: "histology_summary", label: "البنية المجهرية", kind: "textarea" },
      { key: "clinical_significance", label: "الأهمية السريرية", kind: "textarea" },
      { key: "thumbnail_path", label: "الصورة المصغرة", kind: "text" },
      { key: "fallback_image_path", label: "الصورة البديلة", kind: "text" },
      { key: "status", label: "الحالة", kind: "status", required: true },
      { key: "sort_order", label: "الترتيب", kind: "number" },
    ],
  },
  parts: {
    section: "parts",
    label: "الأجزاء التشريحية",
    singular: "جزء تشريحي",
    table: "organ_parts",
    titleField: "slug",
    subtitleField: "latin_name",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "organ_id", label: "معرّف العضو", kind: "uuid", required: true },
      { key: "parent_id", label: "معرّف الجزء الأب", kind: "uuid" },
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true },
      { key: "latin_name", label: "الاسم اللاتيني", kind: "text" },
      { key: "definition", label: "التعريف", kind: "textarea" },
      { key: "function_summary", label: "الوظيفة", kind: "textarea" },
      { key: "clinical_significance", label: "الأهمية السريرية", kind: "textarea" },
      { key: "stable_model_key", label: "مفتاح النموذج المستقر", kind: "text" },
      { key: "status", label: "الحالة", kind: "status", required: true },
      { key: "sort_order", label: "الترتيب", kind: "number" },
    ],
  },
  pathology: {
    section: "pathology",
    label: "موضوعات الباثولوجي",
    singular: "موضوع باثولوجي",
    table: "pathology_topics",
    titleField: "slug",
    subtitleField: "summary",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "parent_id", label: "الموضوع الأب", kind: "uuid" },
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true },
      { key: "scope", label: "النطاق general/systemic", kind: "text", required: true },
      { key: "summary", label: "الملخص", kind: "textarea" },
      { key: "status", label: "الحالة", kind: "status", required: true },
    ],
  },
  diseases: {
    section: "diseases",
    label: "الأمراض",
    singular: "مرض",
    table: "diseases",
    titleField: "slug",
    subtitleField: "definition",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "category_id", label: "معرّف التصنيف", kind: "uuid" },
      { key: "pathology_topic_id", label: "معرّف موضوع الباثولوجي", kind: "uuid" },
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true },
      { key: "definition", label: "التعريف", kind: "textarea" },
      { key: "etiology", label: "الأسباب", kind: "textarea" },
      { key: "pathogenesis", label: "الآلية المرضية", kind: "textarea" },
      { key: "gross_changes", label: "التغيرات العيانية", kind: "textarea" },
      { key: "microscopic_changes", label: "التغيرات المجهرية", kind: "textarea" },
      { key: "diagnostic_overview", label: "التشخيص التعليمي", kind: "textarea" },
      { key: "treatment_principles", label: "مبادئ العلاج العامة", kind: "textarea" },
      { key: "prevention", label: "الوقاية", kind: "textarea" },
      { key: "normal_vs_pathological", label: "الطبيعي مقابل المرضي", kind: "textarea" },
      { key: "is_genetic", label: "وراثي", kind: "boolean" },
      { key: "is_infectious", label: "معدٍ", kind: "boolean" },
      { key: "is_malignant", label: "خبيث", kind: "boolean" },
      { key: "course", label: "المسار acute/chronic", kind: "text" },
      { key: "status", label: "الحالة", kind: "status", required: true },
    ],
  },
  lessons: {
    section: "lessons",
    label: "الدروس",
    singular: "درس",
    table: "lessons",
    titleField: "slug",
    subtitleField: "summary",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true },
      { key: "system_id", label: "معرّف الجهاز", kind: "uuid" },
      { key: "organ_id", label: "معرّف العضو", kind: "uuid" },
      { key: "disease_id", label: "معرّف المرض", kind: "uuid" },
      { key: "level", label: "المستوى", kind: "text", required: true },
      { key: "estimated_minutes", label: "المدة بالدقائق", kind: "number" },
      { key: "summary", label: "الملخص", kind: "textarea" },
      { key: "status", label: "الحالة", kind: "status", required: true },
    ],
  },
  quizzes: {
    section: "quizzes",
    label: "الاختبارات",
    singular: "اختبار",
    table: "quizzes",
    titleField: "slug",
    subtitleField: "status",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true },
      { key: "lesson_id", label: "معرّف الدرس", kind: "uuid" },
      { key: "organ_id", label: "معرّف العضو", kind: "uuid" },
      { key: "disease_id", label: "معرّف المرض", kind: "uuid" },
      { key: "passing_score", label: "درجة النجاح", kind: "number" },
      { key: "time_limit_seconds", label: "الوقت بالثواني", kind: "number" },
      { key: "status", label: "الحالة", kind: "status", required: true },
    ],
  },
  translations: {
    section: "translations",
    label: "الترجمات",
    singular: "ترجمة",
    table: "translations",
    titleField: "value",
    subtitleField: "locale",
    softDelete: true,
    allowedRoles: ["owner", "admin", "editor", "medical_reviewer", "translator"],
    fields: [
      { key: "entity_type", label: "نوع الكيان", kind: "text", required: true },
      { key: "entity_id", label: "معرّف الكيان", kind: "uuid", required: true },
      { key: "field_name", label: "الحقل", kind: "text", required: true },
      { key: "locale", label: "اللغة", kind: "text", required: true },
      { key: "value", label: "النص المترجم", kind: "textarea", required: true },
      { key: "status", label: "حالة الترجمة", kind: "text", required: true },
      { key: "source_version", label: "إصدار المصدر", kind: "number" },
      { key: "model_name", label: "النموذج المستخدم", kind: "text" },
    ],
  },
  references: {
    section: "references",
    label: "المراجع الطبية",
    singular: "مرجع طبي",
    table: "references",
    titleField: "title",
    subtitleField: "authors",
    softDelete: true,
    allowedRoles: contentRoles,
    fields: [
      { key: "slug", label: "المعرّف الثابت", kind: "text", required: true },
      { key: "title", label: "العنوان", kind: "text", required: true },
      { key: "authors", label: "المؤلفون", kind: "text" },
      { key: "organization", label: "الجهة", kind: "text" },
      { key: "edition", label: "الطبعة", kind: "text" },
      { key: "publication_year", label: "السنة", kind: "number" },
      { key: "doi", label: "DOI", kind: "text" },
      { key: "pmid", label: "PMID", kind: "text" },
      { key: "url", label: "الرابط", kind: "text" },
      { key: "evidence_level", label: "مستوى الدليل", kind: "text", required: true },
      { key: "citation_text", label: "نص الاستشهاد", kind: "textarea" },
      { key: "is_active", label: "نشط", kind: "boolean" },
    ],
  },
};
