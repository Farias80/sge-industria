-- =====================================================================
-- SGE — Addendum: corrige "stack depth limit exceeded" causado por
-- recursão nas políticas de RLS (eh_admin() e tem_permissao_setor()
-- consultavam `perfis`/`permissoes_setor`, que por sua vez chamam essas
-- mesmas funções de novo dentro da própria política de segurança).
--
-- A correção é marcar essas funções como SECURITY DEFINER: elas passam a
-- rodar com privilégio de quem as criou (não do usuário logado), então as
-- consultas internas não disparam de novo a checagem de RLS — quebrando o
-- loop. Isso é seguro aqui porque as funções só fazem leituras simples e
-- não recebem parâmetros que possam ser usados para vazar dados de outros
-- usuários.
--
-- Rode isto no SQL Editor do Supabase. É seguro rodar mais de uma vez.
-- =====================================================================

create or replace function eh_admin()
returns boolean
language sql stable security definer
set search_path = public
as $$
  select exists (
    select 1 from perfis p
    where p.id = auth.uid() and p.papel = 'admin' and p.ativo = true
  );
$$;

create or replace function tem_permissao_setor(p_setor setor_sistema)
returns boolean
language sql stable security definer
set search_path = public
as $$
  select
    eh_admin()
    or exists (
      select 1 from permissoes_setor ps
      join perfis p on p.id = ps.usuario_id
      where ps.usuario_id = auth.uid()
        and ps.setor = p_setor
        and ps.pode_editar = true
        and p.ativo = true
    );
$$;

-- =====================================================================
-- FIM DO ADDENDUM
-- =====================================================================
