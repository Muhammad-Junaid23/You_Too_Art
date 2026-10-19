-- ============================================================================
-- You Too Art — 004 Chat & Realtime Messaging System
-- Run this in your Supabase SQL Editor
-- ============================================================================

-- 1. Conversations Table
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  participant_a uuid not null,
  participant_b uuid not null,
  last_message text not null default '',
  last_message_at timestamptz not null default timezone('utc'::text, now()),
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_conversation_participants unique (participant_a, participant_b)
);

create index if not exists idx_conversations_participant_a on public.conversations(participant_a);
create index if not exists idx_conversations_participant_b on public.conversations(participant_b);
create index if not exists idx_conversations_last_message_at on public.conversations(last_message_at desc);

-- 2. Messages Table
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null,
  text text not null default '',
  media_url text,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists idx_messages_conversation_id on public.messages(conversation_id);
create index if not exists idx_messages_created_at on public.messages(created_at asc);

-- 3. Enable Row Level Security (RLS)
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

-- 4. Conversations Policies
create policy "Users can view their conversations"
  on public.conversations for select
  using (true);

create policy "Users can insert conversations"
  on public.conversations for insert
  with check (true);

create policy "Users can update conversations"
  on public.conversations for update
  using (true);

-- 5. Messages Policies
create policy "Users can view messages"
  on public.messages for select
  using (true);

create policy "Users can insert messages"
  on public.messages for insert
  with check (true);

create policy "Users can update messages"
  on public.messages for update
  using (true);

-- 6. Add to Supabase Realtime publication safely (idempotent)
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'conversations'
  ) then
    alter publication supabase_realtime add table public.conversations;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
