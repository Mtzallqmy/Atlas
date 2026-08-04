-- Protected owner bootstrap and transfer operations.

create or replace function public.bootstrap_initial_owner(
  p_user_id uuid,
  p_username text,
  p_email text
)
returns public.profiles
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result public.profiles;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if exists(select 1 from public.profiles where role='owner' and deleted_at is null and id <> p_user_id) then
    raise exception 'An owner already exists';
  end if;
  if p_username !~ '^[A-Za-z0-9_.-]{3,40}$' then
    raise exception 'Invalid username';
  end if;
  if position('@' in p_email) < 2 then
    raise exception 'Invalid email';
  end if;

  perform set_config('app.allow_owner_transfer', 'on', true);
  insert into public.profiles(id, username, email, role, must_change_credentials, is_active)
  values(p_user_id, p_username, lower(p_email), 'owner', true, true)
  on conflict(id) do update set
    username=excluded.username,
    email=excluded.email,
    role='owner',
    must_change_credentials=true,
    is_active=true,
    deleted_at=null
  returning * into v_result;

  insert into public.user_preferences(user_id) values(p_user_id) on conflict do nothing;
  insert into public.audit_logs(actor_id, actor_role, action, entity_type, entity_id, after_data, metadata)
  values(p_user_id, 'owner', 'owner.initial_bootstrap', 'profiles', p_user_id, to_jsonb(v_result), jsonb_build_object('source','bootstrap-script'));
  return v_result;
end;
$$;

create or replace function public.transfer_owner_role(
  p_current_owner_id uuid,
  p_target_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before_current jsonb;
  v_before_target jsonb;
begin
  if auth.role() <> 'service_role' then
    raise exception 'Service role required';
  end if;
  if p_current_owner_id = p_target_user_id then
    raise exception 'Target is already the owner';
  end if;
  select to_jsonb(p) into v_before_current from public.profiles p where id=p_current_owner_id and role='owner' and deleted_at is null for update;
  select to_jsonb(p) into v_before_target from public.profiles p where id=p_target_user_id and role in ('admin','editor','medical_reviewer','translator','user') and deleted_at is null for update;
  if v_before_current is null or v_before_target is null then
    raise exception 'Current owner or target profile not found';
  end if;

  perform set_config('app.allow_owner_transfer', 'on', true);
  update public.profiles set role='admin', updated_at=timezone('utc', now()) where id=p_current_owner_id;
  update public.profiles set role='owner', must_change_credentials=true, updated_at=timezone('utc', now()) where id=p_target_user_id;

  insert into public.audit_logs(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, metadata)
  values(p_current_owner_id, 'owner', 'owner.role_transferred', 'profiles', p_target_user_id, v_before_target,
    (select to_jsonb(p) from public.profiles p where id=p_target_user_id),
    jsonb_build_object('previousOwnerId', p_current_owner_id));
  return true;
end;
$$;

revoke execute on function public.bootstrap_initial_owner(uuid,text,text) from public, anon, authenticated;
revoke execute on function public.transfer_owner_role(uuid,uuid) from public, anon, authenticated;
grant execute on function public.bootstrap_initial_owner(uuid,text,text) to service_role;
grant execute on function public.transfer_owner_role(uuid,uuid) to service_role;
