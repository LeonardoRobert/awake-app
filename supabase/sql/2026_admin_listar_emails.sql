-- gestao.html (Usuários) mostra e-mail no modal "Editar perfil" e na
-- lista, mas e-mail vive em auth.users (login), NAO em public.profiles
-- -- por isso nunca aparecia. auth.users so' e' legivel com privilegio
-- elevado, entao expoe via funcao security definer que so' devolve
-- alguma coisa se quem chamou for admin.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

create or replace function public.admin_listar_emails()
returns table(id uuid, email text)
language plpgsql
security definer set search_path = public
as $$
begin
  if not (is_admin() or is_admin_financeiro()) then
    raise exception 'Apenas admin pode listar e-mails.';
  end if;

  return query select au.id, au.email::text from auth.users au;
end;
$$;

select 'admin_listar_emails() criada.' as status;
