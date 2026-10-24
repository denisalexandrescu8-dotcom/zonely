// Editor visual de perfiles (divisiones verticales y horizontales) y editor de exclusiones.
// Usa `config`, `state` y `ZONE_IDS` de renderer.js (mismo ámbito global).
//
// Un perfil es un reparto del monitor en hasta 6 zonas. Se edita como un árbol de divisiones: cada división parte un
// rectángulo en dos, en vertical (una al lado de la otra) o en horizontal (una encima de la otra), en una proporción `f`.
// Al guardar, el árbol se convierte en los rectángulos A, B, C… que lee el motor.

const GRID = 10;           // las líneas saltan de 10 en 10 px
const MIN_W = 300;         // px: ninguna zona puede quedar más estrecha...
const MIN_H = 200;         // ...ni más baja que esto

const ed = { reload: false, profile: null, tree: null, selected: 'A', savedKey: '', structure: '', sourceKey: '', built: false, handles: [] };

const edEl = {
  monitor: $('ed-monitor'), select: $('ed-profile'), info: $('ed-info'), msg: $('ed-msg'),
  splitV: $('ed-split-v'), splitH: $('ed-split-h'), remove: $('ed-remove'),
  save: $('ed-save'), reset: $('ed-reset'), width: $('ed-w'), height: $('ed-h'),
  name: $('ed-name'), create: $('ed-create'), copy: $('ed-copy'), del: $('ed-delete'),
};

// ---------- árbol <-> rectángulos ----------
const leaf = (id) => ({ id });
const isLeaf = (n) => n.id !== undefined;

// Rectángulos de cada zona a partir del árbol (las dos mitades de cada corte suman exactamente el rectángulo).
function edLayout(node, b, out = {}, cuts = []) {
  if (isLeaf(node)) { out[node.id] = { ...b }; return { zones: out, cuts }; }
  if (node.dir === 'v') {
    const cut = Math.round(node.f * b.w);
    cuts.push({ node, b, x: b.x + cut, y: b.y, len: b.h });
    edLayout(node.a, { x: b.x, y: b.y, w: cut, h: b.h }, out, cuts);
    edLayout(node.b, { x: b.x + cut, y: b.y, w: b.w - cut, h: b.h }, out, cuts);
  } else {
    const cut = Math.round(node.f * b.h);
    cuts.push({ node, b, x: b.x, y: b.y + cut, len: b.w });
    edLayout(node.a, { x: b.x, y: b.y, w: b.w, h: cut }, out, cuts);
    edLayout(node.b, { x: b.x, y: b.y + cut, w: b.w, h: b.h - cut }, out, cuts);
  }
  return { zones: out, cuts };
}

const edFull = () => ({ x: 0, y: 0, w: config.monitor.w, h: config.monitor.h });
const edRects = () => edLayout(ed.tree, edFull());
const same = (a, b) => Math.abs(a - b) <= 2;

// Reconstruye el árbol de divisiones de un perfil existente. Devuelve null si el reparto no se puede cortar de lado a lado
// (por ejemplo, si se editó a mano en zones.ini): ese perfil se muestra pero no se edita.
function edTreeFromZones(zones, b) {
  const items = Object.entries(zones).filter(([, z]) => z).map(([id, z]) => ({ id, ...z }));
  function build(list, box) {
    if (list.length === 1) {
      const z = list[0];
      return same(z.x, box.x) && same(z.y, box.y) && same(z.w, box.w) && same(z.h, box.h) ? leaf(z.id) : null;
    }
    for (const dir of ['v', 'h']) {
      const key = dir === 'v' ? 'x' : 'y', size = dir === 'v' ? 'w' : 'h';
      const cuts = [...new Set(list.map((z) => z[key]))].filter((c) => c > box[key] + 1).sort((p, q) => p - q);
      for (const cut of cuts) {
        const first = list.filter((z) => z[key] + z[size] <= cut + 1);
        const second = list.filter((z) => z[key] >= cut - 1);
        if (!first.length || !second.length || first.length + second.length !== list.length) continue;
        const boxA = { ...box, [size]: cut - box[key] };
        const boxB = { ...box, [key]: cut, [size]: box[key] + box[size] - cut };
        const a = build(first, boxA), c = build(second, boxB);
        if (a && c) return { dir, f: (cut - box[key]) / box[size], a, b: c };
      }
    }
    return null;
  }
  return items.length ? build(items, b) : null;
}

const edLeaves = (node = ed.tree) => (isLeaf(node) ? [node] : [...edLeaves(node.a), ...edLeaves(node.b)]);
const edKey = () => JSON.stringify(Object.entries(edRects().zones).sort());

