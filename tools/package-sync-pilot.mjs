// Static pilot packaging: keep every asset below the hosting file-size limit.
// Engine code is unchanged; fetch reassembles and validates the exported WASM.
import {cp, mkdir, readFile, writeFile, stat, unlink} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
const input = path.resolve(process.argv[2] || 'build/sync-test');
const output = path.resolve(process.argv[3] || '.tools/sync-pilot-site/dist');
const game = path.join(output, 'Tece-Island');
await mkdir(game, {recursive: true});
await cp(input, game, {recursive: true});
const wasm = await readFile(path.join(input, 'index.wasm'));
const digest = createHash('sha256').update(wasm).digest('hex');
const parts = [];
for (let start = 0; start < wasm.length; start += 8 * 1024 * 1024) {
  const part = wasm.subarray(start, start + 8 * 1024 * 1024);
  const name = `engine-${digest.slice(0, 16)}-${parts.length}.bin`;
  await writeFile(path.join(game, name), part);
  parts.push({name, bytes: part.length});
}
await unlink(path.join(game, 'index.wasm'));
const manifest = {sha256: digest, bytes: wasm.length, parts};
await writeFile(path.join(game, 'pilot-engine.json'), JSON.stringify(manifest, null, 2));
const loader = `
// Split WASM loader; hashed names and digest prevent mixed/corrupt engine parts.
(() => {
 const manifest = ${JSON.stringify(manifest)};
 const originalFetch = window.fetch.bind(window);
 const directory = new URL('./', location.href);
 const target = new URL('index.wasm', directory).href;
 window.fetch = async (input, init) => {
  const url = new URL(input instanceof Request ? input.url : input, location.href);
  if (url.href !== target) return originalFetch(input, init);
  const buffers = await Promise.all(manifest.parts.map(async part => {
   const response = await originalFetch(new URL(part.name, directory), init);
   if (!response.ok) throw new Error('Falha ao carregar parte do jogo: HTTP ' + response.status);
   const buffer = await response.arrayBuffer();
   if (buffer.byteLength !== part.bytes) throw new Error('Parte incompleta do jogo. Recarregue a página.');
   return new Uint8Array(buffer);
  }));
  const bytes = new Uint8Array(manifest.bytes); let offset = 0;
  for (const buffer of buffers) { bytes.set(buffer, offset); offset += buffer.length; }
  const hash = Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', bytes)), b => b.toString(16).padStart(2, '0')).join('');
  if (hash !== manifest.sha256) throw new Error('O jogo baixado está incompleto. Recarregue a página.');
  return new Response(bytes, {headers: {'Content-Type': 'application/wasm', 'Content-Length': String(bytes.length)}});
 };
})();
`;
let html = await readFile(path.join(game, 'index.html'), 'utf8');
if (!html.includes('const engine=new Engine(')) throw new Error('Export shell does not expose Engine initialization');
html = html.replace('const engine=new Engine(', `${loader}\nconst engine=new Engine(`);
html = html.replace('</head>', '<style>#pilot-badge{position:fixed;z-index:500;top:4px;right:8px;font:12px sans-serif;color:#e7f3db;background:#173b2ded;border:1px solid #5d815b;border-radius:8px;padding:5px 9px;pointer-events:none} @media(max-height:420px){#pilot-badge{font-size:10px;top:2px;padding:3px 6px}}</style></head>');
html = html.replace('<body>', '<body><div id="pilot-badge">Piloto de sincronização · contas de teste</div>');
await writeFile(path.join(game, 'index.html'), html);
await writeFile(path.join(output, 'index.html'), '<!doctype html><html lang="pt-BR"><meta charset="utf-8"><title>Tece-Island · piloto</title><meta http-equiv="refresh" content="0;url=/Tece-Island/"><a href="/Tece-Island/">Abrir piloto de sincronização</a></html>');
for (const part of parts) if ((await stat(path.join(game, part.name))).size > 25 * 1024 * 1024) throw new Error('Asset exceeds static limit');
console.log(JSON.stringify({wasm_bytes: wasm.length, parts: parts.length, max_part_bytes: Math.max(...parts.map(p => p.bytes)), sha256: digest, output}));
