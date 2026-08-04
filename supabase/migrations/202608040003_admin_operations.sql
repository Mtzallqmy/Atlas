-- Privileged administrative operations and auditable row changes.

create or replace function public.admin_update_user_access(
  p_target_user_id uuid,
  p_role public.app_role,
  p_is_active boolean default true
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before jsonb;
  v_result public.profiles;
begin
  if auth.uid() is null or public.current_app_role() <> 'owner' then
    raise exception 'Only the owner can change user access';
  end if;
  if p_target_user_id = auth.uid() then
    raise exception 'The owner account cannot be changed from user access management';
  end if;
  if p_role = 'owner' then
    raise exception 'Owner transfer requires the protected owner-transfer Edge Function';
  end if;

  select to_jsonb(p) into v_before
  from public.profiles p
  where p.id = p_target_user_id and p.deleted_at is null
  for update;

  if v_before is null then raise exception 'Target profile not found'; end if;
  if (v_before->>'role') = 'owner' then raise exception 'The owner profile is protected'; end if;

  update public.profiles
  set role = p_role, is_active = p_is_active, updated_at = timezone('utc', now())
  where id = p_target_user_id
  returning * into v_result;

  perform public.write_audit_log(
    'user.access_updated', 'profiles', p_target_user_id,
    v_before, to_jsonb(v_result),
    jsonb_build_object('requestedRole', p_role, 'requestedActive', p_is_active)
  );
  return v_result;
end;
$$;

create or replace function public.submit_medical_review(
  p_entity_type text,
  p_entity_id uuid,
  p_decision public.review_decision,
  p_notes text default null,
  p_reviewed_version integer default null
)
returns public.medical_reviews
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.medical_reviews;
begin
  if auth.uid() is null or not public.has_any_role(array['owner','medical_reviewer']::public.app_role[]) then
    raise exception 'Medical reviewer role required';
  end if;
  if p_entity_type not in ('anatomical_systems','organs','organ_parts','tissues','cell_types','pathology_topics','diseases','lessons','quizzes','content_pages') then
    raise exception 'Unsupported review entity type';
  end if;

  insert into public.medical_reviews(entity_type, entity_id, reviewer_id, decision, notes, reviewed_version)
  values(p_entity_type, p_entity_id, auth.uid(), p_decision, nullif(trim(p_notes), ''), p_reviewed_version)
  returning * into v_result;

  perform public.write_audit_log(
    'medical_review.submitted', p_entity_type, p_entity_id,
    null, to_jsonb(v_result), jsonb_build_object('decision', p_decision)
  );
  return v_result;
end;
$$;

-- Generic trigger used only on operational tables that do not already have
-- content-version snapshots. Sensitive values (passwords/tokens) never enter
-- these tables and therefore never enter audit_logs.
create or replace function public.audit_admin_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
  v_before jsonb;
  v_after jsonb;
begin
  if auth.uid() is null or not public.has_any_role(array['owner','admin','editor','medical_reviewer','translator']::public.app_role[]) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  v_before := case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end;
  v_after := case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end;
  v_id := case when tg_op = 'DELETE' then old.id else new.id end;
  perform public.write_audit_log(
    lower(tg_table_name || '.' || tg_op), tg_table_name, v_id,
    v_before, v_after, jsonb_build_object('trigger', 'audit_admin_row_change')
  );
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create or replace function public.audit_admin_keyed_row_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is not null and public.has_any_role(array['owner','admin']::public.app_role[]) then
    perform public.write_audit_log(
      lower(tg_table_name || '.' || tg_op), tg_table_name, null,
      case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
      case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end,
      jsonb_build_object('recordKey', case when tg_op = 'DELETE' then old.key else new.key end, 'trigger', 'audit_admin_keyed_row_change')
    );
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

create trigger app_settings_audit after insert or update or delete on public.app_settings
for each row execute function public.audit_admin_keyed_row_change();
create trigger navigation_items_audit after insert or update or delete on public.navigation_items
for each row execute function public.audit_admin_row_change();
create trigger content_pages_audit after insert or update or delete on public.content_pages
for each row execute function public.audit_admin_row_change();
create trigger media_assets_audit after insert or update or delete on public.media_assets
for each row execute function public.audit_admin_row_change();
create trigger medical_reviews_audit after insert or update or delete on public.medical_reviews
for each row execute function public.audit_admin_row_change();

revoke execute on function public.admin_update_user_access(uuid,public.app_role,boolean) from public, anon;
revoke execute on function public.submit_medical_review(text,uuid,public.review_decision,text,integer) from public, anon;
grant execute on function public.admin_update_user_access(uuid,public.app_role,boolean) to authenticated;
grant execute on function public.submit_medical_review(text,uuid,public.review_decision,text,integer) to authenticated;
