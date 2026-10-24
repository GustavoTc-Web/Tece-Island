# Piloto .7 — desempenho e resposta do movimento

Cliente **0.9.0-multiplayer-pilot.7**, protocolo **3**, compatível com o servidor
**.6** já em execução. Branch `feat/multiplayer-pilot`.
[Piloto privado](https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/).

**Reteste de 24/10:** usuário bloqueado em “Conferindo endereço atual do
servidor”, antes da sala. Desempenho físico da .7 **não testado nem aprovado**.
Ver [relato manual](evidence/multiplayer-pilot-7-manual.json). Os resultados de
publicação abaixo são históricos de 22/10, não prova de disponibilidade atual.

## Resultado humano anterior e causas reproduzidas

O [reteste humano da .6](evidence/multiplayer-pilot-6-manual.json) confirma entrada
funcional, mas reprova desempenho: muito atraso/travadas e experiência não jogável.
Esse resultado não aprova drops, HUD ou reconexão. A .7 ainda exige reteste físico.

- **HUD/inventário:** `apply_network_state` comparava o dicionário recebido por
  JSON com metadados locais de tipos numéricos diferentes (`selected: 0.0` e
  `selected: 0`). Dez estados idênticos dispararam dez notificações e reconstruções
  do HUD, inclusive slots ocultos. O teste com o formato real do servidor agora
  dispara uma notificação inicial; uma mudança real de quantidade continua
  notificando e preserva o total. Não foi alterado o formato dos saves.
- **Resposta local:** a .6 desenhava também o próprio jogador na linha temporal
  remota com buffer de 120 ms. O movimento aguardava envio, passo do servidor,
  snapshot, rede e interpolação. A .7 prevê somente o movimento visual local,
  com a mesma velocidade, água, limites e colisões do manifesto oficial.
- **Renderização:** DPR 2 desenhava quatro vezes mais pixels que DPR 1. Mesmo
  após corrigir o HUD, houve custo relevante em renderização por software.
  A .7 inicia o multiplayer com densidade 1×; o diagnóstico permite voltar ao
  nativo, até 2×. A área lógica da câmera e os alvos de toque foram conferidos
  após a troca. A imagem pode ficar menos nítida em telas densas. Ao sair do
  multiplayer, a densidade anterior de até 2× do solo é restaurada.
- **Fila:** estados acumulados durante uma pausa são reunidos em um estado por
  quadro, mantendo os últimos arrays completos de recursos/drops. `[]` continua
  significando vazio. ACKs e resultados das ações continuam sendo processados
  em ordem; não são descartadas recompensas nem confirmadas ações localmente.

## Autoridade, reconciliação e preservação da sala

O servidor continua validando direção, velocidade, distância, ferramenta,
intervalo, linha de acesso e inventários. O cliente não envia posições nem
atribui itens; prever movimento não libera coleta ou ultrapassa validações.

O protocolo 3 envia ACK de cada input antes de um estado produzido com esse
input. O teste real de ordenação em WebSocket confere esse vínculo no servidor
inalterado. O cliente associa a cada estado o último ACK aceito anterior a ele,
descarta os segmentos confirmados e refaz somente os restantes a partir da
posição oficial. Correções pequenas são suavizadas; grandes correções têm
prioridade imediata. O histórico é limitado a aproximadamente um segundo.
Esse refazimento é uma estimativa visual: o servidor continua integrando a
direção no seu próprio passo, sem aceitar tempo ou posições declarados pelo cliente.
Sem estado recente por 500 ms, novos movimentos ficam pausados; o timeout e a
recuperação existentes de cinco segundos continuam funcionando.

Os outros jogadores usam interpolação temporal monotônica, com buffer de
120–220 ms ajustado à variação observada. Não há extrapolação através de paredes.
Sob rede ruim podem ocorrer espera e correções; previsão não remove o RTT.

Foram limitadas atualizações redundantes das barras, mundo e aparência dos
personagens. Inputs parados passam a cerca de 4 Hz; em movimento permanecem
perto de 20 Hz, com envio ao mudar direção e limite de frequência. O servidor
mantém seus passos e snapshots existentes; nenhum relógio/campanha foi alterado.

**Não é necessário reiniciar o servidor para publicar este cliente.** O servidor
.6, o túnel e a sala em RAM permanecem ativos; a .7 usa o mesmo protocolo e
manifesto de mundo. `Start` e `Status` distinguem versão do cliente e do servidor.
Não usar `RestartServer` para atualizar só o cliente: esse comando perde a RAM.

## Método das medições

São testes automatizados, não partidas humanas: Windows, dois processos Edge
independentes, SwiftShader, Auth local, PC 1920×950 e celular emulado 640×360.
O cliente .6 anterior foi arquivado com observação passiva equivalente; o
cliente .7 é compilado do commit registrado. Não se extrapola FPS de software
para a GPU do PC ou do telefone do usuário.

