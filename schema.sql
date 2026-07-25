-- ============================================================
-- Launch CRM — database schema (run once in Supabase)
-- Supabase Dashboard → SQL Editor → New query → paste → Run
-- ============================================================

-- 1) Workspace state ------------------------------------------------
-- Each row holds one collection (accounts, deals, quotes, …) as JSON.
-- Simple by design for a small team; migrate to normalized tables as you grow.
create table if not exists public.crm_state (
  key        text primary key,
  data       jsonb not null,
  client     text,
  updated_at timestamptz not null default now()
);

alter table public.crm_state enable row level security;

-- Only signed-in team members can read/write workspace data.
create policy "team can read state"   on public.crm_state for select to authenticated using (true);
create policy "team can insert state" on public.crm_state for insert to authenticated with check (true);
create policy "team can update state" on public.crm_state for update to authenticated using (true);

-- 2) Client signatures inbox ---------------------------------------
-- Customers opening a quote link are anonymous; they may ONLY drop a
-- signature here. The app picks it up, applies it, and deletes the row.
create table if not exists public.quote_signatures (
  id          bigint generated always as identity primary key,
  quote_token text  not null,
  signature   jsonb not null,
  created_at  timestamptz not null default now()
);

alter table public.quote_signatures enable row level security;

create policy "anyone can sign"        on public.quote_signatures for insert to anon, authenticated with check (true);
create policy "team can read sigs"     on public.quote_signatures for select to authenticated using (true);
create policy "team can delete sigs"   on public.quote_signatures for delete to authenticated using (true);

-- 3) Form submissions inbox ----------------------------------------
create table if not exists public.form_submissions (
  id         bigint generated always as identity primary key,
  form_token text  not null,
  payload    jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.form_submissions enable row level security;

create policy "anyone can submit"      on public.form_submissions for insert to anon, authenticated with check (true);
create policy "team can read subs"     on public.form_submissions for select to authenticated using (true);
create policy "team can delete subs"   on public.form_submissions for delete to authenticated using (true);

-- 4) Public read functions -----------------------------------------
-- Lets an anonymous visitor with an unguessable share token read ONE
-- quote (with its account name) or ONE form — nothing else.
create or replace function public.get_public_quote(token text)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  q jsonb;
  acct_name text;
begin
  select quote into q
  from crm_state s, jsonb_array_elements(s.data) as quote
  where s.key = 'quotes' and quote->>'shareToken' = token
  limit 1;

  if q is null then return null; end if;

  select a->>'name' into acct_name
  from crm_state s, jsonb_array_elements(s.data) as a
  where s.key = 'accounts' and a->>'id' = q->>'accountId'
  limit 1;

  return q || jsonb_build_object('account', coalesce(acct_name, ''));
end;
$$;

create or replace function public.get_public_form(token text)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  f jsonb;
begin
  select form into f
  from crm_state s, jsonb_array_elements(s.data) as form
  where s.key = 'forms' and form->>'shareToken' = token
    and form->>'status' = 'Active'
  limit 1;

  if f is null then return null; end if;
  return f - 'submissions';
end;
$$;

grant execute on function public.get_public_quote(text) to anon, authenticated;
grant execute on function public.get_public_form(text) to anon, authenticated;

-- 5) Realtime -------------------------------------------------------
-- Lets the app receive teammates' changes and client signatures live.
do $$
begin
  begin
    alter publication supabase_realtime add table public.crm_state;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.quote_signatures;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.form_submissions;
  exception when duplicate_object then null;
  end;
end $$;

-- Done! Next: Authentication → Sign In / Up → disable "Allow new users
-- to sign up" after your team has signed in once (or invite them from
-- Authentication → Users), so only your team can access the CRM.
