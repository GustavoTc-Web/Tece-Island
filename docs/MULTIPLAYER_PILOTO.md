# Multiplayer — primeiro piloto

Piloto atual: [recuperação da consulta de endereço .7.1](MULTIPLAYER_PILOTO_7_1.md).
Desempenho e resposta do movimento: [piloto .7](MULTIPLAYER_PILOTO_7.md),
com reteste físico ainda pendente.
Histórico de recuperação do host/endereço: [piloto .6](MULTIPLAYER_PILOTO_6.md).
Histórico de recuperação de entrada: [piloto .5](MULTIPLAYER_PILOTO_5.md).
Histórico de desempenho, drops e HUD: [piloto .4](MULTIPLAYER_PILOTO_4.md).
Histórico do mundo compartilhado: [piloto .3](MULTIPLAYER_PILOTO_3.md).
Histórico da correção de conexão: [piloto .2](MULTIPLAYER_PILOTO_2.md).
Os registros da .1 abaixo são históricos.

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

## Hospedagem privada temporária e operação

O cliente usa um novo projeto Sites privado, sem substituir o piloto solo nem
o oficial: `appgprj_6ad6b7bc03c481918665130efcc41739`.
Endereço do cliente: https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/

Publicação privada confirmada em 19/10/2026, versão Sites **1**:

- Jogo: **0.9.0-multiplayer-pilot.1**, commit
  `1be3b14c6316889919135513db14a6e086ddb10f`.
- Fonte do pacote Sites: `dd82caa8f32a37cd8c4858293f0a74bb8808b483`.
- Deploy: `appgdep_6ad6c9f7783081919b743acfaf8d3854`, resultado `succeeded`.
- Versão salva: `appgprj_6ad6b7bc03c481918665130efcc41739~appgver_89dc6b7942a081919515049c1c952aba`.
- WSS publicado: `wss://intake-patrick-jenny-caring.trycloudflare.com/room`.
- PCK servido SHA256: `149c8185ecdc55995df3c8d06bfe53c87bee5476ecf9e6ec168f466e3f693c40`.
- Motor WASM SHA256: `fc74679e3b97f76878947fcd4fbe1268cbfa6188182a2e33bbc3f5dc9bfa57d0`,
  dividido em cinco partes verificadas.
- [CI aprovada para o código publicado](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/39355640833).

O acesso Sites continua privado, somente para o proprietário. Abra o link nos
dois aparelhos com acesso ao mesmo Sites privado e entre com contas **Firebase
diferentes** das duas já autorizadas. O login Sites e o login Firebase são etapas
distintas; nenhuma conta nova ou permissão adicional foi criada.

Uma opção gratuita temporária é Cloudflare Quick Tunnel, encaminhando só o
servidor Node local. Não exige comprar serviço nem habilitar Firebase Billing;
o PC precisa ficar ligado. O domínio é aleatório, muda ao iniciar outro túnel,
não há SLA e o limite é 200 requisições simultâneas. Não é hospedagem permanente.
O usuário autorizou expressamente o trânsito de ID tokens Firebase e pacotes da
partida pela terminação TLS da Cloudflare em 19/10/2026. Somente o serviço do
jogo em `127.0.0.1:8787` é encaminhado; não são servidos arquivos locais.
Servidor, túnel, lista de contas, porta e horários dos processos ficam registrados
em `.tools/mp-runtime.json`, sem tokens ou credenciais administrativas.
[Condições e limites](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/).

**Operação atual na .6:** usar `tools/multiplayer-start.cmd` ou
`Start -PublishEndpoint`; conferir `ready_to_play=True` em Status. A rota
atual é publicada pelo gerenciador, sem reexportar o cliente a cada túnel.
Ver [procedimento e limites da .6](MULTIPLAYER_PILOTO_6.md).

Os comandos e a reexportação abaixo descrevem a operação histórica da .1–.5.
Comandos na raiz deste checkout, usando um terminal com Node no PATH:

```powershell
# Conferir se servidor/túnel estão ativos e qual WSS está em uso.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 -Action Status

# Reiniciar somente o servidor; preserva o domínio se o túnel continuar ativo.
# Isso reinicia a sala de teste e seus inventários.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 -Action RestartServer

# Encerrar ambos: o link do jogo ficará sem servidor.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 -Action Stop

# Iniciar ambos novamente (ou reutilizar os que ainda estiverem ativos).
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 -Action Start
```

O gerenciador verifica executável e horário de criação do PID antes de encerrar
um processo, evitando encerrar processos de terceiros após reutilização de PID.
`Start` é idempotente enquanto os dois processos continuam ativos. O arquivo
das mesmas duas contas é retomado do registro local; também pode ser passado em
`-AllowedUidsFile`. O conector é iniciado oculto e apenas sua porta de métricas
local fica adicionalmente em loopback.

**Encerrar e iniciar o túnel gera outro domínio.** Se `Status` mostrar
`needs_republish: True`, o cliente publicado ainda aponta para o domínio anterior.
Não basta iniciar os processos: reexportar e republicar o endpoint novo no mesmo
Sites privado. Para interromper uma partida sem trocar o domínio, mantenha o
túnel ligado e use `RestartServer`, ciente da perda do progresso desta sala.

