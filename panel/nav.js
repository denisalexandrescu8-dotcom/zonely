// Navegación lateral: muestra una sola vista a la vez y recuerda la última.
let devMode = false;      // el apartado Registro solo se muestra en desarrollo (ver abajo)
document.documentElement.classList.toggle('windows-titlebar', window.zones.platform === 'win32');
const VIEWS = {
  zonas:    [t('Zonas'), t('Tu monitor, tus perfiles y sus zonas.')],
  editor:   [t('Editor de perfiles'), t('Ajusta las zonas de un perfil.')],
  atajos:   [t('Atajos'), t('Cambia las combinaciones de teclado del motor.')],
  ajustes:  [t('Ajustes'), t('Personaliza cómo se comportan tus ventanas.')],
  manual:   [t('Manual'), t('Guía de uso de Zonely.')],
  registro: [t('Registro'), t('Lo que hace el motor y la última ventana usada.')],
};     // IS_MAC viene de hotkeys.js

function showView(name) {
  if (name === 'registro' && !devMode) name = 'zonas';
  if (!VIEWS[name]) name = 'zonas';
  document.getElementById('app').dataset.view = name;
  for (const v of document.querySelectorAll('.view')) v.classList.toggle('on', v.dataset.view === name);
  for (const b of document.querySelectorAll('.nav-item')) b.classList.toggle('on', b.dataset.nav === name);
  document.getElementById('view-title').textContent = VIEWS[name][0];
  document.getElementById('view-sub').textContent = VIEWS[name][1];
  if (name === 'manual') {                // el manual se carga la primera vez que se abre
    const frame = document.getElementById('manual-frame');
    if (!frame.getAttribute('src')) frame.src = IS_MAC ? '../manual/mac.html' : '../manual/index.html';
  }
  try { localStorage.setItem('view', name); } catch { /* sin almacenamiento: no pasa nada */ }
}

for (const b of document.querySelectorAll('.nav-item'))
  b.addEventListener('click', () => showView(b.dataset.nav));

document.getElementById('edit-profile').addEventListener('click', () => {
  if (!config || !config.profiles.length) return;
  const select = document.getElementById('ed-profile');
  select.value = state.profile || config.startProfile || config.profiles[0]?.id || '';
  select.dispatchEvent(new Event('change'));
  showView('editor');
});
document.getElementById('editor-back').addEventListener('click', () => showView('zonas'));

let lastView = 'zonas';
try { lastView = localStorage.getItem('view') || 'zonas'; } catch { /* idem */ }
showView(lastView);

// El apartado Registro (registro de actividad y depuración) es solo para desarrollo: en la versión
// instalada no aparece. Hasta saberlo se parte de «Zonas» si la última vista fue el registro.
if (lastView === 'registro') showView('zonas');
Promise.resolve(window.zones?.isDev?.()).then((dev) => {
  devMode = !!dev;
  if (!devMode) return;
  document.querySelector('.nav-item[data-nav="registro"]').hidden = false;
  document.getElementById('engine-reload').hidden = false;      // recargar el motor a mano solo en desarrollo
  if (lastView === 'registro') showView('registro');
}).catch(() => {});

// En macOS se muestran los ajustes que solo existen allí (los textos «Win+Alt+X» se adaptan en i18n.js).
if (IS_MAC) {
  for (const el of document.querySelectorAll('.mac-only')) el.hidden = false;
}
