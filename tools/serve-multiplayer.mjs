import {createServer} from 'node:http';
import {readFile} from 'node:fs/promises';
import {resolve, sep, extname} from 'node:path';
const root = resolve('build/multiplayer-pilot');
createServer(async (req, res) => {
  const path = resolve(root, '.' + (new URL(req.url, 'http://localhost').pathname === '/' ? '/index.html' : new URL(req.url, 'http://localhost').pathname));
  if (!path.startsWith(root + sep)) {res.writeHead(403); res.end(); return;}
  try {
    const bytes = await readFile(path);
    res.writeHead(200, {'Content-Type': {'.html':'text/html', '.js':'text/javascript', '.wasm':'application/wasm', '.svg':'image/svg+xml', '.json':'application/json', '.ttf':'font/ttf'}[extname(path)] || 'application/octet-stream', 'Cache-Control':'no-store'});
    res.end(bytes);
  } catch {res.writeHead(404); res.end();}
}).listen(8060, '127.0.0.1', () => console.log('Piloto local: http://localhost:8060/ (somente este computador; Ctrl+C encerra)'));
