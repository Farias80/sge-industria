-- =====================================================================
-- SGE — Schema completo para Supabase (Postgres)
-- Projeto: uqxyogatphxpwszyryac
-- Rode este arquivo inteiro em: Supabase → SQL Editor → New query → Run
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0) EXTENSÕES
-- ---------------------------------------------------------------------
create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- 1) TIPOS (ENUMs)
-- ---------------------------------------------------------------------
do $$ begin
  create type papel_usuario as enum ('admin', 'usuario');
exception when duplicate_object then null; end $$;

do $$ begin
  create type setor_sistema as enum ('arte', 'estamparia', 'laboratorio', 'qualidade');
exception when duplicate_object then null; end $$;

do $$ begin
  create type status_pedido as enum ('pendente', 'concluida');
exception when duplicate_object then null; end $$;

do $$ begin
  create type status_qualidade as enum ('aprovado', 'reprovado', 'pendente');
exception when duplicate_object then null; end $$;

do $$ begin
  create type categoria_item_receita as enum ('materia_prima', 'coloracao');
exception when duplicate_object then null; end $$;

do $$ begin
  create type acao_auditoria as enum ('criar', 'editar', 'excluir');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 2) USUÁRIOS E PERMISSÕES
-- ---------------------------------------------------------------------

-- Perfil de cada usuário autenticado (1 linha por usuário do Supabase Auth)
create table if not exists perfis (
  id            uuid primary key references auth.users(id) on delete cascade,
  nome          text not null,
  papel         papel_usuario not null default 'usuario',
  ativo         boolean not null default true,
  criado_em     timestamptz not null default now()
);
comment on table perfis is 'Um perfil por usuário logado. Administrador = acesso total. Usuário = leitura + impressão, e edição apenas onde liberado em permissoes_setor.';

-- Liberação de edição por setor (só o Administrador insere/edita esta tabela)
create table if not exists permissoes_setor (
  id            uuid primary key default gen_random_uuid(),
  usuario_id    uuid not null references perfis(id) on delete cascade,
  setor         setor_sistema not null,
  pode_editar   boolean not null default false,
  liberado_por  uuid references perfis(id),
  liberado_em   timestamptz not null default now(),
  unique (usuario_id, setor)
);
comment on table permissoes_setor is 'Controla, por setor (arte/estamparia/laboratorio/qualidade), se um usuário comum pode editar/excluir. Administrador sempre pode, independente desta tabela.';

-- Função auxiliar: o usuário atual é admin?
create or replace function eh_admin()
returns boolean
language sql stable
as $$
  select exists (
    select 1 from perfis p
    where p.id = auth.uid() and p.papel = 'admin' and p.ativo = true
  );
$$;

-- Função auxiliar: o usuário atual pode editar/excluir no setor informado?
create or replace function tem_permissao_setor(p_setor setor_sistema)
returns boolean
language sql stable
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

-- ---------------------------------------------------------------------
-- 3) MÓDULO 01 · ARTES (fichas técnicas / pantones)
-- ---------------------------------------------------------------------
create table if not exists fichas (
  id              bigint generated always as identity primary key,
  referencia      text not null unique,
  dados           jsonb not null default '{}'::jsonb,  -- estampas, tagless, imagens (compactadas), observações
  criado_por      uuid references perfis(id),
  atualizado_por  uuid references perfis(id),
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

-- Pantones extraídos da ficha, normalizados para consulta rápida pelo Módulo 03
create table if not exists ficha_pantones (
  id          bigint generated always as identity primary key,
  ficha_id    bigint not null references fichas(id) on delete cascade,
  grupo       text,          -- ex: nome da estampa ou 'tagless'
  tipo        text,          -- sequência automática (ex: "01", "02"...)
  pantone     text not null,
  ordem       int default 0
);
create index if not exists idx_ficha_pantones_ficha on ficha_pantones(ficha_id);

-- ---------------------------------------------------------------------
-- 4) MÓDULO 02 · ESTAMPARIA (pedidos / ordens de produção)
-- ---------------------------------------------------------------------
create table if not exists pedidos (
  id              bigint generated always as identity primary key,
  numero          text not null unique,
  referencia      text,
  ficha_id        bigint references fichas(id),
  status          status_pedido not null default 'pendente',
  observacoes     text,
  criado_por      uuid references perfis(id),
  atualizado_por  uuid references perfis(id),
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);

create table if not exists ordens_producao (
  id          bigint generated always as identity primary key,
  pedido_id   bigint not null references pedidos(id) on delete cascade,
  numero      text,
  quantidade  numeric(12,2) not null default 0 check (quantidade >= 0),
  ordem       int default 0
);
create index if not exists idx_ordens_pedido on ordens_producao(pedido_id);

-- ---------------------------------------------------------------------
-- 5) MÓDULO 03 · LABORATÓRIO DE TINTA (fornecedores, estoque, receitas)
-- ---------------------------------------------------------------------
create table if not exists fornecedores (
  id          bigint generated always as identity primary key,
  nome        text not null,
  cidade      text,
  estado      text,
  contato     text,
  email       text,
  criado_por  uuid references perfis(id),
  criado_em   timestamptz not null default now()
);

