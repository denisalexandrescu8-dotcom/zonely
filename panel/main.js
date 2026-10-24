// Panel de control del gestor de zonas (proceso principal de Electron).
// El motor es el script AutoHotkey; aquí solo leemos zones.ini / ipc\state.json
// y escribimos órdenes en ipc\cmd.txt.
const { app, BrowserWindow, ipcMain, shell, screen } = require('electron');
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const updater = require('./updater');

// El motor lanza «Zonely --background-update» para buscar e instalar actualizaciones sin enseñar ninguna ventana.
const BACKGROUND = process.argv.includes('--background-update');

// Una sola ventana del panel: si se vuelve a abrir (menú Inicio, doble clic en el icono de la bandeja…), se trae al frente la que ya hay.
const gotLock = app.requestSingleInstanceLock();
if (!gotLock) app.quit();
app.on('second-instance', () => {
  if (!mainWindow) return;
  if (mainWindow.isMinimized()) mainWindow.restore();
  mainWindow.show();
  mainWindow.focus();
});

const ROOT = path.join(__dirname, '..');

// Datos del usuario (ajustes, registro, comunicación con el motor): %APPDATA%\Zonely, igual que el motor
// (lib\Paths.ahk). Así una actualización o un instalador nuevo nunca los pisa. ZONELY_DATA cambia la carpeta.
const DATA_DIR = process.env.ZONELY_DATA || path.join(process.env.APPDATA || app.getPath('appData'), 'Zonely');
const INI = path.join(DATA_DIR, 'zones.ini');
const IPC_DIR = path.join(DATA_DIR, 'ipc');
try { fs.mkdirSync(DATA_DIR, { recursive: true }); } catch { /* sin permisos: el panel dirá que no encuentra zones.ini */ }

// Perfiles de fábrica para un monitor de w × h píxeles (zonas mínimas de 400 px).
// La misma regla está en lib/Paths.ahk (DefaultProfilesText): si cambias una, cambia la otra.
function defaultProfiles(w, h) {
  const min = 400;
  let out = '';
  const uw = Math.round(h * 43 / 18);                                   // pantalla 21:9 (3440×1440) + columna
  if (uw >= min && w - uw >= min)
    out += `[Profile.ultrawide]\n; A = pantalla 21:9 a la izquierda, B = columna a la derecha\nA=0,0,${uw},${h}\nB=${uw},0,${w - uw},${h}\n\n`;
  const half = Math.floor(w / 2);
  if (half >= min)
    out += `[Profile.dual]\n; Dos mitades iguales\nA=0,0,${half},${h}\nB=${half},0,${w - half},${h}\n\n`;
  const c = Math.round(h * 16 / 9);                                     // pantalla 16:9 en el centro
  const side = Math.floor((w - c) / 2);
  if (side >= min)
    out += `[Profile.centrado]\n; Pantalla 16:9 en el centro (A) y una zona a cada lado (B derecha, C izquierda)\nA=${side},0,${c},${h}\nB=${side + c},0,${w - side - c},${h}\nC=0,0,${side},${h}\n\n`;
  out += `[Profile.normal]\n; Pantalla normal: sin zonas (no hay B). Ni atajos de colocación, ni encaje, ni vigilante.\nA=0,0,${w},${h}\n`;
  return out;
}

// Primer arranque: crea zones.ini desde la plantilla con el tamaño (físico) del monitor principal.
// Hay que llamarla con la aplicación lista (necesita la API de pantallas).
function ensureIni() {
  try {
    if (fs.existsSync(INI)) return;
    const tpl = path.join(ROOT, 'zones.template.ini');
    if (!fs.existsSync(tpl)) return;
    const d = screen.getPrimaryDisplay();
    const scale = process.platform === 'darwin' ? 1 : d.scaleFactor;      // en macOS las coordenadas son puntos, no píxeles físicos
    const w = Math.round(d.bounds.width * scale), h = Math.round(d.bounds.height * scale);
    const txt = fs.readFileSync(tpl, 'utf8')
      .replace('{{WIDTH}}', w).replace('{{HEIGHT}}', h).replace('{{PROFILES}}', defaultProfiles(w, h));
    if (!fs.existsSync(INI)) fs.writeFileSync(INI, txt, { flag: 'wx' });    // 'wx': si el motor se adelantó, no se pisa
  } catch { /* sin permisos o ya creado por el motor */ }
}

