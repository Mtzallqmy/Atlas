-- Expanded non-destructive integrity reporting, including Storage metadata.
create or replace function public.content_integrity_report(p_limit integer default 200)
returns table(issue_key text, severity public.issue_severity, entity_type text, entity_id uuid, message text, suggested_action text)
language sql
stable
security definer
set search_path = public, storage
as $$
  select * from (
    select 'organ_missing_reference:'||o.id, 'error'::public.issue_severity, 'organs', o.id, 'Organ has no linked medical reference', 'Link at least one verified reference'
    from public.organs o where o.deleted_at is null and not exists(select 1 from public.content_references cr where cr.entity_type='organs' and cr.entity_id=o.id)
    union all
    select 'organ_missing_translation:'||o.id, 'warning'::public.issue_severity, 'organs', o.id, 'Organ is missing a published Arabic or English name', 'Add and review ar/en name translations'
    from public.organs o where o.deleted_at is null and (
      not exists(select 1 from public.translations t where t.entity_type='organs' and t.entity_id=o.id and t.field_name='name' and t.locale='ar' and t.status='published' and t.deleted_at is null)
      or not exists(select 1 from public.translations t where t.entity_type='organs' and t.entity_id=o.id and t.field_name='name' and t.locale='en' and t.status='published' and t.deleted_at is null)
    )
    union all
    select 'disease_missing_reference:'||d.id, 'error'::public.issue_severity, 'diseases', d.id, 'Disease has no linked medical reference', 'Link at least one verified reference'
    from public.diseases d where d.deleted_at is null and not exists(select 1 from public.content_references cr where cr.entity_type='diseases' and cr.entity_id=d.id)
    union all
    select 'disease_missing_review:'||d.id, 'error'::public.issue_severity, 'diseases', d.id, 'Disease has no approved medical review', 'Request review from a medical_reviewer'
    from public.diseases d where d.deleted_at is null and not exists(select 1 from public.medical_reviews mr where mr.entity_type='diseases' and mr.entity_id=d.id and mr.decision='approved')
    union all
    select 'asset_incomplete:'||m.id, 'warning'::public.issue_severity, 'media_assets', m.id, 'Asset metadata or checksum is incomplete', 'Re-run asset validation and fill checksum, size, MIME type, license, and attribution'
    from public.media_assets m where m.deleted_at is null and (m.checksum_sha256 is null or m.byte_size is null or m.mime_type is null or m.license_name is null or m.attribution is null)
    union all
    select 'asset_object_missing:'||m.id, 'critical'::public.issue_severity, 'media_assets', m.id, 'Asset record points to a missing Storage object', 'Restore the object from backup or archive the record after dependency review'
    from public.media_assets m
    where m.deleted_at is null and not exists(select 1 from storage.objects o where o.bucket_id=m.storage_bucket and o.name=m.storage_path)
    union all
    select 'storage_orphan:'||o.id, 'warning'::public.issue_severity, 'storage_objects', o.id, 'Storage object has no media_assets record', 'Inspect upload history and either register or quarantine the object'
    from storage.objects o
    where o.bucket_id='medical-content' and not exists(select 1 from public.media_assets m where m.storage_bucket=o.bucket_id and m.storage_path=o.name and m.deleted_at is null)
    union all
    select 'reference_url:'||r.id, 'warning'::public.issue_severity, 'references', r.id, 'Reference URL is not a valid absolute HTTP(S) URL', 'Correct the URL or leave it null when no online source exists'
    from public.references r where r.deleted_at is null and r.url is not null and r.url !~* '^https?://[^[:space:]]+$'
    union all
    select 'model_missing_fallback:'||m.id, 'warning'::public.issue_severity, 'models_3d', m.id, '3D model has no 2D fallback asset', 'Attach a licensed fallback image before publication'
    from public.models_3d m where m.deleted_at is null and m.fallback_asset_id is null
    union all
    select 'hotspot_unlinked:'||h.id, 'warning'::public.issue_severity, 'model_hotspots', h.id, 'Hotspot is not linked to an anatomical part', 'Link the hotspot to a stable organ_part identifier'
    from public.model_hotspots h where h.deleted_at is null and h.organ_part_id is null
    union all
    select 'package_manifest:'||p.id, 'critical'::public.issue_severity, 'content_packages', p.id, 'Content package manifest is missing required fields', 'Regenerate the versioned manifest before publication'
    from public.content_packages p where p.deleted_at is null and not (p.manifest ? 'packageId' and p.manifest ? 'version' and p.manifest ? 'checksum' and p.manifest ? 'assets')
  ) issues
  where public.is_content_staff()
  order by case severity when 'critical' then 1 when 'error' then 2 when 'warning' then 3 else 4 end, issue_key
  limit greatest(1, least(p_limit, 1000));
$$;
