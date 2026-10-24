// Comprobación de actualizaciones.
//  - Windows: electron-updater con las releases de GitHub. Pregunta si quieres actualizar, descarga y reinicia.
//  - macOS: Zonely no está firmada por Apple, así que electron-updater no sirve. Se hace a mano: se descarga el .dmg de la
//    release desde la propia app (lo que descarga la app no queda «en cuarentena», así que macOS no pone el aviso de
//    seguridad), se comprueba su SHA-256, y un guion se encarga de sustituir Zonely.app y volver a abrirla.
// Se comprueba al iniciar (unos segundos después de abrir) y cuando el usuario pulsa «Buscar ahora».
let electron = {};
try { electron = require('electron'); } catch { /* las pruebas con Node no necesitan Electron */ }
const fs = require('fs');
const os = require('os');
const path = require('path');
const crypto = require('crypto');
const { Readable, Transform } = require('stream');
const { pipeline } = require('stream/promises');
const { spawn } = require('child_process');
const { app, dialog, shell, net } = electron;

const RELEASES_API = 'https://api.github.com/repos/denisalexandrescu8-dotcom/zonely/releases/latest';

// "v0.34.0" → [0, 34, 0] (o null si no es una versión).
function parseVersion(v) {
  const m = String(v || '').trim().replace(/^v/i, '').match(/^(\d+)\.(\d+)\.(\d+)/);
  return m ? m.slice(1).map(Number) : null;
}

// 1 si a > b, -1 si a < b, 0 si son iguales (o alguna no es una versión).
function compareVersions(a, b) {
  const x = parseVersion(a), y = parseVersion(b);
  if (!x || !y) return 0;
  for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] > y[i] ? 1 : -1;
  return 0;
}

// ---- Piezas de la actualización de macOS (sin Electron: se prueban con Node) ----------------------------------------

// Línea de SHA256SUMS.txt («<hash>  <archivo>») → el hash del archivo, o null.
function hashFor(sumsText, fileName) {
  for (const line of String(sumsText).split(/\r?\n/)) {
    const m = line.trim().match(/^([0-9a-f]{64})\s+\*?(.+)$/i);
    if (m && m[2].trim() === fileName) return m[1].toLowerCase();
  }
  return null;
}

// /Applications/Zonely.app/Contents/MacOS/Zonely → /Applications/Zonely.app (o null si no es una app empaquetada).
function appBundleFromExe(exePath) {
  const bundle = path.resolve(exePath, '..', '..', '..');
  return bundle.endsWith('.app') ? bundle : null;
}

// Del JSON de una release: el instalador de Mac (Apple Silicon) y el archivo de sumas.
function pickMacAssets(release) {
  const assets = Array.isArray(release && release.assets) ? release.assets : [];
  const dmg = assets.find((a) => /mac-arm64\.dmg$/.test(a.name || ''));
  const sums = assets.find((a) => a.name === 'SHA256SUMS.txt');
  return { dmg, sums };
}

// Descarga un archivo calculando su SHA-256 por el camino. `fetchFn` se puede cambiar para probarlo.
async function downloadFile(url, file, onProgress, fetchFn) {
  const res = await fetchFn(url, { headers: { 'User-Agent': 'Zonely' } });
  if (!res.ok || !res.body) throw new Error(`descarga: GitHub respondió ${res.status}`);
  const total = Number(res.headers.get('content-length')) || 0;
  const hash = crypto.createHash('sha256');
  let received = 0;
  const counter = new Transform({
    transform(chunk, _enc, cb) {
      hash.update(chunk);
      received += chunk.length;
      if (total && onProgress) onProgress(received / total);
      cb(null, chunk);
    },
  });
  await pipeline(Readable.fromWeb(res.body), counter, fs.createWriteStream(file));
  return hash.digest('hex');
}

// Guion que sustituye la app cuando Zonely ya se ha cerrado. Recibe: ruta de la app, ruta del .dmg y el pid de Zonely.
// Si algo falla antes de copiar, la app antigua se queda como estaba; al final se vuelve a abrir en cualquier caso.
const MAC_INSTALL_SCRIPT = `#!/bin/bash
APP="$1"; DMG="$2"; PID="$3"; MODE="$4"
for i in $(seq 1 60); do kill -0 "$PID" 2>/dev/null || break; sleep 0.25; done
pkill -x ZonelyEngine 2>/dev/null
sleep 1
MOUNT="$(hdiutil attach "$DMG" -nobrowse -readonly | awk -F'\\t' '/\\/Volumes\\//{print $NF; exit}')"
if [ -n "$MOUNT" ]; then
  SRC="$(find "$MOUNT" -maxdepth 1 -name '*.app' | head -1)"
  if [ -n "$SRC" ]; then
    rm -rf "$APP.new"
    if ditto "$SRC" "$APP.new"; then
      rm -rf "$APP" && mv "$APP.new" "$APP"
      xattr -dr com.apple.quarantine "$APP" 2>/dev/null
    else
      rm -rf "$APP.new"
    fi
  fi
  hdiutil detach "$MOUNT" -quiet 2>/dev/null
fi
rm -f "$DMG"
if [ "$MODE" = background ]; then
  nohup "$APP/Contents/Resources/ZonelyEngine" >/dev/null 2>&1 &
else
  open "$APP"
fi
`;

