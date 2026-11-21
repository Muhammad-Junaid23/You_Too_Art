-- ============================================================================
-- You Too Art — Account Deletion & User Verification Support
-- Run this in your Supabase SQL Editor
-- ============================================================================

-- 1. Allow authenticated users to delete their own record from public.users
drop policy if exists "Users can delete their own profile" on public.users;
create policy "Users can delete their own profile"
  on public.users for delete
  to authenticated
  using (auth.uid() = id);

-- 2. Add is_verified column to public.users if not present
alter table public.users add column if not exists is_verified boolean not null default false;

-- 3. Stored procedure to atomically delete user account from auth.users (cascades to all child tables)
create or replace function public.delete_user_account()
returns void
language plpgsql
security definer
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;
