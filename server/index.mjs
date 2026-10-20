import {readFile} from 'node:fs/promises';
import {firebaseVerifier, readNickname} from './auth.mjs';
import {startServer} from './service.mjs';

const publicConfig = JSON.parse(await readFile(new URL('../config/firebase-public.json', import.meta.url), 'utf8'));
const projectId = process.env.TECE_FIREBASE_PROJECT || publicConfig.projectId;
const apiKey = process.env.TECE_FIREBASE_API_KEY || publicConfig.apiKey;
let allowedUids = (process.env.TECE_ALLOWED_UIDS || '').split(',').map(s => s.trim()).filter(Boolean);
if (process.env.TECE_ALLOWED_UIDS_FILE) {
  const config = JSON.parse(await readFile(process.env.TECE_ALLOWED_UIDS_FILE, 'utf8'));
  allowedUids = config.allowed_uids;
}
const localTest = process.env.TECE_LOCAL_AUTH_TEST === '1';
const host = process.env.TECE_BIND || '127.0.0.1';
const origins = (process.env.TECE_ORIGINS || 'http://localhost:8060,http://127.0.0.1:8060').split(',').map(s => s.trim());
if (localTest && (host !== '127.0.0.1' || !projectId.startsWith('demo-') || origins.some(o => !['localhost', '127.0.0.1'].includes(new URL(o).hostname)))) throw new Error('Local test authentication is restricted to loopback and demo projects');
const verifier = firebaseVerifier({projectId, apiKey, localTest});
const server = await startServer({verify: token => verifier.verify(token),
  nickname: (token, uid) => readNickname({projectId, token, uid, localTest}),
  allowedUids, origins, host, port: Number(process.env.PORT || 8787)});
console.log(`Multiplayer protocol 1 listening on ${host}:${server.port}; ${localTest ? 'LOCAL EMULATOR ONLY' : 'Firebase verification enabled'}; room resets on restart`);
let stopping = false;
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => {
  if (stopping) return; stopping = true;
  await server.close(); await verifier.close(); process.exit(0);
});