// ---- Estado y diálogos ------------------------------------------------------------------------------------------------

let getWindow = () => null;
let current = '0.0.0';
let log = () => {};
let busy = false;
let progressHooked = false;
let isAuto = () => true;                            // ¿actualizar automáticamente? (Ajustes → Actualizaciones, [General] AutoUpdate)

function init(options) {
  getWindow = options.getWindow || getWindow;
  current = options.version || current;
  log = options.logger || log;
  isAuto = options.isAuto || isAuto;
  if (!enabled()) return;
  // Con la actualización automática activada, el motor lanza cada pocas horas el panel sin ventana (--background-update)
  // y es ese el que descarga e instala. Si está apagada, se pregunta al abrir el panel.
  if (!options.background && !isAuto()) setTimeout(() => { check(false, false); }, 6000);
}

// Modo sin ventana (lo lanza el motor): busca, descarga e instala sin preguntar ni enseñar nada, y se cierra.
async function runBackground() {
  const limit = setTimeout(() => app.quit(), 20 * 60 * 1000);     // por si algo se queda colgado
  try {
    if (enabled() && isAuto()) await check(false, true);
  } finally {
    clearTimeout(limit);
    app.quit();
  }
}

// En desarrollo (sin empaquetar) no se busca nada, salvo que se fuerce con ZONELY_UPDATE_TEST=1.
function enabled() {
  return app.isPackaged || process.env.ZONELY_UPDATE_TEST === '1';
}

function parent() {
  const w = getWindow();
  return w && !w.isDestroyed() ? w : undefined;
}

function box(options) {
  return dialog.showMessageBox(parent(), { title: 'Zonely', noLink: true, ...options });
}

function progress(fraction) {
  const w = parent();
  if (w) w.setProgressBar(fraction);
}

async function check(manual, background = false) {
  if (!enabled()) return { status: 'dev' };
  if (busy) return { status: 'busy' };
  busy = true;
  try {
    return process.platform === 'win32' ? await checkWindows(manual, background) : await checkMac(manual, background);
  } catch (e) {
    log('WARN', `Actualizaciones: ${e && e.message}`);
    progress(-1);
    if (manual) await box({ type: 'warning', message: 'No he podido comprobar las actualizaciones', detail: 'Revisa tu conexión a internet e inténtalo de nuevo.' });
    return { status: 'error' };
  } finally {
    busy = false;
  }
}

async function upToDate(manual) {
  if (manual) await box({ type: 'info', message: 'Zonely está al día', detail: `Tienes la última versión (${current}).` });
  return { status: 'none' };
}

async function ask(version) {
  const extra = process.platform === 'darwin' ? ' Después, macOS puede pedirte de nuevo el permiso de Accesibilidad.' : '';
  const { response } = await box({
    type: 'question',
    buttons: ['Actualizar ahora', 'Más tarde'],
    defaultId: 0,
    cancelId: 1,
    message: `Hay una versión nueva de Zonely (${version})`,
    detail: `Tienes la ${current}. ¿Quieres actualizar? Se descarga ahora y Zonely se reinicia para terminar.${extra}`,
  });
  return response === 0;
}

// ---- Windows ----------------------------------------------------------------------------------------------------------

