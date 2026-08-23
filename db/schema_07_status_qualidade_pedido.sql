-- =====================================================================
-- SGE — Addendum: sinaliza o resultado da Qualidade (Módulo 04) direto no
-- pedido, para que os Módulos 02 (Estamparia) e 03 (Laboratório de Tinta)
-- também vejam se aquele pedido foi aprovado ou reprovado.
-- Rode depois de aplicar schema.sql.
-- =====================================================================

alter table pedidos add column if not exists status_qualidade status_qualidade not null default 'pendente';

-- =====================================================================
-- FIM DO ADDENDUM
-- =====================================================================
