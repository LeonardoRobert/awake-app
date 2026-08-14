-- Quando alguem casa (estado_civil vira 'noivo'/'casado'), a trigger
-- trg_calcular_categoria ja muda categoria pra 'one' sozinha. Esse SQL
-- adiciona um segundo trigger que reage a ESSA transicao (AFTER, na
-- mesma coluna estado_civil -- por isso enxerga o categoria ja
-- recalculado, porque o BEFORE trigger roda primeiro) e:
--   1. entra automaticamente em 'homens' ou 'mulheres' (conforme sexo);
--   2. sai do 'awake' (deixa de ser considerado do ministerio de jovens).
--
-- E' um trigger na TABELA (nao em UI nenhuma) -- por isso funciona
-- tanto quando o ADMIN edita o perfil de alguem em gestao.html quanto
-- quando a PROPRIA PESSOA edita o estado civil dela mesma pelo app
-- (editar_perfil_screen.dart -> updateProfileFields()), sem precisar
-- de nenhuma mudanca no codigo do app.
--
-- So dispara na transicao PRA 'one' (nunca reage de novo numa edicao
-- subsequente que mantem 'casado'), pra nao ficar re-inserindo o
-- vinculo ou derrubando um lider de Homens/Mulheres que so corrigiu
-- outro campo. NAO faz o caminho inverso (sair de 'one' nao devolve
-- pro Awake sozinho) -- isso fica por conta de um admin decidir na mao.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.ajustar_ministerios_ao_entrar_one()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.categoria = 'one' and old.categoria is distinct from 'one' then
    if new.sexo = 'masculino' then
      insert into public.profile_ministerios (profile_id, ministerio, papel)
      values (new.id, 'homens', 'membro')
      on conflict (profile_id, ministerio) do nothing;
    elsif new.sexo = 'feminino' then
      insert into public.profile_ministerios (profile_id, ministerio, papel)
      values (new.id, 'mulheres', 'membro')
      on conflict (profile_id, ministerio) do nothing;
    end if;

    delete from public.profile_ministerios
    where profile_id = new.id and ministerio = 'awake';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_ajustar_ministerios_ao_entrar_one on public.profiles;
create trigger trg_ajustar_ministerios_ao_entrar_one
  after update of estado_civil on public.profiles
  for each row execute procedure public.ajustar_ministerios_ao_entrar_one();

select 'Trigger de casamento -> homens/mulheres + sai do Awake criada.' as status;
