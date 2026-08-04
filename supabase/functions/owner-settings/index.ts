import { authenticatedUser, corsHeaders, env, HttpError, jsonResponse, reauthenticate, requireProfile, supabaseFetch } from "../_shared/http.ts";

interface Payload {
  currentPassword?: string;
  username?: string;
  email?: string;
  newPassword?: string;
  initialSetup?: boolean;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  let authUpdated = false;
  try {
    const { token, user } = await authenticatedUser(req);
    const profile = await requireProfile(user.id, ["owner"]);
    const payload = await req.json() as Payload;
    const currentEmail = String(user.email || profile.email || "").toLowerCase();
    const currentUsername = String(profile.username || "");
    const username = String(payload.username || currentUsername).trim();
    const email = String(payload.email || currentEmail).trim().toLowerCase();
    const newPassword = payload.newPassword ? String(payload.newPassword) : undefined;
    const initialSetup = profile.must_change_credentials === true || payload.initialSetup === true;

    if (!/^[A-Za-z0-9_.-]{3,40}$/.test(username)) throw new HttpError(400, "Username must be 3–40 safe characters.");
    if (!/^\S+@\S+\.\S+$/.test(email)) throw new HttpError(400, "A valid email is required.");
    if (newPassword && newPassword.length < 14) throw new HttpError(400, "The new password must contain at least 14 characters.");
    if (initialSetup) {
      if (!newPassword || username === currentUsername || email === currentEmail) {
        throw new HttpError(400, "Initial setup requires a new username, email, and password.");
      }
    }

    await reauthenticate(currentEmail, String(payload.currentPassword || ""));

    const previousMetadata = user.user_metadata || {};
    await supabaseFetch(`/auth/v1/admin/users/${encodeURIComponent(user.id)}`, {
      method: "PUT",
      body: {
        email,
        ...(newPassword ? { password: newPassword } : {}),
        email_confirm: true,
        user_metadata: { ...previousMetadata, username, initial_owner: false },
      },
    });
    authUpdated = true;

    try {
      const publishableKey = env("SUPABASE_ANON_KEY");
      await supabaseFetch("/rest/v1/rpc/sync_owner_profile", {
        method: "POST",
        apikey: publishableKey,
        bearer: token,
        body: { p_username: username, p_email: email, p_must_change_credentials: false },
      });
    } catch (syncError) {
      // Compensating rollback keeps Auth and profiles aligned if the database transaction fails.
      await supabaseFetch(`/auth/v1/admin/users/${encodeURIComponent(user.id)}`, {
        method: "PUT",
        body: {
          email: currentEmail,
          ...(newPassword ? { password: String(payload.currentPassword) } : {}),
          email_confirm: true,
          user_metadata: previousMetadata,
        },
      });
      authUpdated = false;
      throw syncError;
    }

    return jsonResponse({ ok: true, username, email, role: "owner", mustChangeCredentials: false });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : "Unexpected server error.";
    console.error("owner-settings failed", { status, message, authUpdated });
    return jsonResponse({ error: message }, status);
  }
});
