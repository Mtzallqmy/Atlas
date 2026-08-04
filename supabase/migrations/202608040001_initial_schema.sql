-- Anatomy Atlas production schema
-- All privileged operations are performed through RLS-aware RPCs or Edge Functions.

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;
create extension if not exists unaccent;

create type public.app_role as enum ('owner', 'admin', 'editor', 'medical_reviewer', 'translator', 'user');
create type public.content_status as enum ('draft', 'under_review', 'medically_reviewed', 'published', 'archived');
create type public.translation_status as enum ('missing', 'machine_generated', 'human_reviewed', 'medical_reviewed', 'published', 'outdated');
create type public.evidence_level as enum ('textbook', 'guideline', 'systematic_review', 'randomized_trial', 'observational', 'expert_consensus', 'other');
create type public.review_decision as enum ('pending', 'approved', 'changes_requested', 'rejected');
create type public.ai_provider_mode as enum ('disabled', 'platformManaged', 'openAICompatible', 'userProvidedKey', 'puterWeb');
create type public.issue_severity as enum ('info', 'warning', 'error', 'critical');

create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

create table public.roles (
  code public.app_role primary key,
  display_name text not null,
  description text,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.roles (code, display_name, description) values
  ('owner', 'Owner', 'Single protected application owner'),
  ('admin', 'Administrator', 'Manages content, users, and operational settings'),
  ('editor', 'Content editor', 'Creates and edits educational content'),
  ('medical_reviewer', 'Medical reviewer', 'Reviews and medically approves content'),
  ('translator', 'Translator', 'Manages localized medical content'),
  ('user', 'Learner', 'Standard learner account')
on conflict do nothing;

create table public.permissions (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  description text,
  created_at timestamptz not null default timezone('utc', now())
);

create table public.role_permissions (
  role public.app_role not null references public.roles(code) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (role, permission_id)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  display_name text,
  email text,
  avatar_url text,
  role public.app_role not null default 'user',
  locale text not null default 'en',
  must_change_credentials boolean not null default false,
  is_active boolean not null default true,
  last_seen_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint profiles_username_format check (username ~ '^[A-Za-z0-9_.-]{3,40}$'),
  constraint profiles_locale_format check (locale ~ '^[a-z]{2}(-[A-Z]{2})?$')
);
create unique index profiles_username_unique_active on public.profiles (lower(username)) where deleted_at is null;
create unique index profiles_email_unique_active on public.profiles (lower(email)) where email is not null and deleted_at is null;
create unique index profiles_single_owner on public.profiles ((role)) where role = 'owner' and deleted_at is null;
create index profiles_role_idx on public.profiles(role) where deleted_at is null;
create trigger profiles_set_updated_at before update on public.profiles for each row execute function public.set_updated_at();

create table public.user_preferences (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  preferred_locale text not null default 'en',
  learner_type text not null default 'general' check (learner_type in ('medical_student','nursing_student','health_professional','school_student','general')),
  learning_level text not null default 'beginner' check (learning_level in ('beginner','intermediate','advanced')),
  theme text not null default 'system' check (theme in ('system','light','dark','high_contrast')),
  text_scale numeric(3,2) not null default 1.0 check (text_scale between 0.8 and 2.0),
  reduced_motion boolean not null default false,
  wifi_downloads_only boolean not null default true,
  analytics_consent boolean not null default false,
  ai_consent boolean not null default false,
  search_history_enabled boolean not null default false,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create trigger user_preferences_set_updated_at before update on public.user_preferences for each row execute function public.set_updated_at();

-- Generic application configuration and navigation.
create table public.app_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,
  description text,
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create trigger app_settings_set_updated_at before update on public.app_settings for each row execute function public.set_updated_at();

create table public.navigation_items (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.navigation_items(id) on delete cascade,
  slug text not null unique,
  route text not null,
  icon text,
  sort_order integer not null default 0,
  required_role public.app_role,
  is_enabled boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger navigation_items_set_updated_at before update on public.navigation_items for each row execute function public.set_updated_at();

create table public.content_pages (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  status public.content_status not null default 'draft',
  template text not null default 'article',
  metadata jsonb not null default '{}'::jsonb,
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger content_pages_set_updated_at before update on public.content_pages for each row execute function public.set_updated_at();

-- Core anatomy content.
create table public.anatomical_systems (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  code text unique,
  status public.content_status not null default 'draft',
  sort_order integer not null default 0,
  summary text,
  icon_asset_path text,
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index anatomical_systems_status_idx on public.anatomical_systems(status, sort_order) where deleted_at is null;
create trigger anatomical_systems_set_updated_at before update on public.anatomical_systems for each row execute function public.set_updated_at();

create table public.body_regions (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.body_regions(id) on delete set null,
  slug text not null unique,
  status public.content_status not null default 'draft',
  anatomical_plane text,
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger body_regions_set_updated_at before update on public.body_regions for each row execute function public.set_updated_at();

create table public.organs (
  id uuid primary key default gen_random_uuid(),
  system_id uuid not null references public.anatomical_systems(id) on delete restrict,
  body_region_id uuid references public.body_regions(id) on delete set null,
  slug text not null unique,
  latin_name text,
  status public.content_status not null default 'draft',
  definition text,
  function_summary text,
  location_summary text,
  histology_summary text,
  clinical_significance text,
  sex_specific text check (sex_specific in ('male','female','both') or sex_specific is null),
  sort_order integer not null default 0,
  thumbnail_path text,
  fallback_image_path text,
  published_at timestamptz,
  last_medical_review_at timestamptz,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index organs_system_idx on public.organs(system_id, status, sort_order) where deleted_at is null;
create index organs_slug_trgm_idx on public.organs using gin (slug gin_trgm_ops);
create trigger organs_set_updated_at before update on public.organs for each row execute function public.set_updated_at();

create table public.organ_parts (
  id uuid primary key default gen_random_uuid(),
  organ_id uuid not null references public.organs(id) on delete cascade,
  parent_id uuid references public.organ_parts(id) on delete set null,
  slug text not null,
  latin_name text,
  status public.content_status not null default 'draft',
  definition text,
  function_summary text,
  clinical_significance text,
  stable_model_key text,
  sort_order integer not null default 0,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique (organ_id, slug)
);
create index organ_parts_organ_idx on public.organ_parts(organ_id, status, sort_order) where deleted_at is null;
create trigger organ_parts_set_updated_at before update on public.organ_parts for each row execute function public.set_updated_at();

create table public.tissues (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  tissue_type text not null,
  status public.content_status not null default 'draft',
  definition text,
  microscopic_features text,
  normal_pathology_comparison text,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger tissues_set_updated_at before update on public.tissues for each row execute function public.set_updated_at();

create table public.cell_types (
  id uuid primary key default gen_random_uuid(),
  tissue_id uuid references public.tissues(id) on delete set null,
  slug text not null unique,
  status public.content_status not null default 'draft',
  definition text,
  morphology text,
  function_summary text,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger cell_types_set_updated_at before update on public.cell_types for each row execute function public.set_updated_at();

create table public.anatomical_relationships (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (source_type in ('organ','organ_part','tissue','body_region')),
  source_id uuid not null,
  target_type text not null check (target_type in ('organ','organ_part','tissue','body_region')),
  target_id uuid not null,
  relationship_type text not null,
  description text,
  status public.content_status not null default 'draft',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index anatomical_relationships_source_idx on public.anatomical_relationships(source_type, source_id) where deleted_at is null;
create index anatomical_relationships_target_idx on public.anatomical_relationships(target_type, target_id) where deleted_at is null;
create trigger anatomical_relationships_set_updated_at before update on public.anatomical_relationships for each row execute function public.set_updated_at();

create table public.blood_supplies (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('organ','organ_part','tissue')),
  entity_id uuid not null,
  vessel_name text not null,
  supply_type text not null check (supply_type in ('arterial','venous','lymphatic')),
  description text,
  status public.content_status not null default 'draft',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index blood_supplies_entity_idx on public.blood_supplies(entity_type, entity_id) where deleted_at is null;
create trigger blood_supplies_set_updated_at before update on public.blood_supplies for each row execute function public.set_updated_at();

create table public.innervations (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('organ','organ_part','tissue')),
  entity_id uuid not null,
  nerve_name text not null,
  division text,
  description text,
  status public.content_status not null default 'draft',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index innervations_entity_idx on public.innervations(entity_type, entity_id) where deleted_at is null;
create trigger innervations_set_updated_at before update on public.innervations for each row execute function public.set_updated_at();

create table public.functions (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null check (entity_type in ('system','organ','organ_part','tissue','cell_type')),
  entity_id uuid not null,
  title text not null,
  description text not null,
  sort_order integer not null default 0,
  status public.content_status not null default 'draft',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index functions_entity_idx on public.functions(entity_type, entity_id, sort_order) where deleted_at is null;
create trigger functions_set_updated_at before update on public.functions for each row execute function public.set_updated_at();

-- Pathology and diseases.
create table public.pathology_topics (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.pathology_topics(id) on delete set null,
  slug text not null unique,
  scope text not null check (scope in ('general','systemic')),
  status public.content_status not null default 'draft',
  summary text,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger pathology_topics_set_updated_at before update on public.pathology_topics for each row execute function public.set_updated_at();

create table public.disease_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  parent_id uuid references public.disease_categories(id) on delete set null,
  status public.content_status not null default 'draft',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger disease_categories_set_updated_at before update on public.disease_categories for each row execute function public.set_updated_at();

create table public.diseases (
  id uuid primary key default gen_random_uuid(),
  category_id uuid references public.disease_categories(id) on delete set null,
  pathology_topic_id uuid references public.pathology_topics(id) on delete set null,
  slug text not null unique,
  status public.content_status not null default 'draft',
  definition text,
  etiology text,
  pathogenesis text,
  gross_changes text,
  microscopic_changes text,
  diagnostic_overview text,
  treatment_principles text,
  prevention text,
  normal_vs_pathological text,
  is_genetic boolean,
  is_infectious boolean,
  is_malignant boolean,
  course text check (course in ('acute','chronic','acute_on_chronic') or course is null),
  prevalence_rank integer,
  last_medical_review_at timestamptz,
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index diseases_category_idx on public.diseases(category_id, status) where deleted_at is null;
create index diseases_filters_idx on public.diseases(is_genetic, is_infectious, is_malignant, course) where deleted_at is null;
create trigger diseases_set_updated_at before update on public.diseases for each row execute function public.set_updated_at();

create table public.disease_organ_links (
  disease_id uuid not null references public.diseases(id) on delete cascade,
  organ_id uuid not null references public.organs(id) on delete cascade,
  involvement_type text not null default 'primary',
  description text,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (disease_id, organ_id)
);
create index disease_organ_links_organ_idx on public.disease_organ_links(organ_id);

create table public.disease_part_links (
  disease_id uuid not null references public.diseases(id) on delete cascade,
  organ_part_id uuid not null references public.organ_parts(id) on delete cascade,
  description text,
  hotspot_effect jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  primary key (disease_id, organ_part_id)
);

create table public.disease_risk_factors (
  id uuid primary key default gen_random_uuid(),
  disease_id uuid not null references public.diseases(id) on delete cascade,
  factor text not null,
  category text,
  modifiable boolean,
  evidence_level public.evidence_level,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create trigger disease_risk_factors_set_updated_at before update on public.disease_risk_factors for each row execute function public.set_updated_at();

create table public.disease_symptoms (
  id uuid primary key default gen_random_uuid(),
  disease_id uuid not null references public.diseases(id) on delete cascade,
  symptom text not null,
  is_sign boolean not null default false,
  frequency text,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create trigger disease_symptoms_set_updated_at before update on public.disease_symptoms for each row execute function public.set_updated_at();

create table public.disease_complications (
  id uuid primary key default gen_random_uuid(),
  disease_id uuid not null references public.diseases(id) on delete cascade,
  complication text not null,
  severity text,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create trigger disease_complications_set_updated_at before update on public.disease_complications for each row execute function public.set_updated_at();

-- Lessons, quizzes and study tools.
create table public.lessons (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  system_id uuid references public.anatomical_systems(id) on delete set null,
  organ_id uuid references public.organs(id) on delete set null,
  disease_id uuid references public.diseases(id) on delete set null,
  level text not null default 'beginner' check (level in ('beginner','intermediate','advanced')),
  estimated_minutes integer check (estimated_minutes > 0),
  status public.content_status not null default 'draft',
  summary text,
  objectives jsonb not null default '[]'::jsonb,
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index lessons_context_idx on public.lessons(system_id, organ_id, disease_id, status) where deleted_at is null;
create trigger lessons_set_updated_at before update on public.lessons for each row execute function public.set_updated_at();

create table public.lesson_sections (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid not null references public.lessons(id) on delete cascade,
  section_type text not null default 'text',
  heading text,
  body_markdown text,
  media_asset_id uuid,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index lesson_sections_lesson_idx on public.lesson_sections(lesson_id, sort_order);
create trigger lesson_sections_set_updated_at before update on public.lesson_sections for each row execute function public.set_updated_at();

create table public.learning_paths (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  audience text,
  level text check (level in ('beginner','intermediate','advanced') or level is null),
  status public.content_status not null default 'draft',
  summary text,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger learning_paths_set_updated_at before update on public.learning_paths for each row execute function public.set_updated_at();

create table public.learning_path_items (
  id uuid primary key default gen_random_uuid(),
  learning_path_id uuid not null references public.learning_paths(id) on delete cascade,
  item_type text not null check (item_type in ('lesson','quiz','organ','disease')),
  item_id uuid not null,
  sort_order integer not null default 0,
  is_required boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  unique (learning_path_id, item_type, item_id)
);

create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  lesson_id uuid references public.lessons(id) on delete set null,
  organ_id uuid references public.organs(id) on delete set null,
  disease_id uuid references public.diseases(id) on delete set null,
  status public.content_status not null default 'draft',
  passing_score numeric(5,2) not null default 70 check (passing_score between 0 and 100),
  time_limit_seconds integer,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger quizzes_set_updated_at before update on public.quizzes for each row execute function public.set_updated_at();

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  question_type text not null check (question_type in ('single_choice','multiple_choice','true_false','hotspot','short_answer')),
  prompt text not null,
  explanation text,
  difficulty text check (difficulty in ('easy','medium','hard') or difficulty is null),
  points numeric(6,2) not null default 1,
  sort_order integer not null default 0,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index questions_quiz_idx on public.questions(quiz_id, sort_order);
create trigger questions_set_updated_at before update on public.questions for each row execute function public.set_updated_at();

create table public.question_options (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  option_text text not null,
  is_correct boolean not null default false,
  feedback text,
  sort_order integer not null default 0,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index question_options_question_idx on public.question_options(question_id, sort_order);
create trigger question_options_set_updated_at before update on public.question_options for each row execute function public.set_updated_at();

create table public.flashcards (
  id uuid primary key default gen_random_uuid(),
  lesson_id uuid references public.lessons(id) on delete cascade,
  organ_id uuid references public.organs(id) on delete cascade,
  disease_id uuid references public.diseases(id) on delete cascade,
  front_text text not null,
  back_text text not null,
  status public.content_status not null default 'draft',
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create trigger flashcards_set_updated_at before update on public.flashcards for each row execute function public.set_updated_at();

-- Media and downloadable packages.
create table public.media_assets (
  id uuid primary key default gen_random_uuid(),
  storage_bucket text not null default 'medical-content',
  storage_path text not null,
  asset_type text not null check (asset_type in ('image','microscopy','audio','video','document','model_3d','thumbnail','fallback')),
  mime_type text,
  byte_size bigint check (byte_size >= 0),
  checksum_sha256 text,
  width integer,
  height integer,
  duration_seconds numeric,
  license_name text,
  license_url text,
  attribution text,
  alt_text text,
  status public.content_status not null default 'draft',
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique(storage_bucket, storage_path)
);
create index media_assets_type_idx on public.media_assets(asset_type, status) where deleted_at is null;
create trigger media_assets_set_updated_at before update on public.media_assets for each row execute function public.set_updated_at();

alter table public.lesson_sections add constraint lesson_sections_media_asset_fk foreign key (media_asset_id) references public.media_assets(id) on delete set null;

create table public.models_3d (
  id uuid primary key default gen_random_uuid(),
  organ_id uuid references public.organs(id) on delete cascade,
  system_id uuid references public.anatomical_systems(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  slug text not null unique,
  version integer not null default 1,
  lod_level integer not null default 0,
  polygon_count integer,
  texture_max_size integer,
  compression text[] not null default '{}'::text[],
  center jsonb not null default '{"x":0,"y":0,"z":0}'::jsonb,
  scale numeric not null default 1,
  fallback_asset_id uuid references public.media_assets(id) on delete set null,
  minimum_app_version text not null default '1.0.0',
  status public.content_status not null default 'draft',
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index models_3d_context_idx on public.models_3d(organ_id, system_id, lod_level, status) where deleted_at is null;
create trigger models_3d_set_updated_at before update on public.models_3d for each row execute function public.set_updated_at();

create table public.model_hotspots (
  id uuid primary key default gen_random_uuid(),
  model_id uuid not null references public.models_3d(id) on delete cascade,
  organ_part_id uuid references public.organ_parts(id) on delete set null,
  stable_key text not null,
  mesh_key text,
  position jsonb not null,
  normal jsonb,
  camera_target jsonb,
  label_offset jsonb,
  status public.content_status not null default 'draft',
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique(model_id, stable_key)
);
create index model_hotspots_model_idx on public.model_hotspots(model_id, status) where deleted_at is null;
create trigger model_hotspots_set_updated_at before update on public.model_hotspots for each row execute function public.set_updated_at();

create table public.content_packages (
  id uuid primary key default gen_random_uuid(),
  package_id text not null,
  version integer not null,
  locale text not null,
  title text not null,
  description text,
  byte_size bigint not null check (byte_size >= 0),
  checksum_sha256 text not null,
  minimum_app_version text not null,
  manifest jsonb not null,
  storage_path text not null,
  is_core boolean not null default false,
  status public.content_status not null default 'draft',
  published_at timestamptz,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique(package_id, version, locale)
);
create index content_packages_lookup_idx on public.content_packages(package_id, locale, version desc) where deleted_at is null;
create trigger content_packages_set_updated_at before update on public.content_packages for each row execute function public.set_updated_at();

create table public.content_package_assets (
  content_package_id uuid not null references public.content_packages(id) on delete cascade,
  media_asset_id uuid not null references public.media_assets(id) on delete restrict,
  relative_path text not null,
  checksum_sha256 text not null,
  byte_size bigint not null check (byte_size >= 0),
  created_at timestamptz not null default timezone('utc', now()),
  primary key(content_package_id, media_asset_id)
);

-- Localization and terminology.
create table public.translations (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  field_name text not null,
  locale text not null,
  value text not null,
  status public.translation_status not null default 'missing',
  source_version integer not null default 1,
  model_name text,
  translated_at timestamptz,
  reviewed_by uuid references public.profiles(id),
  reviewed_at timestamptz,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  unique(entity_type, entity_id, field_name, locale)
);
create index translations_entity_idx on public.translations(entity_type, entity_id, locale, status) where deleted_at is null;
create index translations_value_trgm_idx on public.translations using gin (value gin_trgm_ops);
create trigger translations_set_updated_at before update on public.translations for each row execute function public.set_updated_at();

create table public.medical_terms (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  preferred_english text not null,
  preferred_arabic text,
  latin_term text,
  definition text,
  status public.content_status not null default 'draft',
  pronunciation_asset_id uuid references public.media_assets(id) on delete set null,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index medical_terms_english_trgm_idx on public.medical_terms using gin (preferred_english gin_trgm_ops);
create index medical_terms_arabic_trgm_idx on public.medical_terms using gin (preferred_arabic gin_trgm_ops);
create trigger medical_terms_set_updated_at before update on public.medical_terms for each row execute function public.set_updated_at();

create table public.term_synonyms (
  id uuid primary key default gen_random_uuid(),
  term_id uuid not null references public.medical_terms(id) on delete cascade,
  locale text not null,
  synonym text not null,
  normalized_synonym text,
  created_at timestamptz not null default timezone('utc', now()),
  unique(term_id, locale, synonym)
);
create index term_synonyms_search_idx on public.term_synonyms using gin (synonym gin_trgm_ops);

-- References, review and versioning.
create table public.references (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  title text not null,
  authors text,
  organization text,
  edition text,
  publication_year integer,
  doi text,
  pmid text,
  url text,
  accessed_at date,
  evidence_level public.evidence_level not null default 'other',
  publisher text,
  citation_text text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id),
  updated_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz,
  constraint references_identifier_present check (doi is not null or pmid is not null or url is not null or citation_text is not null)
);
create index references_doi_idx on public.references(doi) where doi is not null;
create index references_pmid_idx on public.references(pmid) where pmid is not null;
create trigger references_set_updated_at before update on public.references for each row execute function public.set_updated_at();

create table public.content_references (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  reference_id uuid not null references public.references(id) on delete restrict,
  locator text,
  quote_note text,
  supports_fields text[] not null default '{}'::text[],
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  unique(entity_type, entity_id, reference_id, locator)
);
create index content_references_entity_idx on public.content_references(entity_type, entity_id);
create index content_references_reference_idx on public.content_references(reference_id);

create table public.medical_reviews (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  reviewer_id uuid not null references public.profiles(id) on delete restrict,
  decision public.review_decision not null default 'pending',
  notes text,
  reviewed_version integer,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index medical_reviews_entity_idx on public.medical_reviews(entity_type, entity_id, decision);
create trigger medical_reviews_set_updated_at before update on public.medical_reviews for each row execute function public.set_updated_at();

create table public.content_versions (
  id uuid primary key default gen_random_uuid(),
  entity_type text not null,
  entity_id uuid not null,
  version_number integer not null,
  snapshot jsonb not null,
  change_summary text,
  changed_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  unique(entity_type, entity_id, version_number)
);
create index content_versions_entity_idx on public.content_versions(entity_type, entity_id, version_number desc);

-- Learner-owned records.
create table public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  created_at timestamptz not null default timezone('utc', now()),
  unique(user_id, entity_type, entity_id)
);
create index bookmarks_user_idx on public.bookmarks(user_id, created_at desc);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  body text not null,
  is_private boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index notes_user_entity_idx on public.notes(user_id, entity_type, entity_id) where deleted_at is null;
create trigger notes_set_updated_at before update on public.notes for each row execute function public.set_updated_at();

create table public.study_progress (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  entity_type text not null,
  entity_id uuid not null,
  progress numeric(5,2) not null default 0 check (progress between 0 and 100),
  state jsonb not null default '{}'::jsonb,
  last_position text,
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique(user_id, entity_type, entity_id)
);
create index study_progress_user_idx on public.study_progress(user_id, updated_at desc);
create trigger study_progress_set_updated_at before update on public.study_progress for each row execute function public.set_updated_at();

create table public.quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  score numeric(5,2) check (score between 0 and 100),
  answers jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default timezone('utc', now()),
  completed_at timestamptz,
  created_at timestamptz not null default timezone('utc', now())
);
create index quiz_attempts_user_idx on public.quiz_attempts(user_id, created_at desc);

create table public.download_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  installation_id text,
  content_package_id uuid not null references public.content_packages(id) on delete cascade,
  version integer not null,
  state text not null check (state in ('queued','downloading','paused','verifying','installed','failed','rolled_back','deleted')),
  bytes_downloaded bigint not null default 0,
  local_path text,
  checksum_verified boolean not null default false,
  error_code text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint download_records_identity check (user_id is not null or installation_id is not null)
);
create index download_records_user_idx on public.download_records(user_id, updated_at desc);
create trigger download_records_set_updated_at before update on public.download_records for each row execute function public.set_updated_at();

-- AI usage is optional and user-private.
create table public.ai_conversations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text,
  context_entity_type text,
  context_entity_id uuid,
  locale text not null default 'en',
  provider_mode public.ai_provider_mode not null default 'disabled',
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  deleted_at timestamptz
);
create index ai_conversations_user_idx on public.ai_conversations(user_id, updated_at desc) where deleted_at is null;
create trigger ai_conversations_set_updated_at before update on public.ai_conversations for each row execute function public.set_updated_at();

create table public.ai_messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.ai_conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('user','assistant','system','tool')),
  content text not null,
  structured_response jsonb,
  citations jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);
create index ai_messages_conversation_idx on public.ai_messages(conversation_id, created_at);

create table public.ai_usage (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  conversation_id uuid references public.ai_conversations(id) on delete set null,
  provider_mode public.ai_provider_mode not null,
  model_name text,
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  estimated_cost numeric(12,6),
  latency_ms integer,
  request_id text,
  created_at timestamptz not null default timezone('utc', now())
);
create index ai_usage_user_date_idx on public.ai_usage(user_id, created_at desc);

create table public.ai_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  message_id uuid not null references public.ai_messages(id) on delete cascade,
  rating smallint check (rating between 1 and 5),
  is_helpful boolean,
  feedback text,
  created_at timestamptz not null default timezone('utc', now()),
  unique(user_id, message_id)
);

-- Editorial feedback, moderation and auditing.
create table public.content_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete set null,
  entity_type text,
  entity_id uuid,
  suggestion text not null,
  status text not null default 'open' check (status in ('open','triaged','accepted','rejected','resolved')),
  assigned_to uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create trigger content_suggestions_set_updated_at before update on public.content_suggestions for each row execute function public.set_updated_at();

create table public.content_corrections (
  id uuid primary key default gen_random_uuid(),
  suggestion_id uuid references public.content_suggestions(id) on delete set null,
  entity_type text not null,
  entity_id uuid not null,
  field_name text,
  proposed_value text,
  rationale text not null,
  reference_id uuid references public.references(id) on delete set null,
  status text not null default 'open' check (status in ('open','under_review','applied','rejected')),
  created_by uuid references public.profiles(id),
  reviewed_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create trigger content_corrections_set_updated_at before update on public.content_corrections for each row execute function public.set_updated_at();

create table public.moderation_queue (
  id uuid primary key default gen_random_uuid(),
  item_type text not null,
  item_id uuid not null,
  reason text not null,
  severity public.issue_severity not null default 'warning',
  status text not null default 'open' check (status in ('open','in_review','resolved','dismissed')),
  assigned_to uuid references public.profiles(id) on delete set null,
  resolution text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index moderation_queue_status_idx on public.moderation_queue(status, severity, created_at desc);
create trigger moderation_queue_set_updated_at before update on public.moderation_queue for each row execute function public.set_updated_at();

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.profiles(id) on delete set null,
  actor_role public.app_role,
  action text not null,
  entity_type text,
  entity_id uuid,
  ip_hash text,
  user_agent text,
  before_data jsonb,
  after_data jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now())
);
create index audit_logs_actor_idx on public.audit_logs(actor_id, created_at desc);
create index audit_logs_entity_idx on public.audit_logs(entity_type, entity_id, created_at desc);
create index audit_logs_action_idx on public.audit_logs(action, created_at desc);

-- Role helpers. Authorization is derived from profiles, never mutable user metadata.
create or replace function public.current_app_role()
returns public.app_role
language sql stable security definer
set search_path = public
as $$
  select coalesce((select role from public.profiles where id = auth.uid() and deleted_at is null and is_active), 'user'::public.app_role);
$$;

create or replace function public.has_any_role(allowed public.app_role[])
returns boolean
language sql stable security definer
set search_path = public
as $$
  select auth.uid() is not null and public.current_app_role() = any(allowed);
$$;

create or replace function public.is_content_staff()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.has_any_role(array['owner','admin','editor','medical_reviewer','translator']::public.app_role[]);
$$;

create or replace function public.is_content_manager()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select public.has_any_role(array['owner','admin','editor']::public.app_role[]);
$$;

create or replace function public.write_audit_log(
  p_action text,
  p_entity_type text default null,
  p_entity_id uuid default null,
  p_before jsonb default null,
  p_after jsonb default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  insert into public.audit_logs(actor_id, actor_role, action, entity_type, entity_id, before_data, after_data, metadata)
  values(auth.uid(), public.current_app_role(), p_action, p_entity_type, p_entity_id, p_before, p_after, coalesce(p_metadata, '{}'::jsonb))
  returning id into v_id;
  return v_id;
end;
$$;

-- Protect the single owner account at the database boundary.
create or replace function public.protect_owner_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' and old.role = 'owner' and current_setting('app.allow_owner_transfer', true) <> 'on' then
    raise exception 'The owner profile cannot be deleted';
  end if;
  if tg_op = 'UPDATE' and old.role = 'owner' and new.role <> 'owner' and current_setting('app.allow_owner_transfer', true) <> 'on' then
    raise exception 'The owner role cannot be reduced';
  end if;
  if tg_op = 'UPDATE' and old.role <> 'owner' and new.role = 'owner' and current_setting('app.allow_owner_transfer', true) <> 'on' then
    raise exception 'Owner transfer requires the protected transfer operation';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;
create trigger profiles_protect_owner before update or delete on public.profiles for each row execute function public.protect_owner_profile();

create or replace function public.handle_new_auth_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, username, display_name, email, role)
  values(
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'username',''), 'user_' || substr(replace(new.id::text,'-',''),1,12)),
    nullif(new.raw_user_meta_data->>'display_name',''),
    new.email,
    'user'
  )
  on conflict (id) do nothing;
  insert into public.user_preferences(user_id) values(new.id) on conflict do nothing;
  return new;
end;
$$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_auth_user();

-- Version snapshots for important editorial tables.
create or replace function public.snapshot_content_version()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_next integer;
  v_entity_type text := tg_table_name;
  v_entity_id uuid := coalesce(new.id, old.id);
begin
  select coalesce(max(version_number), 0) + 1 into v_next
  from public.content_versions
  where entity_type = v_entity_type and entity_id = v_entity_id;

  insert into public.content_versions(entity_type, entity_id, version_number, snapshot, changed_by)
  values(v_entity_type, v_entity_id, v_next, to_jsonb(old), auth.uid());
  return new;
end;
$$;

create trigger anatomical_systems_version before update on public.anatomical_systems for each row execute function public.snapshot_content_version();
create trigger organs_version before update on public.organs for each row execute function public.snapshot_content_version();
create trigger organ_parts_version before update on public.organ_parts for each row execute function public.snapshot_content_version();
create trigger diseases_version before update on public.diseases for each row execute function public.snapshot_content_version();
create trigger lessons_version before update on public.lessons for each row execute function public.snapshot_content_version();
create trigger quizzes_version before update on public.quizzes for each row execute function public.snapshot_content_version();
create trigger translations_version before update on public.translations for each row execute function public.snapshot_content_version();
create trigger references_version before update on public.references for each row execute function public.snapshot_content_version();

-- A reference that supports published content may not be hard deleted.
create or replace function public.prevent_published_reference_delete()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if exists (
    select 1 from public.content_references cr
    where cr.reference_id = old.id
      and (
        (cr.entity_type = 'organs' and exists(select 1 from public.organs x where x.id = cr.entity_id and x.status = 'published')) or
        (cr.entity_type = 'diseases' and exists(select 1 from public.diseases x where x.id = cr.entity_id and x.status = 'published')) or
        (cr.entity_type = 'lessons' and exists(select 1 from public.lessons x where x.id = cr.entity_id and x.status = 'published'))
      )
  ) then
    raise exception 'Cannot delete a reference used by published content';
  end if;
  return old;
end;
$$;
create trigger references_prevent_published_delete before delete on public.references for each row execute function public.prevent_published_reference_delete();

-- Sensitive content must have at least one reference and approved medical review before publication.
create or replace function public.validate_publishable_content()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_sensitive boolean := tg_table_name in ('organs','organ_parts','tissues','diseases','lessons');
  v_entity_type text := tg_table_name;
begin
  if tg_op = 'INSERT' and new.status = 'published' then
    raise exception 'Create content as draft, then publish after references and medical review are attached';
  end if;
  if new.status = 'published' and old.status is distinct from 'published' and v_sensitive then
    if not exists(select 1 from public.content_references where entity_type = v_entity_type and entity_id = new.id) then
      raise exception 'Published medical content requires at least one reference';
    end if;
    if not exists(select 1 from public.medical_reviews where entity_type = v_entity_type and entity_id = new.id and decision = 'approved') then
      raise exception 'Published medical content requires an approved medical review';
    end if;
    new.published_at := coalesce(new.published_at, timezone('utc', now()));
  end if;
  return new;
end;
$$;
create trigger organs_validate_publish before insert or update on public.organs for each row execute function public.validate_publishable_content();
create trigger diseases_validate_publish before insert or update on public.diseases for each row execute function public.validate_publishable_content();
create trigger lessons_validate_publish before insert or update on public.lessons for each row execute function public.validate_publishable_content();

-- Arabic-aware normalization for local/server search. Keeps normalization conservative.
create or replace function public.normalize_arabic(input text)
returns text language sql immutable as $$
  select lower(
    translate(
      regexp_replace(unaccent(coalesce(input,'')), '[\u064B-\u065F\u0670\u06D6-\u06ED]', '', 'g'),
      'أإآىؤئة',
      'ااايوهه'
    )
  );
$$;

create or replace function public.search_medical_content(p_query text, p_locale text default 'en', p_limit integer default 30)
returns table(entity_type text, entity_id uuid, slug text, title text, subtitle text, rank real)
language sql stable security definer set search_path = public as $$
  with q as (select public.normalize_arabic(p_query) as value),
  candidates as (
    select 'organ'::text as entity_type, o.id as entity_id, o.slug,
      coalesce((select t.value from public.translations t where t.entity_type='organs' and t.entity_id=o.id and t.field_name='name' and t.locale=p_locale and t.status='published' and t.deleted_at is null limit 1), o.latin_name, o.slug) as title,
      o.function_summary as subtitle
    from public.organs o where o.status='published' and o.deleted_at is null
    union all
    select 'disease'::text as entity_type, d.id as entity_id, d.slug,
      coalesce((select t.value from public.translations t where t.entity_type='diseases' and t.entity_id=d.id and t.field_name='name' and t.locale=p_locale and t.status='published' and t.deleted_at is null limit 1), d.slug),
      d.definition
    from public.diseases d where d.status='published' and d.deleted_at is null
    union all
    select 'lesson'::text as entity_type, l.id as entity_id, l.slug,
      coalesce((select t.value from public.translations t where t.entity_type='lessons' and t.entity_id=l.id and t.field_name='title' and t.locale=p_locale and t.status='published' and t.deleted_at is null limit 1), l.slug),
      l.summary
    from public.lessons l where l.status='published' and l.deleted_at is null
    union all
    select 'term'::text as entity_type, mt.id as entity_id, mt.slug, case when p_locale='ar' then coalesce(mt.preferred_arabic, mt.preferred_english) else mt.preferred_english end, mt.definition
    from public.medical_terms mt where mt.status='published' and mt.deleted_at is null
  )
  select c.entity_type, c.entity_id, c.slug, c.title, c.subtitle,
    greatest(similarity(public.normalize_arabic(c.title), q.value), similarity(public.normalize_arabic(c.slug), q.value))::real as rank
  from candidates c cross join q
  where public.normalize_arabic(c.title) % q.value
     or public.normalize_arabic(c.slug) % q.value
     or public.normalize_arabic(coalesce(c.subtitle,'')) like '%' || q.value || '%'
  order by rank desc, c.title
  limit greatest(1, least(p_limit, 100));
$$;

-- Full organ page in one RPC.
create or replace function public.get_organ_page(p_slug text, p_locale text default 'en')
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'organ', to_jsonb(o),
    'system', to_jsonb(s),
    'translations', coalesce((select jsonb_agg(to_jsonb(t) order by t.field_name) from public.translations t where t.entity_type='organs' and t.entity_id=o.id and t.locale=p_locale and t.status='published' and t.deleted_at is null), '[]'::jsonb),
    'parts', coalesce((select jsonb_agg(to_jsonb(op) order by op.sort_order) from public.organ_parts op where op.organ_id=o.id and op.status='published' and op.deleted_at is null), '[]'::jsonb),
    'functions', coalesce((select jsonb_agg(to_jsonb(f) order by f.sort_order) from public.functions f where f.entity_type='organ' and f.entity_id=o.id and f.status='published' and f.deleted_at is null), '[]'::jsonb),
    'bloodSupply', coalesce((select jsonb_agg(to_jsonb(b)) from public.blood_supplies b where b.entity_type='organ' and b.entity_id=o.id and b.status='published' and b.deleted_at is null), '[]'::jsonb),
    'innervation', coalesce((select jsonb_agg(to_jsonb(i)) from public.innervations i where i.entity_type='organ' and i.entity_id=o.id and i.status='published' and i.deleted_at is null), '[]'::jsonb),
    'diseases', coalesce((select jsonb_agg(jsonb_build_object('link', to_jsonb(l), 'disease', to_jsonb(d))) from public.disease_organ_links l join public.diseases d on d.id=l.disease_id where l.organ_id=o.id and d.status='published' and d.deleted_at is null), '[]'::jsonb),
    'models', coalesce((select jsonb_agg(jsonb_build_object('model', to_jsonb(m), 'asset', to_jsonb(a), 'hotspots', coalesce((select jsonb_agg(to_jsonb(h)) from public.model_hotspots h where h.model_id=m.id and h.status='published' and h.deleted_at is null), '[]'::jsonb))) from public.models_3d m join public.media_assets a on a.id=m.media_asset_id where m.organ_id=o.id and m.status='published' and m.deleted_at is null), '[]'::jsonb),
    'references', coalesce((select jsonb_agg(jsonb_build_object('link', to_jsonb(cr), 'reference', to_jsonb(r))) from public.content_references cr join public.references r on r.id=cr.reference_id where cr.entity_type='organs' and cr.entity_id=o.id and r.deleted_at is null), '[]'::jsonb)
  )
  from public.organs o join public.anatomical_systems s on s.id=o.system_id
  where o.slug=p_slug and o.status='published' and o.deleted_at is null and s.status='published' and s.deleted_at is null;
$$;

create or replace function public.admin_dashboard_summary()
returns jsonb language sql stable security definer set search_path = public as $$
  select case when public.has_any_role(array['owner','admin','editor','medical_reviewer','translator']::public.app_role[]) then
    jsonb_build_object(
      'systems', (select count(*) from public.anatomical_systems where deleted_at is null),
      'organs', (select count(*) from public.organs where deleted_at is null),
      'diseases', (select count(*) from public.diseases where deleted_at is null),
      'lessons', (select count(*) from public.lessons where deleted_at is null),
      'quizzes', (select count(*) from public.quizzes where deleted_at is null),
      'translationsPending', (select count(*) from public.translations where deleted_at is null and status not in ('published','medical_reviewed')),
      'reviewQueue', (select count(*) from public.medical_reviews where decision='pending'),
      'moderationOpen', (select count(*) from public.moderation_queue where status in ('open','in_review')),
      'brokenAssets', (select count(*) from public.media_assets where deleted_at is null and (checksum_sha256 is null or byte_size is null)),
      'users', (select count(*) from public.profiles where deleted_at is null),
      'recentAudit', coalesce((select jsonb_agg(x) from (select to_jsonb(a) x from public.audit_logs a order by created_at desc limit 10) q), '[]'::jsonb)
    )
  else null end;
$$;

create or replace function public.content_integrity_report(p_limit integer default 200)
returns table(issue_key text, severity public.issue_severity, entity_type text, entity_id uuid, message text, suggested_action text)
language sql stable security definer set search_path = public as $$
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
    select 'disease_missing_review:'||d.id, 'error'::public.issue_severity, 'diseases', d.id, 'Disease has no approved medical review', 'Request review from a medical_reviewer'
    from public.diseases d where d.deleted_at is null and not exists(select 1 from public.medical_reviews mr where mr.entity_type='diseases' and mr.entity_id=d.id and mr.decision='approved')
    union all
    select 'asset_incomplete:'||m.id, 'warning'::public.issue_severity, 'media_assets', m.id, 'Asset metadata or checksum is incomplete', 'Re-run asset validation and fill checksum/size'
    from public.media_assets m where m.deleted_at is null and (m.checksum_sha256 is null or m.byte_size is null or m.mime_type is null)
    union all
    select 'package_manifest:'||p.id, 'critical'::public.issue_severity, 'content_packages', p.id, 'Content package manifest is missing required fields', 'Regenerate the versioned manifest before publication'
    from public.content_packages p where p.deleted_at is null and not (p.manifest ? 'packageId' and p.manifest ? 'version' and p.manifest ? 'checksum' and p.manifest ? 'assets')
  ) issues
  where public.is_content_staff()
  limit greatest(1, least(p_limit, 1000));
$$;

create or replace function public.restore_content_version(p_version_id uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare
  v public.content_versions%rowtype;
  before_snapshot jsonb;
begin
  if not public.has_any_role(array['owner','admin']::public.app_role[]) then raise exception 'Forbidden'; end if;
  select * into v from public.content_versions where id=p_version_id;
  if not found then raise exception 'Version not found'; end if;

  if v.entity_type='anatomical_systems' then
    select to_jsonb(x) into before_snapshot from public.anatomical_systems x where id=v.entity_id;
    update public.anatomical_systems x set slug=r.slug, code=r.code, status=r.status, sort_order=r.sort_order, summary=r.summary, icon_asset_path=r.icon_asset_path, published_at=r.published_at, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.anatomical_systems, v.snapshot) r where x.id=v.entity_id;
  elsif v.entity_type='organs' then
    select to_jsonb(x) into before_snapshot from public.organs x where id=v.entity_id;
    update public.organs x set system_id=r.system_id, body_region_id=r.body_region_id, slug=r.slug, latin_name=r.latin_name, status=r.status, definition=r.definition, function_summary=r.function_summary, location_summary=r.location_summary, histology_summary=r.histology_summary, clinical_significance=r.clinical_significance, sex_specific=r.sex_specific, sort_order=r.sort_order, thumbnail_path=r.thumbnail_path, fallback_image_path=r.fallback_image_path, published_at=r.published_at, last_medical_review_at=r.last_medical_review_at, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.organs, v.snapshot) r where x.id=v.entity_id;
  elsif v.entity_type='organ_parts' then
    select to_jsonb(x) into before_snapshot from public.organ_parts x where id=v.entity_id;
    update public.organ_parts x set organ_id=r.organ_id, parent_id=r.parent_id, slug=r.slug, latin_name=r.latin_name, status=r.status, definition=r.definition, function_summary=r.function_summary, clinical_significance=r.clinical_significance, stable_model_key=r.stable_model_key, sort_order=r.sort_order, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.organ_parts, v.snapshot) r where x.id=v.entity_id;
  elsif v.entity_type='diseases' then
    select to_jsonb(x) into before_snapshot from public.diseases x where id=v.entity_id;
    update public.diseases x set category_id=r.category_id, pathology_topic_id=r.pathology_topic_id, slug=r.slug, status=r.status, definition=r.definition, etiology=r.etiology, pathogenesis=r.pathogenesis, gross_changes=r.gross_changes, microscopic_changes=r.microscopic_changes, diagnostic_overview=r.diagnostic_overview, treatment_principles=r.treatment_principles, prevention=r.prevention, normal_vs_pathological=r.normal_vs_pathological, is_genetic=r.is_genetic, is_infectious=r.is_infectious, is_malignant=r.is_malignant, course=r.course, prevalence_rank=r.prevalence_rank, last_medical_review_at=r.last_medical_review_at, published_at=r.published_at, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.diseases, v.snapshot) r where x.id=v.entity_id;
  elsif v.entity_type='lessons' then
    select to_jsonb(x) into before_snapshot from public.lessons x where id=v.entity_id;
    update public.lessons x set slug=r.slug, system_id=r.system_id, organ_id=r.organ_id, disease_id=r.disease_id, level=r.level, estimated_minutes=r.estimated_minutes, status=r.status, summary=r.summary, objectives=r.objectives, published_at=r.published_at, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.lessons, v.snapshot) r where x.id=v.entity_id;
  elsif v.entity_type='quizzes' then
    select to_jsonb(x) into before_snapshot from public.quizzes x where id=v.entity_id;
    update public.quizzes x set slug=r.slug, lesson_id=r.lesson_id, organ_id=r.organ_id, disease_id=r.disease_id, status=r.status, passing_score=r.passing_score, time_limit_seconds=r.time_limit_seconds, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.quizzes, v.snapshot) r where x.id=v.entity_id;
  elsif v.entity_type='translations' then
    select to_jsonb(x) into before_snapshot from public.translations x where id=v.entity_id;
    update public.translations x set entity_type=r.entity_type, entity_id=r.entity_id, field_name=r.field_name, locale=r.locale, value=r.value, status=r.status, source_version=r.source_version, model_name=r.model_name, translated_at=r.translated_at, reviewed_by=r.reviewed_by, reviewed_at=r.reviewed_at, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.translations, v.snapshot) r where x.id=v.entity_id;
  elsif v.entity_type='references' then
    select to_jsonb(x) into before_snapshot from public.references x where id=v.entity_id;
    update public.references x set slug=r.slug, title=r.title, authors=r.authors, organization=r.organization, edition=r.edition, publication_year=r.publication_year, doi=r.doi, pmid=r.pmid, url=r.url, accessed_at=r.accessed_at, evidence_level=r.evidence_level, publisher=r.publisher, citation_text=r.citation_text, is_active=r.is_active, deleted_at=r.deleted_at, updated_by=auth.uid()
    from jsonb_populate_record(null::public.references, v.snapshot) r where x.id=v.entity_id;
  else
    raise exception 'Restoration is not enabled for %', v.entity_type;
  end if;

  perform public.write_audit_log('content.version_restored', v.entity_type, v.entity_id, before_snapshot, v.snapshot, jsonb_build_object('versionId', v.id, 'versionNumber', v.version_number));
  return true;
end;
$$;

-- Safe patch tool for incomplete records. Only allowlisted non-relational fields are mutable.
create or replace function public.apply_safe_content_patch(p_entity_type text, p_entity_id uuid, p_patch jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare before_snapshot jsonb; after_snapshot jsonb;
begin
  if not public.has_any_role(array['owner','admin','editor']::public.app_role[]) then raise exception 'Forbidden'; end if;
  if jsonb_typeof(p_patch) <> 'object' then raise exception 'Patch must be a JSON object'; end if;

  if p_entity_type='organs' then
    if exists (
      select 1 from jsonb_object_keys(p_patch) as keys(field_name)
      where field_name not in ('definition','function_summary','location_summary','histology_summary','clinical_significance','thumbnail_path','fallback_image_path')
    ) then raise exception 'Patch contains fields that are not allowed for organs'; end if;
    select to_jsonb(x) into before_snapshot from public.organs x where id=p_entity_id;
    update public.organs set
      definition=coalesce(p_patch->>'definition',definition),
      function_summary=coalesce(p_patch->>'function_summary',function_summary),
      location_summary=coalesce(p_patch->>'location_summary',location_summary),
      histology_summary=coalesce(p_patch->>'histology_summary',histology_summary),
      clinical_significance=coalesce(p_patch->>'clinical_significance',clinical_significance),
      thumbnail_path=coalesce(p_patch->>'thumbnail_path',thumbnail_path),
      fallback_image_path=coalesce(p_patch->>'fallback_image_path',fallback_image_path),
      updated_by=auth.uid()
    where id=p_entity_id returning to_jsonb(organs) into after_snapshot;
  elsif p_entity_type='diseases' then
    if exists (
      select 1 from jsonb_object_keys(p_patch) as keys(field_name)
      where field_name not in ('definition','etiology','pathogenesis','gross_changes','microscopic_changes','diagnostic_overview','treatment_principles','prevention','normal_vs_pathological')
    ) then raise exception 'Patch contains fields that are not allowed for diseases'; end if;
    select to_jsonb(x) into before_snapshot from public.diseases x where id=p_entity_id;
    update public.diseases set
      definition=coalesce(p_patch->>'definition',definition),
      etiology=coalesce(p_patch->>'etiology',etiology),
      pathogenesis=coalesce(p_patch->>'pathogenesis',pathogenesis),
      gross_changes=coalesce(p_patch->>'gross_changes',gross_changes),
      microscopic_changes=coalesce(p_patch->>'microscopic_changes',microscopic_changes),
      diagnostic_overview=coalesce(p_patch->>'diagnostic_overview',diagnostic_overview),
      treatment_principles=coalesce(p_patch->>'treatment_principles',treatment_principles),
      prevention=coalesce(p_patch->>'prevention',prevention),
      normal_vs_pathological=coalesce(p_patch->>'normal_vs_pathological',normal_vs_pathological),
      updated_by=auth.uid()
    where id=p_entity_id returning to_jsonb(diseases) into after_snapshot;
  elsif p_entity_type='media_assets' then
    if exists (
      select 1 from jsonb_object_keys(p_patch) as keys(field_name)
      where field_name not in ('mime_type','checksum_sha256','byte_size','alt_text','license_name','attribution')
    ) then raise exception 'Patch contains fields that are not allowed for media assets'; end if;
    if p_patch ? 'checksum_sha256' and (p_patch->>'checksum_sha256') !~ '^[a-fA-F0-9]{64}$' then
      raise exception 'checksum_sha256 must contain exactly 64 hexadecimal characters';
    end if;
    select to_jsonb(x) into before_snapshot from public.media_assets x where id=p_entity_id;
    update public.media_assets set
      mime_type=coalesce(p_patch->>'mime_type',mime_type),
      checksum_sha256=coalesce(p_patch->>'checksum_sha256',checksum_sha256),
      byte_size=coalesce((p_patch->>'byte_size')::bigint,byte_size),
      alt_text=coalesce(p_patch->>'alt_text',alt_text),
      license_name=coalesce(p_patch->>'license_name',license_name),
      attribution=coalesce(p_patch->>'attribution',attribution),
      updated_by=auth.uid()
    where id=p_entity_id returning to_jsonb(media_assets) into after_snapshot;
  else
    raise exception 'Safe patch is not enabled for %', p_entity_type;
  end if;

  if after_snapshot is null then raise exception 'Record not found'; end if;
  perform public.write_audit_log('content.safe_patch', p_entity_type, p_entity_id, before_snapshot, after_snapshot, jsonb_build_object('patch', p_patch));
  return after_snapshot;
end;
$$;

-- Edge Function calls this after a fresh password re-authentication.
create or replace function public.sync_owner_profile(p_username text, p_email text, p_must_change_credentials boolean default false)
returns public.profiles language plpgsql security definer set search_path = public as $$
declare before_snapshot jsonb; result public.profiles;
begin
  if auth.uid() is null or public.current_app_role() <> 'owner' then raise exception 'Forbidden'; end if;
  if p_username !~ '^[A-Za-z0-9_.-]{3,40}$' then raise exception 'Invalid username'; end if;
  if position('@' in p_email) < 2 then raise exception 'Invalid email'; end if;
  select to_jsonb(p) into before_snapshot from public.profiles p where id=auth.uid() for update;
  update public.profiles
    set username=p_username, email=lower(p_email), must_change_credentials=p_must_change_credentials, updated_at=timezone('utc', now())
    where id=auth.uid() and role='owner'
    returning * into result;
  if result.id is null then raise exception 'Owner profile not found'; end if;
  perform public.write_audit_log('owner.credentials_profile_sync','profiles',auth.uid(),before_snapshot,to_jsonb(result),'{}'::jsonb);
  return result;
end;
$$;

-- RLS setup.
alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.role_permissions enable row level security;
alter table public.profiles enable row level security;
alter table public.user_preferences enable row level security;
alter table public.app_settings enable row level security;
alter table public.navigation_items enable row level security;
alter table public.content_pages enable row level security;
alter table public.anatomical_systems enable row level security;
alter table public.body_regions enable row level security;
alter table public.organs enable row level security;
alter table public.organ_parts enable row level security;
alter table public.tissues enable row level security;
alter table public.cell_types enable row level security;
alter table public.anatomical_relationships enable row level security;
alter table public.blood_supplies enable row level security;
alter table public.innervations enable row level security;
alter table public.functions enable row level security;
alter table public.pathology_topics enable row level security;
alter table public.disease_categories enable row level security;
alter table public.diseases enable row level security;
alter table public.disease_organ_links enable row level security;
alter table public.disease_part_links enable row level security;
alter table public.disease_risk_factors enable row level security;
alter table public.disease_symptoms enable row level security;
alter table public.disease_complications enable row level security;
alter table public.lessons enable row level security;
alter table public.lesson_sections enable row level security;
alter table public.learning_paths enable row level security;
alter table public.learning_path_items enable row level security;
alter table public.quizzes enable row level security;
alter table public.questions enable row level security;
alter table public.question_options enable row level security;
alter table public.flashcards enable row level security;
alter table public.media_assets enable row level security;
alter table public.models_3d enable row level security;
alter table public.model_hotspots enable row level security;
alter table public.content_packages enable row level security;
alter table public.content_package_assets enable row level security;
alter table public.translations enable row level security;
alter table public.medical_terms enable row level security;
alter table public.term_synonyms enable row level security;
alter table public.references enable row level security;
alter table public.content_references enable row level security;
alter table public.medical_reviews enable row level security;
alter table public.content_versions enable row level security;
alter table public.bookmarks enable row level security;
alter table public.notes enable row level security;
alter table public.study_progress enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.download_records enable row level security;
alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;
alter table public.ai_usage enable row level security;
alter table public.ai_feedback enable row level security;
alter table public.content_suggestions enable row level security;
alter table public.content_corrections enable row level security;
alter table public.moderation_queue enable row level security;
alter table public.audit_logs enable row level security;

create policy roles_read on public.roles for select to authenticated using (true);
create policy permissions_staff_read on public.permissions for select to authenticated using (public.has_any_role(array['owner','admin']::public.app_role[]));
create policy role_permissions_staff_read on public.role_permissions for select to authenticated using (public.has_any_role(array['owner','admin']::public.app_role[]));

create policy profiles_self_read on public.profiles for select to authenticated using ((select auth.uid())=id);
create policy profiles_admin_read on public.profiles for select to authenticated using (public.has_any_role(array['owner','admin']::public.app_role[]));
create policy profiles_admin_manage on public.profiles for update to authenticated using (public.has_any_role(array['owner','admin']::public.app_role[])) with check (public.has_any_role(array['owner','admin']::public.app_role[]));
create policy preferences_owner_all on public.user_preferences for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

create policy app_settings_public_read on public.app_settings for select to anon, authenticated using (is_public or public.has_any_role(array['owner','admin']::public.app_role[]));
create policy app_settings_owner_manage on public.app_settings for all to authenticated using (public.has_any_role(array['owner']::public.app_role[])) with check (public.has_any_role(array['owner']::public.app_role[]));
create policy navigation_public_read on public.navigation_items for select to anon, authenticated using (is_enabled and deleted_at is null and (required_role is null or public.has_any_role(array[required_role]::public.app_role[])));
create policy navigation_admin_manage on public.navigation_items for all to authenticated using (public.has_any_role(array['owner','admin']::public.app_role[])) with check (public.has_any_role(array['owner','admin']::public.app_role[]));
create policy content_pages_public_read on public.content_pages for select to anon, authenticated using (status='published' and deleted_at is null);
create policy content_pages_staff_read on public.content_pages for select to authenticated using (public.is_content_staff());
create policy content_pages_manager_manage on public.content_pages for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());

-- Reusable policy pattern expanded explicitly for exposed content tables.
create policy systems_public_read on public.anatomical_systems for select to anon, authenticated using (status='published' and deleted_at is null);
create policy systems_staff_read on public.anatomical_systems for select to authenticated using (public.is_content_staff());
create policy systems_manager_write on public.anatomical_systems for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy regions_public_read on public.body_regions for select to anon, authenticated using (status='published' and deleted_at is null);
create policy regions_staff_read on public.body_regions for select to authenticated using (public.is_content_staff());
create policy regions_manager_write on public.body_regions for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy organs_public_read on public.organs for select to anon, authenticated using (status='published' and deleted_at is null);
create policy organs_staff_read on public.organs for select to authenticated using (public.is_content_staff());
create policy organs_manager_write on public.organs for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy organ_parts_public_read on public.organ_parts for select to anon, authenticated using (status='published' and deleted_at is null);
create policy organ_parts_staff_read on public.organ_parts for select to authenticated using (public.is_content_staff());
create policy organ_parts_manager_write on public.organ_parts for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy tissues_public_read on public.tissues for select to anon, authenticated using (status='published' and deleted_at is null);
create policy tissues_staff_read on public.tissues for select to authenticated using (public.is_content_staff());
create policy tissues_manager_write on public.tissues for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy cells_public_read on public.cell_types for select to anon, authenticated using (status='published' and deleted_at is null);
create policy cells_staff_read on public.cell_types for select to authenticated using (public.is_content_staff());
create policy cells_manager_write on public.cell_types for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy relationships_public_read on public.anatomical_relationships for select to anon, authenticated using (status='published' and deleted_at is null);
create policy relationships_staff_read on public.anatomical_relationships for select to authenticated using (public.is_content_staff());
create policy relationships_manager_write on public.anatomical_relationships for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy blood_public_read on public.blood_supplies for select to anon, authenticated using (status='published' and deleted_at is null);
create policy blood_staff_read on public.blood_supplies for select to authenticated using (public.is_content_staff());
create policy blood_manager_write on public.blood_supplies for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy nerves_public_read on public.innervations for select to anon, authenticated using (status='published' and deleted_at is null);
create policy nerves_staff_read on public.innervations for select to authenticated using (public.is_content_staff());
create policy nerves_manager_write on public.innervations for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy functions_public_read on public.functions for select to anon, authenticated using (status='published' and deleted_at is null);
create policy functions_staff_read on public.functions for select to authenticated using (public.is_content_staff());
create policy functions_manager_write on public.functions for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());

create policy pathology_public_read on public.pathology_topics for select to anon, authenticated using (status='published' and deleted_at is null);
create policy pathology_staff_read on public.pathology_topics for select to authenticated using (public.is_content_staff());
create policy pathology_manager_write on public.pathology_topics for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy disease_categories_public_read on public.disease_categories for select to anon, authenticated using (status='published' and deleted_at is null);
create policy disease_categories_staff_read on public.disease_categories for select to authenticated using (public.is_content_staff());
create policy disease_categories_manager_write on public.disease_categories for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy diseases_public_read on public.diseases for select to anon, authenticated using (status='published' and deleted_at is null);
create policy diseases_staff_read on public.diseases for select to authenticated using (public.is_content_staff());
create policy diseases_manager_write on public.diseases for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());

create policy disease_organ_public_read on public.disease_organ_links for select to anon, authenticated using (exists(select 1 from public.diseases d where d.id=disease_id and d.status='published' and d.deleted_at is null));
create policy disease_organ_manager_write on public.disease_organ_links for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy disease_part_public_read on public.disease_part_links for select to anon, authenticated using (exists(select 1 from public.diseases d where d.id=disease_id and d.status='published' and d.deleted_at is null));
create policy disease_part_manager_write on public.disease_part_links for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy risk_public_read on public.disease_risk_factors for select to anon, authenticated using (exists(select 1 from public.diseases d where d.id=disease_id and d.status='published' and d.deleted_at is null));
create policy risk_manager_write on public.disease_risk_factors for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy symptoms_public_read on public.disease_symptoms for select to anon, authenticated using (exists(select 1 from public.diseases d where d.id=disease_id and d.status='published' and d.deleted_at is null));
create policy symptoms_manager_write on public.disease_symptoms for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy complications_public_read on public.disease_complications for select to anon, authenticated using (exists(select 1 from public.diseases d where d.id=disease_id and d.status='published' and d.deleted_at is null));
create policy complications_manager_write on public.disease_complications for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());

create policy lessons_public_read on public.lessons for select to anon, authenticated using (status='published' and deleted_at is null);
create policy lessons_staff_read on public.lessons for select to authenticated using (public.is_content_staff());
create policy lessons_manager_write on public.lessons for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy sections_public_read on public.lesson_sections for select to anon, authenticated using (exists(select 1 from public.lessons l where l.id=lesson_id and l.status='published' and l.deleted_at is null));
create policy sections_manager_write on public.lesson_sections for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy paths_public_read on public.learning_paths for select to anon, authenticated using (status='published' and deleted_at is null);
create policy paths_staff_read on public.learning_paths for select to authenticated using (public.is_content_staff());
create policy paths_manager_write on public.learning_paths for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy path_items_public_read on public.learning_path_items for select to anon, authenticated using (exists(select 1 from public.learning_paths p where p.id=learning_path_id and p.status='published' and p.deleted_at is null));
create policy path_items_manager_write on public.learning_path_items for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy quizzes_public_read on public.quizzes for select to anon, authenticated using (status='published' and deleted_at is null);
create policy quizzes_staff_read on public.quizzes for select to authenticated using (public.is_content_staff());
create policy quizzes_manager_write on public.quizzes for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy questions_public_read on public.questions for select to anon, authenticated using (exists(select 1 from public.quizzes q where q.id=quiz_id and q.status='published' and q.deleted_at is null));
create policy questions_manager_write on public.questions for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy options_public_read on public.question_options for select to authenticated using (exists(select 1 from public.questions q join public.quizzes z on z.id=q.quiz_id where q.id=question_id and z.status='published' and z.deleted_at is null));
create policy options_manager_write on public.question_options for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy flashcards_public_read on public.flashcards for select to anon, authenticated using (status='published' and deleted_at is null);
create policy flashcards_staff_read on public.flashcards for select to authenticated using (public.is_content_staff());
create policy flashcards_manager_write on public.flashcards for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());

create policy assets_public_read on public.media_assets for select to anon, authenticated using (status='published' and deleted_at is null);
create policy assets_staff_read on public.media_assets for select to authenticated using (public.is_content_staff());
create policy assets_manager_write on public.media_assets for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy models_public_read on public.models_3d for select to anon, authenticated using (status='published' and deleted_at is null);
create policy models_staff_read on public.models_3d for select to authenticated using (public.is_content_staff());
create policy models_manager_write on public.models_3d for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy hotspots_public_read on public.model_hotspots for select to anon, authenticated using (status='published' and deleted_at is null);
create policy hotspots_staff_read on public.model_hotspots for select to authenticated using (public.is_content_staff());
create policy hotspots_manager_write on public.model_hotspots for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy packages_public_read on public.content_packages for select to anon, authenticated using (status='published' and deleted_at is null);
create policy packages_staff_read on public.content_packages for select to authenticated using (public.is_content_staff());
create policy packages_manager_write on public.content_packages for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy package_assets_public_read on public.content_package_assets for select to anon, authenticated using (exists(select 1 from public.content_packages p where p.id=content_package_id and p.status='published' and p.deleted_at is null));
create policy package_assets_manager_write on public.content_package_assets for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());

create policy translations_public_read on public.translations for select to anon, authenticated using (status='published' and deleted_at is null);
create policy translations_staff_read on public.translations for select to authenticated using (public.is_content_staff());
create policy translations_write on public.translations for all to authenticated using (public.has_any_role(array['owner','admin','editor','medical_reviewer','translator']::public.app_role[])) with check (public.has_any_role(array['owner','admin','editor','medical_reviewer','translator']::public.app_role[]));
create policy terms_public_read on public.medical_terms for select to anon, authenticated using (status='published' and deleted_at is null);
create policy terms_staff_read on public.medical_terms for select to authenticated using (public.is_content_staff());
create policy terms_manager_write on public.medical_terms for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy synonyms_public_read on public.term_synonyms for select to anon, authenticated using (exists(select 1 from public.medical_terms t where t.id=term_id and t.status='published' and t.deleted_at is null));
create policy synonyms_manager_write on public.term_synonyms for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());

create policy refs_public_read on public.references for select to anon, authenticated using (is_active and deleted_at is null);
create policy refs_staff_read on public.references for select to authenticated using (public.is_content_staff());
create policy refs_manager_write on public.references for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy content_refs_public_read on public.content_references for select to anon, authenticated using (true);
create policy content_refs_manager_write on public.content_references for all to authenticated using (public.is_content_manager()) with check (public.is_content_manager());
create policy reviews_staff_read on public.medical_reviews for select to authenticated using (public.is_content_staff());
create policy reviews_reviewer_write on public.medical_reviews for all to authenticated using (public.has_any_role(array['owner','admin','medical_reviewer']::public.app_role[])) with check (public.has_any_role(array['owner','admin','medical_reviewer']::public.app_role[]));
create policy versions_staff_read on public.content_versions for select to authenticated using (public.is_content_staff());

create policy bookmarks_owner_all on public.bookmarks for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy notes_owner_all on public.notes for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy progress_owner_all on public.study_progress for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy attempts_owner_all on public.quiz_attempts for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy downloads_owner_all on public.download_records for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

create policy ai_conversations_owner_all on public.ai_conversations for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy ai_messages_owner_all on public.ai_messages for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);
create policy ai_usage_owner_read on public.ai_usage for select to authenticated using ((select auth.uid())=user_id);
create policy ai_feedback_owner_all on public.ai_feedback for all to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id);

