/* =====================================================================
   SGE — Cliente Supabase compartilhado + helpers de autenticação/permissão
   Incluir em toda página (depois do script da CDN do supabase-js):

   <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
   <script src="assets/supabase-client.js"></script>
   ===================================================================== */

const SGE_SUPABASE_URL = 'https://uqxyogatphxpwszyryac.supabase.co';
const SGE_SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVxeHlvZ2F0cGh4cHdzenlyeWFjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODM4ODg0MzEsImV4cCI6MjA5OTQ2NDQzMX0.UIBuMvI54lVVu-ncEjTzGn-RIz2OwjBM7eqAYe9bdbo';

window.sgeSupabase = window.supabase.createClient(SGE_SUPABASE_URL, SGE_SUPABASE_ANON_KEY);

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
  return error.message || 'Não foi possível concluir a operação.';
}
