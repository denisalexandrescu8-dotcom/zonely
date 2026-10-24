// Capa oscura: elegir zona y opacidad.
let dimSaveTimer = null;

function paintDim() {
  const cur = state.dim || 'off';
  for (const b of document.querySelectorAll('#dim-seg button')) {
    b.classList.toggle('on', b.dataset.dim === cur);
    const zones = config.profiles.find((p) => p.id === state.profile)?.zones;
    const exists = b.dataset.dim === 'off' || !!zones?.[b.dataset.dim];
    b.hidden = b.dataset.dim === 'C' && !exists;                                // la zona C solo existe en algunos perfiles
    b.disabled = !state.engineUp || !exists;                                    // sin zonas no hay nada que atenuar
  }
  const slider = $('dim-level');
  slider.disabled = !state.engineUp;
  if (document.activeElement !== slider && state.dimLevel !== undefined) {
    slider.value = state.dimLevel;
    $('dim-val').textContent = `${state.dimLevel}%`;
  }
}

for (const b of document.querySelectorAll('#dim-seg button'))
  b.addEventListener('click', () => window.zones.send({ type: 'dim', value: b.dataset.dim }).then(() => setTimeout(refresh, 300)));

$('dim-level').addEventListener('input', (e) => {
  const v = Number(e.target.value);
  $('dim-val').textContent = `${v}%`;
  window.zones.send({ type: 'dimlevel', value: String(v) });       // en vivo
  clearTimeout(dimSaveTimer);
  dimSaveTimer = setTimeout(() => window.zones.setDim(v), 400);     // y se guarda en zones.ini al soltar
});

const prevPaint = window.onPanelPaint;
window.onPanelPaint = () => { prevPaint?.(); paintDim(); };
