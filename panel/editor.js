// Editor visual de zonas y editor de exclusiones.
// Usa `config` y `state` de renderer.js (mismo ámbito global).

const MIN_ZONE = 400;      // px: ninguna zona puede quedar más estrecha que esto
const GRID = 10;           // el divisor salta de 10 en 10 px

const ed = { profile: null, aw: 0, savedAw: 0, dirty: false, built: false };

const edEl = {
  monitor: $('ed-monitor'), select: $('ed-profile'), aw: $('ed-aw'), bw: $('ed-bw'),
  save: $('ed-save'), reset: $('ed-reset'),
};

// ---------- zonas ----------
function edBuild() {
  for (const id of ['A', 'B']) {
    const z = document.createElement('div');
    z.className = `zone ${id}`;
    z.id = `ed-zone-${id}`;
    z.innerHTML = `<span class="letter">${id}</span><span class="dim"></span>`;
    edEl.monitor.appendChild(z);
  }
  const handle = document.createElement('div');
  handle.className = 'handle';
  handle.id = 'ed-handle';
  edEl.monitor.appendChild(handle);

  // Arrastrar el divisor
  handle.addEventListener('pointerdown', (e) => { handle.setPointerCapture(e.pointerId); });
  handle.addEventListener('pointermove', (e) => {
    if (!handle.hasPointerCapture(e.pointerId)) return;
    const r = edEl.monitor.getBoundingClientRect();
    const raw = ((e.clientX - r.left) / r.width) * config.monitor.w;
    edSetWidth(Math.round(raw / GRID) * GRID);
  });
  ed.built = true;
}

function edSetWidth(aw) {
  const total = config.monitor.w;
  ed.aw = Math.min(total - MIN_ZONE, Math.max(MIN_ZONE, aw));
  ed.dirty = ed.aw !== ed.savedAw;
  edPaint();
}

function edPaint() {
  const { w, h } = config.monitor;
  edEl.monitor.style.aspectRatio = `${w} / ${h}`;
  const a = $('ed-zone-A'), b = $('ed-zone-B');
  a.style.left = '0%';
  a.style.width = pct(ed.aw, w);
  b.style.left = pct(ed.aw, w);
  b.style.width = pct(w - ed.aw, w);
  a.querySelector('.dim').textContent = `${ed.aw} × ${h}`;
  b.querySelector('.dim').textContent = `${w - ed.aw} × ${h}`;
  $('ed-handle').style.left = pct(ed.aw, w);
  if (document.activeElement !== edEl.aw) edEl.aw.value = ed.aw;
  edEl.aw.max = w - MIN_ZONE;
  edEl.bw.textContent = `B = ${w - ed.aw} px`;
  edEl.save.disabled = !ed.dirty;
  edEl.reset.disabled = !ed.dirty;
}

// Se llama desde renderer.js en cada refresco.
function edSync() {
  if (!ed.built) edBuild();

  // Lista de perfiles en el desplegable (solo si cambió)
  const ids = config.profiles.filter((p) => p.zones.B && !p.zones.C).map((p) => p.id);     // el perfil sin zonas no se edita
  if (ids.join() !== [...edEl.select.options].map((o) => o.value).join()) {
    edEl.select.innerHTML = '';
    for (const id of ids) edEl.select.add(new Option(id, id));
    ed.profile = null;
  }
  if (!ed.profile || !ids.includes(ed.profile)) {
    ed.profile = state.profile && ids.includes(state.profile) ? state.profile : ids[0];
    edEl.select.value = ed.profile;
    ed.dirty = false;
  }
  // Sin cambios pendientes: seguimos lo que diga el .ini
  const p = config.profiles.find((x) => x.id === ed.profile);
  if (!ed.dirty) {
    ed.savedAw = p.zones.A.w;
    ed.aw = ed.savedAw;
  }
  edPaint();
}

edEl.select.addEventListener('change', () => {
  ed.profile = edEl.select.value;
  ed.dirty = false;
  edSync();
});
edEl.aw.addEventListener('input', () => {
  const v = parseInt(edEl.aw.value, 10);
  if (Number.isInteger(v)) edSetWidth(v);
});
edEl.aw.addEventListener('blur', () => { edEl.aw.value = ed.aw; });
edEl.reset.addEventListener('click', () => { ed.dirty = false; edSync(); });
edEl.save.addEventListener('click', async () => {
  edEl.save.disabled = true;
  await window.zones.setZones({ profile: ed.profile, aw: ed.aw });
  ed.dirty = false;
  await window.zones.send({ type: 'reload' });      // el motor relee zones.ini (conserva perfil y interruptores)
  setTimeout(refresh, 1500);
});

// ---------- exclusiones ----------
async function exSave(kind, list) {
  const ex = { ...config.exclusions, [kind]: list };
  await window.zones.setExclusions(ex);
  await window.zones.send({ type: 'reload' });
  setTimeout(refresh, 1500);
}

function exPaint() {
  for (const kind of ['processes', 'classes']) {
    const box = $(`ex-${kind}`);
    const key = JSON.stringify(config.exclusions[kind]);
    if (box.dataset.key === key) continue;           // nada cambió
    box.dataset.key = key;
    box.innerHTML = '';
    if (!config.exclusions[kind].length) {
      const e = document.createElement('span');
      e.className = 'empty';
      e.textContent = 'Ninguna';
      box.appendChild(e);
    }
    for (const item of config.exclusions[kind]) {
      const chip = document.createElement('span');
      chip.className = 'chip x';
      const label = document.createElement('span');
      label.textContent = item;                       // textContent: nada se interpreta como HTML
      const del = document.createElement('button');
      del.textContent = '✕';
      del.title = 'Quitar';
      del.onclick = () => exSave(kind, config.exclusions[kind].filter((x) => x !== item));
      chip.append(label, del);
      box.appendChild(chip);
    }
  }
  $('ex-add-target').disabled = !state.engineUp || !state.target;
}

for (const form of document.querySelectorAll('.ex-form')) {
  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const input = form.querySelector('input');
    const v = input.value.trim();
    const kind = form.dataset.kind;
    if (!/^[\w.\- ]{1,80}$/.test(v)) { input.setCustomValidity('Solo letras, números, punto, guion y espacio'); input.reportValidity(); input.setCustomValidity(''); return; }
    if (!config.exclusions[kind].includes(v)) exSave(kind, [...config.exclusions[kind], v]);
    input.value = '';
  });
}
$('ex-add-target').addEventListener('click', () => {
  const proc = state.target?.proc;
  if (proc && !config.exclusions.processes.includes(proc)) exSave('processes', [...config.exclusions.processes, proc]);
});

window.onPanelPaint = () => { edSync(); exPaint(); };
