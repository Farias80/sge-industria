-- =====================================================================
-- SGE — Addendum: ajustes para o Módulo 04 (Qualidade)
-- Rode depois de aplicar schema.sql.
-- =====================================================================

-- Guarda o número do pedido como texto também (além do vínculo pedido_id),
-- pelo mesmo motivo do Módulo 03: garante que nada se perde mesmo que o
-- pedido não seja encontrado no momento de salvar.
alter table registros_qualidade add column if not exists pedido_numero text;

-- Guarda o nome do responsável técnico como texto também (além do vínculo
-- responsavel_id), pois é assim que o app já exibe/compara em vários lugares.
alter table registros_qualidade add column if not exists responsavel_nome text;

-- Campo "Aprovar/Reprovar geral" definido manualmente pelo usuário — é
-- diferente da coluna `status`, que pode ser calculada automaticamente a
-- partir do resultado das OPs quando ninguém força uma aprovação/reprovação.
alter table registros_qualidade add column if not exists aprovacao_geral text;

-- =====================================================================
-- FIM DO ADDENDUM DO MÓDULO 04
-- =====================================================================
