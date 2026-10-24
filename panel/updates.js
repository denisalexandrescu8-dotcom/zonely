// Ajustes → Actualizaciones: «Buscar ahora». La comprobación al iniciar y los diálogos viven en el proceso principal (updater.js).
const updateButton = document.getElementById('update-check');
const updateStatus = document.getElementById('update-status');

const UPDATE_TEXT = {
  none: 'Estás al día.',
  later: 'Hay una versión nueva (la dejaste para más tarde).',
  available: 'Hay una versión nueva.',
  downloaded: 'Descargada: se instalará al reiniciar.',
  error: 'No se pudo comprobar.',
  dev: 'No disponible en la versión de desarrollo.',
  busy: 'Ya se está comprobando…',
};

updateButton.addEventListener('click', async () => {
  updateButton.disabled = true;
  updateStatus.textContent = 'Comprobando…';
  try {
    const result = await window.zones.checkUpdates();
    updateStatus.textContent = UPDATE_TEXT[result?.status] || '';
  } catch {
    updateStatus.textContent = UPDATE_TEXT.error;
  }
  updateButton.disabled = false;
});
