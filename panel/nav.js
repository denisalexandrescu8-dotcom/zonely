// Navegación lateral: muestra una sola vista a la vez y recuerda la última.
let devMode = false;      // el apartado Registro solo se muestra en desarrollo (ver abajo)
const VIEWS = {
  zonas:    ['Zonas', 'Tu monitor, tus perfiles y sus zonas.'],
  atajos:   ['Atajos', 'Cambia las combinaciones de teclado del motor.'],
  ajustes:  ['Ajustes', 'Modo juego, capa oscura y exclusiones.'],
  registro: ['Registro', 'Lo que hace el motor y la última ventana usada.'],
};

function showView(name) {
  if (name === 'registro' && !devMode) name = 'zonas';
  if (!VIEWS[name]) name = 'zonas';
  document.getElementById('app').dataset.view = name;
  for (const v of document.querySelectorAll('.view')) v.classList.toggle('on', v.dataset.view === name);
  for (const b of document.querySelectorAll('.nav-item')) b.classList.toggle('on', b.dataset.nav === name);
  document.getElementById('view-title').textContent = VIEWS[name][0];
  document.getElementById('view-sub').textContent = VIEWS[name][1];
  try { localStorage.setItem('view', name); } catch { /* sin almacenamiento: no pasa nada */ }
}

for (const b of document.querySelectorAll('.nav-item'))
  b.addEventListener('click', () => showView(b.dataset.nav));

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

// En macOS los atajos de fábrica son ⌃⌥ + tecla: los textos fijos de la interfaz que dicen «Win+Alt+X» se adaptan.
if (/Mac/i.test(navigator.platform || '')) {
  for (const el of document.querySelectorAll('.mac-only')) el.hidden = false;      // ajustes que solo existen en macOS
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  for (let n = walker.nextNode(); n; n = walker.nextNode())
    n.nodeValue = n.nodeValue.replace(/Win\+Alt\+(\w)/g, (_, k) => `⌃⌥${k.toUpperCase()}`);
}
