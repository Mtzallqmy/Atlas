"use client";

import { AlertCircle, CheckCircle2, KeyRound, Mail, Save, ShieldCheck, UserRound } from "lucide-react";
import { useState } from "react";
import type { Profile } from "../../lib/supabase-browser";
import { invokeFunction } from "../../lib/supabase-browser";

interface Props { profile: Profile; onUpdated: () => Promise<void> }

export function OwnerSettings({ profile, onUpdated }: Props) {
  const [username, setUsername] = useState(profile.username);
  const [email, setEmail] = useState(profile.email || "");
  const [currentPassword, setCurrentPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [saving, setSaving] = useState(false);

  const save = async () => {
    setError(""); setSuccess("");
    if (!currentPassword) return setError("أدخل كلمة المرور الحالية لإعادة التحقق.");
    if (newPassword && newPassword !== confirmPassword) return setError("كلمتا المرور الجديدتان غير متطابقتين.");
    if (profile.must_change_credentials && (!newPassword || username === profile.username || email.toLowerCase() === profile.email?.toLowerCase())) {
      return setError("في الإعداد الأول يجب تغيير اسم المستخدم والبريد وكلمة المرور جميعًا.");
    }
    setSaving(true);
    try {
      await invokeFunction("owner-settings", {
        currentPassword,
        username,
        email,
        newPassword: newPassword || undefined,
        initialSetup: profile.must_change_credentials,
      });
      setCurrentPassword(""); setNewPassword(""); setConfirmPassword("");
      setSuccess("تم تحديث بيانات المالك بصورة آمنة. قد تحتاج إلى تسجيل الدخول بالبريد الجديد عند انتهاء الجلسة.");
      await onUpdated();
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setSaving(false); }
  };

  return (
    <section className="admin-page owner-settings-page">
      <header className="admin-page-header"><div><em>حساب محمي</em><h1>إعدادات المالك</h1><p>تُنفذ التغييرات من Edge Function بعد إعادة التحقق، ثم تُزامن Auth وprofiles وتُسجل في audit_logs.</p></div><span className="owner-role-badge"><ShieldCheck size={18} /> owner</span></header>
      {profile.must_change_credentials && <div className="first-login-banner"><KeyRound size={22} /><div><b>إعداد أول تسجيل دخول</b><p>لا يمكن متابعة الإدارة قبل تغيير اسم المستخدم والبريد وكلمة المرور الافتراضية.</p></div></div>}
      {error && <div className="admin-inline-error"><AlertCircle size={18} /><span>{error}</span></div>}
      {success && <div className="admin-inline-success"><CheckCircle2 size={18} /><span>{success}</span></div>}
      <div className="owner-settings-grid">
        <article className="admin-panel-card">
          <header><div><em>الهوية</em><h2>بيانات الحساب</h2></div><UserRound size={20} /></header>
          <div className="admin-form-grid one-column">
            <label><span><UserRound size={14} /> اسم المستخدم</span><input value={username} onChange={(event) => setUsername(event.target.value)} autoComplete="username" /></label>
            <label><span><Mail size={14} /> البريد الإلكتروني</span><input type="email" value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="email" /></label>
          </div>
        </article>
        <article className="admin-panel-card">
          <header><div><em>إعادة التحقق</em><h2>كلمة المرور</h2></div><KeyRound size={20} /></header>
          <div className="admin-form-grid one-column">
            <label><span>كلمة المرور الحالية *</span><input type="password" value={currentPassword} onChange={(event) => setCurrentPassword(event.target.value)} autoComplete="current-password" /></label>
            <label><span>كلمة المرور الجديدة {profile.must_change_credentials && "*"}</span><input type="password" value={newPassword} onChange={(event) => setNewPassword(event.target.value)} autoComplete="new-password" placeholder="14 حرفًا على الأقل" /></label>
            <label><span>تأكيد كلمة المرور الجديدة</span><input type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} autoComplete="new-password" /></label>
          </div>
        </article>
      </div>
      <div className="security-note"><ShieldCheck size={20} /><p><b>حماية دور المالك</b>لا تعرض اللوحة كلمات المرور ولا تخزنها. يمنع trigger قاعدة البيانات تخفيض دور owner أو إنشاء مالك ثانٍ، وتحتاج عملية النقل إلى endpoint خادمي منفصل وإعادة تحقق حديثة.</p></div>
      <button className="primary-admin-button owner-save-button" onClick={save} disabled={saving}><Save size={17} /> {saving ? "جارٍ التحقق والتحديث…" : "حفظ التغييرات الآمنة"}</button>
    </section>
  );
}
