-- =====================================================================
-- SGE — Addendum: ajustes para o Módulo 03 (Laboratório de Tinta)
-- Rode depois de aplicar schema.sql e schema_02_trigger_novo_usuario.sql.
-- =====================================================================

-- O vínculo com o pedido do Módulo 02 ainda é só texto (o "número do pedido"),
-- porque o Módulo 02 ainda não foi migrado para o Supabase — ele continua
-- salvando os pedidos no armazenamento local do navegador por enquanto.
-- Quando o Módulo 02 migrar, isso pode virar uma FK de verdade (pedido_id).
alter table receitas add column if not exists pedido_numero text;

-- Campo usado pelo Módulo 01 (Artes) para lembrar de qual estampa veio o pantone
alter table receitas add column if not exists estampa_origem text;

-- Campo auxiliar (reservado para uso futuro) nos itens da receita
alter table receita_itens add column if not exists tipo text;

-- A regra de negócio original travava quantidade > 0, mas o app permite
-- adicionar uma matéria-prima/coloração momentaneamente sem quantidade
-- preenchida (fica 0 até o usuário digitar). Relaxamos para >= 0.
alter table receita_itens drop constraint if exists receita_itens_quantidade_check;
alter table receita_itens add constraint receita_itens_quantidade_check check (quantidade >= 0);

-- =====================================================================
-- FIM DO ADDENDUM DO MÓDULO 03
-- =====================================================================
