-- Quando alguem "descasa" (estado_civil sai de 'noivo'/'casado' pra
-- qualquer outro valor -- solteiro, namorando, outro etc.), o campo
-- grupo_casais (Discipulado de Casais) fica parado com o grupo antigo,
-- porque nada limpava ele sozinho. Esse trigger zera grupo_casais
-- nessa transicao.
--
-- Continua igual ao ministerios de servico Homens/Mulheres (ver
-- 2026_casamento_ajusta_ministerios.sql) -- so entra sozinho ao casar,
-- NAO sai sozinho ao descasar (decisao deliberada do Leo: "continua no
-- homem ou mulher"). So o grupo_casais mesmo que zera.
--
-- Trigger de tabela, nao de tela -- funciona tanto quando o admin edita
-- em gestao.html quanto quando a propria pessoa edita o proprio perfil
-- pelo app.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.limpar_grupo_casais_ao_sair_de_casado()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if old.estado_civil in ('noivo', 'casado')
     and new.estado_civil is distinct from 'casado'
     and new.estado_civil is distinct from 'noivo'
  then
    new.grupo_casais := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_limpar_grupo_casais_ao_sair_de_casado on public.profiles;
create trigger trg_limpar_grupo_casais_ao_sair_de_casado
  before update of estado_civil on public.profiles
  for each row execute procedure public.limpar_grupo_casais_ao_sair_de_casado();

select 'Trigger de limpar grupo_casais ao descasar criada.' as status;
