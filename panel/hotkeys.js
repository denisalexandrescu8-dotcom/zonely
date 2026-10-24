// Atajos de teclado: lista, cambio (modificadores + una tecla), restablecer.
// El motor publica ipc\hotkeys.json con cada atajo; aquí se editan y se guardan en zones.ini ([Hotkeys]).
// En macOS los modificadores se muestran con sus símbolos (⌃⌥⇧⌘) y en el orden habitual del Mac; # = Comando, ! = Opción, ^ = Control.
const IS_MAC = /Mac/i.test(navigator.platform || navigator.userAgent || '');
const MOD_LABEL = IS_MAC ? { '#': '⌘', '!': '⌥', '^': '⌃', '+': '⇧' } : { '#': 'Win', '!': 'Alt', '^': 'Ctrl', '+': t('Mayús') };
const MOD_ORDER = IS_MAC ? ['^', '!', '+', '#'] : ['#', '!', '^', '+'];
const KEY_LABEL = {
  Left: '←', Right: '→', Up: '↑', Down: '↓', BackSpace: IS_MAC ? '⌫' : t('Retroceso'), PgUp: t('RePág'), PgDn: t('AvPág'),
  Space: t('Espacio'), Enter: t('Intro'), Esc: 'Esc', Delete: t('Supr'), Insert: t('Ins'),
};

let hkList = [];            // [{ id, label, default, key, error }]
let hkKey = '';
let hkEditing = null;       // { id, mods: Set, key, capturing, msg }