// ---------- construcción y pintado ----------
// Se rehacen los elementos solo cuando cambia la estructura (dividir, quitar, cambiar de perfil); al arrastrar solo se mueven.
function edBuild() {
  edEl.monitor.innerHTML = '';
  ed.handles = [];
  for (const l of edLeaves()) {
    const z = document.createElement('div');
    z.className = `zone ${l.id}`;
    z.dataset.id = l.id;
    z.innerHTML = `<span class="letter">${l.id}</span><span class="dim"></span>`;
    z.addEventListener('click', () => { ed.selected = l.id; edPaint(); });
    edEl.monitor.appendChild(z);
  }
  for (const cut of edRects().cuts) {
    const h = document.createElement('div');
    h.className = `handle ${cut.node.dir}`;
    h.addEventListener('pointerdown', (e) => { h.setPointerCapture(e.pointerId); });
    h.addEventListener('pointermove', (e) => {
      if (!h.hasPointerCapture(e.pointerId)) return;
      const r = edEl.monitor.getBoundingClientRect();
      const b = ed.handles.find((x) => x.el === h).cut.b;
      if (cut.node.dir === 'v') {
        const px = ((e.clientX - r.left) / r.width) * config.monitor.w - b.x;
        cut.node.f = edClamp(px, b.w, MIN_W) / b.w;
      } else {
        const py = ((e.clientY - r.top) / r.height) * config.monitor.h - b.y;
        cut.node.f = edClamp(py, b.h, MIN_H) / b.h;
      }
      edPaint();
    });
    edEl.monitor.appendChild(h);
    ed.handles.push({ el: h, cut });
  }
  ed.structure = edLeaves().map((l) => l.id).join('') + JSON.stringify(edShape(ed.tree));
}

const edShape = (n) => (isLeaf(n) ? n.id : [n.dir, edShape(n.a), edShape(n.b)]);
const edClamp = (v, total, min) => Math.min(total - min, Math.max(min, Math.round(v / GRID) * GRID));

function edPaint() {
  const { w, h } = config.monitor;
  edEl.monitor.style.aspectRatio = `${w} / ${h}`;
  const { zones, cuts } = edRects();
  for (const el of edEl.monitor.querySelectorAll('.zone')) {
    const z = zones[el.dataset.id];
    el.style.left = pct(z.x, w);
    el.style.top = pct(z.y, h);
    el.style.width = pct(z.w, w);
    el.style.height = pct(z.h, h);
    el.querySelector('.dim').textContent = `${z.w} × ${z.h}`;
    el.classList.toggle('sel', el.dataset.id === ed.selected);
  }
  cuts.forEach((c, i) => {                           // el orden de los cortes es el de la construcción
    const el = ed.handles[i].el;
    ed.handles[i].cut = c;
    if (c.node.dir === 'v') {
      el.style.left = pct(c.x, w); el.style.top = pct(c.y, h); el.style.height = pct(c.len, h); el.style.width = '';
    } else {
      el.style.left = pct(c.x, w); el.style.top = pct(c.y, h); el.style.width = pct(c.len, w); el.style.height = '';
    }
  });

  const sel = zones[ed.selected];
  const count = Object.keys(zones).length;
  const editable = !!ed.tree;
  edEl.info.textContent = sel ? t('Zona {zone} · {w} × {h}', { zone: ed.selected, w: sel.w, h: sel.h }) : '';
  edEl.splitV.disabled = !sel || count >= ZONE_IDS.length || sel.w < MIN_W * 2;
  edEl.splitH.disabled = !sel || count >= ZONE_IDS.length || sel.h < MIN_H * 2;
  edEl.remove.disabled = !sel || count < 2;
  for (const [input, dir, value] of [[edEl.width, 'v', sel && sel.w], [edEl.height, 'h', sel && sel.h]]) {
    input.disabled = !editable || !edCutOf(dir);
    if (document.activeElement !== input) input.value = value ?? '';
  }
  const dirty = edKey() !== ed.savedKey;
  edEl.save.disabled = !dirty;
  edEl.reset.disabled = !dirty;
  edEl.del.disabled = config.profiles.length < 2;
  edEl.copy.disabled = !editable;
}

// Mensaje bajo el editor (errores y avisos); se borra solo.
let edMsgTimer = 0;
function edNote(text) {
  edEl.msg.textContent = text || '';
  clearTimeout(edMsgTimer);
  if (text) edMsgTimer = setTimeout(() => { edEl.msg.textContent = ''; }, 6000);
}

