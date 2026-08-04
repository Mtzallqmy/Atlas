"use client";

import { AlertTriangle, RefreshCw } from "lucide-react";

export default function RootError({ error, reset }: { error: Error & { digest?: string }; reset: () => void }) {
  return <main className="root-error-state"><AlertTriangle size={42} /><h1>تعذر عرض Anatomy Atlas</h1><p>{error.message}</p><button onClick={reset}><RefreshCw size={17} /> إعادة المحاولة</button></main>;
}