Cada execução tem aquecimento e as mesmas cinco fases: parado (5 s), exploração
simultânea (8 s), extração compartilhada (5 s), seis inícios de movimento (7,5 s)
e varredura controlada de câmera pelos 18 biomas (9 s). Essa varredura usa
reposicionamento do servidor; o percurso real floresta–pântano é outro teste.
As execuções são sequenciais, sem exportação ou outras suítes concorrentes.

Rede local e atraso simulado usam WS real e um proxy FIFO limitado ao loopback.
A simulação adiciona 120±30 ms por sentido, com a mesma distribuição e semente.
RTT de input/ACK inclui polling e agendamento do cliente. O servidor mede
simulação, construção do snapshot e callback completo do tick, inclusive
serialização/envio e instrumentação. Intervalo entre ticks e atraso do event loop
são reportados separadamente de CPU da simulação.

O endereço público e o loopback são comparados no **mesmo servidor .6 vivo**,
com 60 pings de controle RFC6455 em cada caminho. Não acessam contas, não criam
personagens e não medem input até desenho de uma partida autenticada. Não houve
ensaio automatizado de duas contas reais jogando pelo túnel; esse é o reteste
físico assistido pelo diagnóstico. A rede real do celular ainda precisa ser medida.

Tempo por quadro vem de `requestAnimationFrame`; aplicação de estado usa relógio
monotônico dentro do Godot. `TIME_PROCESS` é auxiliar, não tempo exclusivo de GPU.
Não foi obtido um timer isolado de GPU física. As amostras são curtas e os seis
inícios de comando têm resolução de observação de aproximadamente um quadro.
Relatórios incluem p50/p95/p99/máximo; p95 não é o pior quadro.

Valores em ms; pares PC / celular emulado.

| Métrica | .6 | .7 |
| --- | --- | --- |
| Aplicar estado p95, local | 19.2 / 20.7 | 1.3 / 1.2 |
| Primeiro movimento visual, mediana local | 149.3 / 132.4 | 16.0 / 16.5 |
| Primeiro movimento visual, mediana com atraso | 483.3 / 449.1 | 16.9 / 16.8 |
| Quadro p95 durante inícios locais | 32.7 / 33.4 | 16.9 / 16.9 |
| RTT input/ACK p95 com atraso | 300.7 / 310.2 | 308.5 / 302.6 |
| Quadro p95, DPR 2, exploração (nativo .6 / econômico .7) | 50.2 / 66.7 | 16.8 / 16.9 |

No mesmo build .7 em DPR 2, o modo nativo teve 33.7 / 33.5 ms p95 na exploração,
contra 16.8 / 16.9 ms no econômico. A comparação separa o custo de pixels do
conserto do HUD. O canvas do celular passa de 1280×720 para 640×360; a área
lógica permanece igual.

CPU p95 do callback completo do tick, pior fase local: 2,40 → 2,74 ms. Só a
simulação: 0,27 → 0,32 ms. O servidor permanece abaixo do orçamento de 50 ms;
variações pequenas não representam otimização do servidor, que não mudou.

O intervalo entre ticks teve p95 de até 63,7 → 64,2 ms para o agendamento
nominal de 50 ms. Isso é distinto do tempo de execução da simulação. Estados
comuns permaneceram em 1.024 bytes; o servidor envia aproximadamente 8–10/s
por jogador nessa máquina. Em repouso, os inputs observados caíram de cerca
de 16,1 para 3,8/s por jogador. O formato e a frequência nominal de snapshots
não foram alterados.

| Caminho do mesmo servidor .6 | RTT mediano/p95 antes | RTT mediano/p95 depois | Variação p95 antes/depois |
| --- | --- | --- | --- |
| Loopback | 1,5 / 7,9 ms | 1,4 / 10,1 ms | 17,1 / 10,3 ms |
| Túnel público | 25,3 / 55,9 ms | 29,3 / 81,0 ms | 36,3 / 50,1 ms |

Não houve melhoria demonstrada da rede pública: a segunda janela variou para
cima. Previsão reduz a espera visual local, sem acelerar a rede ou antecipar
recompensas. Na exploração automatizada .7, as correções p95 ficaram na ordem
de 8–11 unidades do mundo na conexão local e 9–19 com atraso. Reposicionamentos artificiais da câmera
geram correções grandes por construção e não representam caminhada normal.
Os relatórios completos estão em
[medições antes/depois](evidence/multiplayer-pilot-7-performance.json).

## Diagnóstico e reteste físico

