"use client";

import React from "react";
import { AlertTriangle, RefreshCw } from "lucide-react";
import { reportAdminError } from "../../lib/supabase-browser";

interface Props { children: React.ReactNode }
interface State { error: Error | null }

export class AdminErrorBoundary extends React.Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    void reportAdminError(error, { componentStack: info.componentStack });
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <section className="admin-fatal-state" role="alert">
        <AlertTriangle size={38} />
        <h1>تعذر تحميل لوحة التحكم</h1>
        <p>{this.state.error.message}</p>
        <button type="button" onClick={() => this.setState({ error: null })}>
          <RefreshCw size={17} /> إعادة المحاولة
        </button>
      </section>
    );
  }
}
