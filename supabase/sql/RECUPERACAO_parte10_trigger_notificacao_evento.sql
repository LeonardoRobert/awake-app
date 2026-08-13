-- Buraco achado numa revisao geral pos-incidente: trigger_notificar_
-- novo_evento() (definida em 2026_suprimir_notificacao_teste.sql) e a
-- FUNCAO em si -- ela sobreviveu ao incidente (funcao nao morre com a
-- tabela). Mas o TRIGGER que a conecta em "depois de inserir em
-- eventos" e dono da tabela eventos, e morreu junto quando ela foi
-- dropada na parte 1. Sem isso, criar evento nunca dispara notificacao
-- pra ninguem, em silencio.
--
-- Roda isso independente de ja ter rodado 2026_suprimir_notificacao_
-- teste.sql antes ou nao -- e idempotente (create or replace + drop
-- trigger if exists).
drop trigger if exists trg_notificar_novo_evento on public.eventos;
create trigger trg_notificar_novo_evento
  after insert on public.eventos
  for each row execute function public.trigger_notificar_novo_evento();

select 'Trigger de notificacao de evento novo reconectada.' as status;
