import assert from "node:assert/strict";
import { access, readFile } from "node:fs/promises";
import test from "node:test";

const root = new URL("../", import.meta.url);
const file = (path) => new URL(path, root);

const requiredFiles = [
  "README.md", ".env.example", "app/admin/page.tsx",
  "app/admin/components/ConfigurationManager.tsx",
  "app/admin/components/MedicalReviewsManager.tsx",
  "app/admin/components/AuditLogViewer.tsx",
  "mobile/pubspec.yaml", "mobile/lib/main.dart",
  "supabase/migrations/202608040001_initial_schema.sql",
  "supabase/migrations/202608040002_owner_security.sql",
  "supabase/migrations/202608040003_admin_operations.sql",
  "supabase/migrations/202608040004_security_and_content_refinements.sql",
  "supabase/migrations/202608040005_integrity_and_storage_checks.sql",
  "supabase/functions/owner-settings/index.ts",
  "supabase/functions/owner-transfer/index.ts",
  "supabase/functions/ai-tutor/index.ts",
];

test("production surfaces and infrastructure are present", async () => {
  await Promise.all(requiredFiles.map((path) => access(file(path))));
});

test("owner credentials are environment-only and service role is not used by clients", async () => {
  const [bootstrap, envExample, browser, flutter] = await Promise.all([
    readFile(file("scripts/bootstrap-owner.mjs"), "utf8"),
    readFile(file(".env.example"), "utf8"),
    readFile(file("app/lib/supabase-browser.ts"), "utf8"),
    readFile(file("mobile/lib/app/bootstrap/bootstrap.dart"), "utf8"),
  ]);
  assert.match(bootstrap, /process\.env\.INITIAL_OWNER_PASSWORD/);
  const unsafeExample = ["Change", "Me", "Immediately"].join("");
  assert.ok(!bootstrap.includes(unsafeExample));
  assert.match(envExample, /INITIAL_OWNER_PASSWORD=SET_A_UNIQUE_TEMPORARY_PASSWORD/);
  assert.doesNotMatch(browser, /SERVICE_ROLE/i);
  assert.doesNotMatch(flutter, /SERVICE_ROLE/i);
});

test("database protects the single owner and uses RLS", async () => {
  const schema = await readFile(file("supabase/migrations/202608040001_initial_schema.sql"), "utf8");
  const owner = await readFile(file("supabase/migrations/202608040002_owner_security.sql"), "utf8");
  const operations = await readFile(file("supabase/migrations/202608040003_admin_operations.sql"), "utf8");
  assert.match(schema, /create unique index profiles_single_owner/i);
  assert.match(schema, /alter table public\.profiles enable row level security/i);
  assert.match(owner, /auth\.role\(\) <> 'service_role'/i);
  assert.match(operations, /admin_update_user_access/i);
  assert.match(operations, /Owner transfer requires the protected owner-transfer Edge Function/i);
  assert.match(schema, /audit_logs/i);
});

test("README contains required attribution and setup topics", async () => {
  const readme = await readFile(file("README.md"), "utf8");
  assert.match(readme, /تطوير وبرمجة:\s*معتز العلقمي/);
  for (const topic of ["Supabase", "Flutter", "لوحة التحكم", "الاختبارات", "المساهمة", "النشر"]) assert.match(readme, new RegExp(topic, "i"));
});


test("offline package delivery and AI gateway include failure controls", async () => {
  const [downloads, ai, quizSecurity] = await Promise.all([
    readFile(file("mobile/lib/core/downloads/download_manager.dart"), "utf8"),
    readFile(file("supabase/functions/ai-tutor/index.ts"), "utf8"),
    readFile(file("supabase/migrations/202608040004_security_and_content_refinements.sql"), "utf8"),
  ]);
  assert.match(downloads, /Range/);
  assert.match(downloads, /sha256/);
  assert.match(downloads, /rolled_back/);
  assert.doesNotMatch(downloads, /Future<void> closeSink[\s\S]{0,180}await closeSink\(\)/);
  assert.match(ai, /AbortSignal\.timeout\(45_000\)/);
  assert.match(ai, /AI_DAILY_USER_QUOTA/);
  assert.match(quizSecurity, /revoke select on public\.question_options from anon, authenticated/i);
});

test("all public tables in the initial schema enable row-level security", async () => {
  const schema = await readFile(file("supabase/migrations/202608040001_initial_schema.sql"), "utf8");
  const tables = [...schema.matchAll(/create table public\.([a-z_][a-z0-9_]*)/gi)].map((match) => match[1]);
  const protectedTables = new Set([...schema.matchAll(/alter table public\.([a-z_][a-z0-9_]*) enable row level security/gi)].map((match) => match[1]));
  assert.ok(tables.length > 50);
  assert.deepEqual(tables.filter((table) => !protectedTables.has(table)), []);
});
