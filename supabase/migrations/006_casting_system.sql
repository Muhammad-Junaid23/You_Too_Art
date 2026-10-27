-- ============================================================================
-- You Too Art — Casting Calls & Applications System (Screen 4 & Casting Engine)
-- Run this in your Supabase SQL Editor (100% Free Tier Compatible)
-- ============================================================================

-- 1. Casting Calls Table
create table if not exists public.casting_calls (
  id text primary key,
  title text not null,
  description text not null default '',
  author_id text not null,
  author_name text not null default '',
  author_avatar text,
  location text,
  city text,
  type text default 'Short Film',
  shoot_duration text default '',
  budget text default 'Negotiable',
  crew_required text default '1',
  shoot_details text default '',
  position text default '',
  age_required text default 'Any',
  height_required text default 'Any',
  gender text default 'Any',
  contact_email text,
  contact_number text,
  role_title text,
  role_description text,
  applicants_count int not null default 0,
  is_deleted boolean not null default false,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- Drop foreign keys to allow mock test personas, guest mode & auth users to interact seamlessly
alter table if exists public.casting_calls drop constraint if exists casting_calls_posted_by_id_fkey;
alter table if exists public.casting_calls drop constraint if exists casting_calls_author_id_fkey;

-- 2. Casting Applications Table
create table if not exists public.casting_applications (
  id text primary key,
  casting_call_id text not null,
  project_title text not null default '',
  applicant_id text not null,
  applicant_name text not null default '',
  applicant_avatar text,
  applied_at text default 'Recently',
  contact_number text default '',
  contact_email text default '',
  age text default '',
  height text default '',
  gender text default '',
  experience text default '',
  location text default '',
  note text default '',
  status text not null default 'received',
  is_wishlisted boolean not null default false,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- Drop foreign keys for flexible guest & multi-persona applications
alter table if exists public.casting_applications drop constraint if exists casting_applications_casting_call_id_fkey;
alter table if exists public.casting_applications drop constraint if exists casting_applications_applicant_id_fkey;

-- 3. Indexes for High Performance Queries
create index if not exists idx_casting_calls_author_id on public.casting_calls(author_id);
create index if not exists idx_casting_calls_created_at on public.casting_calls(created_at desc);
create index if not exists idx_casting_calls_is_deleted on public.casting_calls(is_deleted);

create index if not exists idx_casting_applications_call_id on public.casting_applications(casting_call_id);
create index if not exists idx_casting_applications_applicant on public.casting_applications(applicant_id);
create index if not exists idx_casting_applications_created_at on public.casting_applications(created_at desc);

-- 4. Enable Row Level Security (RLS)
alter table public.casting_calls enable row level security;
alter table public.casting_applications enable row level security;

-- 5. Open RLS Policies (Supports development, persona switching & cloud sync)
drop policy if exists "Anyone can read casting calls" on public.casting_calls;
drop policy if exists "Anyone can insert casting calls" on public.casting_calls;
drop policy if exists "Anyone can update casting calls" on public.casting_calls;
drop policy if exists "Anyone can delete casting calls" on public.casting_calls;

create policy "Anyone can read casting calls"
  on public.casting_calls for select
  using (true);

create policy "Anyone can insert casting calls"
  on public.casting_calls for insert
  with check (true);

create policy "Anyone can update casting calls"
  on public.casting_calls for update
  using (true)
  with check (true);

create policy "Anyone can delete casting calls"
  on public.casting_calls for delete
  using (true);

drop policy if exists "Anyone can read casting applications" on public.casting_applications;
drop policy if exists "Anyone can insert casting applications" on public.casting_applications;
drop policy if exists "Anyone can update casting applications" on public.casting_applications;
drop policy if exists "Anyone can delete casting applications" on public.casting_applications;

create policy "Anyone can read casting applications"
  on public.casting_applications for select
  using (true);

create policy "Anyone can insert casting applications"
  on public.casting_applications for insert
  with check (true);

create policy "Anyone can update casting applications"
  on public.casting_applications for update
  using (true)
  with check (true);

create policy "Anyone can delete casting applications"
  on public.casting_applications for delete
  using (true);

-- 6. Enable Realtime on casting tables safely (idempotent)
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'casting_calls'
  ) then
    alter publication supabase_realtime add table public.casting_calls;
  end if;

  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'casting_applications'
  ) then
    alter publication supabase_realtime add table public.casting_applications;
  end if;
end $$;
