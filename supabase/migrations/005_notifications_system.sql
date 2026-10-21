-- ============================================================================
-- You Too Art — In-App Realtime Notification System (Screen 1 & Across App)
-- Run this in your Supabase SQL Editor (100% Free Tier Compatible)
-- ============================================================================

-- 1. Notifications Table
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null,
  actor_id uuid not null,
  type text not null check (type in (
    'connection_request',
    'connection_accepted',
    'post_like',
    'post_comment',
    'casting_call',
    'casting_application',
    'chat_message'
  )),
  primary_subject text not null,
  action_text text not null,
  target_object text,
  entity_type text,
  entity_id text,
  avatar_url text,
  is_filmfare boolean not null default false,
  is_casting_icon boolean not null default false,
  request_status text not null default 'none' check (request_status in ('none', 'pending', 'accepted', 'rejected')),
  is_read boolean not null default false,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- Drop any foreign key constraints so mock talents and auth users interact freely
alter table if exists public.notifications drop constraint if exists notifications_recipient_id_fkey;
alter table if exists public.notifications drop constraint if exists notifications_actor_id_fkey;
alter table if exists public.notifications drop constraint if exists unique_notification_recipient_actor_type;

-- 2. Indexes for High Performance Queries
create index if not exists idx_notifications_recipient_id on public.notifications(recipient_id);
create index if not exists idx_notifications_recipient_unread on public.notifications(recipient_id) where is_read = false;
create index if not exists idx_notifications_created_at on public.notifications(created_at desc);

-- 3. Enable Row Level Security (RLS)
alter table public.notifications enable row level security;

-- 4. RLS Policies
drop policy if exists "Users can view notifications" on public.notifications;
drop policy if exists "Users can insert notifications" on public.notifications;
drop policy if exists "Users can update notifications" on public.notifications;
drop policy if exists "Users can delete notifications" on public.notifications;

create policy "Users can view notifications"
  on public.notifications for select
  using (true);

create policy "Users can insert notifications"
  on public.notifications for insert
  with check (true);

create policy "Users can update notifications"
  on public.notifications for update
  using (true)
  with check (true);

create policy "Users can delete notifications"
  on public.notifications for delete
  using (true);

-- 5. Enable Realtime on notifications safely (idempotent)
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
