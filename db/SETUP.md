# SGE · Configuração do banco no Supabase

## 1. Rodar o schema
1. Abra o projeto em https://supabase.com/dashboard → **uqxyogatphxpwszyryac**
2. Menu lateral → **SQL Editor** → **New query**
3. Cole todo o conteúdo de `schema.sql` e clique em **Run**
4. Cole e rode também `schema_02_trigger_novo_usuario.sql` (cria a linha em `perfis` automaticamente quando alguém é cadastrado em Authentication)
5. Confira em **Table Editor** se as tabelas apareceram: `perfis`, `permissoes_setor`, `fichas`, `pedidos`, `fornecedores`, `produtos`, `receitas`, `receita_itens`, `registros_qualidade`, `auditoria`, etc.

## 2. Criar o bucket de imagens (opcional, recomendado)
Menu lateral → **Storage** → **New bucket** → nome `sge-imagens` → marque **Public bucket**.
(Isso evita guardar fotos em base64 dentro do banco — mais rápido e mais barato.)

## 3. Criar o primeiro usuário Administrador
1. Menu lateral → **Authentication** → **Users** → **Add user** → informe e-mail e senha
2. Volte ao **SQL Editor** e rode (trocando o e-mail):
```sql
insert into perfis (id, nome, papel)
select id, 'Administrador', 'admin'
from auth.users where email = 'seuemail@empresa.com'
on conflict (id) do update set papel = 'admin';
```
3. Esse usuário passa a ter acesso total. Os próximos usuários que você criar em Authentication entram automaticamente como `usuario` (leitura + impressão) até o admin liberar edição por setor na tabela `permissoes_setor`.

## 4. Como funciona a permissão por setor
- `perfis.papel = 'admin'` → acesso total, sempre.
- `perfis.papel = 'usuario'` → só visualiza e imprime, **a menos que** exista uma linha em `permissoes_setor` para aquele usuário com `pode_editar = true` no setor correspondente (`arte`, `estamparia`, `laboratorio` ou `qualidade`).
- Isso é aplicado automaticamente no banco via RLS (Row Level Security) — mesmo que alguém tente editar direto pela API, o Postgres bloqueia se não tiver permissão. A tela ainda vai precisar checar isso também, só para esconder os botões de quem não pode usar — mas a segurança de verdade está no banco.

## 5. Regra "sem produto no estoque não salva receita"
Já está garantida no banco: a tabela `receita_itens` exige `produto_id` (`not null references produtos(id)`). Se o produto não existir no estoque, o Postgres recusa o insert com um erro de chave estrangeira — o app só precisa mostrar essa mensagem de forma amigável.

## 6. O que já está pronto no app
- ✅ `login.html` — tela de login (Supabase Auth)
- ✅ `admin.html` — painel do Administrador para liberar/revogar edição por setor
- ✅ `modulo-00.html` — exige login, mostra nome/papel do usuário, mostra "Administração" só para admin
- ✅ `modulo-dashboard.html` — os 6 indicadores agora leem direto das tabelas do Supabase

## 7. O que falta (próxima etapa)
- Trocar `window.storage` por Supabase nos módulos **01 (Artes)**, **02 (Estamparia)**, **03 (Laboratório de Tinta)** e **04 (Qualidade)**
- Adicionar botões Editar/Excluir com confirmação (`sgeConfirmar()`, já pronta em `assets/supabase-client.js`) nesses 4 módulos
- Esconder/mostrar os botões de editar conforme `sgePodeEditar('arte' | 'estamparia' | 'laboratorio' | 'qualidade')`
- Gravar cada edição/exclusão na tabela `auditoria`

Isso é feito módulo a módulo para não arriscar quebrar o que já funciona.

## Credenciais para o próximo passo
Guarde estas duas informações — vou usar para conectar o app:
- **Project URL:** `https://uqxyogatphxpwszyryac.supabase.co`
- **anon public key:** (a que você já me enviou)

Nunca cole aqui a chave `service_role` nem a senha do banco — essas ficam só no painel do Supabase.
