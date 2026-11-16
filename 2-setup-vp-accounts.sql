-- Step 2: username and password accounts made by the admin. Already applied. Safe to run again.
alter table public.vp_staff add column if not exists username text;
alter table public.vp_staff add column if not exists title text not null default '';
create unique index if not exists vp_staff_username_key on public.vp_staff (lower(username));
alter table public.vp_staff drop constraint if exists vp_staff_role_check;
update public.vp_staff set role = 'admin' where role = 'owner';
alter table public.vp_staff add constraint vp_staff_role_check check (role in ('admin', 'vp', 'staff'));
alter table public.vp_staff alter column role set default 'staff';
create or replace function public.vp_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.vp_staff where user_id = auth.uid() and role = 'admin');
$$;
drop policy if exists vp_staff_owner on public.vp_staff;
revoke delete, insert, update on public.vp_staff from authenticated;
drop function if exists public.vp_claim(text);
drop table if exists public.vp_invites;
