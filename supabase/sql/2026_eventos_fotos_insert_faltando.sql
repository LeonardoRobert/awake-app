-- Bucket eventos-fotos so tinha policy de SELECT -- nunca teve INSERT
-- (nem UPDATE/DELETE), diferente de outdoors/materiais-conteudo (que
-- ja tinham os 4). Isso bloqueava QUALQUER upload de capa de evento,
-- admin incluido -- uploadFotoEvento() sempre falhava com erro de
-- Storage.
--
-- Mesmo padrao ja usado em outdoors_escrita_autenticado /
-- materiais_escrita_autenticado -- qualquer autenticado pode escrever
-- (a proteção de verdade é a RLS da tabela eventos em si, que já exige
-- ser líder do ministério ou admin pra criar/editar o evento ao qual a
-- foto pertence).
--
-- Cole no Supabase Dashboard -> SQL Editor e rode manualmente.

drop policy if exists "eventos_fotos_insert" on storage.objects;
create policy "eventos_fotos_insert" on storage.objects
  for insert with check (bucket_id = 'eventos-fotos' and auth.role() = 'authenticated');

drop policy if exists "eventos_fotos_update" on storage.objects;
create policy "eventos_fotos_update" on storage.objects
  for update using (bucket_id = 'eventos-fotos' and auth.role() = 'authenticated');

drop policy if exists "eventos_fotos_delete" on storage.objects;
create policy "eventos_fotos_delete" on storage.objects
  for delete using (bucket_id = 'eventos-fotos' and auth.role() = 'authenticated');

select 'INSERT/UPDATE/DELETE restaurados no bucket eventos-fotos.' as status;