// ---------- operaciones ----------
// El corte más cercano, en esa dirección, que toca la zona elegida (null si la zona ya ocupa todo ese eje).
function edCutOf(dir) {
  const path = (node, trail = []) => {
    if (isLeaf(node)) return node.id === ed.selected ? trail : null;
    return path(node.a, [...trail, { node, side: 'a' }]) || path(node.b, [...trail, { node, side: 'b' }]);
  };
  const trail = ed.tree && path(ed.tree);
  if (!trail) return null;
  const hit = [...trail].reverse().find((s) => s.node.dir === dir);
  return hit ? { ...hit, b: edRects().cuts.find((c) => c.node === hit.node).b } : null;
}

// Pone el ancho o el alto exacto de la zona elegida moviendo ese corte (la contigua se ajusta).
function edSetSize(dir, value) {
  const cut = edCutOf(dir);
  const px = parseInt(value, 10);
  if (!cut || !Number.isFinite(px)) return edPaint();
  const total = dir === 'v' ? cut.b.w : cut.b.h, min = dir === 'v' ? MIN_W : MIN_H;
  const own = Math.min(total - min, Math.max(min, px));
  if (own !== px) edNote(t('Entre {min} y {max} px', { min, max: total - min }));
  cut.node.f = (cut.side === 'a' ? own : total - own) / total;
  edPaint();
}
function edReplace(node, target, replacement) {      // devuelve el árbol con `target` sustituido por `replacement`
  if (node === target) return replacement;
  if (isLeaf(node)) return node;
  return { ...node, a: edReplace(node.a, target, replacement), b: edReplace(node.b, target, replacement) };
}

function edSplit(dir) {
  const l = edLeaves().find((x) => x.id === ed.selected);
  const rect = edRects().zones[ed.selected];
  if (!l || !rect || edLeaves().length >= ZONE_IDS.length) return;
  const total = dir === 'v' ? rect.w : rect.h;
  const f = edClamp(total / 2, total, dir === 'v' ? MIN_W : MIN_H) / total;
  ed.tree = edReplace(ed.tree, l, { dir, f, a: leaf(l.id), b: leaf(ZONE_IDS[edLeaves().length]) });
  edBuild();
  edPaint();
}

// Quita la zona elegida: la contigua ocupa su sitio. Las letras se vuelven a numerar para que sigan seguidas.
function edRemove() {
  if (edLeaves().length < 2) return;
  const drop = (node) => {
    if (isLeaf(node)) return node;
    if (isLeaf(node.a) && node.a.id === ed.selected) return node.b;
    if (isLeaf(node.b) && node.b.id === ed.selected) return node.a;
    return { ...node, a: drop(node.a), b: drop(node.b) };
  };
  ed.tree = drop(ed.tree);
  const order = edLeaves().map((l) => l.id).sort();
  const rename = Object.fromEntries(order.map((id, i) => [id, ZONE_IDS[i]]));
  const relabel = (n) => (isLeaf(n) ? leaf(rename[n.id]) : { ...n, a: relabel(n.a), b: relabel(n.b) });
  ed.tree = relabel(ed.tree);
  ed.selected = 'A';
  edBuild();
  edPaint();
}

// ---------- sincronía con zones.ini (se llama desde renderer.js en cada refresco) ----------
function edSync() {
  if (!ed.built) { ed.built = true; }
  const ids = config.profiles.map((p) => p.id);
  if (ids.join('\n') !== [...edEl.select.options].map((o) => o.value).join('\n')) {
    const keep = ed.profile;
    edEl.select.innerHTML = '';
    for (const id of ids) edEl.select.add(new Option(id, id));
    ed.profile = ids.includes(keep) ? keep : null;
    ed.sourceKey = '';
  }
  if (!ed.profile || !ids.includes(ed.profile)) {
    ed.profile = state.profile && ids.includes(state.profile) ? state.profile : ids[0];
    ed.reload = true;
  }
  edEl.select.value = ed.profile;

  // Sin cambios pendientes se sigue lo que diga el .ini (si lo cambió otra cosa, por ejemplo otro monitor).
  const p = config.profiles.find((x) => x.id === ed.profile);
  const sourceKey = JSON.stringify([ed.profile, p.zones, config.monitor.w, config.monitor.h]);
  const dirty = ed.tree && edKey() !== ed.savedKey;
  if (ed.reload || (sourceKey !== ed.sourceKey && !dirty)) {
    ed.reload = false;
    ed.sourceKey = sourceKey;
    ed.tree = edTreeFromZones(p.zones, edFull());
    if (ed.tree) {
      ed.savedKey = edKey();
      if (!edLeaves().some((l) => l.id === ed.selected)) ed.selected = 'A';
    }
    edBuild();
  }
  if (ed.tree) edPaint();
  const editable = !!ed.tree;
  edEl.monitor.classList.toggle('readonly', !editable);
  if (!editable) edEl.info.textContent = t('Este reparto no se puede editar aquí (se hizo a mano en zones.ini).');
  for (const b of [edEl.splitV, edEl.splitH, edEl.remove, edEl.save, edEl.reset]) if (!editable) b.disabled = true;
}

