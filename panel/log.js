// Registro de actividad (logs/gestor.log) y versión.
const LOG_LEVEL = /\s(INFO|WARN|ERROR)\s/;
let logKey = '';
let stickBottom = true;

async function paintLog() {
  if (document.hidden) return;
  const lines = await window.zones.readLog();
  const key = lines.join('\n');
  if (key === logKey) return;
  logKey = key;
  const box = $('lg-box');
  box.innerHTML = '';
  if (!lines.length) {
    const e = document.createElement('div');
    e.className = 'ts';
    e.textContent = 'El registro está vacío.';
    box.appendChild(e);
    return;
  }
  for (const l of lines) {
    const row = document.createElement('div');
    const m = l.match(LOG_LEVEL);
    row.className = m ? m[1] : '';
    row.textContent = l;                                   // textContent: nada del registro se interpreta como HTML
    box.appendChild(row);
  }
  if (stickBottom) box.scrollTop = box.scrollHeight;       // sigue lo último, salvo que estés leyendo más arriba
}

$('lg-box').addEventListener('scroll', (e) => {
  const b = e.target;
  stickBottom = b.scrollHeight - b.scrollTop - b.clientHeight < 24;
});
$('lg-refresh').addEventListener('click', paintLog);
$('lg-open').addEventListener('click', () => window.zones.openLog());
$('lg-clear').addEventListener('click', async () => { await window.zones.clearLog(); logKey = ''; paintLog(); });
$('lg-copy').addEventListener('click', async () => {
  const lines = await window.zones.readLog();
  await navigator.clipboard.writeText(lines.join('\n'));
  const b = $('lg-copy');
  b.textContent = '¡Copiado!';
  setTimeout(() => { b.textContent = 'Copiar'; }, 1500);
});

// Versión: la del panel (config.version) y la del motor (state.version).
function paintVersion() {
  const pv = config?.version || '?';
  const mv = state.engineUp ? (state.version || '?') : null;
  const el = $('ver');
  el.className = '';
  if (mv === null) el.textContent = `panel v${pv} · motor detenido`;
  else if (mv !== pv) { el.textContent = `panel v${pv} · motor v${mv} (pulsa Recargar)`; el.className = 'ver-warn'; }
  else el.textContent = `v${pv}`;
}

// Errores de la propia interfaz → registro.
window.addEventListener('error', (e) => window.zones.logError(`${e.message} @ ${e.filename}:${e.lineno}`));
window.addEventListener('unhandledrejection', (e) => window.zones.logError(`promesa rechazada: ${e.reason}`));

const prevPaint4 = window.onPanelPaint;
window.onPanelPaint = () => { prevPaint4?.(); paintVersion(); };
paintLog();
setInterval(paintLog, 3000);