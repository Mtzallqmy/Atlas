#!/usr/bin/env node
/**
 * Creates exactly one initial owner through the Supabase Admin API.
 * This script is idempotent and reads all credentials from environment variables.
 */

const required = [
  "SUPABASE_URL",
  "SUPABASE_SERVICE_ROLE_KEY",
  "INITIAL_OWNER_USERNAME",
  "INITIAL_OWNER_EMAIL",
  "INITIAL_OWNER_PASSWORD",
];

for (const key of required) {
  if (!process.env[key]) {
    console.error(`Missing required environment variable: ${key}`);
    process.exit(1);
  }
}

const baseUrl = process.env.SUPABASE_URL.replace(/\/$/, "");
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const username = process.env.INITIAL_OWNER_USERNAME.trim();
const email = process.env.INITIAL_OWNER_EMAIL.trim().toLowerCase();
const password = process.env.INITIAL_OWNER_PASSWORD;

if (!/^[A-Za-z0-9_.-]{3,40}$/.test(username)) {
  throw new Error("INITIAL_OWNER_USERNAME must be 3–40 safe characters.");
}
if (!email.includes("@")) throw new Error("INITIAL_OWNER_EMAIL is invalid.");
if (password.length < 14) throw new Error("INITIAL_OWNER_PASSWORD must contain at least 14 characters.");
const headers = {
  apikey: serviceKey,
  Authorization: `Bearer ${serviceKey}`,
  "Content-Type": "application/json",
};

async function request(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, { ...options, headers: { ...headers, ...options.headers } });
  const text = await response.text();
  const body = text ? JSON.parse(text) : null;
  if (!response.ok) {
    throw new Error(`${options.method || "GET"} ${path} failed (${response.status}): ${body?.message || body?.error_description || text}`);
  }
  return body;
}

const existingOwners = await request("/rest/v1/profiles?role=eq.owner&deleted_at=is.null&select=id,email,username&limit=2");
if (existingOwners.length > 0) {
  const owner = existingOwners[0];
  console.log(`Initial owner already exists (${owner.email || owner.id}). No changes were made.`);
  process.exit(0);
}

const usersResponse = await request("/auth/v1/admin/users?page=1&per_page=1000");
const users = usersResponse.users || usersResponse;
let authUser = users.find((user) => user.email?.toLowerCase() === email);
let createdByThisRun = false;

if (!authUser) {
  const created = await request("/auth/v1/admin/users", {
    method: "POST",
    body: JSON.stringify({
      email,
      password,
      email_confirm: true,
      user_metadata: { username, display_name: username, initial_owner: true },
      app_metadata: { bootstrap_source: "server-script" },
    }),
  });
  authUser = created.user || created;
  createdByThisRun = true;
  console.log(`Created Supabase Auth user ${authUser.id}.`);
}

let profile;
try {
  profile = await request("/rest/v1/rpc/bootstrap_initial_owner", {
    method: "POST",
    headers: { Prefer: "return=representation" },
    body: JSON.stringify({ p_user_id: authUser.id, p_username: username, p_email: email }),
  });
} catch (error) {
  if (createdByThisRun) {
    try { await request(`/auth/v1/admin/users/${encodeURIComponent(authUser.id)}`, { method: "DELETE" }); }
    catch (cleanupError) { console.error("Owner bootstrap rollback failed:", cleanupError); }
  }
  throw error;
}

console.log(`Owner bootstrap complete for ${profile.email || email}.`);
console.log("The owner will be forced to change username, email, and password at first sign-in.");
