-- Junta os papeis 'admin' e 'admin_financeiro' num so. Motivo: os dois
-- ja tinham as mesmas permissoes de banco (is_admin() cobre ambos), e
-- a tela de Financeiro virou so pagamento de evento ingressado (bem
-- mais simples que o lancamento geral de antes) -- nao faz mais
-- sentido manter a distincao. O app (profile_model.dart) ja trata
-- 'admin_financeiro' como admin mesmo sem essa migracao, mas rodar
-- isso deixa o banco condizente e evita confusao ao criar
-- conta/promover gente pelo Table Editor do Supabase dai pra frente.
update public.profiles set papel = 'admin' where papel = 'admin_financeiro';

select 'Perfis admin_financeiro migrados para admin.' as status;