Toque/clique na linha de **FPS e RTT** do HUD, ou use F3. O painel mostra quadro
p95, RTT mediano/p95, variação p95, intervalo de estados, custo de aplicação,
tráfego, entradas/estados por segundo, fila e correção. As janelas são de até
120 quadros/aplicações e 60 RTTs; variação é a diferença absoluta entre RTTs
consecutivos. A tela contém números de desempenho, sem tokens ou credenciais.

1. Recarregar e conferir **.7**; entrar com uma conta no PC e outra no celular.
2. Andar simultaneamente por 20 s e abrir o diagnóstico. Anotar FPS, quadro p95,
   RTT p95 e variação em cada aparelho; informar Wi-Fi ou rede móvel.
3. Na mesma sala, alternar **Previsão local** e comparar início/parada do próprio
   personagem. Depois manter ligada. Alternar gráficos econômico/nativo para
   distinguir limite gráfico de rede; manter econômico se houver travadas.
4. Observar o outro jogador, curvas e colisões. Relatar correções bruscas ou
   congelamento junto dos números, evitando marcar o desempenho como aprovado
   apenas porque a entrada funciona.

Drops, soma dos inventários, HUD e reconexão física seguem pendentes. A suíte
automatizada verifica extração sem crédito imediato, disputa de cinco madeiras,
inventário e cantil preservados, chat, toques e reconexão; isso não é teste físico.

## Verificações

- **33** testes do servidor, incluindo a ordenação de ACK/estado e as proteções
  existentes contra ações inválidas, contas externas e duplicação.
- **1.113** verificações de previsão, com 56 trajetórias comparadas ao `Room`
  oficial, reconciliação, limite do histórico, normalização JSON e união de estados.
- **14 suítes** nativas de regressão: campanha, migração, reabertura, saves/backups,
  sync/handoff, controles, mobile/menu, autenticação, poços e isolamento multiplayer.
- **64** verificações Web com duas identidades emuladas; teclado, joystick e dois
  dedos; concorrência da árvore/drop; reconexão, inventário, cantil, chat e percurso
  real; diagnóstico por toque/F3, densidade e área lógica da câmera; pausa artificial
  de 350 ms com retomada da fila sem alterar totais.

Oficial **0.9.0**, `main`, saves solo v8, campanha e duas contas permanecem
preservados. Sem faturamento, merge na main, combate ou PvP nesta etapa.

## Publicação conferida

- Jogo: `a8caa555f8aca433deb2f46c85090e81faefb080`.
- Sites versão **7**, fonte `2336d0259124272eccc80fa30cfba84ed8e607cf`;
  deploy `appgdep_6ada96bcf5e08191a9b888d54a7c07e0`, **succeeded**.
- PCK servido: `c2a4ba11e78157a2d387e248188466b1f7b739262c6492cba25e4bdc6ee68375`.
  Manifesto .7 não emulado e compatibilidade com servidor .6 conferidos; 17 assets
  coincidem por SHA256 e o HTML preserva toda a fonte com a inserção do provedor.
- Status final: cliente .7/servidor .6/protocolo 3, HTTP local, HTTPS e WSS
  externos prontos, descoberta compatível, `ready_to_play=True`.
- Servidor `21580` e túnel `13600` preservados. **Nenhum reset da sala nesta
  publicação.** O ambiente Auth emulado de testes foi encerrado separadamente.
- Oficial ao vivo reconferido em 0.9.0, commit `15ba9685`, PCK
  `2681e0b166b982a9642019770b11803dde28c76bfa1e7b20fcc1a8c31a8d40ae`.
  `main` `c790758` e tag `v0.9.0` preservados, assim como as alterações do IDE.

Evidências: [desempenho](evidence/multiplayer-pilot-7-performance.json),
[Web](evidence/multiplayer-pilot-7-web.json),
[regressões nativas](evidence/multiplayer-pilot-7-native.json),
[pacote real e saves](evidence/multiplayer-pilot-7-pack.json),
[bytes publicados](evidence/multiplayer-pilot-7-published.json),
[transporte da origem publicada](evidence/multiplayer-pilot-7-browser-transport.json),
[WSS e segurança](evidence/multiplayer-pilot-7-wss.json),
[deploy](evidence/multiplayer-pilot-7-deployment.json),
[oficial preservado](evidence/multiplayer-pilot-7-official.json).

Capturas do diagnóstico [PC](images/multiplayer-7-pc-diagnostic.png) e
[mobile](images/multiplayer-7-mobile-diagnostic.png) são emuladas. Seus números
são janelas instantâneas de outra execução, não os agregados do benchmark.
O [controle aberto/fechado](evidence/multiplayer-pilot-7-ui.json) inclui partida
recém-aberta e amostras de inicialização; não demonstrou piora ao abrir o painel
e também não comprova desempenho físico ou FPS constante.
