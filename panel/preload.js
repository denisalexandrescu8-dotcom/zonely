// Puente seguro entre la interfaz y el proceso principal.
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('zones', {
  getConfig: () => ipcRenderer.invoke('config:get'),
  getState: () => ipcRenderer.invoke('state:get'),
  send: (cmd) => ipcRenderer.invoke('cmd:send', cmd),
  setZones: (a) => ipcRenderer.invoke('config:setZones', a),
  setExclusions: (a) => ipcRenderer.invoke('config:setExclusions', a),
  readIpc: (name) => ipcRenderer.invoke('ipc:read', name),
  setDim: (pct) => ipcRenderer.invoke('config:setDim', pct),
  openManual: () => ipcRenderer.invoke('manual:open'),
  isDev: () => ipcRenderer.invoke('app:isDev'),
  readLog: () => ipcRenderer.invoke('log:read'),
  openLog: () => ipcRenderer.invoke('log:open'),
  clearLog: () => ipcRenderer.invoke('log:clear'),
  logError: (m) => ipcRenderer.invoke('log:renderer', String(m).slice(0, 500)),
  setOption: (key, on) => ipcRenderer.invoke('config:setOption', { key, on: !!on }),
  setHotkeys: (changes) => ipcRenderer.invoke('config:setHotkeys', changes),
  setGameZone: (profile, zone) => ipcRenderer.invoke('config:setGameZone', { profile, zone }),
  startEngine: () => ipcRenderer.invoke('engine:start'),
});