-- Estoque de matéria-prima (lotes recebidos)
create table if not exists produtos (
  id                bigint generated always as identity primary key,
  fornecedor_id     bigint references fornecedores(id),
  nome              text not null,
  lote              text not null,
  data_fabricacao   date,
  quantidade        numeric(12,2) not null default 0 check (quantidade >= 0),
  criado_por        uuid references perfis(id),
  data_cadastro     timestamptz not null default now()
);
create index if not exists idx_produtos_nome on produtos(nome);

create table if not exists receitas (
  id              bigint generated always as identity primary key,
  pedido_id       bigint references pedidos(id),   -- nulo = receita avulsa
  pantone         text not null,
  referencia      text not null,
  tipo            text,
  amostra_pedido  text check (amostra_pedido in ('Amostra','Pedido')),
  op              text,
  criado_por      uuid references perfis(id),
  atualizado_por  uuid references perfis(id),
  criado_em       timestamptz not null default now(),
  atualizado_em   timestamptz not null default now()
);
create index if not exists idx_receitas_pedido on receitas(pedido_id);

-- Itens da receita (matéria-prima e coloração), SEMPRE vinculados a um produto do estoque.
-- A FK abaixo é a regra de negócio pedida: sem produto cadastrado, não é possível salvar o item.
create table if not exists receita_itens (
  id            bigint generated always as identity primary key,
  receita_id    bigint not null references receitas(id) on delete cascade,
  categoria     categoria_item_receita not null,
  produto_id    bigint not null references produtos(id),   -- <- trava a regra: produto tem que existir
  fornecedor_id bigint references fornecedores(id),
  lote          text,
  data_fabricacao date,
  quantidade    numeric(12,2) not null check (quantidade > 0),
  ordem         int default 0
);
create index if not exists idx_receita_itens_receita on receita_itens(receita_id);
create index if not exists idx_receita_itens_produto on receita_itens(produto_id);

-- ---------------------------------------------------------------------
-- 6) MÓDULO 04 · QUALIDADE (testes e durabilidade)
-- ---------------------------------------------------------------------
create table if not exists responsaveis_qualidade (
  id      bigint generated always as identity primary key,
  nome    text not null
);

create table if not exists registros_qualidade (
  id                bigint generated always as identity primary key,
  referencia        text,
  pedido_id         bigint references pedidos(id),
  solicitante       text,
  responsavel_id    bigint references responsaveis_qualidade(id),
  status            status_qualidade not null default 'pendente',
  ops               jsonb default '[]'::jsonb,     -- espelho das OPs testadas
  testes            jsonb default '{}'::jsonb,     -- fricção, lavagem, aplicações
  imagens           jsonb default '{}'::jsonb,     -- referências às imagens (ver seção 8 sobre Storage)
  observacoes       text,
  criado_por        uuid references perfis(id),
  atualizado_por    uuid references perfis(id),
  criado_em         timestamptz not null default now(),
  atualizado_em     timestamptz not null default now()
);
create index if not exists idx_registros_qualidade_pedido on registros_qualidade(pedido_id);

-- ---------------------------------------------------------------------
-- 7) AUDITORIA (rastreio de edições e exclusões — suporta as confirmações do app)
-- ---------------------------------------------------------------------
create table if not exists auditoria (
  id            bigint generated always as identity primary key,
  tabela        text not null,
  registro_id   text not null,
  acao          acao_auditoria not null,
  usuario_id    uuid references perfis(id),
  dados_antes   jsonb,
  dados_depois  jsonb,
  criado_em     timestamptz not null default now()
);
create index if not exists idx_auditoria_tabela on auditoria(tabela, registro_id);

-- ---------------------------------------------------------------------
-- 8) IMAGENS
-- ---------------------------------------------------------------------
-- Recomendado: criar um bucket "sge-imagens" em Storage (público para leitura,
-- escrita restrita a autenticados) e salvar só a URL/path nos campos jsonb
-- acima (dados/imagens), em vez de base64 dentro do banco. Isso é mais rápido
-- e mais barato do que manter imagens como texto nas colunas jsonb.
-- Rode isto separadamente (Storage não é criado via SQL comum):
--   Supabase → Storage → New bucket → nome "sge-imagens" → Public bucket: ON

-- ---------------------------------------------------------------------
-- 9) GATILHOS (atualizado_em automático)
-- ---------------------------------------------------------------------
create or replace function set_atualizado_em()
returns trigger language plpgsql as $$
begin
  new.atualizado_em = now();
  return new;
end;
$$;

drop trigger if exists trg_fichas_atualizado on fichas;
create trigger trg_fichas_atualizado before update on fichas
  for each row execute function set_atualizado_em();

drop trigger if exists trg_pedidos_atualizado on pedidos;
create trigger trg_pedidos_atualizado before update on pedidos
  for each row execute function set_atualizado_em();

