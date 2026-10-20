import {WebSocket} from 'ws';
import {initializeApp, deleteApp} from 'firebase-admin/app';
import {getAuth} from 'firebase-admin/auth';

export const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
export async function identities() {
  if (process.env.FIREBASE_AUTH_EMULATOR_HOST !== '127.0.0.1:9099') throw Error('Local Auth emulator on 9099 is required; production is never used');
  const app = initializeApp({projectId: 'demo-tece-island'}, `test-${crypto.randomUUID()}`);
  const auth = getAuth(app), result = {};
  for (const uid of ['mp-a', 'mp-b', 'mp-outsider', 'mp-unverified']) {
    try {await auth.deleteUser(uid);} catch {}
    await auth.createUser({uid, email: `${uid}@example.test`, password: 'local-emulator-only-123', emailVerified: uid !== 'mp-unverified'});
    const response = await fetch('http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=local-test', {
      method: 'POST', headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email: `${uid}@example.test`, password: 'local-emulator-only-123', returnSecureToken: true})
    });
    const data = await response.json();
    if (!data.idToken) throw Error('Emulator sign-in failed');
    result[uid] = {uid, token: data.idToken};
  }
  await deleteApp(app);
  return result;
}
export class Client {
  constructor(url, origin = 'http://localhost:8060') {
    this.ws = new WebSocket(url, {origin});
    this.messages = [];
    this.seq = 0; this.input = 0;
    this.ws.on('message', bytes => {const message = JSON.parse(bytes); this.messages.push(message); if (message.type === 'state' || message.type === 'welcome') this.state = message;});
    this.ws.on('close', (code, reason) => {this.closed = {code, reason: reason.toString()};});
    this.ws.on('error', () => {});
  }
  async wait(predicate, timeout = 5000) {
    const end = Date.now() + timeout;
    do {const found = this.messages.find(predicate); if (found) return found; await pause(15);} while (Date.now() < end);
    throw Error('Timed out waiting for protocol message');
  }
  async open() {while (this.ws.readyState === WebSocket.CONNECTING) await pause(10); if (this.ws.readyState !== WebSocket.OPEN) throw Error('Socket refused');}
  async hello(identity, extra = {}) {
    await this.open(); this.send({type: 'hello', protocol: 1, ...identity, ...extra});
    const response = await this.wait(m => ['welcome', 'error'].includes(m.type));
    if (response.type === 'welcome') {this.self = response.self; this.seq = response.nextAction - 1;}
    return response;
  }
  send(data) {this.ws.send(JSON.stringify(data));}
  async action(type, data = {}) {
    const seq = ++this.seq;
    this.send({type, seq, ...data});
    return this.wait(m => m.type === 'ack' && m.action === type && m.seq === seq);
  }
  async walk(x, y, ms) {
    const end = Date.now() + ms;
    while (Date.now() < end) {this.send({type: 'input', seq: ++this.input, x, y}); await pause(50);}
    this.send({type: 'input', seq: ++this.input, x: 0, y: 0}); await pause(120);
  }
  close() {this.ws.close();}
}
