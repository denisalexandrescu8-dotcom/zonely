// Interfaz: dibuja el monitor, los perfiles y refleja el estado del motor.
const $ = (id) => document.getElementById(id);

let config = null;       // contenido de zones.ini
let state = { engineUp: false };
let monitorBuilt = false;

const pct = (v, total) => (v / total) * 100 + '%';

const ZONE_IDS = ['A', 'B', 'C', 'D', 'E', 'F'];       // un perfil puede tener hasta 6 zonas

// Crea (una sola vez) las zonas del monitor grande.
function buildMonitor() {
  const mon = $('monitor');
  for (const id of ZONE_IDS) {
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
  for (const id of ZONE_IDS) {
    const z = profile.zones[id];
    const el = $(`zone-${id}`);
    el.style.display = z ? '' : 'none';              // el perfil «normal» no tiene zona B
    if (!z) continue;
    el.style.left = pct(z.x, w);
    el.style.width = pct(z.w, w);
    el.style.top = pct(z.y, h);
    el.style.height = pct(z.h, h);
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
    mini.style.aspectRatio = `${w} / ${h}`;
    for (const id of ZONE_IDS) {
      const z = p.zones[id];
      if (!z) continue;
      const el = document.createElement('div');
      el.className = `zone ${id}`;
      el.style.left = pct(z.x, w);
      el.style.width = pct(z.w, w);
      el.style.top = pct(z.y, h);
      el.style.height = pct(z.h, h);
      el.innerHTML = `<span class="letter">${id}</span>`;
      mini.appendChild(el);
    }
    const info = document.createElement('div');
    const name = document.createElement('div');
    name.className = 'name';
    name.textContent = p.id;                       // textContent: nada del .ini se interpreta como HTML
    const sizes = document.createElement('div');
    sizes.className = 'sizes';
    sizes.textContent = p.zones.B ? ZONE_IDS.filter((id) => p.zones[id]).map((id) => `${id} ${p.zones[id].w}×${p.zones[id].h}`).join(' · ') : t('Pantalla completa · sin zonas');
    info.append(name, sizes);
    card.append(mini, info);
    card.onclick = () => window.zones.send({ type: 'profile', value: p.id }).then(refreshSoon);
    box.appendChild(card);
  }
}

let engineBusy = false;                       // mientras el motor arranca o se apaga, el interruptor no se toca solo
function paintEngine() {
  const el = $('engine');
  el.className = 'motor ' + (state.engineUp ? 'up' : 'down');
  $('engine-text').textContent = state.engineUp
    ? (state.paused ? t('Motor activo · atajos en pausa') : t('Motor activo'))
    : t('Motor detenido');
  const sw = $('engine-switch');
  if (document.activeElement !== sw && !engineBusy) sw.checked = !!state.engineUp;
  document.querySelector('.nav-item[data-nav="ajustes"]').classList.toggle('alert', !state.engineUp);     // punto rojo si el motor está apagado
  const w = $('watcher');
  w.disabled = !state.engineUp;
  w.checked = !!state.watcher;
  const s = $('snap');
  s.disabled = !state.engineUp;
  s.checked = !!state.snap;
  const sk = $('opt-snapkey');
  if (document.activeElement !== sk && config.options?.snapkey) sk.value = config.options.snapkey;
  const lg = $('opt-language');
  if (document.activeElement !== lg) lg.value = config.options?.language || 'auto';
  // Opciones guardadas en zones.ini (se leen de la configuración, no del estado del motor).
  for (const [id, key] of [['opt-halves', 'halves'], ['opt-restore', 'restore'], ['opt-fullscreen', 'fullscreen'], ['opt-animate', 'animate'], ['opt-menubar', 'menubar'], ['opt-autoupdate', 'autoupdate']]) {
    const el = $(id);
    el.disabled = !state.engineUp && key !== 'autoupdate';        // las actualizaciones no dependen del motor
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

// Selector de monitor (barra lateral): enseña el elegido y, si hay más de uno conectado, los despliega para cambiar.
const monitorLabel = (m) => (m.primary ? t('{name} (principal)', { name: m.name }) : m.name);
let monitorsKey = '';
function paintMonitorPicker() {
  const list = state.monitors ?? [];
  const chosen = list.find((m) => m.id === config.monitor.id) ?? list.find((m) => m.id === state.monitor) ?? list.find((m) => m.primary) ?? list[0];
  $('mon-name').textContent = chosen ? chosen.name : t('Monitor principal');
  $('res').textContent = chosen ? `${chosen.w}×${chosen.h}` : `${config.monitor.w}×${config.monitor.h}`;
  $('monitor-card').title = `${$('mon-name').textContent} · ${$('res').textContent}`;      // el nombre completo, por si no cabe
  const pickable = list.length > 1;
  $('monitor-card').classList.toggle('pickable', pickable);
  $('monitor-chev').toggleAttribute('hidden', !pickable);       // es un SVG: no tiene la propiedad .hidden
  if (!pickable) closeMonitorMenu();
  const key = JSON.stringify([list, chosen?.id]);
  if (key === monitorsKey) return;                              // solo se reconstruye el menú si cambian los monitores
  monitorsKey = key;
  const menu = $('monitor-menu');
  menu.replaceChildren(...list.map((m) => {
    const li = document.createElement('li');
    li.setAttribute('role', 'option');
    li.classList.toggle('on', m === chosen);
    const tick = document.createElement('span');
    tick.className = 'tick';
    tick.textContent = m === chosen ? '✓' : '';
    const text = document.createElement('div');
    text.textContent = monitorLabel(m);
    const small = document.createElement('small');
    small.textContent = m.profile ? `${m.w}×${m.h} · ${t('perfil {name}', { name: m.profile })}` : `${m.w}×${m.h}`;
    text.appendChild(small);
    li.append(tick, text);
    li.addEventListener('click', async () => {
      closeMonitorMenu();
      if (m === chosen) return;
      try { await window.zones.setMonitor(m.id); } catch (err) { window.zones.logError(`monitor: ${err && err.message}`); }
      refreshSoon();                                            // el motor relee zones.ini y reinicia: se mira varias veces mientras tanto
    });
    return li;
  }));
}
function closeMonitorMenu() {
  $('monitor-menu').hidden = true;
  $('monitor-card').setAttribute('aria-expanded', 'false');
}
$('monitor-card').addEventListener('click', () => {
  if (!$('monitor-card').classList.contains('pickable')) return;
  const open = $('monitor-menu').hidden;
  $('monitor-menu').hidden = !open;
  $('monitor-card').setAttribute('aria-expanded', String(open));
});
document.addEventListener('click', (e) => { if (!e.target.closest('.monitor-pick')) closeMonitorMenu(); });
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') closeMonitorMenu(); });

// Tras una orden al motor: se vuelve a mirar enseguida y unas cuantas veces más, para ver el cambio en cuanto ocurre.
let soonTimers = [];
function refreshSoon() {
  soonTimers.forEach(clearTimeout);
  soonTimers = [0, 250, 600, 1100, 1800, 2800].map((ms) => setTimeout(refresh, ms));
}

let lastKey = '';
async function refresh() {
  const [cfg, st] = await Promise.all([window.zones.getConfig(), window.zones.getState()]);
  config = cfg;
  state = st;
  if (!monitorBuilt) buildMonitor();

  const activeId = state.profile ?? config.startProfile;
  const active = config.profiles.find((p) => p.id === activeId) ?? config.profiles[0];
  paintMonitorPicker();
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
// Idioma: las opciones salen con su nombre en su propio idioma; «Automático» sigue al sistema. Al cambiarlo se recarga el panel.
(() => {
  const sel = $('opt-language');
  for (const [code, name] of LANGUAGES) sel.add(new Option(name || t('Automático'), code));
  sel.value = (config && config.options && config.options.language) || 'auto';
  sel.addEventListener('change', async () => {
    await window.zones.setLanguage(sel.value);
    location.reload();
  });
})();
$('opt-snapkey').addEventListener('change', async (e) => {
  await window.zones.setSnapKey(e.target.value);
  refresh();
});
$('snap').addEventListener('change', (e) =>
  window.zones.send({ type: 'snap', value: e.target.checked ? 'on' : 'off' }).then(refresh));
for (const [id, key] of [['opt-halves', 'halves'], ['opt-restore', 'restore'], ['opt-fullscreen', 'fullscreen'], ['opt-animate', 'animate'], ['opt-menubar', 'menubar'], ['opt-autoupdate', 'autoupdate']])
  $(id).addEventListener('change', async (e) => {
    await window.zones.setOption(key, e.target.checked);                                      // se guarda en zones.ini
    if (key === 'autoupdate') { /* lo lee el actualizador cuando le toca: el motor no se entera */ }
    else if (key === 'menubar' || key === 'animate') await window.zones.send({ type: 'reload' });                   // el motor de Mac lo aplica al releer zones.ini
    else await window.zones.send({ type: key, value: e.target.checked ? 'on' : 'off' });      // y se aplica ya en el motor
    refresh();
  });
$('engine-reload').addEventListener('click', () => window.zones.send({ type: 'reload' }).then(() => setTimeout(refresh, 1500)));
// Interruptor del motor (Ajustes → Motor): encender lo arranca; apagarlo le manda cerrarse.
$('engine-switch').addEventListener('change', async (e) => {
  engineBusy = true;
  try {
    if (e.target.checked) await window.zones.startEngine();
    else await window.zones.send({ type: 'quit' });
  } catch (err) {
    e.target.checked = !e.target.checked;                              // no se pudo: el interruptor vuelve a como estaba
    window.zones.logError(`motor: ${err && err.message}`);
  }
  setTimeout(() => { engineBusy = false; refresh(); }, 2500);          // se espera a que el estado del motor cambie de verdad
});

refresh();
setInterval(() => { if (!document.hidden) refresh(); }, 1000);     // minimizado u oculto: no se lee nada
