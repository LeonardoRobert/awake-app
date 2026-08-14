-- Cria os 2 buckets novos (outdoors, materiais-conteudo) direto via SQL,
-- sem precisar passar pela tela de Storage do Dashboard -- nomes tem
-- que bater exatamente com o que o app chama (ver
-- lib/services/outdoor_service.dart e lib/services/video_material_service.dart).
insert into storage.buckets (id, name, public)
values ('outdoors', 'outdoors', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('materiais-conteudo', 'materiais-conteudo', true)
on conflict (id) do nothing;

-- Leitura publica (banner e material precisam abrir sem login).
drop policy if exists "outdoors_leitura_publica" on storage.objects;
create policy "outdoors_leitura_publica" on storage.objects
  for select using (bucket_id = 'outdoors');

drop policy if exists "materiais_leitura_publica" on storage.objects;
create policy "materiais_leitura_publica" on storage.objects
  for select using (bucket_id = 'materiais-conteudo');

-- Escrita liberada pra qualquer autenticado -- quem garante de verdade
-- que so Admin cria outdoor/anexa material e a RLS das TABELAS
-- (outdoors_insert/video_materiais_insert exigem is_admin()); mesmo que
-- alguem tentasse subir um arquivo aqui sem ser admin, sem conseguir
-- criar a linha correspondente o arquivo fica orfao, nao aparece em
-- lugar nenhum do app.
drop policy if exists "outdoors_escrita_autenticado" on storage.objects;
create policy "outdoors_escrita_autenticado" on storage.objects
  for insert with check (bucket_id = 'outdoors' and auth.role() = 'authenticated');

drop policy if exists "materiais_escrita_autenticado" on storage.objects;
create policy "materiais_escrita_autenticado" on storage.objects
  for insert with check (bucket_id = 'materiais-conteudo' and auth.role() = 'authenticated');

-- Update (upsert de imagem/PDF ao editar outdoor ou substituir material).
drop policy if exists "outdoors_update_autenticado" on storage.objects;
create policy "outdoors_update_autenticado" on storage.objects
  for update using (bucket_id = 'outdoors' and auth.role() = 'authenticated');

drop policy if exists "materiais_update_autenticado" on storage.objects;
create policy "materiais_update_autenticado" on storage.objects
  for update using (bucket_id = 'materiais-conteudo' and auth.role() = 'authenticated');

-- Delete (apagar outdoor / remover material).
drop policy if exists "outdoors_delete_autenticado" on storage.objects;
create policy "outdoors_delete_autenticado" on storage.objects
  for delete using (bucket_id = 'outdoors' and auth.role() = 'authenticated');

drop policy if exists "materiais_delete_autenticado" on storage.objects;
create policy "materiais_delete_autenticado" on storage.objects
  for delete using (bucket_id = 'materiais-conteudo' and auth.role() = 'authenticated');

select 'Buckets outdoors e materiais-conteudo criados com policies.' as status;
