"use client";

import { AlertTriangle, LoaderCircle } from "lucide-react";
import { useCallback, useEffect, useState, type ReactNode } from "react";
import type { Profile } from "../lib/supabase-browser";
import { loadCurrentProfile, reportAdminError, signOut } from "../lib/supabase-browser";
import { AdminErrorBoundary } from "./components/AdminErrorBoundary";
import { AdminShell } from "./components/AdminShell";
import { ContentManager } from "./components/ContentManager";
import { ConfigurationManager } from "./components/ConfigurationManager";
import { MedicalReviewsManager } from "./components/MedicalReviewsManager";
import { AuditLogViewer } from "./components/AuditLogViewer";
import { DashboardOverview } from "./components/DashboardOverview";
import { IntegrityPanel } from "./components/IntegrityPanel";
import { MediaManager } from "./components/MediaManager";
import { OwnerSettings } from "./components/OwnerSettings";
import { UsersManager } from "./components/UsersManager";
import { resources, type AdminSection } from "./types";

const staffRoles = ["owner", "admin", "editor", "medical_reviewer", "translator"];

export default function AdminPage() {
  const [profile, setProfile] = useState<Profile | null>(null);
  const [section, setSection] = useState<AdminSection>("overview");
  const [error, setError] = useState("");

  const load = useCallback(async () => {
    try {
      const result = await loadCurrentProfile();
      if (!staffRoles.includes(result.role)) throw new Error("لا يملك هذا الحساب صلاحية إدارة المحتوى.");
      setProfile(result);
      if (result.must_change_credentials) setSection("settings");
    } catch (value) {
      const message = value instanceof Error ? value.message : String(value);
      setError(message);
      void reportAdminError(value, { page: "admin-bootstrap" });
      setTimeout(() => window.location.assign("/admin/login"), 1200);
    }
  }, []);

  useEffect(() => {
    const hash = window.location.hash.replace("#", "") as AdminSection;
    if (hash) setSection(hash);
    void load();
  }, [load]);

  const navigate = (next: AdminSection) => {
    if (profile?.must_change_credentials && next !== "settings") return setSection("settings");
    setSection(next);
    window.history.replaceState(null, "", `#${next}`);
  };

  const logout = async () => { await signOut(); window.location.assign("/admin/login"); };

  if (!profile) return <main className="admin-bootstrap-state" dir="rtl">{error ? <><AlertTriangle size={34} /><h1>تعذر فتح لوحة التحكم</h1><p>{error}</p></> : <><LoaderCircle className="spin" size={34} /><h1>جارٍ التحقق من الجلسة…</h1></>}</main>;

  let content: ReactNode;
  const config = resources[section];
  if (section === "overview") content = <DashboardOverview />;
  else if (config) content = <ContentManager config={config} role={profile.role} locked={profile.must_change_credentials} />;
  else if (section === "media") content = <MediaManager role={profile.role} locked={profile.must_change_credentials} />;
  else if (section === "reviews") content = <MedicalReviewsManager profile={profile} locked={profile.must_change_credentials} />;
  else if (section === "configuration") content = <ConfigurationManager role={profile.role} locked={profile.must_change_credentials} />;
  else if (section === "audit") content = profile.role === "owner" ? <AuditLogViewer /> : <DashboardOverview />;
  else if (section === "integrity") content = <IntegrityPanel locked={profile.must_change_credentials} />;
  else if (section === "users") content = <UsersManager currentProfile={profile} locked={profile.must_change_credentials} />;
  else if (section === "settings") content = profile.role === "owner" ? <OwnerSettings profile={profile} onUpdated={load} /> : <DashboardOverview />;
  else content = <DashboardOverview />;

  return <AdminErrorBoundary><AdminShell profile={profile} active={section} onNavigate={navigate} onSignOut={logout}>{content}</AdminShell></AdminErrorBoundary>;
}
