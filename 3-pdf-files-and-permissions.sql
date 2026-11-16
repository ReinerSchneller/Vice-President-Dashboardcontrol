-- PDFs for Discord, and the permissions the site needs. Safe to run more than once.
-- Run this again after any Supabase reset if the site says it cannot read the staff list.
create table if not exists public.nation_files (
  file_id uuid not null,
  part int not null check (part >= 0 and part < 200),
  data text not null check (length(data) <= 400000),
  created_at timestamptz not null default now(),
  created_by uuid default auth.uid(),
  primary key (file_id, part)
);
alter table public.nation_files enable row level security;
revoke all on public.nation_files from anon, authenticated;
drop policy if exists vp_files_insert on public.nation_files;
create policy vp_files_insert on public.nation_files for insert to authenticated with check (public.vp_is_staff());

grant usage on schema public to authenticated;
grant select on public.vp_staff to authenticated;
grant select, insert, update, delete on public.vp_store to authenticated;
grant select, insert on public.nation_commands to authenticated;
grant insert on public.nation_files to authenticated;
grant execute on function public.vp_is_staff() to authenticated;
revoke all on public.vp_staff, public.vp_store, public.nation_files from anon;
