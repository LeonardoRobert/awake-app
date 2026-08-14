-- O cron "sincronizar-pagbank" estava active=true, chamando a Edge
-- Function pagbank-sync de verdade a cada 15 min -- mas essa automacao
-- e' pausada de proposito (ver CLAUDE.md). Desativa sem apagar a
-- definicao do job (assim, se um dia a automacao for retomada de
-- proposito, e' so' rodar o mesmo alter_job com active => true, sem
-- precisar redigitar o schedule/comando do zero).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

select cron.alter_job(
  (select jobid from cron.job where jobname = 'sincronizar-pagbank'),
  active => false
);

select jobname, schedule, active from cron.job where jobname = 'sincronizar-pagbank';
