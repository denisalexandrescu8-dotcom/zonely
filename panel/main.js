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
      zones: { A: parseZone(ini[s].A), B: ini[s].B ? parseZone(ini[s].B) : null, C: ini[s].B && ini[s].C ? parseZone(ini[s].C) : null },   // sin B = pantalla normal, sin zonas
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

// Cambia el ancho de la zona A de un perfil; B ocupa el resto.
function setZones({ profile, aw }) {
  const cfg = readConfig();
  const p = cfg.profiles.find((x) => x.id === profile);
  aw = Number(aw);
  if (!p || !p.zones.B || p.zones.C || !Number.isInteger(aw) || aw < 400 || aw > cfg.monitor.w - 400) throw new Error('Zonas no válidas');
  const h = cfg.monitor.h;
  writeIni((t) => {
    t = setIniValue(t, `Profile.${profile}`, 'A', `0,0,${aw},${h}`);
    return setIniValue(t, `Profile.${profile}`, 'B', `${aw},0,${cfg.monitor.w - aw},${h}`);
  });
}

// Elige el monitor al que se aplican las zonas. Solo vale uno de los que el motor ha publicado (ipc/state.json).
// Las zonas de todos los perfiles se reescalan al tamaño del monitor nuevo, para que sigan ocupando lo mismo en proporción.
function setMonitor(id) {
  const st = readState();
  const mon = (st.monitors || []).find((m) => m.id === id);
  if (!st.engineUp || !mon) throw new Error('Monitor no disponible: enciende el motor y vuelve a probar');
  const cfg = readConfig();
  const sx = mon.w / cfg.monitor.w, sy = mon.h / cfg.monitor.h;
  const scale = (zone) => {
    if (!zone) return null;
    const x0 = Math.round(zone.x * sx), x1 = Math.round((zone.x + zone.w) * sx);
    const y0 = Math.round(zone.y * sy), y1 = Math.round((zone.y + zone.h) * sy);
    return `${x0},${y0},${x1 - x0},${y1 - y0}`;
  };
  writeIni((t) => {
    if (sx !== 1 || sy !== 1) {
      for (const p of cfg.profiles)
        for (const key of ['A', 'B', 'C'])
          if (p.zones[key]) t = setIniValue(t, `Profile.${p.id}`, key, scale(p.zones[key]));
    }
    t = setIniValue(t, 'Monitor', 'Width', String(mon.w));
    t = setIniValue(t, 'Monitor', 'Height', String(mon.h));
    return setIniValue(t, 'Monitor', 'Id', mon.id);
  });
  appendLog('INFO', `Monitor elegido: ${mon.name} (${mon.w}x${mon.h})`);
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
    (cmd.type === 'dim' && ['A', 'B', 'C', 'off'].includes(cmd.value)) ||
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
ipcMain.handle('state:get', () => readState());
ipcMain.handle('cmd:send', (_e, cmd) => sendCommand(cmd));
ipcMain.handle('config:setZones', (_e, a) => setZones(a));
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
  if (zone !== 'auto' && !(['A', 'B', 'C'].includes(zone) && p.zones[zone])) throw new Error('Zona no válida');
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
    updater.init({ getWindow: () => null, version: readVersion(), logger: appendLog, isAuto: autoUpdateEnabled, background: true });
    updater.runBackground();
    return;
  }
  ensureIni();
  appendLog('INFO', `Panel iniciado v${readVersion()}`);
  // macOS instalado: el panel arranca el motor si no está en marcha (el motor evita ser lanzado dos veces).
  if (app.isPackaged && process.platform === 'darwin' && !fs.existsSync(ENGINE_STOPPED)) { try { startEngine(); } catch (e) { appendLog('WARN', `No pude iniciar el motor: ${e.message}`); } }
  createWindow();
  updater.init({ getWindow: () => mainWindow, version: readVersion(), logger: appendLog, isAuto: autoUpdateEnabled });
});
app.on('window-all-closed', () => app.quit());
