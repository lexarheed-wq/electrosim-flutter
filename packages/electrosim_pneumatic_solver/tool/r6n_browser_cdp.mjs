import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as sleep } from 'node:timers/promises';

// CDP observes the real DOM after a Worker reply, never the script source.
const [binary, target] = process.argv.slice(2);
if (!binary || !target) throw new Error('Chrome path and URL required');
const directory = await mkdtemp(join(tmpdir(), 'r6n-chrome-'));
const port = 19387;
const chrome = spawn(binary, [
  '--headless=new', '--no-sandbox', '--disable-dev-shm-usage',
  '--disable-gpu', '--no-first-run',
  `--remote-debugging-port=${port}`,
  `--user-data-dir=${directory}`, target,
], { stdio: 'ignore' });
let socket;
try {
  let page;
  for (let attempt = 0; attempt < 160; attempt++) {
    if (chrome.exitCode !== null) throw new Error('Chromium exited unexpectedly');
    try {
      const response = await fetch(`http://127.0.0.1:${port}/json`);
      if (response.ok) {
        const pages = await response.json();
        page = pages.find(p => p.type === 'page' && p.url.startsWith(target));
        if (page?.webSocketDebuggerUrl) break;
      }
    } catch (_) { /* Chrome is still starting. */ }
    await sleep(100);
  }
  if (!page?.webSocketDebuggerUrl) throw new Error('Chromium CDP unavailable');
  socket = new WebSocket(page.webSocketDebuggerUrl);
  await Promise.race([
    new Promise((resolve, reject) => {
      socket.addEventListener('open', resolve, { once: true });
      socket.addEventListener('error', reject, { once: true });
    }),
    sleep(12000).then(() => { throw new Error('CDP connection timeout'); }),
  ]);
  // A headless tab may navigate after CDP attaches. Evaluating a long
  // promise across that navigation destroys its execution context. Poll the
  // DOM using independent evaluations and retry *only* that navigation error.
  const evaluate = (id) => new Promise((resolve, reject) => {
    const onMessage = event => {
      let message;
      try {
        message = JSON.parse(event.data);
      } catch (error) {
        socket.removeEventListener('message', onMessage);
        reject(error);
        return;
      }
      if (message.id !== id) return;
      socket.removeEventListener('message', onMessage);
      if (message.error) reject(new Error(JSON.stringify(message.error)));
      else resolve(message.result?.result?.value ?? 'R6N_NO_OUTPUT');
    };
    socket.addEventListener('message', onMessage);
    socket.send(JSON.stringify({
      id,
      method: 'Runtime.evaluate',
      params: {
        expression: "document.getElementById('result')?.textContent ?? 'R6N_NO_OUTPUT'",
        returnByValue: true,
      },
    }));
  });
  let result = 'R6N_NO_OUTPUT';
  for (let attempt = 1; attempt <= 300; attempt++) {
    if (chrome.exitCode !== null) throw new Error('Chromium exited unexpectedly');
    try {
      result = await Promise.race([
        evaluate(attempt),
        sleep(2000).then(() => { throw new Error('CDP evaluation timeout'); }),
      ]);
      if (result !== 'R6N_PENDING' && result !== 'R6N_NO_OUTPUT') break;
    } catch (error) {
      if (!String(error).includes('Execution context was destroyed') &&
          !String(error).includes('Cannot find context')) {
        throw error;
      }
    }
    await sleep(100);
  }
  if (result !== 'R6N_WEB_WORKER_PASS') {
    throw new Error(`Real Chromium worker status: ${result}`);
  }
  process.stdout.write('R6N_WEB_WORKER_PASS\n');
} finally {
  socket?.close();
  chrome.kill('SIGTERM');
  await sleep(250);
  if (chrome.exitCode === null) chrome.kill('SIGKILL');
  await rm(directory, { recursive: true, force: true });
}