drop trigger if exists trg_receitas_atualizado on receitas;
create trigger trg_receitas_atualizado before update on receitas
  for each row execute function set_atualizado_em();

drop trigger if exists trg_registros_qualidade_atualizado on registros_qualidade;
create trigger trg_registros_qualidade_atualizado before update on registros_qualidade
  for each row execute function set_atualizado_em();

-- ---------------------------------------------------------------------
-- 10) ROW LEVEL SECURITY (RLS) — todo mundo lê, edição por setor liberado
-- ---------------------------------------------------------------------
alter table perfis enable row level security;
alter table permissoes_setor enable row level security;
alter table fichas enable row level security;
alter table ficha_pantones enable row level security;
alter table pedidos enable row level security;
alter table ordens_producao enable row level security;
alter table fornecedores enable row level security;
alter table produtos enable row level security;
alter table receitas enable row level security;
alter table receita_itens enable row level security;
alter table responsaveis_qualidade enable row level security;
alter table registros_qualidade enable row level security;
alter table auditoria enable row level security;

-- perfis: cada um vê o próprio; admin vê todos
create policy "perfis_select" on perfis for select
  using (id = auth.uid() or eh_admin());
create policy "perfis_update_admin" on perfis for update
  using (eh_admin());
create policy "perfis_insert_admin" on perfis for insert
  with check (eh_admin() or id = auth.uid());

-- permissoes_setor: usuário vê a sua; só admin cria/edita/apaga
create policy "permissoes_select" on permissoes_setor for select
  using (usuario_id = auth.uid() or eh_admin());
create policy "permissoes_admin_all" on permissoes_setor for all
  using (eh_admin()) with check (eh_admin());

-- Leitura liberada para qualquer usuário autenticado em todas as tabelas de negócio
create policy "fichas_select" on fichas for select using (auth.uid() is not null);
create policy "ficha_pantones_select" on ficha_pantones for select using (auth.uid() is not null);
create policy "pedidos_select" on pedidos for select using (auth.uid() is not null);
create policy "ordens_producao_select" on ordens_producao for select using (auth.uid() is not null);
create policy "fornecedores_select" on fornecedores for select using (auth.uid() is not null);
create policy "produtos_select" on produtos for select using (auth.uid() is not null);
create policy "receitas_select" on receitas for select using (auth.uid() is not null);
create policy "receita_itens_select" on receita_itens for select using (auth.uid() is not null);
create policy "responsaveis_qualidade_select" on responsaveis_qualidade for select using (auth.uid() is not null);
create policy "registros_qualidade_select" on registros_qualidade for select using (auth.uid() is not null);

-- Escrita (insert/update/delete) só para quem tem permissão no setor correspondente
create policy "fichas_write" on fichas for all
  using (tem_permissao_setor('arte')) with check (tem_permissao_setor('arte'));
create policy "ficha_pantones_write" on ficha_pantones for all
  using (tem_permissao_setor('arte')) with check (tem_permissao_setor('arte'));

create policy "pedidos_write" on pedidos for all
  using (tem_permissao_setor('estamparia')) with check (tem_permissao_setor('estamparia'));
create policy "ordens_producao_write" on ordens_producao for all
  using (tem_permissao_setor('estamparia')) with check (tem_permissao_setor('estamparia'));

create policy "fornecedores_write" on fornecedores for all
  using (tem_permissao_setor('laboratorio')) with check (tem_permissao_setor('laboratorio'));
create policy "produtos_write" on produtos for all
  using (tem_permissao_setor('laboratorio')) with check (tem_permissao_setor('laboratorio'));
create policy "receitas_write" on receitas for all
  using (tem_permissao_setor('laboratorio')) with check (tem_permissao_setor('laboratorio'));
create policy "receita_itens_write" on receita_itens for all
  using (tem_permissao_setor('laboratorio')) with check (tem_permissao_setor('laboratorio'));

create policy "responsaveis_qualidade_write" on responsaveis_qualidade for all
  using (tem_permissao_setor('qualidade')) with check (tem_permissao_setor('qualidade'));
create policy "registros_qualidade_write" on registros_qualidade for all
  using (tem_permissao_setor('qualidade')) with check (tem_permissao_setor('qualidade'));

-- auditoria: qualquer autenticado insere (o próprio app grava o log); só admin lê tudo
create policy "auditoria_insert" on auditoria for insert with check (auth.uid() is not null);
create policy "auditoria_select_admin" on auditoria for select using (eh_admin());

-- ---------------------------------------------------------------------
-- 11) PRIMEIRO ADMINISTRADOR
-- ---------------------------------------------------------------------
-- Depois de criar o primeiro usuário em Authentication → Users (ou via
-- tela de login do app), rode o comando abaixo trocando o e-mail:
--
--   insert into perfis (id, nome, papel)
--   select id, 'Administrador', 'admin'
--   from auth.users where email = 'seuemail@empresa.com'
--   on conflict (id) do update set papel = 'admin';
--
-- =====================================================================
-- FIM DO SCHEMA
-- =====================================================================
