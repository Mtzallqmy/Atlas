"use client";

import { AlertCircle, ArrowLeft, Eye, EyeOff, ShieldCheck } from "lucide-react";
import Link from "next/link";
import { useState } from "react";
import { loadCurrentProfile, signIn, signOut } from "../../lib/supabase-browser";

export default function AdminLoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [visible, setVisible] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const submit = async (event: React.FormEvent) => {
    event.preventDefault(); setLoading(true); setError("");
    try {
      await signIn(email, password);
      const profile = await loadCurrentProfile();
      if (!["owner", "admin", "editor", "medical_reviewer", "translator"].includes(profile.role)) {
        await signOut();
        throw new Error("هذا الحساب لا يملك صلاحية الوصول إلى لوحة الإدارة.");
      }
      window.location.assign("/admin");
    } catch (value) { setError(value instanceof Error ? value.message : String(value)); }
    finally { setLoading(false); }
  };

  return (
    <main className="admin-login-page" dir="rtl">
      <section className="admin-login-art">
        <Link href="/" className="back-to-atlas"><ArrowLeft size={16} /> العودة إلى الأطلس</Link>
        <div className="admin-login-mark"><ShieldCheck size={34} /></div>
        <em>Anatomy Atlas</em>
        <h1>إدارة المعرفة الطبية<br />بدقة ومسؤولية.</h1>
        <p>مساحة محمية لتحرير المحتوى، المراجعة الطبية، الترجمة، إدارة الأصول والإصدارات.</p>
        <blockquote>المحتوى المنشور لا يظهر للمتعلمين قبل اكتمال المرجع والمراجعة الطبية.</blockquote>
      </section>
      <section className="admin-login-form-wrap">
        <form onSubmit={submit} className="admin-login-form">
          <div className="admin-login-logo"><ShieldCheck size={22} /><span><b>Anatomy Atlas</b><small>Admin Console</small></span></div>
          <header><em>دخول آمن</em><h2>مرحبًا بعودتك</h2><p>استخدم حسابًا إداريًا مرتبطًا بـ Supabase Auth.</p></header>
          {error && <div className="admin-inline-error"><AlertCircle size={18} /><span>{error}</span></div>}
          <label><span>البريد الإلكتروني</span><input type="email" required value={email} onChange={(event) => setEmail(event.target.value)} autoComplete="username" /></label>
          <label><span>كلمة المرور</span><div className="password-field"><input type={visible ? "text" : "password"} required value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" /><button type="button" onClick={() => setVisible((value) => !value)} aria-label={visible ? "إخفاء كلمة المرور" : "إظهار كلمة المرور"}>{visible ? <EyeOff size={17} /> : <Eye size={17} />}</button></div></label>
          <button className="primary-admin-button login-submit" disabled={loading}>{loading ? "جارٍ التحقق…" : "تسجيل الدخول"}</button>
          <small className="login-security-copy">لا تحفظ لوحة التحكم كلمة المرور. تتم المصادقة مباشرة مع Supabase Auth عبر TLS.</small>
        </form>
      </section>
    </main>
  );
}
