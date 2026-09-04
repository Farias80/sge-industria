/* =====================================================================
   SGE — Cliente Supabase compartilhado + helpers de autenticação/permissão
   Incluir em toda página (depois do script da CDN do supabase-js):

   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
   <script src="assets/supabase-client.js"></script>
   ===================================================================== */

// URL "real" do projeto no Supabase — não é usada diretamente pelo navegador,
// só fica aqui de referência (o vercel.json usa esse mesmo endereço na ponte).
const SGE_SUPABASE_URL_REAL = 'https://uqxyogatphxpwszyryac.supabase.co';

// Em vez de o navegador falar direto com *.supabase.co, ele fala com o próprio
// site (sge-industria.vercel.app/supa) e é o Vercel quem repassa pro Supabase.
// Isso existe porque algumas redes de empresa bloqueiam domínios de banco de
// dados na nuvem — como o navegador só enxerga o domínio do próprio SGE, esse
// bloqueio deixa de acontecer. Configurado em vercel.json (bloco "rewrites").
const SGE_SUPABASE_URL = window.location.origin + '/supa';
const SGE_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxeHlvZ2F0cGh4cHdzenlyeWFjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4ODg0MzEsImV4cCI6MjA5OTQ2NDQzMX0.UIBuMvI54lVVu-ncEjTzGn-RIz2OwjBM7eqAYe9bdbo';

if (!window.supabase || typeof window.supabase.createClient !== 'function') {
  console.error('[SGE] A biblioteca do Supabase (supabase-js) não carregou. Verifique se o <script> da CDN está ANTES de assets/supabase-client.js na página, e se a internet/CDN não está bloqueada.');
  alert('Não foi possível carregar a conexão com o banco de dados (Supabase). Recarregue a página; se o problema continuar, avise o administrador.');
}

window.sgeSupabase = window.supabase.createClient(SGE_SUPABASE_URL, SGE_SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,       // guarda a sessão no localStorage do navegador
    autoRefreshToken: true,     // renova o token sozinho antes de expirar
    detectSessionInUrl: true,   // necessário para o link de redefinir senha funcionar
    storage: window.localStorage,
    storageKey: 'sge-auth-token' // chave fixa, igual em todas as páginas do sistema
  }
});

/* ---------------- Sessão / autenticação ---------------- */

// Garante que existe uma sessão válida; senão redireciona para o login.
// Uso: no topo do <script> de cada página, chamar: await sgeRequireLogin();
async function sgeRequireLogin(){
  const { data } = await window.sgeSupabase.auth.getSession();
  if(!data || !data.session){
    const voltar = encodeURIComponent(window.location.pathname.split('/').pop());
    window.location.href = 'login.html?next=' + voltar;
    return null;
  }
  return data.session;
}

// Retorna o perfil (nome, papel) do usuário logado. Cacheia na sessão da aba.
let __sgePerfilCache = null;
async function sgeGetPerfil(){
  if(__sgePerfilCache) return __sgePerfilCache;
  const { data: sessionData } = await window.sgeSupabase.auth.getSession();
  if(!sessionData || !sessionData.session) return null;
  const uid = sessionData.session.user.id;
  const { data, error } = await window.sgeSupabase.from('perfis').select('*').eq('id', uid).single();
  if(error){ console.error('Falha ao carregar perfil', error); return null; }
  __sgePerfilCache = data;
  return data;
}

async function sgeLogout(){
  await window.sgeSupabase.auth.signOut();
  window.location.href = 'login.html';
}

/* ---------------- Permissões por setor ----------------
   setor ∈ 'arte' | 'estamparia' | 'laboratorio' | 'qualidade' */
async function sgePodeEditar(setor){
  const perfil = await sgeGetPerfil();
  if(!perfil) return false;
  if(perfil.papel === 'admin') return true;
  const { data, error } = await window.sgeSupabase
    .from('permissoes_setor')
    .select('pode_editar')
    .eq('usuario_id', perfil.id)
    .eq('setor', setor)
    .maybeSingle();
  if(error){ console.error('Falha ao checar permissão', error); return false; }
  return !!(data && data.pode_editar);
}

