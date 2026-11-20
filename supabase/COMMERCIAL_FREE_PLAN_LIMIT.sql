-- Patinha: limite de 1 divulgação ativa no plano comercial gratuito.
-- Execute no Supabase SQL Editor do projeto Patinha.
-- O Patinha Pro ainda não possui contratação/pagamento ativo; por isso, todas as contas
-- comerciais permanecem no limite gratuito até a implementação da assinatura.

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
  and (
    select count(*)
    from public.business_ads existing_ads
    where existing_ads.user_id = auth.uid()
  ) < 1
);
