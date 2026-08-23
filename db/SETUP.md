# SGE · Configuração do banco no Supabase

## 1. Rodar o schema
1. Abra o projeto em https://supabase.com/dashboard → **uqxyogatphxpwszyryac**
2. Menu lateral → **SQL Editor** → **New query**
3. Cole todo o conteúdo de `schema.sql` e clique em **Run**
4. Cole e rode também `schema_02_trigger_novo_usuario.sql` (cria a linha em `perfis` automaticamente quando alguém é cadastrado em Authentication)
5. Cole e rode também `schema_03_ajustes_modulo03.sql` (colunas extras e um ajuste de regra usados pelo Módulo 03)
6. Cole e rode também `schema_04_ajustes_modulo04.sql` (colunas extras usadas pelo Módulo 04)
7. Cole e rode também `schema_05_responsavel_usuario_logado.sql` (o responsável técnico do Módulo 04 passou a ser sempre o usuário logado)
8. Cole e rode também `schema_06_fix_recursao_rls.sql` (corrige um erro "stack depth limit exceeded" ao salvar)
9. Cole e rode também `schema_07_status_qualidade_pedido.sql` (sinaliza aprovação/reprovação da Qualidade nos Módulos 02 e 03)
10. Confira em **Table Editor** se as tabelas apareceram: `perfis`, `permissoes_setor`, `fichas`, `pedidos`, `fornecedores`, `produtos`, `receitas`, `receita_itens`, `registros_qualidade`, `auditoria`, etc.

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
- ✅ `modulo-01.html` (Artes) — fichas gravam no Supabase; excluir com confirmação; confirmação ao sobrescrever; modo somente leitura para quem não tem permissão no setor "arte"
- ✅ `modulo-02.html` (Estamparia) — pedidos e ordens de produção gravam no Supabase; excluir com confirmação; modo somente leitura para quem não tem permissão no setor "estamparia"
- ✅ `modulo-03.html` (Laboratório de Tinta) — fornecedores, estoque e receitas gravam no Supabase; editar/excluir com confirmação; regra de receita sem produto no estoque bloqueada; modo somente leitura para quem não tem permissão no setor "laboratorio"
- ✅ `modulo-04.html` (Qualidade) — cadastros e responsáveis técnicos gravam no Supabase; editar/excluir com confirmação; modo somente leitura para quem não tem permissão no setor "qualidade"

**Todos os 5 módulos + dashboard + login + admin estão migrados para o Supabase.**

## 7. O que já foi feito na rodada de melhorias
- ✅ Auditoria: toda edição/exclusão em fornecedores, produtos, receitas, fichas, pedidos e cadastros de qualidade fica registrada na tabela `auditoria`
- ✅ Avisos padronizados (toast) em todos os módulos, no lugar do `alert()` do navegador
- ✅ "Esqueci minha senha" na tela de login + página `redefinir-senha.html`
- ✅ Mensagens de erro mais claras quando falta conexão com a internet (antivírus/proxy bloqueando)

## 8. Configuração necessária para "Esqueci minha senha" funcionar
1. Supabase → seu projeto → **Authentication → URL Configuration**
2. Em **Redirect URLs**, adicione:
   ```
   https://sge-industria.vercel.app/redefinir-senha.html
   ```
   (troque pelo domínio real, se for diferente)
3. Salve. Sem isso, o Supabase recusa o redirecionamento e o link do e-mail não abre a página certa.
4. Confira também se em **Authentication → Emails** o modelo "Reset Password" está ativado (vem ativado por padrão).

## 9. Lixeira (exclusão reversível)
- **Rode `schema_08_lixeira.sql`** no SQL Editor do Supabase — sem isso a Lixeira não funciona
- Ao "excluir" fichas, pedidos, fornecedores, produtos, receitas ou cadastros de qualidade, o item some das telas normais mas fica guardado
- Nova página **`lixeira.html`** — mostra tudo que foi excluído, agrupado por módulo, com botão **Restaurar**
- Restaurar/apagar em definitivo exige a mesma permissão de edição do setor daquele item (ou ser Administrador)
- Apagar em definitivo é exclusivo do Administrador, com dupla confirmação
- Receitas têm um cuidado especial: excluir devolve a matéria-prima ao estoque; restaurar desconta de novo (e bloqueia se não tiver estoque suficiente no momento)
- Link "Lixeira" já está no menu inicial (`modulo-00.html`)

## 10. O que ainda pode ser refinado (não bloqueia o uso)
- Trocar o vínculo "texto" (pedido_numero, responsavel_nome) por FK obrigatória em todo lugar, agora que todos os módulos existem no banco
- Migrar as imagens (hoje em base64 dentro do jsonb) para o Storage do Supabase, se o volume de fotos crescer muito
- Testar o fluxo ponta a ponta com mais de um usuário ao mesmo tempo
- Rotina automática para esvaziar a lixeira após X dias (hoje é só manual, pelo Administrador)

## Credenciais para o próximo passo
Guarde estas duas informações — vou usar para conectar o app:
- **Project URL:** `https://uqxyogatphxpwszyryac.supabase.co`
- **anon public key:** (a que você já me enviou)

Nunca cole aqui a chave `service_role` nem a senha do banco — essas ficam só no painel do Supabase.
