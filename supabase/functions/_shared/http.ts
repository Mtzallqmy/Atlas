export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" },
  });
}

export function env(name: string) {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`Missing server secret: ${name}`);
  return value;
}

export function bearerToken(req: Request) {
  const value = req.headers.get("Authorization") || "";
  if (!value.startsWith("Bearer ")) throw new HttpError(401, "Authentication required.");
  return value.slice(7);
}

export class HttpError extends Error {
  constructor(public status: number, message: string) { super(message); }
}

export async function supabaseFetch<T>(
  path: string,
  options: {
    method?: string;
    apikey?: string;
    bearer?: string;
    body?: unknown;
    headers?: Record<string, string>;
  } = {},
): Promise<T> {
  const url = env("SUPABASE_URL").replace(/\/$/, "");
  const key = options.apikey || env("SUPABASE_SERVICE_ROLE_KEY");
  const response = await fetch(`${url}${path}`, {
    method: options.method || "GET",
    headers: {
      apikey: key,
      Authorization: `Bearer ${options.bearer || key}`,
      "Content-Type": "application/json",
      ...options.headers,
    },
    body: options.body === undefined ? undefined : JSON.stringify(options.body),
  });
  const text = await response.text();
  let payload: unknown = null;
  try { payload = text ? JSON.parse(text) : null; } catch { payload = text; }
  if (!response.ok) {
    const message = typeof payload === "object" && payload
      ? String((payload as Record<string, unknown>).message || (payload as Record<string, unknown>).error_description || (payload as Record<string, unknown>).details || "Supabase request failed")
      : String(payload || "Supabase request failed");
    throw new HttpError(response.status, message);
  }
  return payload as T;
}

export async function authenticatedUser(req: Request) {
  const token = bearerToken(req);
  const user = await supabaseFetch<{ id: string; email?: string; user_metadata?: Record<string, unknown> }>("/auth/v1/user", {
    apikey: env("SUPABASE_SERVICE_ROLE_KEY"),
    bearer: token,
  });
  return { token, user };
}

export async function requireProfile(userId: string, allowedRoles: string[]) {
  const profiles = await supabaseFetch<Array<Record<string, unknown>>>(
    `/rest/v1/profiles?id=eq.${encodeURIComponent(userId)}&deleted_at=is.null&select=id,username,email,role,must_change_credentials,is_active&limit=1`,
  );
  const profile = profiles[0];
  if (!profile || profile.is_active !== true) throw new HttpError(403, "Account is not active.");
  if (!allowedRoles.includes(String(profile.role))) throw new HttpError(403, "Insufficient permissions.");
  return profile;
}

export async function reauthenticate(email: string, password: string) {
  if (!password) throw new HttpError(400, "Current password is required.");
  const publishableKey = env("SUPABASE_ANON_KEY");
  try {
    return await supabaseFetch<{ access_token: string }>("/auth/v1/token?grant_type=password", {
      method: "POST",
      apikey: publishableKey,
      bearer: publishableKey,
      body: { email, password },
    });
  } catch {
    throw new HttpError(401, "Current password is incorrect.");
  }
}
