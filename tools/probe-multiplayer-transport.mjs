import {WebSocket} from '../server/node_modules/ws/wrapper.mjs';

// Read-only readiness probe: no account, token, character or room mutation.
const url = process.argv[2];
const result = {https:false, wss:false, version:'', protocol:0, error:''};
try {
  if (!/^wss:\/\/[a-z0-9-]+\.trycloudflare\.com\/room$/.test(url)) throw Error('invalid_endpoint');
  const response = await fetch(url.replace('wss:', 'https:').replace('/room','/health'), {signal:AbortSignal.timeout(6000)});
  if (!response.ok) throw Error('http_'+response.status);
  const health = await response.json();
  result.https = health.ok === true;
  result.version = health.version;
  result.protocol = health.protocol;
  result.wss = await new Promise((resolve,reject)=>{
    const ws = new WebSocket(url,{origin:'https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site',handshakeTimeout:6000});
    const timer = setTimeout(()=>{ws.terminate();reject(Error('wss_timeout'));},8000);
    ws.on('open',()=>ws.send(JSON.stringify({type:'input',seq:1,x:0,y:0})));
    ws.on('message',bytes=>{
      const message = JSON.parse(bytes);
      clearTimeout(timer);ws.close();
      resolve(message.type === 'error' && message.code === 'auth_required');
    });
    ws.on('error',()=>{clearTimeout(timer);reject(Error('wss_failed'));});
    ws.on('close',()=>{clearTimeout(timer);resolve(false);});
  });
} catch (error) {result.error = error.cause?.code || error.code || (/^(http_\d+|invalid_endpoint|wss_timeout|wss_failed)$/.test(error.message) ? error.message : error.name);}
console.log(JSON.stringify(result));
process.exitCode = result.https && result.wss ? 0 : 1;
