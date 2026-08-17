-- esta_na_escala_primeira_vez() nao tinha NENHUM filtro de data -- uma
-- vez inscrito(a) em "Recepcao/Primeira Vez", o formulario ficava
-- visivel pra sempre no perfil (ate anos depois), a nao ser que a
-- pessoa cancelasse a inscricao. Agora so fica disponivel no PROPRIO
-- dia da escala (24h inteiras daquele dia, ex: escalado(a) dia 16 ->
-- disponivel ate 23h59 do dia 16, some no dia 17) -- EXCETO pra lider
-- do Awake, que fica sempre disponivel (pode receber visitante
-- mesmo fora do proprio turno de recepcao).
--
-- Usa "at time zone 'America/Sao_Paulo'" pra pegar o dia de HOJE em
-- Brasilia, nao o dia UTC do servidor -- sem isso o formulario
-- sumiria/apareceria umas horas errado perto da meia-noite (mesma
-- categoria de bug ja corrigida em data_inicio dos eventos hoje).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.esta_na_escala_primeira_vez()
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select
    is_lider_ministerio('awake')
    or exists (
      select 1 from public.inscricoes i
      join public.escalas e on e.id = i.escala_id
      where i.user_id = auth.uid()
        and e.area_id = '7678a09a-1141-4fcb-833d-0736c91038f0'
        and i.cancelado_em is null
        and i.data_ocorrencia = (now() at time zone 'America/Sao_Paulo')::date
    );
$function$;

select 'esta_na_escala_primeira_vez() agora so libera no dia da escala.' as status;
