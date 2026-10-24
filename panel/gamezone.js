// Zona donde el modo juego coloca la ventana, perfil por perfil.
function gzPaint() {
  const box = $('gz-list');
  const profiles = config.profiles.filter((p) => p.zones.B);          // el perfil sin zonas no tiene modo juego por zona
  const key = JSON.stringify([profiles.map((p) => [p.id, p.gameZone, Object.keys(p.zones).filter((z) => p.zones[z])]), state.engineUp]);
  if (box.dataset.key === key) return;
  box.dataset.key = key;
  box.innerHTML = '';
  for (const p of profiles) {
    const row = document.createElement('div');
    row.className = 'gz-row';
    const name = document.createElement('span');
    name.className = 'name';
    name.textContent = p.id;
    const seg = document.createElement('div');
    seg.className = 'seg';
    const options = [...ZONE_IDS.filter((z) => p.zones[z]).map((z) => [z, t('Zona {zone}', { zone: z })]), ['auto', t('Donde esté')]];
    for (const [value, label] of options) {
      const b = document.createElement('button');
      b.textContent = label;
      b.classList.toggle('on', p.gameZone === value);
      b.disabled = !state.engineUp;
      b.onclick = async () => {
        await window.zones.setGameZone(p.id, value);
        await window.zones.send({ type: 'reload' });                  // el motor relee zones.ini
        setTimeout(refresh, 1500);
      };
      seg.appendChild(b);
    }
    row.append(name, seg);
    box.appendChild(row);
  }
}

const gzPrevPaint = window.onPanelPaint;
window.onPanelPaint = () => { gzPrevPaint?.(); gzPaint(); };