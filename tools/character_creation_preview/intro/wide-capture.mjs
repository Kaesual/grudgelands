// Website-only opening capture and preview checks. Each render gets a fresh
// page, following render-scenes.mjs's initial load + explicit selection.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';
import {createHash} from 'node:crypto';

const args = process.argv.slice(2);
const option = name => { const i = args.indexOf(name); return i < 0 ? null : args[i + 1]; };
const chrome = option('--chrome') || process.env.CHROME_BIN || '/usr/bin/chromium-browser';
const here = path.dirname(fileURLToPath(import.meta.url));
const render = option('--render');
if (!render && !args.includes('--preview')) throw Error('Use --render TEMP_DIRECTORY or --preview');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');

class CDP {
 constructor(url) {
  this.ws = new WebSocket(url); this.next = 0; this.calls = new Map(); this.errors = [];
  this.open = new Promise((resolve, reject) => {
   this.ws.addEventListener('open', resolve, {once: true});
   const fail = () => {
    const error = Error('Browser connection closed'); reject(error);
    for (const call of this.calls.values()) call.reject(error);
    this.calls.clear();
   };
   this.ws.addEventListener('error', fail); this.ws.addEventListener('close', fail);
  });
  this.ws.addEventListener('message', event => {
   const message = JSON.parse(event.data);
   if (message.id) {
    const call = this.calls.get(message.id); if (!call) return;
    this.calls.delete(message.id);
    if (message.error) call.reject(Error(JSON.stringify(message.error))); else call.resolve(message.result);
   } else if (message.method === 'Runtime.exceptionThrown' ||
              (message.method === 'Runtime.consoleAPICalled' && message.params.type === 'error') ||
              (message.method === 'Log.entryAdded' && message.params.entry.level === 'error')) {
    this.errors.push(message.params);
   }
  });
 }
 async send(method, params = {}) {
  await this.open;
  if (this.ws.readyState !== WebSocket.OPEN) throw Error('Browser connection is not open');
  return new Promise((resolve, reject) => {
   const id = ++this.next; this.calls.set(id, {resolve, reject});
   this.ws.send(JSON.stringify({id, method, params}));
  });
 }
 async evaluate(expression) {
  const result = await this.send('Runtime.evaluate', {expression, awaitPromise: true, returnByValue: true});
  if (result.exceptionDetails) throw Error(JSON.stringify(result.exceptionDetails));
  return result.result.value;
 }
}

