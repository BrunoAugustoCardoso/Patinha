-- Patinha: acesso Tutor / Comerciante / Administrador
-- Execute no SQL Editor do Supabase antes de testar a nova versão.
create table if not exists public.business_profiles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 business_name text not null, category text not null, phone text not null,
 city text not null, description text,
 status text not null default 'pending' check (status in ('pending','approved','rejected')),
 created_at timestamptz not null default now()
);
create table if not exists public.business_ads (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 title text not null check (char_length(title) between 1 and 100),
 category text not null check (category in ('Produto','Serviço','Promoção','Evento')),
 description text not null check (char_length(description) between 1 and 1000),
 created_at timestamptz not null default now()
);
alter table public.business_profiles enable row level security;
alter table public.business_ads enable row level security;
grant select, insert, update on public.business_profiles to authenticated;
grant select, insert, delete on public.business_ads to authenticated;
drop policy if exists "business_profiles_select_owner_or_admin" on public.business_profiles;
create policy "business_profiles_select_owner_or_admin" on public.business_profiles for select to authenticated
using (user_id=auth.uid() or (auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "business_profiles_insert_pending_owner" on public.business_profiles;
create policy "business_profiles_insert_pending_owner" on public.business_profiles for insert to authenticated
with check (user_id=auth.uid() and status='pending');
drop policy if exists "business_profiles_admin_update" on public.business_profiles;
create policy "business_profiles_admin_update" on public.business_profiles for update to authenticated
using ((auth.jwt()->'app_metadata'->>'role')='admin')
with check ((auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "business_ads_select_owner_or_admin" on public.business_ads;
create policy "business_ads_select_owner_or_admin" on public.business_ads for select to authenticated
using ((user_id=auth.uid() and exists(select 1 from public.business_profiles bp where bp.user_id=auth.uid() and bp.status='approved'))
 or (auth.jwt()->'app_metadata'->>'role')='admin');
drop policy if exists "business_ads_insert_approved_owner" on public.business_ads;
create policy "business_ads_insert_approved_owner" on public.business_ads for insert to authenticated
with check (user_id=auth.uid() and exists(select 1 from public.business_profiles bp where bp.user_id=auth.uid() and bp.status='approved'));
drop policy if exists "business_ads_delete_approved_owner" on public.business_ads;
create policy "business_ads_delete_approved_owner" on public.business_ads for delete to authenticated
using (user_id=auth.uid() and exists(select 1 from public.business_profiles bp where bp.user_id=auth.uid() and bp.status='approved'));
-- Depois que sua conta existir em Authentication > Users, defina o administrador:
-- update auth.users set raw_app_meta_data=coalesce(raw_app_meta_data,'{}'::jsonb)||'{"role":"admin"}'::jsonb
-- where email='SEU_EMAIL_ADMIN_AQUI';
-- Saia e entre novamente na conta administradora para renovar o token.
