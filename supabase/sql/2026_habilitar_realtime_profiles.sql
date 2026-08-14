-- Habilita o Supabase Realtime na tabela profiles -- por padrao NENHUMA
-- tabela manda evento de Realtime, precisa entrar explicitamente na
-- publication supabase_realtime. Sem isso, profileRealtimeProvider
-- (lib/providers/auth_provider.dart) fica inscrito num canal que nunca
-- recebe nada -- nao quebra nada, so' nunca atualiza sozinho.
--
-- Continua protegido pela MESMA RLS de sempre (profiles_select ja
-- libera profile_id = auth.uid()) -- o Realtime do Supabase respeita
-- RLS nas subscriptions autenticadas, entao ninguem passa a enxergar
-- linha de outra pessoa por causa disso.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

alter publication supabase_realtime add table public.profiles;

select 'Realtime habilitado em profiles.' as status;
