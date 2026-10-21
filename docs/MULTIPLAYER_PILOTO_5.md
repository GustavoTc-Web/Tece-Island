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

Pendências físicas: **entrada com as duas contas reais em produção**, movimento
entre PC/celular e observação do aviso/Chat nesses aparelhos. Os testes físicos
de **desempenho, drops e HUD da .4 continuam pendentes**, pois o usuário não
conseguiu entrar. Nenhuma dessas etapas foi marcada como aprovada.

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
