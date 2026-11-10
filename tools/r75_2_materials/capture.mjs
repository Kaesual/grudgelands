// Capture a selected material-gallery scene from the generated local page.
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {pathToFileURL} from 'node:url';
import {spawn} from 'node:child_process';

const here = path.dirname(new URL(import.meta.url).pathname);
const chrome = process.env.CHROME;
if (!chrome) throw new Error('set CHROME to a Chromium/Chrome executable');
const output = process.argv[2] || path.join(here, 'reported-four.png');
const scene = process.argv[3] || 'reported_four_lua';
const targetX = Number(process.argv[4] || 4.5);
const targetZ = Number(process.argv[5] || 0);
const cameraY = Number(process.argv[6] || 4.2);
const cameraDistance = Number(process.argv[7] || 6);
class Client {
  constructor(url) {
    this.ws = new WebSocket(url); this.id = 0; this.pending = new Map();
    this.ready = new Promise((resolve, reject) => { this.ws.onopen = resolve; this.ws.onerror = reject; });
    this.ws.onmessage = event => { const msg = JSON.parse(event.data); if (!msg.id) return;
      const waiter = this.pending.get(msg.id); this.pending.delete(msg.id);
      msg.error ? waiter.reject(msg.error) : waiter.resolve(msg.result); };
  }
  async send(method, params = {}) { await this.ready; return new Promise((resolve, reject) => {
    const id = ++this.id; this.pending.set(id, {resolve, reject});
    this.ws.send(JSON.stringify({id, method, params})); }); }
  async eval(expression) { const result = await this.send('Runtime.evaluate',
    {expression, awaitPromise: true, returnByValue: true});
    if (result.exceptionDetails) throw new Error(JSON.stringify(result.exceptionDetails));
    return result.result.value; }
}

const profile = await fs.mkdtemp(path.join(os.tmpdir(), 'r75-2-chrome-'));
const browser = spawn(chrome, ['--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
  '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader',
  '--disable-gpu-sandbox', '--remote-debugging-port=0', '--user-data-dir=' + profile,
  'about:blank'], {stdio: ['ignore', 'ignore', 'pipe']});
let log = '';
const browserSocket = await new Promise((resolve, reject) => {
  browser.stderr.on('data', data => { log += data; const found = log.match(/DevTools listening on (ws:\/\/[^\s]+)/);
    if (found) resolve(found[1]); }); browser.onerror = reject;
});
const host = new URL(browserSocket).host;
const targets = await (await fetch('http://' + host + '/json/list')).json();
const page = new Client(targets.find(target => target.type === 'page').webSocketDebuggerUrl);
await page.send('Page.enable'); await page.send('Runtime.enable');
await page.send('Emulation.setDeviceMetricsOverride', {width: 1600, height: 900, deviceScaleFactor: 1, mobile: false});
await page.send('Page.navigate', {url: pathToFileURL(path.join(here, 'index.html')).href});
await new Promise(resolve => setTimeout(resolve, 3000));
await page.eval("document.getElementById('collapse').click(); true");
await page.eval(`__viewer.setTown(${JSON.stringify(scene)}); true`);
await page.eval(`__viewer.view.lookAt([${targetX},${cameraY},${targetZ - cameraDistance}],` +
  `[${targetX},1,${targetZ}]); true`);
await new Promise(resolve => setTimeout(resolve, 500));
const shot = await page.send('Page.captureScreenshot', {format: 'png'});
await fs.writeFile(output, Buffer.from(shot.data, 'base64'));
await (new Client(browserSocket)).send('Browser.close').catch(() => {});
await new Promise(resolve => browser.on('exit', resolve));
await fs.rm(profile, {recursive: true, force: true});
console.log('R75.2 MATERIAL SCREENSHOT ' + output + ' scene=' + scene);
