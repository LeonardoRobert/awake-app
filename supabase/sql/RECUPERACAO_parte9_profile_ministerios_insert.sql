-- profile_ministerios nunca teve policy de INSERT (so SELECT/UPDATE) --
-- bug provavelmente anterior ao incidente, nao causado pela
-- reconstrucao (essa tabela sobreviveu intacta, com as mesmas
-- policies de antes). auth_service.dart's signUp() tenta fazer
-- upsert() na propria conta durante o cadastro (pra associar aos
-- ministerios escolhidos) -- sem policy de insert, isso sempre falhou
-- em silencio.
create policy "profile_ministerios_insert" on public.profile_ministerios
  for insert with check (profile_id = auth.uid() or is_admin() or is_admin_financeiro());

select 'Policy de insert em profile_ministerios criada.' as status;
