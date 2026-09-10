-- solicitar_papel_lider() tinha uma lista fixa de ministerios validos
-- que NUNCA incluiu 'intercessao' (apesar de ja ser oferecido como
-- opcao de lideranca no cadastro, signup_screen.dart) e nao tinha como
-- incluir os grupos de casais dinamicos ('casais_henrique_patricia',
-- etc -- ver 2026_grupos_casais_ministerios.sql), que nem existiam
-- quando essa funcao foi escrita. Quem tentasse virar lider de um
-- desses recebia "Ministerio invalido" e a conta ficava so' como
-- membro.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.solicitar_papel_lider(p_codigo text, p_ministerio text default 'awake'::text)
returns void
language plpgsql security definer set search_path = 'public'
as $func$
declare
  v_hash text;
begin
  if p_ministerio not in (
    'awake', 'homens', 'mulheres', 'criancas',
    'coral', 'danca', 'diaconos', 'louvor', 'midia', 'multimidia', 'teatro', 'intercessao'
  ) and p_ministerio not like 'casais_%' then
    raise exception 'Ministerio invalido: %', p_ministerio;
  end if;

  select codigo_hash into v_hash from public.lider_config limit 1;
  if v_hash is null or extensions.crypt(p_codigo, v_hash) <> v_hash then
    raise exception 'Codigo de lider invalido';
  end if;

  insert into public.profile_ministerios (profile_id, ministerio, papel)
  values (auth.uid(), p_ministerio, 'lider')
  on conflict (profile_id, ministerio) do update set papel = 'lider';
end;
$func$;

select 'solicitar_papel_lider corrigida: aceita intercessao e casais_*.' as status;
