# Piloto .5 — recuperação da entrada e diagnóstico de conexão

Versão **0.9.0-multiplayer-pilot.5**, protocolo **3**, branch
`feat/multiplayer-pilot`. Mesmo [piloto privado](https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/).
Oficial 0.9.0, saves solo v8, campanha e duas contas preservados; sem faturamento.

## Causa comprovada antes da recuperação

- Servidor `25248` e cloudflared `33464` da .4 já não estavam executando.
  A porta loopback 8791 não tinha listener; HTTP local retornou
  `ECONNREFUSED`. HTTPS e WSS externos do endereço publicado falharam com
  `ENOTFOUND`.
- O manifesto realmente servido identificava .4, commit `4791f31`, protocolo
  3 e `wss://donors-gave-pmid-rental.trycloudflare.com/room`, igual ao runtime
  registrado. O PCK servido tinha SHA256
  `3fd595cab897582154e650132d366820e16ecfa48132c02ceba33dea596fa1db`.
  Não havia evidência de versão incorreta ou incompatibilidade de protocolo.
- O cloudflared registra encerramento por sinal em **20/10/2026 às 22:36:01
  BRT** (21/10 01:36:01 UTC). O Windows registra suspensão, evento 42 do
  Kernel-Power, às 22:36:05. Essa proximidade é evidência de contexto; não
  prova quem enviou o sinal. A máquina não reiniciou nesse intervalo.
- A falha reproduzida ocorreu **na conexão**, antes de autenticar ou receber
  o estado inicial. O cenário parcial era desenhado pelo cliente localmente;
  sua presença não comprovava uma sala ativa.

Os logs/runtime antigos foram copiados antes de iniciar processos novos.
O servidor já estava encerrado, portanto seu estado em RAM já havia sido
perdido antes desta recuperação. Foi necessário iniciar uma **nova sala**.
Nenhum mundo solo foi importado, apagado ou sobrescrito.

## Correções

- Hospedagem local sob uma tarefa Windows sob demanda
  **`TeceIsland-Multiplayer-mp`**, no usuário atual, sem elevação, senha salva
  ou gatilho de início automático. Ela mantém o host fora da shell das
  ferramentas. A shell que solicitou o início foi encerrada e a tarefa,
  servidor e túnel continuaram ativos; a origem do processo foi conferida.
  `Start` repetido preservou os PIDs do servidor e do túnel.
- A tarefa não reinicia a sala silenciosamente. Há registros de operação e
  detecção de processos ausentes em `.tools/mp-host/events.jsonl`. Os comandos
  `Start`, `Stop`, `RestartServer` e `RepairTunnel` continuam no mesmo script;
  operações de início/reparo são executadas pelo host. `Stop` para a tarefa
  e encerra somente processos com PID, executável e início conferidos.
- Novo Quick Tunnel; o pacote .5 usa o endereço novo e mantém protocolo 3.
  O hostname anterior não é reaproveitável depois de encerrar o Quick Tunnel.
- Cliente distingue **conexão WSS**, **autenticação**, **estado inicial** e
  **partida**. O aviso mostra etapa, host, tentativa, versão/protocolo e código
  de fechamento, sem credenciais. O cenário só é mostrado após receber a sala.
- Servidor registra conexão aleatória, `socket_open`, `auth_begin`, `auth_ok`,
  `welcome_sent`, `state_started`, rejeições e fechamento. O `/health` expõe
  contadores agregados. Não há UID, apelido, token, payload ou exceção bruta
  nos novos registros. Os timeouts de autenticação e estado inicial são
  separados. Falha na leitura opcional de apelido usa nome padrão, sem tratar
  identidade já validada como falha de autenticação.
- Chat passa para o canto superior direito enquanto a sala conecta; o cartão
  de diagnóstico começa abaixo de uma faixa reservada de 64 CSS px. Ao entrar
  na partida, Chat retorna à posição usual. Estilos são removidos ao sair do
  multiplayer; o solo continua com a apresentação existente.

## Validação e limites

- **32 testes do servidor**: WS real, duas identidades do Auth emulado,
  movimentos, concorrência, reconexão, recusas e novos diagnósticos. Um teste
  segura o apelido para conferir a distinção entre conta autenticada e sala
  recebida; depois simula falha do perfil e confirma entrada com nome padrão.
  Logs e health foram verificados contra tokens, UIDs e payloads de erro.
- **355 verificações Godot** de campanha, migração/reabertura, saves, sync,
  handoff, controles, mobile/menu, autenticação, poços e isolamento/drops/HUD;
  **22** de regras e **11** de chat nativo em emuladores.
- Web: dois processos Edge independentes, PC 1920×950 e mobile emulado
  640×360, contas emuladas distintas. Estados de autenticação/recebimento foram
  observados com latência artificial só no teste. Personagens apareceram e
  moveram na mesma sala; o roteiro também interrompe o transporte, verifica
  diagnóstico/Chat em ambos os formatos e reconecta os dois personagens.
  Capturas de partida e de falha são emuladas, não partidas humanas.
