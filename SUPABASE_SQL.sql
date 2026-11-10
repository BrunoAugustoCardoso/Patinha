-- Execute no SQL Editor do Supabase para complementar a tabela pets criada anteriormente.
alter table public.pets add column if not exists local_id text;
alter table public.pets add column if not exists app_data jsonb not null default '{}'::jsonb;
create unique index if not exists pets_user_local_id_key on public.pets(user_id, local_id);

-- Confirme que RLS está ativo e que as políticas da tabela pets restringem
-- SELECT/INSERT/UPDATE/DELETE a auth.uid() = user_id.