// El apartado Registro (registro de actividad y depuración) es solo para desarrollo: en la versión instalada
// no se ve. Se puede forzar con ZONELY_DEV=1.
const IS_DEV = !app.isPackaged || process.env.ZONELY_DEV === '1';

// ---- zones.ini -> objeto -------------------------------------
function parseIni(text) {
  const out = {};
  let section = null;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith(';')) continue;
    const m = line.match(/^\[(.+)\]$/);
    if (m) { section = m[1]; out[section] = {}; continue; }
    const kv = line.match(/^([^=]+)=(.*)$/);
    if (kv && section) out[section][kv[1].trim()] = kv[2].trim();
  }
  return out;
}

function parseZone(s) {
  const [x, y, w, h] = String(s).split(',').map((n) => parseInt(n, 10));
  return { x, y, w, h };
}

const ZONE_KEYS = ['A', 'B', 'C', 'D', 'E', 'F'];

// Zonas de una sección [Profile.xxx]: las letras tienen que ir seguidas (como en los motores); las que faltan son null.
function readZones(section) {
  const zones = {};
  let more = true;
  for (const key of ZONE_KEYS) {
    more = more && !!section[key];
    zones[key] = more ? parseZone(section[key]) : null;
  }
  return zones;
}

// ---- registro compartido con el motor (logs/gestor.log) ----------
const LOG_DIR = path.join(DATA_DIR, 'logs');
const LOG_FILE = path.join(LOG_DIR, 'gestor.log');
function stamp() {
  const d = new Date(), p = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
}
function appendLog(level, msg) {
  try {
    fs.mkdirSync(LOG_DIR, { recursive: true });
    fs.appendFileSync(LOG_FILE, `${stamp()} [panel] ${level} ${String(msg).replace(/[\r\n]+/g, ' ').slice(0, 500)}\n`);
  } catch { /* si el registro falla, no tumbamos el panel */ }
}
process.on('uncaughtException', (e) => appendLog('ERROR', `uncaughtException: ${e && e.stack || e}`));
process.on('unhandledRejection', (e) => appendLog('ERROR', `unhandledRejection: ${e && e.stack || e}`));

function readVersion() {
  try { return fs.readFileSync(path.join(ROOT, 'version.txt'), 'utf8').trim(); } catch { return '?'; }
}

function readLogTail(n = 300) {
  try {
    const lines = fs.readFileSync(LOG_FILE, 'utf8').split(/\r?\n/).filter(Boolean);
    return lines.slice(-n);
  } catch { return []; }
}

const splitList = (s) => String(s ?? '').split(',').map((x) => x.trim()).filter(Boolean);

function readConfig() {
  const ini = parseIni(fs.readFileSync(INI, 'utf8'));
  const profiles = Object.keys(ini)
    .filter((s) => s.startsWith('Profile.'))
    .map((s) => ({
      id: s.slice(8),
      gameZone: (() => { const g = String(ini[s].GameZone ?? 'auto').toUpperCase(); return g === 'AUTO' ? 'auto' : g; })(),
      zones: readZones(ini[s]),                       // A, B, C… seguidas (hasta 6); sin B = pantalla normal, sin zonas
    }));
  return {
    monitor: { w: parseInt(ini.Monitor?.Width ?? 5120, 10), h: parseInt(ini.Monitor?.Height ?? 1440, 10), id: ini.Monitor?.Id ?? '' },
    profiles,
    startProfile: ini.General?.Profile ?? 'ultrawide',
    version: readVersion(),
    options: {
      halves: String(ini.Snap?.Halves ?? '0') === '1',
      restore: String(ini.General?.RestoreOnLeave ?? '1') === '1',
      menubar: String(ini.General?.MenuBarIcon ?? '1') === '1',          // solo macOS: icono en la barra de menús
      fullscreen: String(ini.General?.FullScreenToZone ?? '1') === '1',  // solo macOS: sacar de pantalla completa nativa y colocar en la zona
      snapkey: ['Shift', 'Ctrl', 'Alt'].includes(ini.Snap?.Key) ? ini.Snap.Key : 'Shift',
      language: LANGS.includes(ini.General?.Language) ? ini.General.Language : 'auto',
      autoupdate: String(ini.General?.AutoUpdate ?? '1') === '1',        // actualizar automáticamente
    },
    exclusions: { processes: splitList(ini.Exclusions?.Processes), classes: splitList(ini.Exclusions?.Classes) },
  };
}

