# SGE · Deploy no Vercel (via GitHub)

## 1. Colocar os arquivos num repositório GitHub
1. Crie um repositório novo em https://github.com/new (ex: `sge`)
2. Suba todos os arquivos deste pacote mantendo a estrutura:
   ```
   /modulo-00.html
   /modulo-01.html
   /modulo-02.html
   /modulo-03.html
   /modulo-04.html
   /modulo-dashboard.html
   /login.html
   /admin.html
   /vercel.json
   /assets/supabase-client.js
   ```
   (o mais simples: arrastar os arquivos na própria página do GitHub em "Add file → Upload files")

## 2. Conectar ao Vercel
1. Acesse https://vercel.com → **Add New → Project**
2. Selecione o repositório `sge` que você acabou de criar
3. Em **Framework Preset**, escolha **Other** (é um site estático puro, sem build)
4. **Build Command**: deixe em branco · **Output Directory**: deixe em branco (raiz)
5. Clique em **Deploy**

## 3. Domínio
- O Vercel já entrega uma URL tipo `https://sge-xxxx.vercel.app`
- Se quiser manter `https://sge-lake-ten.vercel.app/` (o link secreto que já está no app), configure esse projeto para usar esse domínio em **Project Settings → Domains**

## 4. Atualizações depois do primeiro deploy
Qualquer novo `git push` no repositório atualiza o site automaticamente — não precisa repetir os passos acima.

## 5. Checklist antes de liberar para a equipe
- [ ] `schema.sql` e `schema_02_trigger_novo_usuario.sql` já rodados no Supabase
- [ ] Bucket `sge-imagens` criado (se for usar upload de fotos)
- [ ] Usuário Administrador criado e promovido (`papel = 'admin'`)
- [ ] Login testado em `/login.html`
- [ ] Permissões de setor testadas em `/admin.html`
