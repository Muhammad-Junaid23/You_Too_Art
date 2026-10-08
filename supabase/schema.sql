-- ============================================================================
-- You Too Art — Complete Supabase PostgreSQL Schema & Security Policies
-- ============================================================================

-- 1. EXTENSIONS
create extension if not exists "uuid-ossp";
create extension if not exists "pgcrypto";

-- ============================================================================
-- 2. TABLES
-- ============================================================================

-- ─── Users Table ────────────────────────────────────────────────────────────
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  first_name text default '',
  last_name text default '',
  email text not null,
  role text not null default 'unset',
  bio text default '',
  profile_image_path text,
  location text,
  incorporation_number text,
  established_year int,
  address text,
  is_admin boolean not null default false,
  fcm_token text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ─── Countries Table ────────────────────────────────────────────────────────
create table if not exists public.countries (
  code text primary key,
  name text not null
);

-- ─── Cities Table ───────────────────────────────────────────────────────────
create table if not exists public.cities (
  id uuid primary key default gen_random_uuid(),
  country_code text not null references public.countries(code) on delete cascade,
  name text not null
);

-- ─── Posts Table ────────────────────────────────────────────────────────────
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.users(id) on delete cascade,
  caption text not null default '',
  media_url text,
  media_type text default 'image',
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- ─── Post Likes Table ───────────────────────────────────────────────────────
create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_post_user_like unique (post_id, user_id)
);

-- ─── Post Comments Table ────────────────────────────────────────────────────
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.users(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- ─── Connections Table (Mutual Follows / Networking) ────────────────────────
create table if not exists public.connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  connected_user_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'blocked')),
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_user_connection unique (user_id, connected_user_id)
);

-- ─── Conversations Table ────────────────────────────────────────────────────
create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  participant_a uuid not null references public.users(id) on delete cascade,
  participant_b uuid not null references public.users(id) on delete cascade,
  last_message text,
  last_message_at timestamptz not null default timezone('utc'::text, now()),
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_conversation_participants unique (participant_a, participant_b)
);

-- ─── Messages Table ─────────────────────────────────────────────────────────
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.users(id) on delete cascade,
  text text not null,
  media_url text,
  read_at timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- ─── Casting Calls Table ────────────────────────────────────────────────────
create table if not exists public.casting_calls (
  id uuid primary key default gen_random_uuid(),
  posted_by_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  description text not null,
  role_type text not null,
  location text,
  deadline timestamptz,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- ─── Casting Applications Table ─────────────────────────────────────────────
create table if not exists public.casting_applications (
  id uuid primary key default gen_random_uuid(),
  casting_call_id uuid not null references public.casting_calls(id) on delete cascade,
  applicant_id uuid not null references public.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'reviewed', 'shortlisted', 'accepted', 'rejected')),
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_application unique (casting_call_id, applicant_id)
);

-- ─── Portfolio Items Table ──────────────────────────────────────────────────
create table if not exists public.portfolio_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  title text not null,
  media_url text not null,
  media_type text not null default 'image',
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- ============================================================================
-- 3. INDEXES FOR PERFORMANCE
-- ============================================================================

create index if not exists idx_posts_author_id on public.posts(author_id);
create index if not exists idx_posts_created_at on public.posts(created_at desc);

create index if not exists idx_post_likes_post_id on public.post_likes(post_id);
create index if not exists idx_post_likes_user_id on public.post_likes(user_id);

create index if not exists idx_post_comments_post_id on public.post_comments(post_id);
create index if not exists idx_post_comments_created_at on public.post_comments(created_at);

create index if not exists idx_connections_user_id on public.connections(user_id);
create index if not exists idx_connections_connected_user_id on public.connections(connected_user_id);

create index if not exists idx_conversations_participant_a on public.conversations(participant_a);
create index if not exists idx_conversations_participant_b on public.conversations(participant_b);
create index if not exists idx_conversations_last_message_at on public.conversations(last_message_at desc);

create index if not exists idx_messages_conversation_id on public.messages(conversation_id);
create index if not exists idx_messages_created_at on public.messages(created_at);

create index if not exists idx_casting_calls_posted_by on public.casting_calls(posted_by_id);
create index if not exists idx_casting_calls_role_type on public.casting_calls(role_type);
create index if not exists idx_casting_calls_created_at on public.casting_calls(created_at desc);

create index if not exists idx_casting_applications_call_id on public.casting_applications(casting_call_id);
create index if not exists idx_casting_applications_applicant on public.casting_applications(applicant_id);

create index if not exists idx_portfolio_items_user_id on public.portfolio_items(user_id);

-- ============================================================================
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

alter table public.users enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.connections enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.casting_calls enable row level security;
alter table public.casting_applications enable row level security;
alter table public.portfolio_items enable row level security;

-- ─── Users Policies ─────────────────────────────────────────────────────────
create policy "Users are viewable by authenticated users"
  on public.users for select
  to authenticated
  using (true);

create policy "Users can insert their own profile"
  on public.users for insert
  to authenticated
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.users for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- ─── Posts Policies ─────────────────────────────────────────────────────────
create policy "Posts are viewable by authenticated users"
  on public.posts for select
  to authenticated
  using (true);