// "#!+Left" → { mods: Set('#','!','+'), key: 'Left' }
function hkParse(s) {
  const m = String(s).match(/^([#!^+]*)(.*)$/);
  return { mods: new Set(m[1].split('').filter(Boolean)), key: m[2] };
}
function hkBuild(mods, key) { return MOD_ORDER.filter((c) => mods.has(c)).join('') + key; }

function keycaps(s) {
  const { mods, key } = hkParse(s);
  const box = document.createElement('span');
  box.className = 'hk-keys';
  const parts = MOD_ORDER.filter((c) => mods.has(c)).map((c) => MOD_LABEL[c]);
  parts.push(KEY_LABEL[key] || (key.length === 1 ? key.toUpperCase() : key));
  parts.forEach((p, i) => {
    if (i) { const plus = document.createElement('i'); plus.textContent = '+'; box.appendChild(plus); }
    const k = document.createElement('span'); k.className = 'keycap'; k.textContent = p; box.appendChild(k);
  });
  return box;
}

// Traduce el evento del navegador al nombre de tecla de AutoHotkey (o null si no se admite).
function eventToAhkKey(e) {
  const c = e.code;
  let m;
  if ((m = c.match(/^Key([A-Z])$/))) return m[1].toLowerCase();
  if ((m = c.match(/^Digit([0-9])$/))) return m[1];
  if ((m = c.match(/^Arrow(Left|Right|Up|Down)$/))) return m[1];
  if ((m = c.match(/^F([1-9]|1\d|2[0-4])$/))) return `F${m[1]}`;
  if ((m = c.match(/^Numpad([0-9])$/))) return `Numpad${m[1]}`;
  const map = { Backspace: 'BackSpace', Space: 'Space', Tab: 'Tab', Enter: 'Enter', Delete: 'Delete', Insert: 'Insert', Home: 'Home', End: 'End', PageUp: 'PgUp', PageDown: 'PgDn' };
  return map[c] || null;
}

function onCapture(e) {
  if (!hkEditing || !hkEditing.capturing) return;
  e.preventDefault(); e.stopPropagation();
  if (e.code === 'Escape') { hkEditing.capturing = false; hkEditing.msg = ''; paintHotkeys(true); return; }
  if (['ShiftLeft', 'ShiftRight', 'ControlLeft', 'ControlRight', 'AltLeft', 'AltRight', 'MetaLeft', 'MetaRight'].includes(e.code)) return;   // solo modificador: se sigue esperando
  const k = eventToAhkKey(e);
  hkEditing.capturing = false;
  if (!k) { hkEditing.msg = t('Esa tecla no se admite (usa letras, números, flechas, F1–F24, Retroceso, Espacio, Tab, Intro, Supr, Ins, Inicio, Fin, RePág, AvPág o el teclado numérico).'); }
  else { hkEditing.key = k; hkEditing.msg = ''; }
  paintHotkeys(true);
}
document.addEventListener('keydown', onCapture, true);

const hkSaved = new Set();      // atajos recién guardados: su fila parpadea en verde un momento

async function saveHotkeys(changes) {
  await window.zones.setHotkeys(changes);
  for (const id of Object.keys(changes)) hkSaved.add(id);
  setTimeout(() => hkSaved.clear(), 1500);
  await window.zones.send({ type: 'reload' });          // el motor relee zones.ini y registra los atajos nuevos
  setTimeout(refreshHotkeys, 2000);
}

function rowFor(h) {
  const row = document.createElement('div');
  const editing = hkEditing && hkEditing.id === h.id;
  row.className = 'hk-row' + (h.error ? ' bad' : '') + (editing ? ' editing' : '') + (hkSaved.has(h.id) ? ' saved' : '');

  const label = document.createElement('div');
  label.className = 'hk-label';
  label.textContent = t(h.label);
  if (h.error) { const s = document.createElement('small'); s.textContent = t('Aviso: {error}', { error: h.error }); label.appendChild(s); }

  if (!editing) {
    const btns = document.createElement('div'); btns.className = 'hk-btns';
    const change = document.createElement('button'); change.textContent = t('Cambiar');
    change.onclick = () => { const p = hkParse(h.key); hkEditing = { id: h.id, mods: p.mods, key: p.key, capturing: false, msg: '' }; paintHotkeys(true); };
    btns.appendChild(change);
    if (h.key !== h.default) {
      const reset = document.createElement('button'); reset.textContent = t('Restablecer'); reset.title = t('Vuelve a {key}', { key: h.default });
      reset.onclick = () => saveHotkeys({ [h.id]: h.default });
      btns.appendChild(reset);
    }
    row.append(label, keycaps(h.key), btns);
    return row;
  }

  // ---- modo edición ----
  const ed = document.createElement('div'); ed.className = 'hk-edit';
  for (const c of ['#', '!', '^', '+']) {
    const lb = document.createElement('label');
    const cb = document.createElement('input'); cb.type = 'checkbox'; cb.checked = hkEditing.mods.has(c);
    cb.onchange = () => { cb.checked ? hkEditing.mods.add(c) : hkEditing.mods.delete(c); paintHotkeys(true); };
    lb.append(cb, document.createTextNode(MOD_LABEL[c]));
    ed.appendChild(lb);
  }
  const cap = document.createElement('button'); cap.className = 'capture' + (hkEditing.capturing ? ' waiting' : '');
  cap.textContent = hkEditing.capturing ? t('Pulsa la tecla… (Esc cancela)') : t('Tecla: {key} · cambiar', { key: KEY_LABEL[hkEditing.key] || hkEditing.key.toUpperCase() });
  cap.onclick = () => { hkEditing.capturing = true; paintHotkeys(true); };
  ed.appendChild(cap);

  const preview = keycaps(hkBuild(hkEditing.mods, hkEditing.key));
  const msg = document.createElement('div'); msg.className = 'hk-msg'; msg.textContent = hkEditing.msg || '';
  const btns = document.createElement('div'); btns.className = 'hk-btns';
  const save = document.createElement('button'); save.className = 'primary'; save.textContent = t('Guardar');
  save.onclick = () => {
    const next = hkBuild(hkEditing.mods, hkEditing.key);
    if (!hkEditing.mods.size) { hkEditing.msg = t('Marca al menos un modificador (Win, Alt, Ctrl o Mayús).'); return paintHotkeys(true); }
    const clash = hkList.find((x) => x.id !== h.id && x.key.toLowerCase() === next.toLowerCase());
    if (clash) { hkEditing.msg = t('Ya lo usa «{label}».', { label: t(clash.label) }); return paintHotkeys(true); }
    const id = h.id; hkEditing = null;
    saveHotkeys({ [id]: next }).catch((e) => { hkEditing = { id, mods: hkParse(next).mods, key: hkParse(next).key, capturing: false, msg: String(e.message || e) }; paintHotkeys(true); });
    paintHotkeys(true);
  };
  const cancel = document.createElement('button'); cancel.textContent = t('Cancelar');
  cancel.onclick = () => { hkEditing = null; paintHotkeys(true); };
  btns.append(save, cancel);
  row.append(label, ed, preview, msg, btns);
  return row;
}

function paintHotkeys(force) {
  const key = JSON.stringify(hkList);
  if (!force && key === hkKey) return;
  if (!force && hkEditing) return;                      // no se repinta mientras se edita
  hkKey = key;
  const box = $('hk-list');
  box.innerHTML = '';
  if (!hkList.length) {
    const e = document.createElement('span'); e.className = 'empty';
    e.textContent = state.engineUp ? t('Esperando datos del motor…') : t('Motor detenido');
    box.appendChild(e);
    return;
  }
  for (const h of hkList) box.appendChild(rowFor(h));
}

async function refreshHotkeys() {
  if (document.hidden) return;
  const data = await window.zones.readIpc('hotkeys');
  if (Array.isArray(data)) { hkList = data; paintHotkeys(false); }
}

$('hk-reset-all').addEventListener('click', () => {
  const changes = {};
  for (const h of hkList) if (h.key !== h.default) changes[h.id] = h.default;
  if (Object.keys(changes).length) saveHotkeys(changes);
});

document.addEventListener('visibilitychange', refreshHotkeys);
refreshHotkeys();
setInterval(refreshHotkeys, 3000);
