begin;
select plan(13);

select has_table('public', 'profiles', 'profiles exists');
select has_table('public', 'audit_logs', 'audit logs exist');
select has_table('public', 'organs', 'organs exist');
select has_table('public', 'medical_reviews', 'medical reviews exist');
select has_function('public', 'bootstrap_initial_owner', array['uuid','text','text'], 'owner bootstrap RPC exists');
select has_function('public', 'admin_update_user_access', array['uuid','app_role','boolean'], 'user access RPC exists');
select has_function('public', 'content_integrity_report', array['integer'], 'integrity report exists');
select has_function('public', 'restore_content_version', array['uuid'], 'version restore exists');
select has_function('public', 'search_medical_content', array['text','text','integer'], 'medical search exists');
select policies_are('public', 'bookmarks', array['bookmarks_owner_all'], 'bookmarks are owner-scoped');
select policies_are('public', 'notes', array['notes_owner_all'], 'notes are owner-scoped');
select col_is_pk('public', 'profiles', 'id', 'profile id is primary key');
select col_type_is('public', 'profiles', 'role', 'app_role', 'profile role uses app_role enum');

select * from finish();
rollback;
