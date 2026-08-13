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

  select count(*), max(id) into v_quantidade, v_profile_id
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
