// Interfaz: dibuja el monitor, los perfiles y refleja el estado del motor.
const $ = (id) => document.getElementById(id);

let config = null;       // contenido de zones.ini
let state = { engineUp: false };
let monitorBuilt = false;

const pct = (v, total) => (v / total) * 100 + '%';

// Crea (una sola vez) las dos zonas del monitor grande.
function buildMonitor() {
  const mon = $('monitor');
  for (const id of ['A', 'B', 'C']) {
    const z = document.createElement('div');
    z.className = `zone ${id}`;
    z.id = `zone-${id}`;
    z.innerHTML = `<span class="letter">${id}</span><span class="dim"></span>`;
    mon.appendChild(z);
  }
  monitorBuilt = true;
}

// Coloca las zonas del perfil activo (las transiciones CSS lo animan).
function paintMonitor(profile) {
  const { w, h } = config.monitor;
  $('monitor').style.aspectRatio = `${w} / ${h}`;
  for (const id of ['A', 'B', 'C']) {
    const z = profile.zones[id];
    const el = $(`zone-${id}`);
    el.style.display = z ? '' : 'none';              // el perfil «normal» no tiene zona B
    if (!z) continue;
    el.style.left = pct(z.x, w);
    el.style.width = pct(z.w, w);
    el.querySelector('.dim').textContent = `${z.w} × ${z.h}`;
  }
}

// Tarjetas de perfil con su miniatura.
function paintCards() {
  const { w, h } = config.monitor;
  const box = $('cards');
  box.innerHTML = '';
  for (const p of config.profiles) {
    const card = document.createElement('button');
    card.className = 'card' + (p.id === state.profile ? ' active' : '');
    card.dataset.id = p.id;
    // Se construye con DOM (no con style="" en HTML) por la política CSP de la página.
    const mini = document.createElement('div');
    mini.className = 'mini';
    for (const id of ['A', 'B', 'C']) {
      const z = p.zones[id];
      if (!z) continue;
      const el = document.createElement('div');
      el.className = `zone ${id}`;
      el.style.left = pct(z.x, w);
      el.style.width = pct(z.w, w);
      el.innerHTML = `<span class="letter">${id}</span>`;
      mini.appendChild(el);
    }
    const info = document.createElement('div');
    const name = document.createElement('div');
    name.className = 'name';
    name.textContent = p.id;                       // textContent: nada del .ini se interpreta como HTML
    const sizes = document.createElement('div');
    sizes.className = 'sizes';
    sizes.textContent = p.zones.B ? ['A', 'B', 'C'].filter((id) => p.zones[id]).map((id) => `${id} ${p.zones[id].w}×${p.zones[id].h}`).join(' · ') : 'Pantalla completa · sin zonas';
    info.append(name, sizes);
    card.append(mini, info);
    card.onclick = () => window.zones.send({ type: 'profile', value: p.id }).then(refresh);
    box.appendChild(card);
  }
}

function paintEngine() {
  const el = $('engine');
  el.className = 'engine ' + (state.engineUp ? 'up' : 'down');
  $('engine-text').textContent = state.engineUp
    ? (state.paused ? 'Motor activo · atajos en pausa' : 'Motor activo')
    : 'Motor detenido';
  $('engine-start').hidden = state.engineUp;
  const w = $('watcher');
  w.disabled = !state.engineUp;
  w.checked = !!state.watcher;
  const s = $('snap');
  s.disabled = !state.engineUp;
  s.checked = !!state.snap;
  // Opciones guardadas en zones.ini (se leen de la configuración, no del estado del motor).
  for (const [id, key] of [['opt-halves', 'halves'], ['opt-restore', 'restore'], ['opt-menubar', 'menubar']]) {
    const el = $(id);
    el.disabled = !state.engineUp;
    if (document.activeElement !== el) el.checked = !!config.options?.[key];
  }
}

// Destello breve en las zonas del monitor grande cuando cambia el perfil activo.
let flashedProfile = null;
function flashZones() {
  for (const id of ['A', 'B', 'C']) {
    const el = $(`zone-${id}`);
    el.classList.remove('flash');
    void el.offsetWidth;                              // reinicia la animación
    el.classList.add('flash');
  }
}

let lastKey = '';
async function refresh() {
  const [cfg, st] = await Promise.all([window.zones.getConfig(), window.zones.getState()]);
  config = cfg;
  state = st;
  if (!monitorBuilt) buildMonitor();

  const activeId = state.profile ?? config.startProfile;
  const active = config.profiles.find((p) => p.id === activeId) ?? config.profiles[0];
  $('res').textContent = `${config.monitor.w}×${config.monitor.h}`;
  $('active-name').textContent = active.id;
  paintMonitor(active);
  if (flashedProfile !== null && flashedProfile !== active.id) flashZones();     // no en la primera carga
  flashedProfile = active.id;
  paintEngine();

  // Solo reconstruimos las tarjetas si algo cambió.
  const key = JSON.stringify([config, state.profile]);
  if (key !== lastKey) { lastKey = key; paintCards(); }
  window.onPanelPaint?.();
}

$('watcher').addEventListener('change', (e) =>
  window.zones.send({ type: 'watcher', value: e.target.checked ? 'on' : 'off' }).then(refresh));
$('snap').addEventListener('change', (e) =>
  window.zones.send({ type: 'snap', value: e.target.checked ? 'on' : 'off' }).then(refresh));
for (const [id, key] of [['opt-halves', 'halves'], ['opt-restore', 'restore'], ['opt-menubar', 'menubar']])
  $(id).addEventListener('change', async (e) => {
    await window.zones.setOption(key, e.target.checked);                                      // se guarda en zones.ini
    if (key === 'menubar') await window.zones.send({ type: 'reload' });                        // el motor de Mac lo aplica al releer zones.ini
    else await window.zones.send({ type: key, value: e.target.checked ? 'on' : 'off' });      // y se aplica ya en el motor
    refresh();
  });
$('engine-reload').addEventListener('click', () => window.zones.send({ type: 'reload' }).then(() => setTimeout(refresh, 1500)));
$('open-manual').addEventListener('click', () => window.zones.openManual());
$('engine-start').addEventListener('click', async () => {
  await window.zones.startEngine();
  setTimeout(refresh, 1500);
});

refresh();
setInterval(refresh, 1000);