/* ---------------- Cabeçalho padrão de usuário (nome + sair) ----------------
   Cria um pequeno bloco fixo no topo direito com nome/papel e botão Sair.
   Chamar depois de sgeRequireLogin(): sgeMontarBarraUsuario(). */
async function sgeMontarBarraUsuario(){
  const perfil = await sgeGetPerfil();
  if(!perfil) return;
  const bar = document.createElement('div');
  bar.style.cssText = 'position:fixed;top:14px;right:16px;z-index:9998;display:flex;align-items:center;gap:10px;background:rgba(255,255,255,.08);border:1px solid rgba(255,255,255,.16);backdrop-filter:blur(6px);padding:6px 8px 6px 14px;border-radius:100px;font:600 12.5px Inter,system-ui,sans-serif;color:#fff;';
  const papelLabel = perfil.papel === 'admin' ? 'Administrador' : 'Usuário';
  bar.innerHTML = `
    <span>${perfil.nome} <span style="opacity:.6;font-weight:500;">· ${papelLabel}</span></span>
    <button id="sgeBtnSair" style="background:rgba(255,255,255,.14);border:none;color:#fff;font:600 11.5px Inter,system-ui,sans-serif;padding:6px 12px;border-radius:100px;cursor:pointer;">Sair</button>
  `;
  document.body.appendChild(bar);
  document.getElementById('sgeBtnSair').addEventListener('click', sgeLogout);
}

/* ---------------- Confirmações padronizadas de editar/excluir ----------------
   Uso: if(await sgeConfirmar('Excluir o fornecedor "ACME"?')) { ...excluir... } */
