"use client";

import { AlertTriangle, RefreshCw } from "lucide-react";
import { useEffect } from "react";
import { reportAdminError } from "../lib/supabase-browser";

export default function AdminRouteError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  useEffect(() => { void reportAdminError(error, { digest: error.digest, boundary: "admin-route" }); }, [error]);
  return <main className="admin-fatal-state" dir="rtl"><AlertTriangle size={38} /><h1>حدث خطأ غير متوقع</h1><p>{error.message}</p><button onClick={reset}><RefreshCw size={17} /> إعادة المحاولة</button></main>;
}
