"use client";

import {
  Activity,
  BookOpenCheck,
  Boxes,
  Bug,
  ClipboardCheck,
  Database,
  FileQuestion,
  FlaskConical,
  Languages,
  LibraryBig,
  LogOut,
  Menu,
  Microscope,
  PanelRightClose,
  Settings,
  SlidersHorizontal,
  History,
  ShieldCheck,
  UploadCloud,
  Users,
} from "lucide-react";
import { useState, type ReactNode } from "react";
import type { Profile } from "../../lib/supabase-browser";
import type { AdminSection } from "../types";

interface Props {
  profile: Profile;
  active: AdminSection;
  onNavigate: (section: AdminSection) => void;
  onSignOut: () => void;
  children: ReactNode;
}

const items: Array<{ key: AdminSection; label: string; icon: typeof Activity; ownerOnly?: boolean }> = [
  { key: "overview", label: "نظرة عامة", icon: Activity },
  { key: "systems", label: "الأجهزة", icon: Boxes },
  { key: "organs", label: "الأعضاء", icon: LibraryBig },
  { key: "parts", label: "الأجزاء", icon: Microscope },
  { key: "pathology", label: "الباثولوجي", icon: FlaskConical },
  { key: "diseases", label: "الأمراض", icon: ClipboardCheck },
  { key: "lessons", label: "الدروس", icon: BookOpenCheck },
  { key: "quizzes", label: "الاختبارات", icon: FileQuestion },
  { key: "translations", label: "الترجمات", icon: Languages },
  { key: "references", label: "المراجع", icon: Database },
  { key: "media", label: "الملفات والنماذج", icon: UploadCloud },
  { key: "reviews", label: "المراجعات الطبية", icon: ClipboardCheck },
  { key: "configuration", label: "الإعدادات والقوائم", icon: SlidersHorizontal },
  { key: "audit", label: "سجل العمليات", icon: History, ownerOnly: true },
  { key: "users", label: "المستخدمون والصلاحيات", icon: Users, ownerOnly: true },
  { key: "integrity", label: "سلامة المحتوى", icon: Bug },
  { key: "settings", label: "إعدادات المالك", icon: Settings, ownerOnly: true },
];

export function AdminShell({ profile, active, onNavigate, onSignOut, children }: Props) {
  const [open, setOpen] = useState(false);
  return (
    <main className="admin-app" dir="rtl">
      <aside className={`admin-sidebar ${open ? "open" : ""}`}>
        <div className="admin-brand">
          <span><ShieldCheck size={22} /></span>
          <div><strong>Anatomy Atlas</strong><small>لوحة إدارة المحتوى الطبي</small></div>
          <button type="button" className="admin-sidebar-close" onClick={() => setOpen(false)} aria-label="إغلاق القائمة"><PanelRightClose size={20} /></button>
        </div>
        <nav aria-label="أقسام لوحة التحكم">
          {items.filter((item) => !item.ownerOnly || profile.role === "owner").map((item) => {
            const Icon = item.icon;
            return (
              <button
                key={item.key}
                type="button"
                className={active === item.key ? "active" : ""}
                onClick={() => { onNavigate(item.key); setOpen(false); }}
              >
                <Icon size={18} /><span>{item.label}</span>
              </button>
            );
          })}
        </nav>
        <div className="admin-sidebar-profile">
          <span>{profile.username.slice(0, 2).toUpperCase()}</span>
          <div><b>{profile.username}</b><small>{profile.role}</small></div>
          <button type="button" onClick={onSignOut} aria-label="تسجيل الخروج"><LogOut size={17} /></button>
        </div>
      </aside>
      <section className="admin-main">
        <header className="admin-mobile-header">
          <button type="button" onClick={() => setOpen(true)} aria-label="فتح القائمة"><Menu size={22} /></button>
          <strong>Anatomy Atlas Admin</strong>
          <span>{profile.username.slice(0, 2).toUpperCase()}</span>
        </header>
        {profile.must_change_credentials && active !== "settings" && (
          <button className="credential-warning" type="button" onClick={() => onNavigate("settings")}>
            <ShieldCheck size={18} /> يجب تغيير اسم المستخدم والبريد وكلمة المرور قبل متابعة إدارة المحتوى.
          </button>
        )}
        <div className="admin-content">{children}</div>
      </section>
      {open && <button type="button" className="admin-backdrop" aria-label="إغلاق القائمة" onClick={() => setOpen(false)} />}
    </main>
  );
}
