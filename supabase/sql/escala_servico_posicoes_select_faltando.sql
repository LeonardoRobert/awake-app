-- Mesmo buraco de escalas_servico, na tabela filha: escala_servico_
-- posicoes tambem so tinha a restritiva de esconder conta de teste,
-- sem nenhuma permissiva de select -- por isso as posicoes ja
-- existentes (inclusive as recem-criadas pelo seed do catalogo) ficam
-- invisiveis, e a tela de Escala Semanal so mostra "Adicionar posição"
-- vazio.
create policy "escala_servico_posicoes_select" on public.escala_servico_posicoes
  for select using (auth.uid() is not null);
