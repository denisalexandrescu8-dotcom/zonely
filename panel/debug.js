// Depuración en vivo de la última ventana que usaste (el motor solo escribe estos datos mientras el panel mira).
let dbgKey = '';
function paintDebug(d) {
  const key = JSON.stringify(d);
  if (key === dbgKey) return;
  dbgKey = key;
  const box = $('dbg');
  const verdict = $('dbg-verdict');
  box.innerHTML = '';
  if (!d) {
    verdict.className = 'verdict';
    verdict.textContent = 'sin ventana';
    return;
  }
  if (d.exact) {
    verdict.className = 'verdict ok';
    verdict.textContent = `✔ coincide con la zona ${d.zone}`;
  } else {
    verdict.className = 'verdict bad';
    verdict.textContent = `✘ difiere ${d.dw} × ${d.dh} px de la zona ${d.zone}`;
  }
  const rows = [
    ['Proceso', d.proc],
    ['Ruta', d.path],
    ['Clase', d.class],
    ['Título', d.title],
    ['Estado', ['minimizada', 'normal', 'maximizada'][d.state + 1]],
    ['Estilo', `${d.style} (${d.caption ? 'con barra de título' : 'SIN barra de título'})`],
    ['Visible', `x=${d.x} y=${d.y}  ${d.w}×${d.h}`],
    ['Con sombra', `x=${d.ox} y=${d.oy}  ${d.ow}×${d.oh}`],
    ['Área cliente', `${d.cw}×${d.ch}`],
    ['Zona esperada', `${d.zone}: x=${d.zx} y=${d.zy}  ${d.zw}×${d.zh}`],
  ];
  for (const [k, v] of rows) {
    const dt = document.createElement('dt'); dt.textContent = k;
    const dd = document.createElement('dd'); dd.textContent = v ?? '';
    box.append(dt, dd);
  }
}

async function pollDebug() {
  if (document.hidden) return;
  paintDebug(await window.zones.readIpc('debug'));
}
function keepWatching() {
  if (!document.hidden && state.engineUp) window.zones.send({ type: 'watch' });
}

keepWatching();
setInterval(keepWatching, 5000);
setInterval(pollDebug, 500);