- WSS público recusa conexão anônima e token sem assinatura; isso valida
  transporte e restrição, não login positivo das contas reais.

**Reteste físico confirmado pelo usuário em 21/10/2026:** após a solicitação de
entrada na .5 com uma conta no PC e outra no celular, respondeu: “Os dois
entraram e se movem”. Registradas **entrada dos dois jogadores e movimentação**
no piloto publicado, conforme o [relato manual](evidence/multiplayer-pilot-5-manual.json).

Continuam pendentes de confirmação física: **desempenho, drops e HUD** (sem
aprovação na .4, em que a entrada falhou), saída/reconexão com preservação de
inventário e personagem, além do posicionamento do aviso/Chat. O relato atual
não aprova essas etapas nem confirma totais de recursos ou ausência de duplicação.

Capturas: [aviso PC](images/multiplayer-5-pc-connection.png),
[aviso mobile emulado](images/multiplayer-5-mobile-connection.png),
[partida PC emulada](images/multiplayer-5-pc-forest.png),
[partida mobile emulada](images/multiplayer-5-mobile-well.png).

## Operação e reteste

No checkout `.tools/multiplayer-pilot`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Status
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Start
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Stop
```

`Status` confirma tarefa, processos, HTTP local, endpoint externo e se é preciso
republicar. `RestartServer` **zera a sala em RAM**; `RepairTunnel` preserva o
servidor vivo, mas muda o endereço e exige atualizar a publicação quando
`needs_republish=True`. Não há recuperação do conteúdo da RAM de um servidor
que já encerrou. Para remover o host definitivamente, executar `Stop` e depois
`Unregister-ScheduledTask -TaskName TeceIsland-Multiplayer-mp -Confirm:$false`.

Este piloto ainda depende do PC **ligado, acordado e com a sessão do usuário
ativa**. A tarefa não impede suspensão nem acorda o PC. O Quick Tunnel segue
temporário e pode perder a rota; não é hospedagem com disponibilidade garantida.
Nenhum serviço pago ou credencial administrativa foi criado.

Reteste: recarregar sem apagar os dados do site; conferir **.5**; entrar com
uma conta por aparelho; verificar os dois personagens e movimento simultâneo;
sair/voltar em um aparelho. Se bloquear, informar a etapa e o código exibidos,
sem enviar token ou senha. Depois disso retomar o reteste físico de desempenho,
itens no chão e vida/fome/água.

## Publicação conferida

- Código do jogo: `9596431c4fc60ca167ed6a3f7e8ffa78f83f2024`.
- Sites versão **5**, fonte `07e0934d40c3fedcc83bb04a5403b20267e25595`;
  deploy `appgdep_6ad94f2150ec8191a4701431429901cf`, **succeeded**.
- Endpoint embutido e ativo:
  `wss://become-tri-billion-window.trycloudflare.com/room`.
- PCK servido: `14961bb908431ee2d907e678e769ae75980fc0c3b72f27a68219b4957c4fce5a`.
  Manifesto identifica .5, protocolo 3 e save v8. Dezessete assets além do HTML
  conferidos por SHA256; HTML conserva toda a fonte e acrescenta a inserção de
  938 caracteres do Sites. O bridge de testes não está no cliente publicado.
- **8** verificações do pacote, incluindo cópias de save v5 e v8 com vitória
  preservada; **30** do cliente publicado; **10** HTTPS/WSS externos; **56** Web
  emuladas até recuperação e movimento simultâneo dos personagens na mesma sala.
- Saúde local/externa e versão conferidas: servidor `30780`, túnel `14148`,
  host sob demanda ativo, `version_matches=True`, `needs_republish=False`.
  A tarefa e os processos permaneceram ativos depois da shell de início encerrar.
- [Login publicado PC](images/multiplayer-5-published-login-pc.png) e
  [mobile emulado](images/multiplayer-5-published-login-mobile.png).
  O harness privado fornece AudioWorklets como Blobs dos bytes publicados já
  verificados, pois o carregamento não recebe cabeçalho de serviço. Isso é só
  um contorno da automação; não muda o cliente nem comprova áudio físico.

Oficial reconferido como 0.9.0, commit `15ba9685`, `main` `c790758`, tag `v0.9.0`;
PCK `2681e0b166b982a9642019770b11803dde28c76bfa1e7b20fcc1a8c31a8d40ae`.
Configurações/lista das duas contas mantiveram o digest
`4ad90aec7bc4d5feadaf2d66de6dd1e87055f2418b24a0bf72973e62d84f2625`.
Alterações locais do IDE e arquivos preexistentes preservados.

Evidências: [diagnóstico anterior à recuperação](evidence/multiplayer-pilot-5-diagnosis.json),
[Web emulado](evidence/multiplayer-pilot-5-web.json),
[pacote e publicação](evidence/multiplayer-pilot-5-deployment.json),
[reteste físico relatado pelo usuário](evidence/multiplayer-pilot-5-manual.json).
