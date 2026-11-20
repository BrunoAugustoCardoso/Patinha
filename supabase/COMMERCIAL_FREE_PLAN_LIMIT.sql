-- Patinha: limite seguro de 1 divulgação ativa no plano comercial gratuito.
-- Execute no SQL Editor do Supabase do projeto Patinha.
-- O Patinha Pro ainda não possui contratação/pagamento ativo.

-- Mantém a política RLS responsável por validar o proprietário e a aprovação.
drop policy if exists business_ads_insert_approved_owner on public.business_ads;

create policy business_ads_insert_approved_owner
on public.business_ads
for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1
    from public.business_profiles bp
    where bp.user_id = auth.uid()
      and bp.status = 'approved'
  )
);

-- A contagem é feita por uma função SECURITY DEFINER para não sofrer
-- filtragem pela própria política RLS de business_ads.
-- O advisory lock serializa inserções simultâneas do mesmo comerciante.
create or replace function public.enforce_business_ads_free_limit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  active_ads_count integer;
begin
  if auth.uid() is null or new.user_id <> auth.uid() then
    raise exception 'Não autorizado a publicar divulgação para esta conta.';
  end if;

  perform pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text, 0)
  );

  select count(*)
    into active_ads_count
  from public.business_ads
  where user_id = new.user_id;

  if active_ads_count >= 1 then
    raise exception 'Limite do plano gratuito atingido: mantenha apenas 1 divulgação ativa.';
  end if;

  return new;
end;
$$;

revoke all on function public.enforce_business_ads_free_limit() from public;
revoke all on function public.enforce_business_ads_free_limit() from anon;
revoke all on function public.enforce_business_ads_free_limit() from authenticated;

drop trigger if exists enforce_business_ads_free_limit_trigger on public.business_ads;

create trigger enforce_business_ads_free_limit_trigger
before insert on public.business_ads
for each row
execute function public.enforce_business_ads_free_limit();
