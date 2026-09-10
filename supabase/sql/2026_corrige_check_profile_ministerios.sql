-- Corrige profile_ministerios_ministerio_check pra 2 problemas achados
-- ao rodar 2026_grupos_casais_ministerios.sql:
--
-- 1) A constraint era uma lista FIXA de valores -- nao tinha como um
--    grupo de casais dinamico ('casais_henrique_patricia') passar por
--    ela. Troca pra aceitar tambem qualquer coisa comecando com
--    'casais_' (mesma convencao usada em profile_ministerios/
--    ocasioes_ministerio/checkin_em_massa_ministerio).
-- 2) 'intercessao' NUNCA esteve nessa lista (bug pre-existente, achado
--    de bandeja) -- mas ja e' usado em varios lugares do app (cadastro
--    em signup_screen.dart, checkin_ministerio_screen.dart, etc). Sem
--    isso, ninguem conseguiria virar membro/lider de Intercessao via
--    profile_ministerios. Adicionado na lista.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

alter table public.profile_ministerios
  drop constraint if exists profile_ministerios_ministerio_check;

alter table public.profile_ministerios
  add constraint profile_ministerios_ministerio_check
  check (
    ministerio = any (array[
      'awake', 'homens', 'mulheres', 'criancas', 'danca', 'diaconos',
      'louvor', 'midia', 'multimidia', 'teatro', 'coral', 'intercessao'
    ])
    or ministerio like 'casais_%'
  );

-- Agora sim, o backfill de 2026_grupos_casais_ministerios.sql pode
-- rodar sem erro. Se voce ja rodou aquele arquivo antes e ele parou no
-- meio (no erro da constraint), rode ele de novo depois deste -- os
-- "create table if not exists"/"on conflict do nothing" fazem ele ser
-- seguro de rodar de novo.

select 'constraint profile_ministerios_ministerio_check corrigida.' as status;
