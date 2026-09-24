-- Mesmo padrao ja visto e corrigido hoje em
-- 2026_remove_solicitar_papel_lider_antiga.sql: existiam DUAS versoes
-- de inscrever_em_escala() ao mesmo tempo --
--   1) inscrever_em_escala(p_escala_id uuid) -- versao ANTIGA, usa
--      escalas.data (data unica), nao entende escala RECORRENTE (nao
--      recebe qual ocorrencia especifica). Nada no app chama essa
--      versao (confirmado: shift_service.dart::signUp sempre manda os
--      2 parametros).
--   2) inscrever_em_escala(p_escala_id uuid, p_data_ocorrencia date) --
--      versao NOVA e correta, e' a que o app sempre chama.
-- Ter as duas ao mesmo tempo deixa a chamada ambigua/instavel pro
-- PostgREST resolver -- causa raiz de "Nao foi possivel se inscrever
-- no momento" reportado pelo Leo (varias pessoas nao conseguindo se
-- inscrever numa escala recorrente do Awake).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop function if exists public.inscrever_em_escala(uuid);

select 'Versao antiga (1 parametro) de inscrever_em_escala removida.' as status;
