"use client";

export type AppRole = "owner" | "admin" | "editor" | "medical_reviewer" | "translator" | "user";

export interface AuthSession {
  access_token: string;
  refresh_token: string;
  expires_at: number;
  user: { id: string; email?: string; user_metadata?: Record<string, unknown> };
}

export interface Profile {
  id: string;
  username: string;
  display_name?: string | null;
  email?: string | null;
  role: AppRole;
  locale: string;
  must_change_credentials: boolean;
  is_active: boolean;
}

const SESSION_KEY = "anatomy-atlas.admin.session";

function config() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL?.replace(/\/$/, "");
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) {
    throw new Error("Supabase is not configured. Set NEXT_PUBLIC_SUPABASE_URL and NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY.");
  }
  return { url, key };
}

function parseJsonSafely(text: string) {
  if (!text) return null;
  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

async function rawRequest(path: string, init: RequestInit = {}, token?: string) {
  const { url, key } = config();
  const response = await fetch(`${url}${path}`, {
    ...init,
    headers: {
      apikey: key,
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...init.headers,
    },
  });
  const text = await response.text();
  const body = parseJsonSafely(text);
  if (!response.ok) {
    const message = typeof body === "object" && body
      ? body.message || body.error_description || body.hint || body.details
      : text;
    throw new Error(message || `Request failed with status ${response.status}`);
  }
  return body;
}

export function readSession(): AuthSession | null {
  if (typeof window === "undefined") return null;
  const value = window.localStorage.getItem(SESSION_KEY);
  if (!value) return null;
  try {
    return JSON.parse(value) as AuthSession;
  } catch {
    window.localStorage.removeItem(SESSION_KEY);
    return null;
  }
}

function storeSession(session: AuthSession | null) {
  if (typeof window === "undefined") return;
  if (!session) window.localStorage.removeItem(SESSION_KEY);
  else window.localStorage.setItem(SESSION_KEY, JSON.stringify(session));
  window.dispatchEvent(new CustomEvent("anatomy-session-changed"));
}

export async function signIn(email: string, password: string): Promise<AuthSession> {
  const result = await rawRequest("/auth/v1/token?grant_type=password", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  }) as Omit<AuthSession, "expires_at"> & { expires_in: number };
  const session: AuthSession = {
    ...result,
    expires_at: Math.floor(Date.now() / 1000) + result.expires_in,
  };
  storeSession(session);
  return session;
}

export async function refreshSession(): Promise<AuthSession | null> {
  const existing = readSession();
  if (!existing) return null;
  try {
    const result = await rawRequest("/auth/v1/token?grant_type=refresh_token", {
      method: "POST",
      body: JSON.stringify({ refresh_token: existing.refresh_token }),
    }) as Omit<AuthSession, "expires_at"> & { expires_in: number };
    const session: AuthSession = {
      ...result,
      expires_at: Math.floor(Date.now() / 1000) + result.expires_in,
    };
    storeSession(session);
    return session;
  } catch {
    storeSession(null);
    return null;
  }
}

export async function getValidSession(): Promise<AuthSession | null> {
  const session = readSession();
  if (!session) return null;
  if (session.expires_at - Math.floor(Date.now() / 1000) < 90) return refreshSession();
  return session;
}

export async function signOut() {
  const session = readSession();
  try {
    if (session) await rawRequest("/auth/v1/logout", { method: "POST" }, session.access_token);
  } finally {
    storeSession(null);
  }
}

function encodeQuery(query: Record<string, string | number | boolean | undefined>) {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value !== undefined) params.set(key, String(value));
  }
  const result = params.toString();
  return result ? `?${result}` : "";
}

export async function restSelect<T>(table: string, query: Record<string, string | number | boolean | undefined> = {}): Promise<T> {
  const session = await getValidSession();
  return rawRequest(`/rest/v1/${table}${encodeQuery(query)}`, { method: "GET" }, session?.access_token) as Promise<T>;
}

export async function restInsert<T>(table: string, value: unknown): Promise<T> {
  const session = await getValidSession();
  if (!session) throw new Error("Authentication required.");
  return rawRequest(`/rest/v1/${table}`, {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify(value),
  }, session.access_token) as Promise<T>;
}

export async function restUpdate<T>(table: string, filter: string, value: unknown): Promise<T> {
  const session = await getValidSession();
  if (!session) throw new Error("Authentication required.");
  return rawRequest(`/rest/v1/${table}?${filter}`, {
    method: "PATCH",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify(value),
  }, session.access_token) as Promise<T>;
}

export async function restDelete<T>(table: string, filter: string): Promise<T> {
  const session = await getValidSession();
  if (!session) throw new Error("Authentication required.");
  return rawRequest(`/rest/v1/${table}?${filter}`, {
    method: "DELETE",
    headers: { Prefer: "return=representation" },
  }, session.access_token) as Promise<T>;
}

export async function rpc<T>(name: string, args: Record<string, unknown> = {}): Promise<T> {
  const session = await getValidSession();
  return rawRequest(`/rest/v1/rpc/${name}`, {
    method: "POST",
    body: JSON.stringify(args),
  }, session?.access_token) as Promise<T>;
}

export async function invokeFunction<T>(name: string, payload: unknown): Promise<T> {
  const session = await getValidSession();
  if (!session) throw new Error("Authentication required.");
  return rawRequest(`/functions/v1/${name}`, {
    method: "POST",
    body: JSON.stringify(payload),
  }, session.access_token) as Promise<T>;
}

export async function uploadMedicalAsset(path: string, file: File): Promise<void> {
  const session = await getValidSession();
  if (!session) throw new Error("Authentication required.");
  const { url, key } = config();
  const response = await fetch(`${url}/storage/v1/object/medical-content/${encodeURIComponent(path).replace(/%2F/g, "/")}`, {
    method: "POST",
    headers: {
      apikey: key,
      Authorization: `Bearer ${session.access_token}`,
      "Content-Type": file.type || "application/octet-stream",
      "x-upsert": "false",
    },
    body: file,
  });
  if (!response.ok) {
    const text = await response.text();
    throw new Error(parseJsonSafely(text)?.message || text || "Asset upload failed.");
  }
}

export async function loadCurrentProfile(): Promise<Profile> {
  const session = await getValidSession();
  if (!session) throw new Error("Authentication required.");
  const profiles = await restSelect<Profile[]>("profiles", {
    select: "id,username,display_name,email,role,locale,must_change_credentials,is_active",
    id: `eq.${session.user.id}`,
    limit: 1,
  });
  if (!profiles[0]) throw new Error("No profile exists for this account.");
  return profiles[0];
}

export async function reportAdminError(error: unknown, context: Record<string, unknown> = {}) {
  try {
    const session = await getValidSession();
    if (!session) return;
    const message = error instanceof Error ? error.message : String(error);
    await restInsert("moderation_queue", {
      item_type: "admin_ui",
      item_id: crypto.randomUUID(),
      reason: message.slice(0, 1000),
      severity: "error",
      metadata: context,
    });
  } catch {
    // Error reporting must never create a second visible failure.
  }
}
