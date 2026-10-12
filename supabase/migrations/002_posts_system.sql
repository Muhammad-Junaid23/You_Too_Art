-- ============================================================================
-- You Too Art — Posts, Likes, Comments, and Tags System
-- Run this in your Supabase SQL Editor
-- ============================================================================

-- 1. Posts Table
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.users(id) on delete cascade,
  caption text not null default '',
  media_url text,
  media_type text default 'image',
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- 2. Post Likes Table
create table if not exists public.post_likes (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_post_user_like unique (post_id, user_id)
);

-- 3. Post Comments Table
create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.users(id) on delete cascade,
  text text not null,
  created_at timestamptz not null default timezone('utc'::text, now())
);

-- 4. Post Tags Table
create table if not exists public.post_tags (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default timezone('utc'::text, now()),
  constraint unique_post_user_tag unique (post_id, user_id)
);

-- 5. Enable Row Level Security (RLS)
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;
alter table public.post_tags enable row level security;

-- 6. Policies for Posts
create policy "Anyone can read posts"
  on public.posts for select
  using (true);

create policy "Authenticated users can create posts"
  on public.posts for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Authors can update their own posts"
  on public.posts for update
  to authenticated
  using (auth.uid() = author_id);

create policy "Authors can delete their own posts"
  on public.posts for delete
  to authenticated
  using (auth.uid() = author_id);

-- 7. Policies for Likes
create policy "Anyone can read post likes"
  on public.post_likes for select
  using (true);

create policy "Authenticated users can like posts"
  on public.post_likes for insert
  to authenticated
  with check (auth.uid() = user_id);

create policy "Users can delete their own likes"
  on public.post_likes for delete
  to authenticated
  using (auth.uid() = user_id);

-- 8. Policies for Comments
create policy "Anyone can read comments"
  on public.post_comments for select
  using (true);

create policy "Authenticated users can add comments"
  on public.post_comments for insert
  to authenticated
  with check (auth.uid() = author_id);

create policy "Authors can delete their own comments"
  on public.post_comments for delete
  to authenticated
  using (auth.uid() = author_id);

-- 9. Policies for Post Tags
create policy "Anyone can read post tags"
  on public.post_tags for select
  using (true);

create policy "Post authors can insert tags"
  on public.post_tags for insert
  to authenticated
  with check (true);
