// Comprobación de actualizaciones.
//  - Windows: electron-updater con las releases de GitHub. Pregunta si quieres actualizar, descarga y reinicia.
//  - macOS: las apps sin firma de Apple no se pueden actualizar solas, así que solo avisa de la versión nueva
//    y abre la página de descarga.
// Se comprueba al iniciar (unos segundos después de abrir) y cuando el usuario pulsa «Buscar ahora».
const electron = require('electron');
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

let getWindow = () => null;
let current = '0.0.0';
let log = () => {};
let busy = false;
let progressHooked = false;

function init(options) {
  getWindow = options.getWindow || getWindow;
  current = options.version || current;
  log = options.logger || log;
  if (!enabled()) return;
  setTimeout(() => { check(false); }, 6000);        // al iniciar, sin retrasar la apertura del panel
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

async function check(manual) {
  if (!enabled()) return { status: 'dev' };
  if (busy) return { status: 'busy' };
  busy = true;
  try {
    return process.platform === 'win32' ? await checkWindows(manual) : await checkNotifyOnly(manual);
  } catch (e) {
    log('WARN', `Actualizaciones: ${e && e.message}`);
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
  const { response } = await box({
    type: 'question',
    buttons: ['Actualizar ahora', 'Más tarde'],
    defaultId: 0,
    cancelId: 1,
    message: `Hay una versión nueva de Zonely (${version})`,
    detail: `Tienes la ${current}. ¿Quieres actualizar? Se descarga ahora y Zonely se reinicia para terminar.`,
  });
  return response === 0;
}

async function checkWindows(manual) {
  const { autoUpdater } = require('electron-updater');
  autoUpdater.autoDownload = false;               // primero se pregunta
  autoUpdater.autoInstallOnAppQuit = false;
  autoUpdater.allowPrerelease = false;
  autoUpdater.logger = null;
  if (!progressHooked) {
    progressHooked = true;
    autoUpdater.on('download-progress', (p) => { const w = parent(); if (w) w.setProgressBar(Math.min(1, p.percent / 100)); });
  }
  const result = await autoUpdater.checkForUpdates();
  const info = result && result.updateInfo;
  if (!info || compareVersions(info.version, current) <= 0) return upToDate(manual);
  log('INFO', `Actualizaciones: hay una versión nueva (${info.version})`);
  if (!(await ask(info.version))) return { status: 'later', version: info.version };

  await autoUpdater.downloadUpdate();
  const w = parent();
  if (w) w.setProgressBar(-1);
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

async function checkNotifyOnly(manual) {
  const res = await net.fetch(RELEASES_API, { headers: { 'User-Agent': 'Zonely', Accept: 'application/vnd.github+json' } });
  if (!res.ok) throw new Error(`GitHub respondió ${res.status}`);
  const release = await res.json();
  const latest = String(release.tag_name || '').replace(/^v/i, '');
  if (compareVersions(latest, current) <= 0) return upToDate(manual);
  log('INFO', `Actualizaciones: hay una versión nueva (${latest})`);
  const { response } = await box({
    type: 'question',
    buttons: ['Abrir la descarga', 'Más tarde'],
    defaultId: 0,
    cancelId: 1,
    message: `Hay una versión nueva de Zonely (${latest})`,
    detail: `Tienes la ${current}. En macOS la actualización se hace descargando el nuevo instalador.`,
  });
  if (response === 0 && /^https:\/\/github\.com\//.test(release.html_url || '')) shell.openExternal(release.html_url);
  return { status: 'available', version: latest };
}

module.exports = { init, check, compareVersions, parseVersion };