async function sgeConfirmar(mensagem){
  return new Promise(resolve => {
    const overlay = document.createElement('div');
    overlay.style.cssText = 'position:fixed;inset:0;background:rgba(14,22,56,.55);z-index:99999;display:flex;align-items:center;justify-content:center;padding:20px;';
    overlay.innerHTML = `
      <div style="background:#fff;border-radius:14px;max-width:380px;width:100%;padding:24px;font-family:Inter,system-ui,sans-serif;box-shadow:0 20px 60px -20px rgba(20,25,70,.5);">
        <div style="font-family:Sora,sans-serif;font-weight:700;font-size:16px;color:#161A3B;margin-bottom:8px;">Confirmar ação</div>
        <div style="font-size:13.5px;color:#6A6F94;line-height:1.5;margin-bottom:20px;">${mensagem}</div>
        <div style="display:flex;gap:10px;justify-content:flex-end;">
          <button id="sgeConfCancelar" style="background:#F1F2F8;border:none;color:#161A3B;font:600 13px Sora,sans-serif;padding:10px 16px;border-radius:9px;cursor:pointer;">Cancelar</button>
          <button id="sgeConfOk" style="background:#5B4FE8;border:none;color:#fff;font:600 13px Sora,sans-serif;padding:10px 16px;border-radius:9px;cursor:pointer;">Confirmar</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);
    overlay.querySelector('#sgeConfCancelar').addEventListener('click', () => { overlay.remove(); resolve(false); });
    overlay.querySelector('#sgeConfOk').addEventListener('click', () => { overlay.remove(); resolve(true); });
    overlay.addEventListener('click', e => { if(e.target === overlay){ overlay.remove(); resolve(false); } });
  });
}

/* ---------------- Erro amigável para FK ausente (ex: produto não cadastrado) ---------------- */
function sgeMensagemErro(error){
  if(!error) return 'Erro desconhecido.';
  if(error.code === '23503') return 'Não é possível salvar: um item vinculado (ex: produto do estoque) não foi encontrado. Cadastre-o antes de salvar.';
  if(error.code === '23505') return 'Já existe um registro com esse identificador único.';
  const msg = (error.message || '').toLowerCase();
  if(msg.includes('failed to fetch') || msg.includes('networkerror') || msg.includes('load failed')){
    return 'Não foi possível conectar ao servidor. Verifique sua internet — se o problema continuar, pode ser um antivírus ou proxy da rede bloqueando a conexão (peça ajuda ao TI da empresa).';
  }
  return error.message || 'Não foi possível concluir a operação.';
}

/* ---------------- Aviso padronizado (toast) ----------------
   Uso: sgeToast('Fornecedor salvo com sucesso!')                 -> sucesso (padrão)
        sgeToast('Não foi possível excluir.', 'erro')             -> erro
        sgeToast('Carregando dados...', 'info')                   -> neutro
   Não bloqueia a tela (diferente de alert()) e some sozinho. */
let __sgeToastTimer = null;
function sgeToast(mensagem, tipo){
  tipo = tipo || 'sucesso';
  let el = document.getElementById('sgeToast');
  if(!el){
    el = document.createElement('div');
    el.id = 'sgeToast';
    el.style.cssText = 'position:fixed;bottom:26px;left:50%;transform:translateX(-50%) translateY(20px);background:#0E1638;color:#fff;padding:11px 20px;border-radius:10px;font:600 13.5px Inter,system-ui,sans-serif;opacity:0;pointer-events:none;transition:.25s ease;display:flex;align-items:center;gap:9px;z-index:99998;max-width:min(90vw,420px);box-shadow:0 12px 30px -10px rgba(14,22,56,.5);';
    el.innerHTML = '<span id="sgeToastIcon" style="display:flex;flex-shrink:0;"></span><span id="sgeToastText"></span>';
    document.body.appendChild(el);
  }
  const icones = {
    sucesso: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#1C9A6C" stroke-width="2.6"><circle cx="12" cy="12" r="9"/><path d="m8 12 3 3 5-6"/></svg>',
    erro: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#F06A66" stroke-width="2.6"><circle cx="12" cy="12" r="9"/><path d="M15 9l-6 6M9 9l6 6"/></svg>',
    info: '<svg viewBox="0 0 24 24" width="15" height="15" fill="none" stroke="#8B93D9" stroke-width="2.6"><circle cx="12" cy="12" r="9"/><path d="M12 8h.01M11 12h1v4h1"/></svg>'
  };
  document.getElementById('sgeToastIcon').innerHTML = icones[tipo] || icones.sucesso;
  document.getElementById('sgeToastText').textContent = mensagem;
  el.style.opacity = '1';
  el.style.transform = 'translateX(-50%) translateY(0)';
  clearTimeout(__sgeToastTimer);
  __sgeToastTimer = setTimeout(() => {
    el.style.opacity = '0';
    el.style.transform = 'translateX(-50%) translateY(20px)';
  }, tipo === 'erro' ? 4200 : 2600);
}

/* ---------------- Auditoria ----------------
   Registra quem criou/editou/excluiu o quê e quando, na tabela `auditoria`.
   Nunca trava a ação principal: se a auditoria falhar (ex: sem internet por
   um instante), só avisa no console e segue o fluxo normalmente.
   Uso: sgeRegistrarAuditoria('fornecedores', novoId, 'criar', null, dadosNovos)
        sgeRegistrarAuditoria('receitas', id, 'editar', dadosAntes, dadosDepois)
        sgeRegistrarAuditoria('produtos', id, 'excluir', dadosAntigos, null) */
async function sgeRegistrarAuditoria(tabela, registroId, acao, dadosAntes, dadosDepois){
  try{
    const perfil = await sgeGetPerfil();
    const { error } = await window.sgeSupabase.from('auditoria').insert({
      tabela: tabela,
      registro_id: String(registroId),
      acao: acao,
      usuario_id: perfil ? perfil.id : null,
      dados_antes: dadosAntes || null,
      dados_depois: dadosDepois || null
    });
    if(error){
      console.error('[SGE] Falha ao gravar auditoria para', tabela, registroId, '—', error.message, error);
    }
  }catch(e){
    console.error('[SGE] Não foi possível registrar auditoria para', tabela, registroId, e);
  }
}

/* ---------------- Lixeira (exclusão reversível) ----------------
   Em vez de apagar de vez, marca o registro como excluído — ele some das
   telas normais mas pode ser restaurado depois em lixeira.html.
   Tabelas que usam isso: fichas, pedidos, fornecedores, produtos, receitas,
   registros_qualidade.
   Uso: const { error } = await sgeSoftDelete('fornecedores', id); */
async function sgeSoftDelete(tabela, id){
  const perfil = await sgeGetPerfil();
  return await window.sgeSupabase.from(tabela).update({
    deletado_em: new Date().toISOString(),
    deletado_por: perfil ? perfil.id : null
  }).eq('id', id);
}

// Uso: const { error } = await sgeRestaurar('fornecedores', id);
async function sgeRestaurar(tabela, id){
  return await window.sgeSupabase.from(tabela).update({
    deletado_em: null,
    deletado_por: null
  }).eq('id', id);
}

/* ---------------- Progresso de pantones (Ficha × Receitas de um pedido) ----------------
   Compara os pantones cadastrados na ficha do Módulo 01 (por estampa + tagless) com as
   receitas do Módulo 03 já vinculadas a um pedido específico. Um pedido só fica
   "concluído" quando TODOS os pantones da ficha tiverem receita cadastrada E vinculada
   a ele — não basta existir uma receita qualquer com aquele pantone em outro pedido.

   Função pura (sem chamadas de rede) — útil para calcular em lote (ex: tabela inteira
   de pedidos) sem fazer uma consulta por linha. */
function sgeProgressoPantones(fichaDados, pantonesDaReceitaDoPedido){
  const grupos = [];
  ((fichaDados && fichaDados.estampas) || []).forEach((estampa, idx) => {
    const nome = estampa.name || ('Estampa ' + (idx + 1));
    const pantones = (estampa.pantones || []).filter(p => p.code);
    if (pantones.length) grupos.push({ nome, codigos: pantones.map(p => p.code) });
  });
  if (fichaDados && fichaDados.tagless) {
    const pantonesTagless = (fichaDados.tagless.pantones || []).filter(p => p.code);
    if (pantonesTagless.length) grupos.push({ nome: 'Tagless', codigos: pantonesTagless.map(p => p.code) });
  }

  const registradosSet = new Set((pantonesDaReceitaDoPedido || []).map(p => (p || '').trim().toLowerCase()));
  let total = 0, registrados = 0;
  const detalhes = grupos.map(g => {
    const itens = g.codigos.map(code => {
      total++;
      const ok = registradosSet.has((code || '').trim().toLowerCase());
      if (ok) registrados++;
      return { code, registrado: ok };
    });
    return { nome: g.nome, itens };
  });
  return { total, registrados, concluido: total > 0 && registrados === total, detalhes };
}

// Versão pronta para uso pontual (ex: dentro do Módulo 03, para 1 pedido só).
// Para telas com uma lista inteira de pedidos (Módulo 02, Dashboard), busque as
// fichas e receitas em lote e use sgeProgressoPantones(...) diretamente por linha,
// para não disparar uma consulta por pedido.
async function sgeBuscarProgressoPantonesPedido(referencia, pedidoNumero){
  if (!referencia || !pedidoNumero) return { total: 0, registrados: 0, concluido: false, detalhes: [] };
  try{
    const [{ data: fichaRow }, { data: receitasRows }] = await Promise.all([
      window.sgeSupabase.from('fichas').select('dados').eq('referencia', referencia).is('deletado_em', null).maybeSingle(),
      window.sgeSupabase.from('receitas').select('pantone').eq('pedido_numero', pedidoNumero).is('deletado_em', null)
    ]);
    return sgeProgressoPantones(fichaRow ? fichaRow.dados : null, (receitasRows || []).map(r => r.pantone));
  }catch(e){
    console.error('[SGE] Falha ao calcular progresso de pantones', e);
    return { total: 0, registrados: 0, concluido: false, detalhes: [] };
  }
}
