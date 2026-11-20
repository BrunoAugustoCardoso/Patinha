-- Patinha: estrutura segura para os planos comerciais.
-- Execute no SQL Editor do Supabase depois de revisar este arquivo.
-- Nenhuma cobrança ou assinatura é ativada por esta migration.
-- Todos os comerciantes existentes permanecem no plano gratuito.

alter table public.business_profiles
  add column if not exists plan text not null default 'commercial_free';

alter table public.business_profiles
  drop constraint if exists business_profiles_plan_check;

alter table public.business_profiles
  add constraint business_profiles_plan_check
  check (plan in ('commercial_free', 'commercial_pro'));

-- Apenas administradores podem alterar business_profiles pela política
-- business_profiles_admin_update já existente. O comerciante não pode
-- promover a própria conta para Pro.

create or replace function public.enforce_business_ads_plan_limit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  current_plan text;
  active_ads_count integer;
  ads_limit integer;
begin
  if auth.uid() is null or new.user_id <> auth.uid() then
    raise exception 'Não autorizado a publicar divulgação para esta conta.';
  end if;

  perform pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text, 0)
  );

  select bp.plan
    into current_plan
  from public.business_profiles bp
  where bp.user_id = new.user_id
    and bp.status = 'approved';

  if not found then
    raise exception 'A conta comercial precisa estar aprovada para publicar.';
  end if;

  ads_limit := case
    when current_plan = 'commercial_pro' then 10
    else 1
  end;

  select count(*)
    into active_ads_count
  from public.business_ads
  where user_id = new.user_id;

  if active_ads_count >= ads_limit then
    if current_plan = 'commercial_pro' then
      raise exception 'Limite do Patinha Pro atingido: mantenha até 10 divulgações ativas.';
    else
      raise exception 'Limite do plano gratuito atingido: mantenha apenas 1 divulgação ativa.';
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_business_ads_plan_limit() from public;
revoke all on function public.enforce_business_ads_plan_limit() from anon;
revoke all on function public.enforce_business_ads_plan_limit() from authenticated;

drop trigger if exists enforce_business_ads_free_limit_trigger on public.business_ads;
drop trigger if exists enforce_business_ads_plan_limit_trigger on public.business_ads;

create trigger enforce_business_ads_plan_limit_trigger
before insert on public.business_ads
for each row
execute function public.enforce_business_ads_plan_limit();

-- Para conceder o Pro manualmente, somente após autorização administrativa:
-- update public.business_profiles
-- set plan = 'commercial_pro'
-- where user_id = 'UUID_DO_COMERCIANTE';
--
-- Para retornar ao gratuito:
-- update public.business_profiles
-- set plan = 'commercial_free'
-- where user_id = 'UUID_DO_COMERCIANTE';
