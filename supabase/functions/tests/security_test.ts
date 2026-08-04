import { assert, assertEquals, assertStringIncludes } from "https://deno.land/std@0.224.0/assert/mod.ts";

Deno.test("owner and AI functions keep privileged credentials server-side", async () => {
  const owner = await Deno.readTextFile(new URL("../owner-settings/index.ts", import.meta.url));
  const transfer = await Deno.readTextFile(new URL("../owner-transfer/index.ts", import.meta.url));
  const ai = await Deno.readTextFile(new URL("../ai-tutor/index.ts", import.meta.url));
  assertStringIncludes(owner, "reauthenticate");
  assertStringIncludes(owner, "sync_owner_profile");
  assertStringIncludes(transfer, "transfer_owner_role");
  assertStringIncludes(ai, 'optionalEnv("OPENAI_API_KEY")');
  assert(!ai.includes("console.log(payload.providerKey"));
  assertEquals((owner.match(/SUPABASE_SERVICE_ROLE_KEY/g) || []).length, 0);
});
