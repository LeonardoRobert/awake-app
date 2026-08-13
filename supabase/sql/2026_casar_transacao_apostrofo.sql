-- Importar extrato: tentar_casar_transacao() so ignorava acento e
-- maiuscula/minuscula (unaccent(lower(...))) -- nao tratava variacao
-- de apostrofo/aspas (ex: apostrofo reto ' vs apostrofo tipografico ’,
-- comuns em nomes como "Sant'Ana" exportados por banco). Visualmente
-- os dois nomes parecem identicos, mas sao bytes diferentes, e a
-- comparacao exata falhava -- a linha caia como "nao casou" mesmo
-- sendo claramente a mesma pessoa.
--
-- Essa versao tambem ignora QUALQUER caractere de apostrofo/aspas
-- (nao so o reto) e colapsa espacos duplicados, alem de continuar
-- ignorando acento e maiuscula/minuscula como antes. Continua exigindo
-- bater EXATO no resto do nome -- so fica mais tolerante ao que sao
-- diferencas puramente de formatacao, nao de identidade.
--
-- ACHADO SEPARADO (bem mais grave, ja existia antes de qualquer coisa
-- desse arquivo): a funcao original usava "max(id)" pra pegar o id
-- quando so 1 pessoa bate -- so que esse Postgres nao tem agregado
-- max() pra uuid ("function max(uuid) does not exist"). Isso fazia a
-- funcao INTEIRA falhar com erro toda vez que era chamada -- e como o
-- app so olha o "data" do retorno da RPC e ignora "error", esse erro
-- sempre foi engolido em silencio. Ou seja: o casamento automatico
-- NUNCA funcionou, pra nome nenhum, desde sempre -- nao era so esse
-- caso do apostrofo. Trocado por array_agg(id) + [1], que funciona com
-- qualquer tipo (inclusive uuid).

create or replace function public.tentar_casar_transacao(p_nome_pagador text)
returns uuid
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_profile_id uuid;
  v_quantidade int;
  v_normalizado text;
begin
  v_normalizado := regexp_replace(
    regexp_replace(unaccent(lower(trim(p_nome_pagador))), '[''`´‘’]', '', 'g'),
    '\s+', ' ', 'g'
  );

  select count(*), (array_agg(id))[1] into v_quantidade, v_profile_id
  from profiles
  where regexp_replace(
    regexp_replace(unaccent(lower(nome)), '[''`´‘’]', '', 'g'),
    '\s+', ' ', 'g'
  ) = v_normalizado;

  if v_quantidade = 1 then
    return v_profile_id;
  end if;
  return null;
end;
$function$;