create policy suggestions_insert on public.content_suggestions for insert to anon, authenticated with check (user_id is null or user_id=(select auth.uid()));
create policy suggestions_owner_read on public.content_suggestions for select to authenticated using (user_id=(select auth.uid()) or public.is_content_staff());
create policy suggestions_staff_manage on public.content_suggestions for all to authenticated using (public.is_content_staff()) with check (public.is_content_staff());
create policy corrections_staff_all on public.content_corrections for all to authenticated using (public.is_content_staff()) with check (public.is_content_staff());
create policy moderation_staff_all on public.moderation_queue for all to authenticated using (public.is_content_staff()) with check (public.is_content_staff());
create policy audit_admin_read on public.audit_logs for select to authenticated using (public.has_any_role(array['owner','admin']::public.app_role[]));

-- Column-level grants keep regular users from changing roles even if a future policy is loosened.
revoke all on public.profiles from anon, authenticated;
grant select on public.profiles to authenticated;
grant update (username, display_name, avatar_url, locale, last_seen_at) on public.profiles to authenticated;
grant select on public.roles to authenticated;

-- RPC permissions.
grant execute on function public.search_medical_content(text,text,integer) to anon, authenticated;
grant execute on function public.get_organ_page(text,text) to anon, authenticated;
grant execute on function public.admin_dashboard_summary() to authenticated;
grant execute on function public.content_integrity_report(integer) to authenticated;
grant execute on function public.restore_content_version(uuid) to authenticated;
grant execute on function public.apply_safe_content_patch(text,uuid,jsonb) to authenticated;
grant execute on function public.sync_owner_profile(text,text,boolean) to authenticated;
revoke execute on function public.write_audit_log(text,text,uuid,jsonb,jsonb,jsonb) from public, anon, authenticated;