async function checkWindows(manual, background) {
  const { autoUpdater } = require('electron-updater');
  autoUpdater.autoDownload = false;               // primero se pregunta
  autoUpdater.autoInstallOnAppQuit = false;
  autoUpdater.allowPrerelease = false;
  autoUpdater.logger = null;
  if (!progressHooked) {
    progressHooked = true;
    autoUpdater.on('download-progress', (p) => progress(Math.min(1, p.percent / 100)));
  }
  const result = await autoUpdater.checkForUpdates();
  const info = result && result.updateInfo;
  if (!info || compareVersions(info.version, current) <= 0) return upToDate(manual);
  log('INFO', `Actualizaciones: hay una versión nueva (${info.version})`);
  const silent = background && !manual;            // en segundo plano no se pregunta nada
  if (!silent && !(await ask(info.version))) return { status: 'later', version: info.version };

  await autoUpdater.downloadUpdate();
  progress(-1);
  if (silent) {
    log('INFO', `Actualizaciones: ${info.version} descargada; instalando en segundo plano`);
    autoUpdater.quitAndInstall(true, false);       // silencioso y sin abrir el panel: el instalador vuelve a arrancar el motor
    return { status: 'downloaded', version: info.version };
  }
  const { response } = await box({
    type: 'info',
    buttons: ['Reiniciar y actualizar', 'Al cerrar Zonely'],
    defaultId: 0,
    cancelId: 1,
    message: `Zonely ${info.version} está lista`,
    detail: 'Para terminar, Zonely se cierra y se vuelve a abrir. Si prefieres esperar, se instalará cuando cierres la aplicación.',
  });
  if (response === 0) {
    log('INFO', 'Actualizaciones: instalando y reiniciando');
    autoUpdater.quitAndInstall(true, true);        // silencioso y se vuelve a abrir
  } else {
    autoUpdater.autoInstallOnAppQuit = true;
  }
  return { status: 'downloaded', version: info.version };
}

// ---- macOS ------------------------------------------------------------------------------------------------------------

async function checkMac(manual, background) {
  const res = await net.fetch(RELEASES_API, { headers: { 'User-Agent': 'Zonely', Accept: 'application/vnd.github+json' } });
  if (!res.ok) throw new Error(`GitHub respondió ${res.status}`);
  const release = await res.json();
  const latest = String(release.tag_name || '').replace(/^v/i, '');
  if (compareVersions(latest, current) <= 0) return upToDate(manual);
  log('INFO', `Actualizaciones: hay una versión nueva (${latest})`);

  const { dmg, sums } = pickMacAssets(release);
  const bundle = app.isPackaged ? appBundleFromExe(app.getPath('exe')) : null;
  let writable = false;
  if (bundle) { try { fs.accessSync(path.dirname(bundle), fs.constants.W_OK); writable = true; } catch { /* sin permiso para sustituirla */ } }

  const silent = background && !manual;            // en segundo plano no se pregunta nada
  // Sin instalador de Mac en la release, en un Mac con Intel, o sin poder escribir donde está la app: solo se avisa.
  if (!dmg || !sums || !bundle || !writable || process.arch !== 'arm64') {
    if (silent) { log('INFO', 'Actualizaciones: esta vez no se puede instalar sola; se avisará al abrir el panel'); return { status: 'available', version: latest }; }
    const { response } = await box({
      type: 'question',
      buttons: ['Abrir la descarga', 'Más tarde'],
      defaultId: 0,
      cancelId: 1,
      message: `Hay una versión nueva de Zonely (${latest})`,
      detail: `Tienes la ${current}. Esta vez la actualización no se puede hacer sola: descarga el nuevo instalador de la página de la versión.`,
    });
    if (response === 0 && /^https:\/\/github\.com\//.test(release.html_url || '')) shell.openExternal(release.html_url);
    return { status: 'available', version: latest };
  }

  if (!silent && !(await ask(latest))) return { status: 'later', version: latest };

  const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), 'zonely-update-')), dmg.name);
  progress(0);
  const sumsRes = await net.fetch(sums.browser_download_url, { headers: { 'User-Agent': 'Zonely' } });
  if (!sumsRes.ok) throw new Error(`no pude leer SHA256SUMS.txt (${sumsRes.status})`);
  const expected = hashFor(await sumsRes.text(), dmg.name);
  if (!expected) throw new Error(`SHA256SUMS.txt no incluye ${dmg.name}`);
  const actual = await downloadFile(dmg.browser_download_url, file, progress, (u, o) => net.fetch(u, o));
  progress(-1);
  if (actual !== expected) {
    fs.rmSync(path.dirname(file), { recursive: true, force: true });
    throw new Error('la suma de comprobación de la descarga no coincide: no se instala');
  }

  log('INFO', `Actualizaciones: instalando ${latest} en ${bundle}`);
  const script = path.join(path.dirname(file), 'install.sh');
  fs.writeFileSync(script, MAC_INSTALL_SCRIPT, { mode: 0o755 });
  spawn('/bin/bash', [script, bundle, file, String(process.pid), silent ? 'background' : 'open'], { detached: true, stdio: 'ignore' }).unref();
  app.quit();                                     // el guion espera a que Zonely se cierre y la sustituye; después abre el panel (o, en segundo plano, solo arranca el motor)
  return { status: 'downloaded', version: latest };
}

module.exports = { init, check, runBackground, compareVersions, parseVersion, hashFor, appBundleFromExe, pickMacAssets, downloadFile, MAC_INSTALL_SCRIPT };
