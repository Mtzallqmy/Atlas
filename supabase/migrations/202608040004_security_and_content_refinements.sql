-- Search, quiz, media, and translation workflow refinements.

create or replace function public.normalize_arabic(input text)
returns text
language sql
immutable
parallel safe
as $$
  select lower(
    translate(
      regexp_replace(unaccent(coalesce(input, '')), U&'[\064B-\065F\0670\06D6-\06ED]', '', 'g'),
      'أإآىؤئة',
      'ااايوهه'
    )
  );
$$;

create or replace function public.validate_media_asset()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.storage_path = '' or new.storage_path like '%..%' or new.storage_path like '/%' then
    raise exception 'Invalid storage path';
  end if;
  if new.checksum_sha256 is not null and new.checksum_sha256 !~ '^[a-fA-F0-9]{64}$' then
    raise exception 'checksum_sha256 must be a 64-character hexadecimal SHA-256 digest';
  end if;
  if new.status = 'published' and (
    new.mime_type is null or new.byte_size is null or new.byte_size <= 0 or
    new.checksum_sha256 is null or new.license_name is null or new.attribution is null
  ) then
    raise exception 'Published media requires MIME type, byte size, checksum, license, and attribution';
  end if;
  return new;
end;
$$;

create trigger media_assets_validate before insert or update on public.media_assets
for each row execute function public.validate_media_asset();

-- Learners never receive correctness or feedback fields through the public quiz RPC.
revoke select on public.question_options from anon, authenticated;

create or replace function public.get_quiz_page(p_slug text, p_locale text default 'en')
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'quiz', jsonb_build_object(
      'id', q.id,
      'slug', q.slug,
      'passingScore', q.passing_score,
      'timeLimitSeconds', q.time_limit_seconds
    ),
    'questions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', qu.id,
          'type', qu.question_type,
          'prompt', qu.prompt,
          'difficulty', qu.difficulty,
          'points', qu.points,
          'sortOrder', qu.sort_order,
          'options', coalesce((
            select jsonb_agg(jsonb_build_object(
              'id', qo.id,
              'text', qo.option_text,
              'sortOrder', qo.sort_order
            ) order by qo.sort_order)
            from public.question_options qo
            where qo.question_id = qu.id
          ), '[]'::jsonb)
        ) order by qu.sort_order
      )
      from public.questions qu
      where qu.quiz_id = q.id
    ), '[]'::jsonb)
  )
  from public.quizzes q
  where q.slug = p_slug and q.status = 'published' and q.deleted_at is null;
$$;

create or replace function public.check_quiz_answer(p_question_id uuid, p_option_ids uuid[])
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_correct uuid[];
  v_selected uuid[];
  v_explanation text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(
    select 1 from public.questions qu
    join public.quizzes q on q.id = qu.quiz_id
    where qu.id = p_question_id and q.status = 'published' and q.deleted_at is null
  ) then raise exception 'Question not found'; end if;

  select coalesce(array_agg(id order by id), '{}'::uuid[])
  into v_correct
  from public.question_options
  where question_id = p_question_id and is_correct;

  select coalesce(array_agg(x order by x), '{}'::uuid[]) into v_selected
  from unnest(coalesce(p_option_ids, '{}'::uuid[])) x;
  select explanation into v_explanation from public.questions where id = p_question_id;
  return jsonb_build_object(
    'correct', v_selected = v_correct,
    'explanation', v_explanation
  );
end;
$$;

create or replace function public.mark_entity_translations_outdated()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_before jsonb;
  v_after jsonb;
begin
  v_before := to_jsonb(old) - array['updated_at','updated_by','status','published_at','last_medical_review_at'];
  v_after := to_jsonb(new) - array['updated_at','updated_by','status','published_at','last_medical_review_at'];
  if v_before is distinct from v_after then
    update public.translations
    set status = 'outdated', updated_at = timezone('utc', now())
    where entity_type = tg_table_name
      and entity_id = new.id
      and status in ('machine_generated','human_reviewed','medical_reviewed','published')
      and deleted_at is null;
  end if;
  return new;
end;
$$;

create trigger systems_translations_outdated after update on public.anatomical_systems
for each row execute function public.mark_entity_translations_outdated();
create trigger organs_translations_outdated after update on public.organs
for each row execute function public.mark_entity_translations_outdated();
create trigger parts_translations_outdated after update on public.organ_parts
for each row execute function public.mark_entity_translations_outdated();
create trigger diseases_translations_outdated after update on public.diseases
for each row execute function public.mark_entity_translations_outdated();
create trigger lessons_translations_outdated after update on public.lessons
for each row execute function public.mark_entity_translations_outdated();

revoke execute on function public.get_quiz_page(text,text) from public;
revoke execute on function public.check_quiz_answer(uuid,uuid[]) from public;
grant execute on function public.get_quiz_page(text,text) to anon, authenticated;
grant execute on function public.check_quiz_answer(uuid,uuid[]) to authenticated;
