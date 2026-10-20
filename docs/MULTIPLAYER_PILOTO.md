# Multiplayer — primeiro piloto

Versão: **0.9.0-multiplayer-pilot.1**, protocolo 1. Branch
`feat/multiplayer-pilot`, criada de `main` `c790758` (solo oficial 0.9.0).
O checkout do IDE foi preservado; o trabalho fica em `.tools/multiplayer-pilot`.
O deploy oficial do GitHub Pages continua na 0.9.0. Não foi habilitado faturamento.

## Arquitetura e limites

Godot 4.7.2 Web usa `WebSocketPeer`, JSON e WSS em HTTPS. Um processo Node 22+
simula movimento a 20 Hz e envia estado a 10 Hz. O cliente envia direção, troca
de ferramenta e tentativa de coleta; posição, alcance, colisão com recursos,
inventários, intervalo e recompensa são decididos no servidor. Não há escrita
de posições no Firestore. [Transporte Godot](https://docs.godotengine.org/en/4.7/tutorials/networking/websocket.html).

A sala tem até duas identidades, um personagem por UID verificado e inventário
privado por jogador. O UID, posição, inventário e apelido enviados pelo cliente
não concedem autoridade. O servidor usa o SDK oficial Firebase para validar a
assinatura, emissor, audiência e validade do ID token; `accounts:lookup` confirma
e-mail verificado, UID, conta disponível e limite de revogação. Somente os dois
UIDs já autorizados entram. O apelido vem do perfil existente `chatProfiles/UID`
lido com o próprio ID token, uma vez por entrada. Sem perfil, aparece Jogador 1/2.
Não são necessárias credenciais administrativas ou chaves privadas.
[Verificação Firebase](https://firebase.google.com/docs/auth/admin/verify-id-tokens),
[consulta de conta](https://firebase.google.com/docs/reference/rest/auth#get_account_info).

Tokens ficam na memória e são enviados no primeiro pacote, nunca em query string
ou logs. A renovação de token também é verificada. Há limite de pacote, de
solicitações por conexão, de conexões pendentes, timeout de autenticação,
heartbeat, lista explícita de origens Web e desconexão de cliente lento.
Tokens de emulador são recusados pelo processo de produção. O modo de teste exige
projeto `demo-*`, emulador e bind/origens de loopback. Não publique esse modo.
Revogação/desativação é reavaliada na entrada/renovação; a sessão expira com o token.

O mundo fixo mede 1280×900 e reaproveita personagem, árvores, pedras, desenho,
tema, login e ações de entrada existentes. Cada jogador começa com um machado e
uma picareta de madeira. Árvores: 3 golpes de machado, 5 madeiras; pedras:
6 golpes de picareta, 4 pedras; intervalo 0,54 s e alcance 82. Mãos também
extraem madeira em 6 golpes, com intervalo de 1,20 s. A recompensa vai a quem
conclui o recurso. O esgotamento é marcado antes da recompensa, em transação
síncrona; golpes simultâneos/repetidos não a duplicam. Ferramentas/recompensas
seguem `ResourceRules`; não há fabricação, combate, mobs, PvP, ranking ou voz.

Entrada tardia recebe um snapshot completo. Desconexão mostra o personagem
offline, para o movimento e mantém seu estado no servidor. Reconectar restaura
o mesmo ID, posição e inventário, incluindo sequência de ações. Uma nova conexão
autenticada da mesma conta substitui a anterior, que mostra aviso e não tenta
reconectar automaticamente. Falhas de rede tentam novamente com espera até 8 s.
A UI distingue validação, conectado, conta recusada, sala cheia, sessão em outro
aparelho e servidor indisponível. Sala cheia é uma proteção do limite; com a
lista fixa das duas contas, uma terceira identidade é recusada antes dela.

**O progresso multiplayer existe apenas na RAM deste processo. Reiniciar,
atualizar, suspender ou encerrar o servidor reinicia recursos e inventários.**
O cliente avisa quando encontra um novo ID de sala. Não há persistência prometida
neste piloto. Mundos solo, saves v8, backups, relógio, campanha, condições de
vitória, chat e sincronização permanecem nos caminhos e serviços anteriores.
Nenhum snapshot multiplayer é importado, salvo ou enviado para `WorldSync`.
Múltiplas réplicas do servidor não são suportadas: hospedar apenas um processo.

## Executar com as duas contas reais no próprio PC

Pré-requisitos: Node 22+, Git, Godot 4.7.2 Standard e templates Web da mesma
versão. Execute na raiz do checkout do piloto. Os comandos PowerShell abaixo
não alteram a política permanente de execução.

```powershell
cd C:\Users\gusta\Desktop\Tece-Island\.tools\multiplayer-pilot
npm ci --prefix server

# Este arquivo local já contém as mesmas duas contas do piloto solo.
$taskAccounts = 'C:\Users\gusta\Desktop\Tece-Island\.tools\solo-pilot-project\config\world-sync.json'
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start-multiplayer.ps1 -AllowedUidsFile $taskAccounts
```

Mantenha o servidor aberto. Ctrl+C encerra a sala e perde apenas o progresso de
teste. Em outro terminal na mesma raiz, exporte e sirva o cliente:

```powershell
$taskGodot = 'C:\Users\gusta\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe'
$taskTemplates = 'C:\Users\gusta\Desktop\Tece-Island\.tools\godot-templates'
$taskAccounts = 'C:\Users\gusta\Desktop\Tece-Island\.tools\solo-pilot-project\config\world-sync.json'
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export-multiplayer-pilot.ps1 -Godot $taskGodot -Templates $taskTemplates -AllowedUidsFile $taskAccounts -ServerUrl 'ws://127.0.0.1:8787/room'
node tools/serve-multiplayer.mjs
```

Abra **http://localhost:8060/** em dois perfis/navegadores independentes, entre
uma conta autorizada em cada e escolha **Multiplayer — teste**. WASD/setas andam;
1/2/3 selecionam machado/picareta/mãos; F/E ou clique no terreno coleta o recurso
próximo destacado. No celular há joystick e botão Coletar. Menu retorna à
biblioteca solo. Os alvos de toque têm pelo menos 44 pixels CSS em 640×360 emulado.

`/health` na porta 8787 retorna versão/protocolo. O servidor e o servidor estático
local escutam somente em loopback. Esse endereço não funciona em outro aparelho;
um celular precisa de cliente HTTPS e servidor WSS alcançável.

O exportador copia para `.tools/multiplayer-export` e `build/multiplayer-pilot`;
não altera configs do checkout nem os saves. A configuração fonte continua
`enabled:false`. Credenciais de servidor, `server/*`, testes e `node_modules`
são excluídos do PCK de distribuição. Não use `-Fixture` numa publicação: essa
opção cria somente a instrumentação de testes local com contas fictícias.

## Hospedagem avaliada e passo pendente

O cliente tem um novo projeto Sites privado reservado, sem substituir o piloto
solo nem o oficial: `appgprj_6ad6b7bc03c481918665130efcc41739`.
Ainda **não está publicado**: falta um backend WSS aprovado e alcançável.

Uma opção gratuita temporária é Cloudflare Quick Tunnel, encaminhando só o
servidor Node local. Não exige comprar serviço nem habilitar Firebase Billing;
o PC precisa ficar ligado. O domínio é aleatório, muda ao iniciar outro túnel,
não há SLA e o limite é 200 requisições simultâneas. Não é hospedagem permanente.
ID tokens Firebase e pacotes da partida passariam pela terminação TLS da
Cloudflare. A revisão automática de aprovação recusou essa transmissão externa
sem autorização específica; **nenhum túnel foi iniciado**.
[Condições e limites](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).

Próximo passo para publicar, após essa autorização explícita:

1. Iniciar `tools/start-multiplayer.ps1` com o arquivo das duas contas e
   `-Origins 'https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site'`.
2. Abrir um terminal com o conector oficial e executar
   `.tools/cloudflared.exe tunnel --url http://127.0.0.1:8787 --no-autoupdate --protocol http2`.
   Foi baixado o conector 2026.10.1, SHA256
   `4d2490e74082c5d48dbfedaf92576fa5bd1702379ab88eb7faa0cfbe8dc891b6`.
3. Copiar o HTTPS devolvido, trocar por `wss://` e acrescentar `/room`. Exportar
   novamente com esse `-ServerUrl`, as mesmas duas contas e sem `-Fixture`.
4. Empacotar com `tools/package-sync-pilot.mjs`, publicar no novo Sites como
   privado e verificar o WebSocket, a recusa de anônimos e a entrada real das
   duas contas. Parar túnel e servidor encerra a disponibilidade; para reabrir
   com outro domínio é preciso reexportar/republicar o endpoint.

Alternativa hospedada avaliada, **não provisionada**: Render Web Service Free,
repo nesta branch, build `npm ci --prefix server`, start `node server/index.mjs`,
`TECE_BIND=0.0.0.0`, `TECE_ALLOWED_UIDS` com os mesmos dois UIDs e `TECE_ORIGINS`
igual ao domínio privado do cliente; usar `wss://DOMINIO.onrender.com/room`.
Não configurar emulador, credencial Admin, disco ou instância paga. É necessário
acesso a uma conta Render e autorizar o repositório; esse acesso não está
disponível nesta sessão. O plano Free dorme após 15 min sem tráfego, pode levar
cerca de um minuto para acordar, tem 750 horas/mês por workspace e perde a RAM
ao reiniciar/dormir. Tráfego/build têm cotas e podem gerar cobrança conforme
plano/configuração; não adicionar cartão, faturamento ou upgrade para este piloto.
[WebSockets](https://render.com/docs/websocket), [limites Free](https://render.com/docs/free).

## Validação automatizada e reteste físico

Testes executados em 19/10/2026, com contas fictícias do emulador e sem mudar
contas, regras, configuração ou dados de produção:

- 19 testes Node: servidor/protocolo WebSocket real, duas conexões independentes,
  conta não autorizada/forjada/não verificada/anônima, movimento com velocidade
  limitada, ferramentas, distância, intervalo, replay, coleta simultânea única,
  pedras, inventários privados, entrada tardia, desconexão/reconexão/substituição,
  renovação de token, origem recusada, pacote inválido, flooding e nova sala após
  reinício do serviço. Capacidade dois também exercitada diretamente na sala.
- Dois processos de navegador independentes executaram o Godot Web real:
  teclado PC, toque/joystick em 640×360 emulado, apelidos, snapshots, coleta
  simultânea, entrada tardia, reconexão, inventário, botões e bloqueio pelo chat.
  Sala cheia foi injetada apenas para verificar sua apresentação, sem alegar
  que uma terceira conta real conseguiu autenticar.
- 14 verificações de isolamento do modo multiplayer; regressões de campanha,
  migração, reabertura do piloto, confiabilidade de saves/backups, WorldSync,
  handoff de sincronização, controles, mobile, menu e autenticação passaram.
- 22 testes de regras Firebase e 11 verificações REST do chat nativo passaram
  em emuladores. O teste de chat exige seu preparador de dados; executá-lo
  isoladamente sem o ambiente não é uma validação positiva.
- 5 verificações no processo configurado com os dois UIDs reais: inicialização
  sem chave Admin, health, recusa de anônimo/token sem assinatura mesmo com UID
  permitido e ausência de tokens/UIDs nos logs. Não usa login real nem demonstra
  sucesso com conta real. `npm audit --omit=dev`: nenhuma vulnerabilidade informada.

Reproduzir protocolo (com Java 21+ e dependências raiz instaladas):

```powershell
npm ci
npm ci --prefix server
npm run test:multiplayer
```

Para reproduzir Web: inicie Auth emulator na porta 9099, exporte com `-Fixture`
e `-ServerUrl ws://127.0.0.1:8787/room`, defina
`FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` apenas no terminal de teste e execute
`node tools/multiplayer-browser-validation.mjs`. Esse script requer Playwright
na pasta local `.tools/browser-test` e Edge (ou `BROWSER_EXE`). Ele abre/encerra
dois navegadores e os servidores locais; relatórios/imagens ficam em `.tools`.

**Ainda pendentes:** publicar/verificar WSS remoto, entrada positiva das duas
contas reais no servidor e partida física PC + celular. Mobile emulado não foi
registrado como teste físico. A campanha humana completa relatada para a 0.9.0
continua sendo evidência do solo anterior; não valida o multiplayer.

Roteiro após disponibilizar WSS:

1. PC e celular em paisagem, uma conta autorizada diferente em cada, abrir o
   piloto privado e Multiplayer — teste. Conferir 2/2 e os dois apelidos.
2. Andar em sentidos diferentes; conferir que cada controle move só o próprio
   personagem. Cortar a mesma árvore quase ao mesmo tempo: apenas 5 madeiras no
   total. Picar uma pedra e conferir 4 pedras somente para o coletor.
3. Sair no celular, coletar no PC e voltar no celular. Conferir recurso removido,
   inventário anterior e um único personagem da conta.
4. Desligar e religar a rede do celular. Conferir aviso e reconexão sem duplicação;
   abrir chat para conferir que o personagem para enquanto digita.
5. Voltar ao Menu e reabrir um mundo solo antigo/piloto: dia, inventário e campanha
   preservados. Não reiniciar servidor durante o reteste de reconexão; um reinício
   intencional deve criar nova sala com inventários de teste zerados.