// ---- escritura de zones.ini (conserva comentarios y orden) ------
function setIniValue(text, section, key, value) {
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const lines = text.split(/\r?\n/);
  let secStart = -1, secEnd = lines.length, done = false;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    const m = t.match(/^\[(.+)\]$/);
    if (m) {
      if (secStart >= 0) { secEnd = i; break; }
      if (m[1] === section) secStart = i;
      continue;
    }
    if (secStart >= 0 && !t.startsWith(';') && t.includes('=') && t.split('=')[0].trim() === key) {
      lines[i] = `${key}=${value}`;
      done = true;
    }
  }
  if (!done) {
    if (secStart < 0) { lines.push('', `[${section}]`, `${key}=${value}`); }
    else {
      let at = secEnd;
      while (at > secStart + 1 && lines[at - 1].trim() === '') at--;   // tras la última línea con contenido
      lines.splice(at, 0, `${key}=${value}`);
    }
  }
  return lines.join(eol);
}

function writeIni(edit) {
  const raw = fs.readFileSync(INI, 'utf8');
  const out = edit(raw);
  const tmp = INI + '.tmp';
  fs.writeFileSync(tmp, out, 'utf8');
  fs.renameSync(tmp, INI);
}

// ---- perfiles: editar, crear, borrar y un conjunto por monitor ------------------------------------------------------
const NAME_RE = /^[\p{L}\p{N} _-]{1,24}$/u;
const zoneText = (z) => `${z.x},${z.y},${z.w},${z.h}`;

function removeIniKey(text, section, key) {
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const lines = text.split(/\r?\n/);
  let inSec = false;
  return lines.filter((raw) => {
    const t = raw.trim();
    const m = t.match(/^\[(.+)\]$/);
    if (m) { inSec = m[1] === section; return true; }
    return !(inSec && !t.startsWith(';') && t.includes('=') && t.split('=')[0].trim() === key);
  }).join(eol);
}

function removeIniSection(text, section) {
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  const out = [];
  let skip = false;
  for (const raw of text.split(/\r?\n/)) {
    const m = raw.trim().match(/^\[(.+)\]$/);
    if (m) skip = m[1] === section;
    if (!skip) out.push(raw);
  }
  return out.join(eol);
}

function appendSection(text, section, lines) {
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  return text.replace(/\s*$/, '') + eol + eol + `[${section}]` + eol + lines.join(eol) + eol;
}

// Las zonas de un perfil: letras A, B, C… seguidas, dentro del monitor, sin solaparse y no demasiado pequeñas.
function validateZones(zones, mon) {
  const ids = ZONE_KEYS.filter((k) => zones && zones[k]);
  if (!ids.length || ids.some((k, i) => k !== ZONE_KEYS[i])) throw new Error('Las zonas tienen que ser A, B, C… seguidas');
  const rects = ids.map((k) => zones[k]);
  for (const z of rects) {
    if (![z.x, z.y, z.w, z.h].every(Number.isInteger) || z.x < 0 || z.y < 0 || z.w < 100 || z.h < 100 || z.x + z.w > mon.w || z.y + z.h > mon.h)
      throw new Error('Una zona se sale del monitor o es demasiado pequeña');
  }
  for (let i = 0; i < rects.length; i++)
    for (let j = i + 1; j < rects.length; j++) {
      const a = rects[i], b = rects[j];
      if (a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h) throw new Error('Dos zonas se solapan');
    }
  return ids;
}