create policy "Users can insert their own posts"
  on public.posts for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own posts"
  on public.posts for delete
  to authenticated
  using (auth.uid() = author_id);

-- ─── Post Likes Policies ────────────────────────────────────────────────────
create policy "Post likes are viewable by authenticated users"
  on public.post_likes for select
  to authenticated
  using (true);

create policy "Users can insert their own likes"
  on public.post_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete their own likes"
  on public.post_likes for delete
  to authenticated
  using (auth.uid() = user_id);

-- ─── Post Comments Policies ─────────────────────────────────────────────────
create policy "Post comments are viewable by authenticated users"
  on public.post_comments for select
  to authenticated
  using (true);

create policy "Users can insert their own comments"
  on public.post_comments for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Users can delete their own comments"
  on public.post_comments for delete
  to authenticated
  using (auth.uid() = author_id);

-- ─── Connections Policies ───────────────────────────────────────────────────
create policy "Users can view their own connections"
  on public.connections for select
  to authenticated
  using (auth.uid() = user_id or auth.uid() = connected_user_id);

create policy "Users can create connection requests"
  on public.connections for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can update connection status where they are recipient"
  on public.connections for update
  to authenticated
  using (auth.uid() = connected_user_id)
  with check (auth.uid() = connected_user_id);

create policy "Users can delete connections they are part of"
  on public.connections for delete
  to authenticated
  using (auth.uid() = user_id or auth.uid() = connected_user_id);

-- ─── Conversations Policies ─────────────────────────────────────────────────
create policy "Participants can view their conversations"
  on public.conversations for select
  to authenticated
  using (auth.uid() = participant_a or auth.uid() = participant_b);

create policy "Participants can create conversations"
  on public.conversations for insert
  to authenticated
  with check (auth.uid() = participant_a or auth.uid() = participant_b);

create policy "Participants can update conversation timestamps"
  on public.conversations for update
  to authenticated
  using (auth.uid() = participant_a or auth.uid() = participant_b);

-- ─── Messages Policies ──────────────────────────────────────────────────────
create policy "Participants can view messages in their conversations"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.participant_a = auth.uid() or c.participant_b = auth.uid())
    )
  );

create policy "Participants can insert messages in their conversations"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.participant_a = auth.uid() or c.participant_b = auth.uid())
    )
  );

create policy "Participants can mark messages as read"
  on public.messages for update
  to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.participant_a = auth.uid() or c.participant_b = auth.uid())
    )
  );

-- ─── Casting Calls Policies ─────────────────────────────────────────────────
create policy "Casting calls are viewable by authenticated users"
  on public.casting_calls for select
  to authenticated
  using (true);

create policy "Users can create casting calls"
  on public.casting_calls for insert
  to authenticated
  with check (auth.uid() = posted_by_id);

create policy "Creators can update their casting calls"
  on public.casting_calls for update
  to authenticated
  using (auth.uid() = posted_by_id)
  with check (auth.uid() = posted_by_id);

create policy "Creators can delete their casting calls"
  on public.casting_calls for delete
  to authenticated
  using (auth.uid() = posted_by_id);

-- ─── Casting Applications Policies ──────────────────────────────────────────
create policy "Applicants and Call posters can view applications"
  on public.casting_applications for select
  to authenticated
  using (
    auth.uid() = applicant_id
    or exists (
      select 1 from public.casting_calls cc
      where cc.id = casting_call_id and cc.posted_by_id = auth.uid()
    )
  );

create policy "Users can apply to casting calls"
  on public.casting_applications for insert
  to authenticated
  with check (auth.uid() = applicant_id);

create policy "Call posters can update application status"
  on public.casting_applications for update
  to authenticated
  using (
    exists (
      select 1 from public.casting_calls cc
      where cc.id = casting_call_id and cc.posted_by_id = auth.uid()
    )
  );

-- ─── Portfolio Items Policies ───────────────────────────────────────────────
create policy "Portfolio items are viewable by authenticated users"
  on public.portfolio_items for select
  to authenticated
  using (true);

create policy "Users can insert their portfolio items"
  on public.portfolio_items for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete their portfolio items"
  on public.portfolio_items for delete
  to authenticated
  using (auth.uid() = user_id);

-- ============================================================================
-- 5. AUTOMATED USER PROFILE CREATION TRIGGER (AUTH HOOK)
-- ============================================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data->>'role', 'actor')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

-- Trigger firing after user creation in Supabase auth
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
-- 6. REALTIME SUBSCRIPTIONS
-- ============================================================================

alter publication supabase_realtime add table public.users;
alter publication supabase_realtime add table public.posts;
alter publication supabase_realtime add table public.post_likes;
alter publication supabase_realtime add table public.post_comments;
alter publication supabase_realtime add table public.connections;
alter publication supabase_realtime add table public.conversations;
alter publication supabase_realtime add table public.messages;
alter publication supabase_realtime add table public.casting_calls;
alter publication supabase_realtime add table public.casting_applications;
alter publication supabase_realtime add table public.portfolio_items;
