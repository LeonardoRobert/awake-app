-- Existiam DUAS versoes de solicitar_papel_lider ao mesmo tempo:
--   1) solicitar_papel_lider(p_codigo text) -- versao ANTIGA, mexe em
--      profiles.papel (sistema de papel unico global, de antes de
--      existir profile_ministerios). NINGUEM no app hoje confia mais
--      em profiles.papel='lider' pra checar lideranca -- is_lider_
--      ministerio()/is_lider_de_algum_ministerio() olham
--      profile_ministerios.papel. Chamar essa versao "funciona" sem
--      erro, mas NAO promove a pessoa a lider de verdade em lugar
--      nenhum que o app realmente confere.
--   2) solicitar_papel_lider(p_codigo text, p_ministerio text) --
--      versao NOVA e correta, grava em profile_ministerios.
-- Ter as duas ao mesmo tempo e' ambiguo pro PostgREST resolver qual
-- chamar. Apaga a antiga, so fica a de verdade.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop function if exists public.solicitar_papel_lider(text);

select 'Versao antiga (1 parametro) de solicitar_papel_lider removida.' as status;
