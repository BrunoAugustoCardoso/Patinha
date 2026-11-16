import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "https://brunoaugustocardoso.github.io",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Método não permitido." }, 405);

  const authorization = req.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return json({ error: "Sessão não autorizada." }, 401);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return json({ error: "A função não está configurada corretamente." }, 500);
  }

  const token = authorization.slice("Bearer ".length);
  const userClient = createClient(supabaseUrl, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: { user }, error: userError } = await userClient.auth.getUser(token);
  if (userError || !user) return json({ error: "Sessão inválida ou expirada." }, 401);

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // Apaga primeiro as fotos pertencentes exclusivamente ao usuário autenticado.
  const bucket = admin.storage.from("fotos-pets");
  let offset = 0;
  const pageSize = 500;
  while (true) {
    const { data: files, error: listError } = await bucket.list(user.id, {
      limit: pageSize,
      offset,
    });
    if (listError) return json({ error: "Não foi possível localizar as fotos da conta." }, 500);
    if (!files?.length) break;

    const paths = files.map((file) => `${user.id}/${file.name}`);
    for (let i = 0; i < paths.length; i += 100) {
      const { error: removeError } = await bucket.remove(paths.slice(i, i + 100));
      if (removeError) return json({ error: "Não foi possível remover todas as fotos da conta." }, 500);
    }
    if (files.length < pageSize) break;
    offset += files.length;
  }

  const { error: petsError } = await admin.from("pets").delete().eq("user_id", user.id);
  if (petsError) return json({ error: "Não foi possível remover os dados dos pets." }, 500);

  const { error: deleteUserError } = await admin.auth.admin.deleteUser(user.id);
  if (deleteUserError) {
    return json({ error: "Os dados dos pets foram removidos, mas não foi possível excluir o acesso. Entre em contato com o suporte." }, 500);
  }

  return json({ success: true });
});
