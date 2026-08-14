// Edge Function "apagar-conta" -- apaga a PROPRIA conta de quem chama,
// pra sempre (hard delete). So essa funcao tem a service role key (o
// app Flutter nunca tem essa chave, so o token normal da pessoa
// logada) -- e a service role e a unica forma de apagar uma linha de
// auth.users.
//
// Seguranca: o id de quem vai ser apagado NUNCA vem do corpo da
// requisicao -- vem exclusivamente de decodificar o token de quem
// chamou (auth.getUser() com o client "anon + Authorization"). Ou
// seja, ninguem consegue apagar a conta de outra pessoa por aqui,
// so a propria.
//
// Depois que profiles/auth.users e todas as tabelas que referenciam
// profiles(id) ganharam ON DELETE CASCADE/SET NULL certo (ver
// supabase/sql/2026_fix_fk_delete_perfil.sql), um unico
// admin.deleteUser ja limpa tudo em cascata sozinho -- nao precisa
// apagar tabela por tabela aqui.
//
// Deploy (nao esta versionado automaticamente, precisa subir manual):
//   supabase functions deploy apagar-conta
// Ou colar direto no editor de Edge Functions do Dashboard.
// Nao precisa configurar SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY como
// secret -- toda Edge Function do Supabase ja recebe essas duas
// automaticamente no ambiente.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Sem token de autenticação.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Cliente com o token de quem chamou -- so pra descobrir QUEM e,
    // nunca usado pra apagar nada.
    const supabaseUsuario = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error: erroUsuario } = await supabaseUsuario.auth.getUser();
    if (erroUsuario || !user) {
      return new Response(JSON.stringify({ error: 'Sessão inválida.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Cliente com a service role -- so esse tem permissao de apagar
    // usuario de auth.users.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { error: erroExclusao } = await supabaseAdmin.auth.admin.deleteUser(user.id);
    if (erroExclusao) {
      return new Response(JSON.stringify({ error: erroExclusao.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
