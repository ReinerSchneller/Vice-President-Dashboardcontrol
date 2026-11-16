-- Office of the Vice President: storage, staff sign-in, and the Discord link.
-- Safe to run more than once.

-- Every record the site keeps (documents, units, people, schedule, log) lives here as JSON, one row per record.
create table if not exists public.vp_store (
  col text not null,
  id text not null,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  primary key (col, id)
);

-- Who may use the site. The first person to sign in becomes the owner.
create table if not exists public.vp_staff (
  user_id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  name text not null default '',
  role text not null default 'staff' check (role in ('owner', 'staff')),
  created_at timestamptz not null default now()
);
-- Emails the owner has invited. They become staff the first time they sign in.
create table if not exists public.vp_invites (
  email text primary key,
  name text not null default '',
  invited_at timestamptz not null default now()
);

create or replace function public.vp_is_staff() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.vp_staff where user_id = auth.uid());
$$;
create or replace function public.vp_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.vp_staff where user_id = auth.uid() and role = 'owner');
$$;

-- Called right after sign-in. Makes the first user the owner, and turns an invite into a staff seat.
create or replace function public.vp_claim(display_name text default '') returns text
language plpgsql security definer set search_path = public as $$
declare
  me uuid := auth.uid();
  mail text := lower(coalesce(auth.jwt() ->> 'email', ''));
  r text;
begin
  if me is null then return 'signed_out'; end if;
  select role into r from public.vp_staff where user_id = me;
  if r is not null then return r; end if;
  perform pg_advisory_xact_lock(hashtext('vp_claim'));
  if not exists (select 1 from public.vp_staff) then
    insert into public.vp_staff (user_id, email, name, role) values (me, mail, coalesce(nullif(display_name, ''), split_part(mail, '@', 1)), 'owner');
    return 'owner';
  end if;
  if exists (select 1 from public.vp_invites where email = mail) then
    insert into public.vp_staff (user_id, email, name, role)
      select me, mail, coalesce(nullif(i.name, ''), nullif(display_name, ''), split_part(mail, '@', 1)), 'staff' from public.vp_invites i where i.email = mail;
    delete from public.vp_invites where email = mail;
    return 'staff';
  end if;
  return 'denied';
end $$;

alter table public.vp_store enable row level security;
alter table public.vp_staff enable row level security;
alter table public.vp_invites enable row level security;

drop policy if exists vp_store_staff on public.vp_store;
create policy vp_store_staff on public.vp_store for all to authenticated using (public.vp_is_staff()) with check (public.vp_is_staff());

drop policy if exists vp_staff_read on public.vp_staff;
create policy vp_staff_read on public.vp_staff for select to authenticated using (public.vp_is_staff());
drop policy if exists vp_staff_owner on public.vp_staff;
create policy vp_staff_owner on public.vp_staff for delete to authenticated using (public.vp_is_owner() and role <> 'owner');

drop policy if exists vp_invites_owner on public.vp_invites;
create policy vp_invites_owner on public.vp_invites for all to authenticated using (public.vp_is_owner()) with check (public.vp_is_owner());

revoke all on public.vp_store, public.vp_staff, public.vp_invites from anon;
grant select, insert, update, delete on public.vp_store to authenticated;
grant select, delete on public.vp_staff to authenticated;
grant select, insert, delete on public.vp_invites to authenticated;
grant execute on function public.vp_claim(text), public.vp_is_staff(), public.vp_is_owner() to authenticated;
revoke execute on function public.vp_claim(text) from anon;

-- The Discord link: staff may add commands from this site, and read back their status. Nothing else.
grant select, insert on public.nation_commands to authenticated;
drop policy if exists vp_commands_insert on public.nation_commands;
create policy vp_commands_insert on public.nation_commands for insert to authenticated
  with check (public.vp_is_staff() and source = 'vp' and status = 'queued'
    and kind in ('doc.issued', 'doc.revoked', 'nation.update', 'event.created', 'announce', 'role.grant', 'role.remove', 'person.enlisted', 'person.promoted', 'person.separated', 'ping'));
drop policy if exists vp_commands_read on public.nation_commands;
create policy vp_commands_read on public.nation_commands for select to authenticated using (public.vp_is_staff() and source = 'vp');

-- Live updates between open copies of the site.
do $$ begin
  alter publication supabase_realtime add table public.vp_store;
exception when duplicate_object then null; when undefined_object then null; end $$;
