// Pruebas del actualizador de macOS con Node (sin Electron ni Mac): funciones puras, descarga con SHA-256 y guion de instalación.
// Uso:  node panel/updater.test.js
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const crypto = require('crypto');
const { spawnSync } = require('child_process');
const u = require('./updater.js');

(async () => {
  // 1) Funciones puras
  const h = 'a'.repeat(64);
  assert.strictEqual(u.hashFor(`${h}  Zonely-0.38.0-mac-arm64.dmg\n${'b'.repeat(64)}  otro.exe\n`, 'Zonely-0.38.0-mac-arm64.dmg'), h);
  assert.strictEqual(u.hashFor(`${h} *Zonely.dmg`, 'Zonely.dmg'), h);
  assert.strictEqual(u.hashFor(`${h}  x.dmg`, 'y.dmg'), null);
  assert.strictEqual(u.appBundleFromExe('/Applications/Zonely.app/Contents/MacOS/Zonely').replace(/\\/g, '/').split(':').pop(), '/Applications/Zonely.app');
  assert.strictEqual(u.appBundleFromExe('/usr/local/bin/electron'), null);
  const rel = { assets: [{ name: 'Zonely-Setup-1.0.0.exe' }, { name: 'Zonely-1.0.0-mac-arm64.dmg' }, { name: 'SHA256SUMS.txt' }] };
  assert.strictEqual(u.pickMacAssets(rel).dmg.name, 'Zonely-1.0.0-mac-arm64.dmg');
  assert.strictEqual(u.pickMacAssets({ assets: [] }).dmg, undefined);
  console.log('1) funciones puras: ok');

  // 2) Descarga con redirección y SHA-256
  const payload = crypto.randomBytes(300000);
  const server = http.createServer((req, res) => {
    if (req.url === '/redirige') { res.writeHead(302, { Location: '/archivo' }); return res.end(); }
    res.writeHead(200, { 'Content-Length': payload.length }); res.end(payload);
  }).listen(0);
  const port = server.address().port;
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'zonely-test-'));
  const file = path.join(tmp, 'x.dmg');
  let last = 0;
  const hash = await u.downloadFile(`http://127.0.0.1:${port}/redirige`, file, (f) => { last = f; }, fetch);
  server.close();
  assert.strictEqual(hash, crypto.createHash('sha256').update(payload).digest('hex'));
  assert.strictEqual(fs.statSync(file).size, payload.length);
  assert.ok(last > 0.99, 'el progreso llega al final');
  console.log('2) descarga y SHA-256: ok');

  // 3) El guion de instalación, con comandos de macOS simulados
  const bin = path.join(tmp, 'bin'); fs.mkdirSync(bin);
  const log = path.join(tmp, 'calls.log');
  const mount = path.join(tmp, 'Volumes', 'Zonely 1.0.0'); fs.mkdirSync(path.join(mount, 'Zonely.app'), { recursive: true });
  fs.writeFileSync(path.join(mount, 'Zonely.app', 'version'), 'nueva');
  const fake = (name, body) => fs.writeFileSync(path.join(bin, name), `#!/bin/bash\n${body}\n`, { mode: 0o755 });
  fake('hdiutil', `echo "hdiutil $@" >> "${log.replace(/\\/g, '/')}"; if [ "$1" = attach ]; then printf '/dev/disk9\\tApple_HFS\\t%s\\n' "${mount.replace(/\\/g, '/')}"; fi`);
  fake('ditto', 'cp -R "$1" "$2"');
  fake('open', `echo "open $@" >> "${log.replace(/\\/g, '/')}"`);
  fake('xattr', 'true');
  fake('pkill', `echo "pkill $@" >> "${log.replace(/\\/g, '/')}"`);
  const appDir = path.join(tmp, 'Apps', 'Zonely.app'); fs.mkdirSync(appDir, { recursive: true });
  fs.writeFileSync(path.join(appDir, 'version'), 'antigua');
  const dmg = path.join(tmp, 'update.dmg'); fs.writeFileSync(dmg, 'x');
  const script = path.join(tmp, 'install.sh'); fs.writeFileSync(script, u.MAC_INSTALL_SCRIPT);
  const bash = process.env.BASH_EXE || 'bash';
  const posix = (p) => p.replace(/\\/g, '/');
  const run = spawnSync(bash, [posix(script), posix(appDir), posix(dmg), '999999'], { env: { ...process.env, PATH: `${posix(bin)}:${process.env.PATH}` }, encoding: 'utf8' });
  assert.strictEqual(run.status, 0, run.stderr);
  assert.strictEqual(fs.readFileSync(path.join(appDir, 'version'), 'utf8'), 'nueva', 'la app se ha sustituido');
  assert.ok(!fs.existsSync(appDir + '.new'), 'no queda la copia temporal');
  assert.ok(!fs.existsSync(dmg), 'se borra el .dmg');
  const calls = fs.readFileSync(log, 'utf8');
  assert.ok(/pkill -x ZonelyEngine/.test(calls) && /hdiutil attach/.test(calls) && /hdiutil detach/.test(calls) && /open .*Zonely\.app/.test(calls), calls);
  console.log('3) guion de instalación: ok');
  console.log(calls.trim().split('\n').map((l) => '   ' + l).join('\n'));
  fs.rmSync(tmp, { recursive: true, force: true });
})().catch((e) => { console.error('FALLO:', e.message); process.exit(1); });
