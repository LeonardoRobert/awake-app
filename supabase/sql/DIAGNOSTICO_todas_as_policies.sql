-- NAO E' um SQL de correcao -- e' um diagnostico pra rodar de vez em
-- quando (ex: depois de uma sessao grande no SQL Editor, ou se algo
-- comecar a dar "violates row-level security policy" do nada) e colar
-- o resultado. Lista TODAS as policies de TODAS as tabelas de uma vez
-- so, pra eu comparar com o que deveria existir sem precisar pedir
-- tabela por tabela.
select
  tablename,
  policyname,
  cmd,
  permissive,
  qual,
  with_check
from pg_policies
where schemaname = 'public'
order by tablename, cmd, policyname;
