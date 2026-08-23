-- =====================================================================
-- SGE — Addendum: Lixeira (exclusão reversível / soft delete)
-- Em vez de apagar de vez, "excluir" passa a marcar o registro como
-- excluído (guardando quando e por quem). Ele some das telas normais,
-- mas pode ser restaurado na tela de Lixeira.
-- Rode depois de aplicar schema.sql.
-- =====================================================================

alter table fichas add column if not exists deletado_em timestamptz;
alter table fichas add column if not exists deletado_por uuid references perfis(id);

alter table pedidos add column if not exists deletado_em timestamptz;
alter table pedidos add column if not exists deletado_por uuid references perfis(id);

alter table fornecedores add column if not exists deletado_em timestamptz;
alter table fornecedores add column if not exists deletado_por uuid references perfis(id);

alter table produtos add column if not exists deletado_em timestamptz;
alter table produtos add column if not exists deletado_por uuid references perfis(id);

alter table receitas add column if not exists deletado_em timestamptz;
alter table receitas add column if not exists deletado_por uuid references perfis(id);

alter table registros_qualidade add column if not exists deletado_em timestamptz;
alter table registros_qualidade add column if not exists deletado_por uuid references perfis(id);

-- Índices para a tela de Lixeira listar rápido "o que está excluído"
create index if not exists idx_fichas_deletado on fichas(deletado_em) where deletado_em is not null;
create index if not exists idx_pedidos_deletado on pedidos(deletado_em) where deletado_em is not null;
create index if not exists idx_fornecedores_deletado on fornecedores(deletado_em) where deletado_em is not null;
create index if not exists idx_produtos_deletado on produtos(deletado_em) where deletado_em is not null;
create index if not exists idx_receitas_deletado on receitas(deletado_em) where deletado_em is not null;
create index if not exists idx_registros_qualidade_deletado on registros_qualidade(deletado_em) where deletado_em is not null;

-- =====================================================================
-- FIM DO ADDENDUM
-- =====================================================================