Procedimento para atualizar a publicação após trocar de túnel:

1. Executar `manage-multiplayer-pilot.ps1 -Action Start` e copiar o campo `wss`
   confirmado em `Status`. Não alterar a lista das duas contas autorizadas.
2. O gerenciador usa o conector oficial 2026.10.1, SHA256
   `4d2490e74082c5d48dbfedaf92576fa5bd1702379ab88eb7faa0cfbe8dc891b6`.
   Para instalação nova, baixar esse binário oficial para `.tools/cloudflared.exe`.
   O conector só encaminha `http://127.0.0.1:8787`; o acesso externo é HTTPS/WSS.
3. Exportar novamente com o novo `-ServerUrl`, as mesmas duas contas e sem
   `-Fixture`, usando `tools/export-multiplayer-pilot.ps1`.
4. Empacotar com `tools/package-sync-pilot.mjs`, publicar no novo Sites como
   privado e verificar o WebSocket, a recusa de anônimos e a entrada real das
   duas contas. A republicação exige acesso ao projeto Sites já reservado; se
   necessário, pedir a atualização ao agente com o novo endereço WSS.

Verificação automatizada do WSS de produção, sem usar logins reais:
`node tools/validate-multiplayer-wss.mjs`. Os resultados não contêm tokens.
O teste confirma health/versão, raiz 404, recusa de ações anônimas e de tokens
forjados com UID permitido ou externo, lista de exatamente duas contas e ausência
dos tokens/UIDs nos logs. A recusa de uma identidade válida fora da lista foi
exercitada nos testes do emulador; não foi criada uma terceira conta de produção.

Verificações da publicação: dez verificações externas HTTPS/WSS aprovadas,
incluindo ausência dos tokens/UIDs de teste nos quatro logs. O PCK compilado
também conectou ao endpoint real e exibiu a recusa esperada de um token sem
assinatura. Foram conferidos por hash os 17 assets estáticos servidos, incluindo
PCK, JavaScript, módulos de áudio, cinco partes do motor, fontes e ícones.
O HTML mantém o prefixo/sufixo do cliente e recebe um script adicional do Sites;
seu hash servido varia por essa inserção, enquanto o manifesto registra o hash
do HTML do pacote de origem. Isso não altera o PCK ou o endpoint.

As telas de login PC e mobile emulado e a recusa WSS a partir do próprio domínio
privado foram verificadas sem autenticar as contas reais. O verificador usa
autorização de serviço enviada exclusivamente ao domínio Sites. AudioWorklet
não herda esse cabeçalho no navegador headless. Na verificação final, os dois
módulos de áudio foram fornecidos como Blobs com os mesmos bytes servidos e
conferidos por hash, sem alterar o jogo publicado ou inserir tokens no jogo.
As **30 verificações finais da publicação passaram**; a entrega normal com cookies
de uma sessão Sites e a reprodução de áudio em aparelho real ficam no reteste
físico. Não confundir esse teste com uma partida humana.

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

Registro do pacote local concluído:

- Código: `5ec809a37c817bcead0509da8d506ffc9167c2d6`.
- [CI de protocolo aprovada](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/39349657771).
- Web: **21 verificações aprovadas**, incluindo entrada pelo botão real do lobby
  e retorno à biblioteca solo. [PC](images/multiplayer-pc-1280.png) e
  [mobile emulado](images/multiplayer-mobile-640.png).
- PCK compilado: **7 verificações aprovadas**, sem fallback para os arquivos do
  projeto fonte: versão/commit, endpoint, contas/configurações, exclusões,
  abertura multiplayer, save legado v5 e save v8 com vitória no dia 7.
- PCK SHA256: `5cc17eb0093d083646a1925b623eb568db9ce0f1db648d45504e67fa92b9b851`.
- ZIP local: `build/tece-island-0.9.0-multiplayer-pilot.1-local.zip`, SHA256
  `a6f103e4f468b2e26386b8e3116a42f6ea77a3137665b625a98bc01e42469eaa`.
- Manifesto servido no endereço oficial reconferido: 0.9.0,
  `15ba9685c120ce867588668a35f3c3f53077981d`, PCK
  `2681e0b166b982a9642019770b11803dde28c76bfa1e7b20fcc1a8c31a8d40ae`.
  `main`, `v0.9.0` e configurações das duas contas não foram modificadas.

Reproduzir protocolo (com Java 21+ e dependências raiz instaladas):

```powershell
npm ci
npm ci --prefix server
npm run test:multiplayer
```

Para reproduzir Web: inicie Auth emulator na porta 9099, exporte com `-Fixture`
e `-ServerUrl ws://127.0.0.1:8789/room`, defina
`FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` apenas no terminal de teste e execute
`node tools/multiplayer-browser-validation.mjs`. Esse script requer Playwright
na pasta local `.tools/browser-test` e Edge (ou `BROWSER_EXE`). Ele abre/encerra
dois navegadores e os servidores locais; relatórios/imagens ficam em `.tools`.

**Ainda pendentes:** entrada positiva das duas contas reais no servidor e partida
física PC + celular. Mobile emulado não foi
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