function saveProfile({ id, zones }) {
  const cfg = readConfig();
  const p = cfg.profiles.find((x) => x.id === id);
  if (!p) throw new Error('Perfil no válido');
  const ids = validateZones(zones, cfg.monitor);
  writeIni((t) => {
    for (const k of ZONE_KEYS) {
      t = ids.includes(k) ? setIniValue(t, `Profile.${id}`, k, zoneText(zones[k])) : removeIniKey(t, `Profile.${id}`, k);
    }
    if (p.gameZone !== 'auto' && !ids.includes(p.gameZone)) t = setIniValue(t, `Profile.${id}`, 'GameZone', 'auto');
    return t;
  });
}

function createProfile({ id, from }) {
  id = String(id || '').trim();
  const cfg = readConfig();
  if (!NAME_RE.test(id)) throw new Error('El nombre puede llevar letras, números, espacios, guion y guion bajo (hasta 24)');
  if (cfg.profiles.some((p) => p.id.toLowerCase() === id.toLowerCase())) throw new Error('Ya existe un perfil con ese nombre');
  const src = cfg.profiles.find((p) => p.id === from);
  const zones = src ? src.zones : { A: { x: 0, y: 0, w: cfg.monitor.w, h: cfg.monitor.h } };
  const lines = ZONE_KEYS.filter((k) => zones[k]).map((k) => `${k}=${zoneText(zones[k])}`);
  writeIni((t) => appendSection(t, `Profile.${id}`, lines));
}

function deleteProfile({ id }) {
  const cfg = readConfig();
  if (!cfg.profiles.some((p) => p.id === id)) throw new Error('Perfil no válido');
  if (cfg.profiles.length < 2) throw new Error('Tiene que quedar al menos un perfil');
  const rest = cfg.profiles.filter((p) => p.id !== id);
  const fallback = rest[0].id;
  if (readState().profile === id) { try { sendCommand({ type: 'profile', value: fallback }); } catch { /* motor parado */ } }
  writeIni((t) => {
    t = removeIniSection(t, `Profile.${id}`);
    return cfg.startProfile === id ? setIniValue(t, 'General', 'Profile', fallback) : t;
  });
}

// Cada monitor guarda su propio conjunto de perfiles (y cuál usa): al cambiar de monitor se guarda el del que se deja y
// se carga el del nuevo; si el nuevo no tiene, empieza con una copia de los actuales ajustados a su tamaño.
const MONITORS_DIR = path.join(DATA_DIR, 'monitors');
const monitorFile = (id) => path.join(MONITORS_DIR, String(id).replace(/[^\w-]+/g, '_') + '.json');