edEl.select.addEventListener('change', () => {
  ed.profile = edEl.select.value;
  ed.reload = true;
  ed.selected = 'A';
  edSync();
});
edEl.width.addEventListener('change', () => edSetSize('v', edEl.width.value));
edEl.height.addEventListener('change', () => edSetSize('h', edEl.height.value));
edEl.splitV.addEventListener('click', () => edSplit('v'));
edEl.splitH.addEventListener('click', () => edSplit('h'));
edEl.remove.addEventListener('click', edRemove);
edEl.reset.addEventListener('click', () => { ed.reload = true; edSync(); });
edEl.save.addEventListener('click', async () => {
  edEl.save.disabled = true;
  try {
    await window.zones.saveProfile({ id: ed.profile, zones: edRects().zones });
    ed.savedKey = edKey();
    await window.zones.send({ type: 'reload' });      // el motor relee zones.ini (conserva perfil y interruptores)
    edNote(t('Guardado.'));
  } catch (err) {
    edNote(String(err && err.message || err).replace(/^Error invoking remote method '[^']+': (Error: )?/, ''));
  }
  setTimeout(refresh, 1500);
});

// Perfiles nuevos: en blanco (pantalla completa) o una copia del que se está viendo.
async function edCreate(from) {
  const name = edEl.name.value.trim();
  try {
    await window.zones.createProfile({ id: name, from });
    edEl.name.value = '';
    ed.profile = name;
    ed.reload = true;
    edNote(t('Perfil «{name}» creado. Divide la pantalla y guarda.', { name }));
  } catch (err) {
    edNote(String(err && err.message || err).replace(/^Error invoking remote method '[^']+': (Error: )?/, ''));
  }
  setTimeout(refresh, 400);
}
edEl.create.addEventListener('click', () => edCreate(''));
edEl.copy.addEventListener('click', () => edCreate(ed.profile));
edEl.name.addEventListener('keydown', (e) => { if (e.key === 'Enter') edCreate(''); });

// Borrar pide una segunda pulsación (sin ventanas emergentes).
let edDeleteArmed = 0;
edEl.del.addEventListener('click', async () => {
  if (!edDeleteArmed) {
    edEl.del.textContent = t('¿Eliminar «{name}»?', { name: ed.profile });
    edDeleteArmed = setTimeout(() => { edDeleteArmed = 0; edEl.del.textContent = t('Eliminar perfil'); }, 4000);
    return;
  }
  clearTimeout(edDeleteArmed);
  edDeleteArmed = 0;
  edEl.del.textContent = t('Eliminar perfil');
  try {
    await window.zones.deleteProfile({ id: ed.profile });
    ed.profile = null;
    ed.reload = true;
    edNote(t('Perfil eliminado.'));
  } catch (err) {
    edNote(String(err && err.message || err).replace(/^Error invoking remote method '[^']+': (Error: )?/, ''));
  }
  setTimeout(refresh, 400);
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
      e.textContent = t('Ninguna');
      box.appendChild(e);
    }
    for (const item of config.exclusions[kind]) {
      const chip = document.createElement('span');
      chip.className = 'chip x';
      const label = document.createElement('span');
      label.textContent = item;                       // textContent: nada se interpreta como HTML
      const del = document.createElement('button');
      del.textContent = '✕';
      del.title = t('Quitar');
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
    if (!/^[\w.\- ]{1,80}$/.test(v)) { input.setCustomValidity(t('Solo letras, números, punto, guion y espacio')); input.reportValidity(); input.setCustomValidity(''); return; }
    if (!config.exclusions[kind].includes(v)) exSave(kind, [...config.exclusions[kind], v]);
    input.value = '';
  });
}
$('ex-add-target').addEventListener('click', () => {
  const proc = state.target?.proc;
  if (proc && !config.exclusions.processes.includes(proc)) exSave('processes', [...config.exclusions.processes, proc]);
});

window.onPanelPaint = () => { edSync(); exPaint(); };
