// Puente seguro entre la interfaz y el proceso principal.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('zones', {
  getConfig: () => ipcRenderer.invoke('config:get'),
  getState: () => ipcRenderer.invoke('state:get'),
  send: (cmd) => ipcRenderer.invoke('cmd:send', cmd),
  saveProfile: (a) => ipcRenderer.invoke('config:saveProfile', a),
  createProfile: (a) => ipcRenderer.invoke('config:createProfile', a),
  deleteProfile: (a) => ipcRenderer.invoke('config:deleteProfile', a),
  setExclusions: (a) => ipcRenderer.invoke('config:setExclusions', a),
  setMonitor: (id) => ipcRenderer.invoke('config:setMonitor', String(id)),
  readIpc: (name) => ipcRenderer.invoke('ipc:read', name),
  setDim: (pct) => ipcRenderer.invoke('config:setDim', pct),
  openManual: () => ipcRenderer.invoke('manual:open'),
  isDev: () => ipcRenderer.invoke('app:isDev'),
  checkUpdates: () => ipcRenderer.invoke('update:check'),
  readLog: () => ipcRenderer.invoke('log:read'),
  openLog: () => ipcRenderer.invoke('log:open'),
  clearLog: () => ipcRenderer.invoke('log:clear'),
  logError: (m) => ipcRenderer.invoke('log:renderer', String(m).slice(0, 500)),
  setOption: (key, on) => ipcRenderer.invoke('config:setOption', { key, on: !!on }),
  setSnapKey: (key) => ipcRenderer.invoke('config:setSnapKey', String(key)),
  setHotkeys: (changes) => ipcRenderer.invoke('config:setHotkeys', changes),
  setGameZone: (profile, zone) => ipcRenderer.invoke('config:setGameZone', { profile, zone }),
  startEngine: () => ipcRenderer.invoke('engine:start'),
});