-- Storage bucket and policies.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values(
  'medical-content',
  'medical-content',
  false,
  524288000,
  array['image/png','image/jpeg','image/webp','image/avif','model/gltf-binary','model/gltf+json','application/octet-stream','audio/mpeg','audio/ogg','video/mp4','application/pdf']
)
on conflict (id) do update set file_size_limit=excluded.file_size_limit, allowed_mime_types=excluded.allowed_mime_types;

create policy storage_published_read on storage.objects for select to anon, authenticated
using (
  bucket_id='medical-content' and (
    name like 'published/%' or public.is_content_staff()
  )
);
create policy storage_staff_insert on storage.objects for insert to authenticated
with check (bucket_id='medical-content' and public.is_content_manager());
create policy storage_staff_update on storage.objects for update to authenticated
using (bucket_id='medical-content' and public.is_content_manager())
with check (bucket_id='medical-content' and public.is_content_manager());
create policy storage_staff_delete on storage.objects for delete to authenticated
using (bucket_id='medical-content' and public.has_any_role(array['owner','admin']::public.app_role[]));

insert into public.app_settings(key, value, is_public, description) values
  ('ai', '{"mode":"disabled","streaming":true,"dailyUserQuota":20}'::jsonb, false, 'Server-side AI provider configuration'),
  ('content', '{"defaultLocale":"ar","supportedLocales":["ar","en","fr","es","de","tr","ur"]}'::jsonb, true, 'Content language configuration'),
  ('downloads', '{"wifiOnlyDefault":true,"maxConcurrent":2}'::jsonb, true, 'Offline package defaults'),
  ('medicalDisclaimer', '{"ar":"هذا المحتوى تعليمي ولا يمثل تشخيصًا أو خطة علاج شخصية.","en":"This content is educational and is not a personal diagnosis or treatment plan."}'::jsonb, true, 'Mandatory medical disclaimer')
on conflict (key) do nothing;