let profile, browser, control, page;
try {
 profile = await fs.mkdtemp(path.join(os.tmpdir(), 'grug-intro-wide-browser-'));
 browser = spawn(chrome, ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--disable-gpu-sandbox', '--force-color-profile=srgb', '--remote-debugging-port=0',
  '--user-data-dir=' + profile, 'about:blank'], {stdio: ['ignore', 'ignore', 'pipe']});
 let log = '';
 const wsURL = await new Promise((resolve, reject) => {
  browser.stderr.on('data', data => {
   log = (log + data).slice(-8000);
   const match = log.match(/DevTools listening on (ws:\/\/[^\s]+)/); if (match) resolve(match[1]);
  });
  browser.once('error', reject);
  browser.once('exit', code => reject(Error('Browser exited ' + code + ': ' + log)));
 });
 control = new CDP(wsURL);
 const targets = await (await fetch('http://' + new URL(wsURL).host + '/json/list')).json();
 page = new CDP(targets.find(target => target.type === 'page').webSocketDebuggerUrl);
 for (const domain of ['Runtime', 'Page', 'Log']) await page.send(domain + '.enable');
 async function open(file, width, height) {
  await page.send('Emulation.setDeviceMetricsOverride', {width, height, deviceScaleFactor: 1, mobile: false});
  const loaded = new Promise((resolve, reject) => {
   const closed = () => { page.ws.removeEventListener('message', listener); reject(Error('Closed during load')); };
   function listener(event) {
    if (JSON.parse(event.data).method === 'Page.loadEventFired') {
     page.ws.removeEventListener('message', listener); page.ws.removeEventListener('close', closed); resolve();
    }
   }
   page.ws.addEventListener('message', listener); page.ws.addEventListener('close', closed, {once: true});
  });
  await page.send('Page.navigate', {url: pathToFileURL(file).href}); await loaded;
 }
 const browserVersion = await control.send('Browser.getVersion');
 if (render) {
  const captures = {browser: browserVersion};
  for (const [name, width, height] of [['wide', 2560, 1440], ['game-base', 1920, 1080], ['game-layer', 1920, 1080]]) {
   console.log('Rendering ' + name);
   await open(path.join(render, name + '.html'), width, height);
   await page.evaluate('window.sceneReady');
   const settings = await page.evaluate(`selectScene('intro', ${width}, ${height})`);
   // Wait for atmosphere textures too; the old page waits for node textures.
   await page.evaluate(`(async () => {
    const images = new Set(); view.root.traverse(o => { if (o.material?.map?.image) images.add(o.material.map.image); });
    await Promise.all([...images].map(image => image.decode()));
    await new Promise(resolve => requestAnimationFrame(resolve)); view.step(0);
   })()`);
   const encoded = await page.evaluate('view.renderer.domElement.toDataURL("image/png").split(",")[1]');
   const state = await page.evaluate(`({fov:view.camera.fov, reference:reference.visible,
    fog:{near:view.scene.fog.near,far:view.scene.fog.far,color:view.scene.fog.color.getHexString()},
    shadowMap:view.renderer.shadowMap.enabled,outputEncoding:view.renderer.outputEncoding})`);
   if (state.reference || page.errors.length) throw Error(JSON.stringify(page.errors));
   await fs.writeFile(path.join(render, name + '.png'), Buffer.from(encoded, 'base64'));
   captures[name] = {...settings, ...state};
  }
  await fs.writeFile(path.join(render, 'captures.json'), JSON.stringify(captures, null, 2) + '\n');
 } else {
  const folder = path.join(here, 'wide'), checks = [];
  const check = (pass, label) => { checks.push({pass: !!pass, label}); if (!pass) throw Error(label); };
  await open(path.join(folder, 'index.html'), 1600, 1000);
  await page.evaluate('Promise.all([...document.images].map(image => image.decode()))');
  check(await page.evaluate('[...document.images].every(i=>i.naturalWidth===(i.dataset.game?1920:2560))'), 'All wide and game images decode at their original size');
  check(await page.evaluate('document.querySelector("#compact").getBoundingClientRect().width===1366 && document.querySelector("#compact").getBoundingClientRect().height===768'), '1366 x 768 view');
  await page.evaluate('document.querySelector("#native").open=true');
  check(await page.evaluate('document.querySelector("#full").getBoundingClientRect().width===2560 && document.querySelector("#full").getBoundingClientRect().height===1440'), '2560 x 1440 view');
  await page.evaluate('document.querySelector("#native").open=false;document.querySelector("#overlay").click()');
  check(await page.evaluate('[...document.querySelectorAll(".layout")].every(e=>getComputedStyle(e).display==="none")'), 'Overlay switches off');
  await page.evaluate('document.querySelector("#overlay").click()');
  check(await page.evaluate('[...document.querySelectorAll(".layout")].every(e=>getComputedStyle(e).display!=="none")'), 'Overlay switches on');
  check(await page.evaluate('document.documentElement.scrollWidth<=innerWidth'), 'No page overflow at 1600');
  const height = await page.evaluate('document.documentElement.scrollHeight');
  const shot = await page.send('Page.captureScreenshot', {format: 'png', captureBeyondViewport: true,
   clip: {x: 0, y: 0, width: 1600, height, scale: 1}});
  const png = Buffer.from(shot.data, 'base64'); await fs.writeFile(path.join(folder, 'preview.png'), png);
  await page.send('Emulation.setDeviceMetricsOverride', {width: 1366, height: 768, deviceScaleFactor: 1, mobile: false});
  check(await page.evaluate('document.documentElement.scrollWidth<=innerWidth'), 'No page overflow at 1366');
  check(page.errors.length === 0, 'No console, JavaScript or resource errors');
  const sources = {};
  for (const file of ['index.html', 'intro.json', '../../../web_data/media/grug_creation_intro_wide.png', '../../../../mods/PLAYER/grug_classes/textures/grug_creation_intro.png']) sources[file] = hash(await fs.readFile(path.join(folder, file)));
  sources['wide-capture.mjs'] = hash(await fs.readFile(fileURLToPath(import.meta.url)));
  await fs.writeFile(path.join(folder, 'browser-check.json'), JSON.stringify({browser: browserVersion,
   checks, errors: page.errors, sources, preview: {width: 1600, height, overlay: true, output: hash(png)}}, null, 2) + '\n');
  console.log(checks.length + ' wide preview checks PASS; preview.png 1600 x ' + height);
 }
} finally {
 page?.ws.close();
 if (browser?.pid && browser.exitCode === null && browser.signalCode === null) {
  const closed = new Promise(resolve => browser.once('exit', resolve));
  // Let Chromium finish its profile writes after acknowledging Browser.close.
  // Terminate only if its control connection failed, not on a successful close.
  if (control) await control.send('Browser.close').catch(() => browser.kill('SIGTERM'));
  else browser.kill('SIGTERM');
  await closed;
 }
 control?.ws.close();
 if (profile) await fs.rm(profile, {recursive: true, force: true, maxRetries: 5, retryDelay: 100});
}
// Native WebSocket can retain a closing handle after Chromium has exited.
// All writes, browser shutdown and profile cleanup have been awaited above.
process.exit(0);
