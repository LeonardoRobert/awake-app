-- Tabela nova pra atrelar um material (PDF de aula/mensagem/esboco) a um
-- video do YouTube. Os videos em si NAO ficam salvos no banco (vem
-- sempre ao vivo da API do YouTube, via YoutubeService) -- aqui so
-- guardamos o vinculo video_youtube_id -> material_url, no maximo 1
-- material por video (unique).
create table if not exists public.video_materiais (
  id uuid primary key default gen_random_uuid(),
  video_youtube_id text not null unique,
  material_url text not null,
  nome_arquivo text,
  criado_por uuid references public.profiles(id),
  criado_em timestamptz not null default now()
);

alter table public.video_materiais enable row level security;

-- Qualquer pessoa logada pode ver quais videos tem material (pra
-- mostrar o botao "Visualizar material" em Nossos Conteudos).
drop policy if exists "video_materiais_select" on public.video_materiais;
create policy "video_materiais_select" on public.video_materiais
  for select using (auth.uid() is not null);

-- So admin anexa/substitui/remove material.
drop policy if exists "video_materiais_insert" on public.video_materiais;
create policy "video_materiais_insert" on public.video_materiais
  for insert with check (is_admin());

drop policy if exists "video_materiais_update" on public.video_materiais;
create policy "video_materiais_update" on public.video_materiais
  for update using (is_admin());

drop policy if exists "video_materiais_delete" on public.video_materiais;
create policy "video_materiais_delete" on public.video_materiais
  for delete using (is_admin());

select 'Tabela video_materiais criada.' as status;