function scaleZones(zones, sx, sy) {
  const out = {};
  for (const k of ZONE_KEYS) {
    const z = zones[k];
    if (!z) continue;
    const x0 = Math.round(z.x * sx), x1 = Math.round((z.x + z.w) * sx), y0 = Math.round(z.y * sy), y1 = Math.round((z.y + z.h) * sy);
    out[k] = { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
  }
  return out;
}

function setMonitor(id) {
  const st = readState();
  const mon = (st.monitors || []).find((m) => m.id === id);
  if (!st.engineUp || !mon) throw new Error('Monitor no disponible: enciende el motor y vuelve a probar');
  const cfg = readConfig();
  const current = cfg.monitor.id || (st.monitors.find((m) => m.primary) || {}).id || '';
  const active = st.profile && cfg.profiles.some((p) => p.id === st.profile) ? st.profile : cfg.startProfile;
  if (current === mon.id && cfg.monitor.w === mon.w && cfg.monitor.h === mon.h) return;

  // 1) se guarda el conjunto del monitor que se deja
  try {
    fs.mkdirSync(MONITORS_DIR, { recursive: true });
    fs.writeFileSync(monitorFile(current), JSON.stringify({ w: cfg.monitor.w, h: cfg.monitor.h, active, profiles: cfg.profiles }));
  } catch (e) { appendLog('WARN', `No pude guardar los perfiles del monitor: ${e.message}`); }

  // 2) se carga el del monitor nuevo (o se parte de una copia de los actuales)
  let saved = null;
  try { saved = JSON.parse(fs.readFileSync(monitorFile(mon.id), 'utf8')); } catch { /* es la primera vez que se elige */ }
  const base = saved && Array.isArray(saved.profiles) && saved.profiles.length ? saved : { w: cfg.monitor.w, h: cfg.monitor.h, active, profiles: cfg.profiles };
  const sx = mon.w / base.w, sy = mon.h / base.h;
  const profiles = base.profiles.map((p) => ({ id: p.id, gameZone: p.gameZone, zones: scaleZones(p.zones, sx, sy) }));
  const nextActive = profiles.some((p) => p.id === base.active) ? base.active : profiles[0].id;

  writeIni((t) => {
    for (const p of cfg.profiles) t = removeIniSection(t, `Profile.${p.id}`);
    for (const p of profiles) {
      const lines = ZONE_KEYS.filter((k) => p.zones[k]).map((k) => `${k}=${zoneText(p.zones[k])}`);
      if (p.gameZone && p.gameZone !== 'auto') lines.push(`GameZone=${p.gameZone}`);
      t = appendSection(t, `Profile.${p.id}`, lines);
    }
    t = setIniValue(t, 'Monitor', 'Width', String(mon.w));
    t = setIniValue(t, 'Monitor', 'Height', String(mon.h));
    t = setIniValue(t, 'Monitor', 'Id', mon.id);
    return setIniValue(t, 'General', 'Profile', nextActive);
  });
  appendLog('INFO', `Monitor elegido: ${mon.name} (${mon.w}x${mon.h}) · perfil ${nextActive}`);
  // El motor recarga zones.ini en un par de segundos; después se le pide el perfil de este monitor.
  setTimeout(() => { try { sendCommand({ type: 'profile', value: nextActive }); } catch { /* motor parado */ } }, 3500);
}

function setExclusions({ processes, classes }) {
  const ok = (a) => Array.isArray(a) && a.length <= 100 && a.every((s) => typeof s === 'string' && /^[\w.\- ]{1,80}$/.test(s));
  if (!ok(processes) || !ok(classes)) throw new Error('Exclusiones no válidas');
  writeIni((t) => {
    t = setIniValue(t, 'Exclusions', 'Processes', processes.join(','));
    return setIniValue(t, 'Exclusions', 'Classes', classes.join(','));
  });
}

// ---- estado del motor ----------------------------------------
function readState() {
  try {
    const s = JSON.parse(fs.readFileSync(path.join(IPC_DIR, 'state.json'), 'utf8'));
    const age = Date.now() / 1000 - s.ts;
    return { ...s, engineUp: age < 6 };   // el motor late cada 2 s
  } catch {
    return { engineUp: false };
  }
}

// ---- órdenes al motor (lista cerrada, nada de texto libre) ----
function sendCommand(cmd) {
  const profiles = readConfig().profiles.map((p) => p.id);
  const ok =
    (cmd.type === 'profile' && profiles.includes(cmd.value)) ||
    (['watcher', 'snap', 'halves', 'restore'].includes(cmd.type) && (cmd.value === 'on' || cmd.value === 'off')) ||
    (cmd.type === 'dim' && [...ZONE_KEYS, 'off'].includes(cmd.value)) ||
    (cmd.type === 'dimlevel' && /^(100|[1-9]?\d)$/.test(String(cmd.value))) ||
    cmd.type === 'watch' ||
    cmd.type === 'reload' ||
    cmd.type === 'quit';                              // apagar el motor (Ajustes → Motor)
  if (!ok) throw new Error('Orden no válida');
  const line = ['reload', 'watch', 'quit'].includes(cmd.type) ? cmd.type : `${cmd.type} ${cmd.value}`;
  if (cmd.type === 'quit') { try { fs.writeFileSync(ENGINE_STOPPED, ''); } catch { /* sin marca, solo afecta al arranque automático del panel en macOS */ } }
  fs.mkdirSync(IPC_DIR, { recursive: true });
  const tmp = path.join(IPC_DIR, 'cmd.tmp');
  fs.writeFileSync(tmp, line + '\n');
  fs.renameSync(tmp, path.join(IPC_DIR, 'cmd.txt'));
}
// Marca de «apagado a mano»: en macOS el panel arranca el motor al abrirse, salvo que el usuario lo haya apagado desde Ajustes.
const ENGINE_STOPPED = path.join(DATA_DIR, '.engine-stopped');
function startEngine() {
  try { fs.unlinkSync(ENGINE_STOPPED); } catch { /* no había marca */ }
  if (process.platform === 'darwin') {               // macOS: motor en Swift (mac/), instalado o compilado con `swift build`
    const exe = [path.join(ROOT, 'ZonelyEngine'), path.join(ROOT, 'mac', '.build', 'release', 'ZonelyEngine'), path.join(ROOT, 'mac', '.build', 'debug', 'ZonelyEngine')]
      .find((p) => fs.existsSync(p));
    if (!exe) throw new Error('No encuentro el motor de macOS: compílalo con «swift build» dentro de la carpeta mac');
    spawn(exe, [], { detached: true, stdio: 'ignore', cwd: ROOT }).unref();
    return;
  }
  if (app.isPackaged) {                              // versión instalada: el motor ya viene compilado
    const exe = path.join(ROOT, 'ZonelyEngine.exe');
    if (!fs.existsSync(exe)) throw new Error('No encuentro ZonelyEngine.exe');
    spawn(exe, [], { detached: true, stdio: 'ignore', cwd: ROOT }).unref();
    return;
  }
  const candidates = [
    path.join(process.env.LOCALAPPDATA || '', 'Programs', 'AutoHotkey', 'v2', 'AutoHotkey64.exe'),
    path.join(process.env.ProgramFiles || '', 'AutoHotkey', 'v2', 'AutoHotkey64.exe'),
  ];
  const exe = candidates.find((p) => fs.existsSync(p));
  if (!exe) throw new Error('No encuentro AutoHotkey v2');
  spawn(exe, [path.join(ROOT, 'ZoneManager.ahk')], { detached: true, stdio: 'ignore', cwd: ROOT }).unref();
}

ipcMain.handle('config:get', () => readConfig());
// Si el monitor guardado en zones.ini ya no está conectado (o ha cambiado de tamaño), el panel lo pone al día con el que de verdad
// está usando el motor: así no se enseña (ni se edita) un 5120×1440 de un monitor externo que ya no está.
let lastReconcile = 0;
function reconcileMonitor(st) {
  if (!st.engineUp || !Array.isArray(st.monitors) || !st.monitors.length || Date.now() - lastReconcile < 5000) return;
  let cfg;
  try { cfg = readConfig(); } catch { return; }
  const known = st.monitors.find((m) => m.id === cfg.monitor.id);
  let target = null;
  if (!known) target = st.monitors.find((m) => m.id === st.monitor) || st.monitors.find((m) => m.primary) || st.monitors[0];
  else if (known.w !== cfg.monitor.w || known.h !== cfg.monitor.h) target = known;
  if (!target) return;
  lastReconcile = Date.now();
  try { setMonitor(target.id); } catch (e) { appendLog('WARN', `Monitor: ${e.message}`); }
}
ipcMain.handle('state:get', () => {
  const st = readState();
  reconcileMonitor(st);
  return st;
});
ipcMain.handle('cmd:send', (_e, cmd) => sendCommand(cmd));
ipcMain.handle('config:saveProfile', (_e, a) => saveProfile(a));
ipcMain.handle('config:createProfile', (_e, a) => createProfile(a));
ipcMain.handle('config:deleteProfile', (_e, a) => deleteProfile(a));
ipcMain.handle('config:setExclusions', (_e, a) => setExclusions(a));
ipcMain.handle('config:setMonitor', (_e, id) => setMonitor(String(id)));
ipcMain.handle('ipc:read', (_e, name) => {
  if (!['debug', 'hotkeys'].includes(name)) return null;       // lista cerrada
  try { return JSON.parse(fs.readFileSync(path.join(IPC_DIR, name + '.json'), 'utf8')); } catch { return null; }
});
ipcMain.handle('config:setDim', (_e, pct) => {
  pct = Number(pct);
  if (!Number.isInteger(pct) || pct < 0 || pct > 100) throw new Error('Opacidad no válida');
  writeIni((t) => setIniValue(t, 'Dim', 'Opacity', String(pct)));
});
// El manual de macOS (mac.html) lleva los atajos, las rutas y los permisos de Mac; el de Windows es index.html.
ipcMain.handle('manual:open', () => shell.openPath(path.join(ROOT, 'manual', process.platform === 'darwin' ? 'mac.html' : 'index.html')));
ipcMain.handle('app:isDev', () => IS_DEV);
ipcMain.handle('log:read', () => readLogTail());
ipcMain.handle('log:open', () => { fs.mkdirSync(LOG_DIR, { recursive: true }); if (!fs.existsSync(LOG_FILE)) fs.writeFileSync(LOG_FILE, ''); return shell.openPath(LOG_FILE); });
ipcMain.handle('log:clear', () => { fs.mkdirSync(LOG_DIR, { recursive: true }); fs.writeFileSync(LOG_FILE, ''); appendLog('INFO', 'Registro limpiado'); });
ipcMain.handle('log:renderer', (_e, msg) => appendLog('ERROR', `interfaz: ${msg}`));
ipcMain.handle('config:setOption', (_e, { key, on }) => {
  const map = { halves: ['Snap', 'Halves'], restore: ['General', 'RestoreOnLeave'], menubar: ['General', 'MenuBarIcon'], fullscreen: ['General', 'FullScreenToZone'], autoupdate: ['General', 'AutoUpdate'] };
  if (!map[key]) throw new Error('Opción no válida');
  writeIni((t) => setIniValue(t, map[key][0], map[key][1], on ? '1' : '0'));
});
// Idioma: [General] Language = auto | es | en | fr | de | pt | it. Los motores lo leen para sus avisos y menús.
const LANGS = ['auto', 'es', 'en', 'fr', 'de', 'pt', 'it'];
function resolveLanguage() {
  let chosen = 'auto';
  try { chosen = parseIni(fs.readFileSync(INI, 'utf8')).General?.Language || 'auto'; } catch { /* sin zones.ini todavía */ }
  if (LANGS.includes(chosen) && chosen !== 'auto') return chosen;
  const system = String((app.isReady() ? app.getLocale() : 'es') || 'es').slice(0, 2).toLowerCase();
  return LANGS.includes(system) ? system : 'en';
}
ipcMain.on('lang:get', (e) => { e.returnValue = resolveLanguage(); });
ipcMain.handle('config:setLanguage', (_e, lang) => {
  if (!LANGS.includes(lang)) throw new Error('Idioma no válido');
  writeIni((t) => setIniValue(t, 'General', 'Language', lang));
});
ipcMain.handle('config:setSnapKey', (_e, key) => {
  if (!['Shift', 'Ctrl', 'Alt'].includes(key)) throw new Error('Tecla no válida');
  writeIni((t) => setIniValue(t, 'Snap', 'Key', key));       // el motor la lee en cada arrastre: no hace falta recargar
});
// Atajos: solo se aceptan ids que el motor ha publicado y combinaciones con el formato AutoHotkey conocido.
const HOTKEY_RE = /^[#!^+]{1,4}([a-z0-9]|F([1-9]|1\d|2[0-4])|Numpad[0-9]|Left|Right|Up|Down|BackSpace|Space|Tab|Enter|Esc|Delete|Insert|Home|End|PgUp|PgDn)$/i;
ipcMain.handle('config:setHotkeys', (_e, changes) => {
  let known = [];
  try { known = JSON.parse(fs.readFileSync(path.join(IPC_DIR, 'hotkeys.json'), 'utf8')).map((h) => h.id); } catch { /* motor parado */ }
  const entries = Object.entries(changes || {});
  if (!entries.length || entries.length > 40) throw new Error('Cambios no válidos');
  for (const [id, key] of entries) {
    if (!/^[A-Za-z]{3,24}$/.test(id) || (known.length && !known.includes(id)) || !HOTKEY_RE.test(String(key))) throw new Error(`Atajo no válido: ${id}`);
  }
  writeIni((t) => entries.reduce((acc, [id, key]) => setIniValue(acc, 'Hotkeys', id, String(key)), t));
});
ipcMain.handle('config:setGameZone', (_e, { profile, zone }) => {
  const p = readConfig().profiles.find((x) => x.id === profile);
  if (!p || !p.zones.B) throw new Error('Perfil no válido');
  if (zone !== 'auto' && !(ZONE_KEYS.includes(zone) && p.zones[zone])) throw new Error('Zona no válida');
  writeIni((t) => setIniValue(t, `Profile.${profile}`, 'GameZone', zone));
});
ipcMain.handle('engine:start', () => startEngine());
ipcMain.handle('update:check', () => updater.check(true));        // «Buscar ahora» (Ajustes → Actualizaciones)

let mainWindow = null;
function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    minWidth: 760,
    minHeight: 560,
    center: true,                  // siempre en el centro de la pantalla, sea cual sea el perfil
    backgroundColor: '#0b0f17',
    autoHideMenuBar: true,
    title: 'Zonely',
    ...(process.platform === 'win32' ? { icon: path.join(ROOT, 'assets', 'zonely.ico') } : {}),    // en macOS el icono es el de la app
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  mainWindow = win;
  win.on('closed', () => { mainWindow = null; });
  win.loadFile(path.join(__dirname, 'index.html'));
}

// ¿Actualizar automáticamente? ([General] AutoUpdate en zones.ini; por defecto sí.)
function autoUpdateEnabled() {
  try { return String(parseIni(fs.readFileSync(INI, 'utf8')).General?.AutoUpdate ?? '1') === '1'; } catch { return true; }
}

app.whenReady().then(() => {
  if (!gotLock) return;                           // ya hay otro panel abierto: este se cierra solo
  if (BACKGROUND) {                               // lo lanza el motor cada pocas horas: sin ventana, busca e instala la actualización
    if (process.platform === 'darwin' && app.dock) app.dock.hide();
    appendLog('INFO', `Comprobación de actualizaciones en segundo plano (v${readVersion()})`);
    updater.init({ getWindow: () => null, version: readVersion(), logger: appendLog, isAuto: autoUpdateEnabled, language: resolveLanguage, background: true });
    updater.runBackground();
    return;
  }
  ensureIni();
  appendLog('INFO', `Panel iniciado v${readVersion()}`);
  // macOS instalado: el panel arranca el motor si no está en marcha (el motor evita ser lanzado dos veces).
  if (app.isPackaged && process.platform === 'darwin' && !fs.existsSync(ENGINE_STOPPED)) { try { startEngine(); } catch (e) { appendLog('WARN', `No pude iniciar el motor: ${e.message}`); } }
  createWindow();
  updater.init({ getWindow: () => mainWindow, version: readVersion(), logger: appendLog, isAuto: autoUpdateEnabled, language: resolveLanguage });
});
app.on('window-all-closed', () => app.quit());
