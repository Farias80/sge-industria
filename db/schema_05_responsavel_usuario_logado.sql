-- =====================================================================
-- SGE — Addendum: Módulo 04 agora usa o usuário logado como responsável
-- técnico, em vez de uma lista de responsáveis cadastrada manualmente.
-- Rode depois de aplicar schema.sql e schema_04_ajustes_modulo04.sql.
-- =====================================================================

-- Vínculo direto com quem estava logado ao salvar/editar o cadastro
alter table registros_qualidade add column if not exists responsavel_usuario_id uuid references perfis(id);

-- Os campos abaixo continuam existindo e não são obrigatórios remover:
--   responsavel_id       -> não é mais usado pelo app (ligava à tabela
--                            responsaveis_qualidade, que também não é mais usada)
--   responsaveis_qualidade -> tabela antiga, pode ficar vazia/sem uso
-- Nada aqui apaga dados existentes; é só uma coluna nova.

-- =====================================================================
-- FIM DO ADDENDUM
-- =====================================================================
