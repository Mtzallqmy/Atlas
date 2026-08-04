-- Safe non-user seed data. The initial owner is intentionally NOT seeded here.
insert into public.app_settings(key, value, is_public, description) values
  ('application', '{"name":"Anatomy Atlas","medicalDisclaimerEnabled":true,"defaultLocale":"ar"}', true, 'Public application identity and defaults'),
  ('ai', '{"mode":"disabled","streaming":true,"dailyUserQuota":20}', false, 'Server-managed AI provider configuration'),
  ('downloads', '{"wifiOnlyDefault":true,"maxParallel":2}', true, 'Content package download defaults')
on conflict(key) do update set value=excluded.value, is_public=excluded.is_public, description=excluded.description;

insert into public.navigation_items(slug, route, icon, sort_order, is_enabled) values
  ('home', '/', 'home', 10, true),
  ('explorer', '/explore', 'body', 20, true),
  ('search', '/search', 'search', 30, true),
  ('downloads', '/downloads', 'download', 40, true),
  ('settings', '/settings', 'settings', 50, true)
on conflict(slug) do update set route=excluded.route, icon=excluded.icon, sort_order=excluded.sort_order, is_enabled=excluded.is_enabled;
