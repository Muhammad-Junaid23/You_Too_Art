-- ============================================================================
-- You Too Art — Connections & Networking System (Screens 2 & 3)
-- Run this in your Supabase SQL Editor
-- ============================================================================

-- 1. Connections Table
create table if not exists public.connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  connected_user_id uuid not null,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_user_connection unique (user_id, connected_user_id)
);

-- Drop foreign key constraints so test talents and app users can connect freely
alter table if exists public.connections drop constraint if exists connections_user_id_fkey;
alter table if exists public.connections drop constraint if exists connections_connected_user_id_fkey;

create index if not exists idx_connections_user_id on public.connections(user_id);
create index if not exists idx_connections_connected_user_id on public.connections(connected_user_id);
create index if not exists idx_connections_status on public.connections(status);

-- 2. Enable Row Level Security (RLS)
alter table public.connections enable row level security;

-- 3. RLS Policies for Connections
drop policy if exists "Users can view connections" on public.connections;
drop policy if exists "Users can insert connections" on public.connections;
drop policy if exists "Users can update connections" on public.connections;
drop policy if exists "Users can delete connections" on public.connections;

create policy "Users can view connections"
  on public.connections for select
  using (true);

create policy "Users can insert connections"
  on public.connections for insert
  with check (true);

create policy "Users can update connections"
  on public.connections for update
  using (true)
  with check (true);

create policy "Users can delete connections"
  on public.connections for delete
  using (true);

-- 4. Enable Realtime on connections safely (idempotent)
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'connections'
  ) then
    alter publication supabase_realtime add table public.connections;
  end if;
end $$;
