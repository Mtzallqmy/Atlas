import { authenticatedUser, corsHeaders, HttpError, jsonResponse, reauthenticate, requireProfile, supabaseFetch } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);
  try {
    const { user } = await authenticatedUser(req);
    const owner = await requireProfile(user.id, ["owner"]);
    const { currentPassword, targetUserId } = await req.json() as { currentPassword?: string; targetUserId?: string };
    if (!targetUserId) throw new HttpError(400, "Target user is required.");
    await reauthenticate(String(user.email || owner.email || ""), String(currentPassword || ""));
    await requireProfile(targetUserId, ["admin", "editor", "medical_reviewer", "translator", "user"]);
    await supabaseFetch("/rest/v1/rpc/transfer_owner_role", {
      method: "POST",
      body: { p_current_owner_id: user.id, p_target_user_id: targetUserId },
    });
    return jsonResponse({ ok: true, previousOwnerId: user.id, ownerId: targetUserId });
  } catch (error) {
    const status = error instanceof HttpError ? error.status : 500;
    const message = error instanceof Error ? error.message : "Unexpected server error.";
    console.error("owner-transfer failed", { status, message });
    return jsonResponse({ error: message }, status);
  }
});
