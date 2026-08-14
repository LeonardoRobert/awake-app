// Edge Function "admin-apagar-usuario" -- apaga a conta de QUALQUER
// usuario, mas so se quem chama for admin. Diferente da
// "apagar-conta" (self-service, so apaga a propria), essa recebe o id
// de quem vai ser apagado no corpo da requisicao -- por isso o check
// de permissao aqui e critico: decodifica o token de quem chamou,
// confere que e admin (via tabela profiles, com o client service
// role, pra nao depender de RLS), e SO ENTAO apaga.
//
// Deploy manual, igual a apagar-conta:
//   supabase functions deploy admin-apagar-usuario

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

    const { profileId } = await req.json();
    if (!profileId || typeof profileId !== 'string') {
      return new Response(JSON.stringify({ error: 'profileId é obrigatório.' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Cliente com o token de quem chamou -- so pra descobrir QUEM e.
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

    // Service role pra tudo dali pra frente -- checar o papel de quem
    // chamou e apagar de auth.users precisam bypassar RLS.
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: perfilQuemChamou, error: erroPerfil } = await supabaseAdmin
      .from('profiles')
      .select('papel')
      .eq('id', user.id)
      .single();

    const ehAdmin = perfilQuemChamou?.papel === 'admin' || perfilQuemChamou?.papel === 'admin_financeiro';
    if (erroPerfil || !ehAdmin) {
      return new Response(JSON.stringify({ error: 'Apenas admin pode apagar a conta de outra pessoa.' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: erroExclusao } = await supabaseAdmin.auth.admin.deleteUser(profileId);
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
