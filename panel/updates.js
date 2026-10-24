// Ajustes → Actualizaciones: «Buscar ahora». La comprobación al iniciar y los diálogos viven en el proceso principal (updater.js).
const updateButton = document.getElementById('update-check');
const updateStatus = document.getElementById('update-status');

const UPDATE_TEXT = {
  none: t('Estás al día.'),
  later: t('Hay una versión nueva (la dejaste para más tarde).'),
  available: t('Hay una versión nueva.'),
  downloaded: t('Descargada: se instalará al reiniciar.'),
  error: t('No se pudo comprobar.'),
  dev: t('No disponible en la versión de desarrollo.'),
  busy: t('Ya se está comprobando…'),
};

updateButton.addEventListener('click', async () => {
  updateButton.disabled = true;
  updateStatus.textContent = t('Comprobando…');
  try {
    const result = await window.zones.checkUpdates();
    updateStatus.textContent = UPDATE_TEXT[result?.status] || '';
  } catch {
    updateStatus.textContent = UPDATE_TEXT.error;
  }
  updateButton.disabled = false;
});
