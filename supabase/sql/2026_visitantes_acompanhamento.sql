-- Acompanhamento de visitantes -- nova aba "Visitantes" no gestao.html.
-- Colunas novas em visitantes_primeira_vez pra registrar quem esta
-- acompanhando cada visitante, se ja retornou (1a e 2a vez) e se virou
-- membro. acompanhado_por referencia profiles (autocomplete de
-- usuario real, nao texto livre).
--
-- Nao precisa de policy nova: visitantes_pv_update ja libera is_admin()
-- (gestao.html so deixa admin/admin_financeiro entrar de qualquer
-- jeito) -- RLS e' por LINHA, nao por coluna, entao ja cobre essas
-- colunas novas tambem.
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

alter table public.visitantes_primeira_vez
  add column if not exists acompanhado_por uuid references public.profiles(id) on delete set null,
  add column if not exists primeiro_retorno date,
  add column if not exists segundo_retorno date,
  add column if not exists virou_membro boolean not null default false;

select 'Colunas de acompanhamento adicionadas em visitantes_primeira_vez.' as status;
