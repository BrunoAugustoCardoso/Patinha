# Função de exclusão segura de conta

A exclusão real depende desta Supabase Edge Function. O código do navegador **não** contém nem recebe a chave `service_role`.

## Implantação no projeto Supabase

Projeto: `wbaoicfuejyvjvejphcp`

1. No painel do Supabase, abra **Edge Functions** e crie uma função chamada `delete-account`.
2. Copie o conteúdo de `supabase/functions/delete-account/index.ts` para o editor da função e implante.
3. Em **Edge Function Secrets** (ou Secrets), confirme que existem:
   - `SUPABASE_URL`: URL do projeto.
   - `SUPABASE_ANON_KEY`: chave publicável/anon do projeto.
   - `SUPABASE_SERVICE_ROLE_KEY`: chave secreta de serviço do projeto.
4. A chave `SUPABASE_SERVICE_ROLE_KEY` deve ficar somente nos secrets do Supabase. **Nunca** coloque essa chave no `index.html`, GitHub Pages ou em mensagens.
5. Mantenha a verificação JWT da função ativada.

A função valida o token da sessão, remove os arquivos da pasta do usuário no bucket `fotos-pets`, remove as linhas dele em `public.pets` e então exclui o usuário do Supabase Auth.

## Teste

Use uma conta de teste com pelo menos um pet e uma foto. Confirme que:
- a tela exige a senha atual e a palavra `EXCLUIR`;
- senha incorreta não exclui nada;
- após confirmar, o usuário sai e não consegue mais entrar;
- os registros em `pets` e as fotos daquela conta foram removidos.

Não teste com a conta principal antes de validar com uma conta descartável. A exclusão é permanente.
