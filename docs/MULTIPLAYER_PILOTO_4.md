# Piloto .4 — desempenho, drops e HUD

**0.9.0-multiplayer-pilot.4**, protocolo **3**, branch `feat/multiplayer-pilot`.
[Piloto privado](https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/).
Solo oficial **0.9.0**, saves v8 e campanha de sete dias preservados.

## Causas e correções

- Cliente: o desenho reunia comandos do cenário inteiro; 274 recursos
  processavam quadros sem animação; layout, alvos e nomes eram atualizados a
  cada quadro. Ocultar o mundo mantendo servidor/rede ativos reduziu o custo
  observado. Agora os mesmos comandos do solo são recortados em áreas de 512
  unidades e só as áreas visíveis são ativadas. Recursos estáticos não processam
  quadros; controles/nomes/alvos têm frequência limitada. Foram mantidos os
  18 biomas, extensão, 274 recursos, 18 poços e 39 construções. Os três corpos
  de desenho compartilhados foram comparados com o commit anterior: comandos
  idênticos, somente o destino do desenho foi extraído.
- Movimento: perseguir o último alvo a cerca de 10 Hz dava cadência irregular.
  O desenho agora interpola uma linha temporal do servidor com buffer de
  120 ms, sem extrapolar colisões. Isso suaviza o movimento, mas não elimina
  atraso de entrada nem implementa previsão local.
- Servidor: a simulação não foi o gargalo medido. Porém, reenviar recursos e
  drops inalterados a cada mensagem faria o tráfego crescer com a exploração.
  Agora esses arrays só são enviados quando uma extração/coleta os modifica.
  Nova conexão sempre recebe tudo; array omitido é inalterado; `[]` é vazio.
- Rede/disponibilidade: o túnel .3 expirou durante a investigação, com
  `Unauthorized: Tunnel not found` e DNS inexistente apesar do processo ativo.
  Essa falha é distinta do desempenho gráfico. A .4 recebe um novo túnel com
  saúde HTTPS/WSS e rejeição anônima verificadas antes da publicação.
- Extração: a .3 adicionava a recompensa diretamente ao inventário. Agora
  gera uma pilha oficial com o visual `ResourceDrop` do solo. **F/mouse ou
  Extrair** cortam/mineram; **E ou Pegar** recolhem; **E/Interagir** abre poços.
  Madeira rende 5, pedra 4, fibra 4. O servidor valida ID, alcance de 58 unidades
  e linha de acesso; atualiza inventário e pilha sem operações assíncronas entre
  as duas mutações. Não duplica unidades entre jogadores. Sem espaço, mantém
  tudo no chão; espaço parcial deixa a quantidade exata restante. Entrada
  tardia e reconexão recebem as pilhas restantes.
- HUD: vida/fome estavam ocultas e somente sede existia no servidor. Agora
  vida, fome e água são estados individuais oficiais, nas barras do solo.
  Vida/fome começam em 100 e permanecem estáveis neste piloto sem alimentos
  funcionais nem combate. Água mantém redução de 8/minuto e poço/cantil.
  Não foram ativados fome, dano por necessidades ou combate. A ajuda explica
  a fome estável. Botões mobile foram separados da barra rápida.

## Medições

Mesma máquina Windows; **dois processos Edge independentes**, PC 1920×950 e
mobile **emulado** 640×360; renderização **SwiftShader**; Auth Firebase local;
WS real local. Bridge de observação limitado a 10 Hz nas duas medições, antes
das otimizações. São medições automatizadas, não desempenho dos aparelhos do
usuário. p95 contém 95% das amostras e não é o pior quadro.

| Carga | .3 p95 PC / mobile, ms por quadro | .4 p95 PC / mobile |
| --- | --- | --- |
| Parado, 6 s | 50,0 / 66,6 | 16,8 / 16,9 |
| Movimento simultâneo, 8 s | 66,8 / 66,8 | 16,8 / 16,8 |
| Extração simultânea, 5 s | 66,8 / 83,3 | 16,8 / 16,8 |

O movimento usa o mesmo corredor e suas colisões; não é uma caminhada pelos
18 biomas. O trajeto floresta–pântano com teclado é validado separadamente.
Na .3, ocultar o mundo mantendo servidor/rede ativos reduziu p95 para
16,9/33,2 ms. Há contribuição do trabalho do cliente, não evidência de
saturação da simulação.

Uma varredura **controlada de câmera**, 9 s pelos 18 biomas por modo no mesmo
build .4, comparou desenho original e recortado: ambos ficaram perto de 17 ms
p95. Tempo ocupado da thread principal caiu de 6.611 para 5.330 ms no PC e
6.898 para 5.500 ms no mobile, cerca de 19–20%. Primitivas medianas caíram de
16.849 para 5.479 e 17.645 para 6.269. Não se atribui toda a melhora entre
builds apenas ao recorte: há mudanças no trabalho por quadro/interpolação,
e cache/carga da máquina limitam a extrapolação. `TIME_PROCESS` foi coletado
como monitor auxiliar, sem tratá-lo como tempo isolado de GPU ou CPU.

Simulação do servidor p95 antes/depois: movimento **0,106/0,128 ms**, extração
**0,158/0,120 ms**. Construção do snapshot após mudanças: abaixo de 0,18 ms p95
nessas cargas. Agendamento do Windows teve intervalos p95 perto de 63 ms para
o passo nominal de 50 ms; isso não é CPU da simulação. RTT de socket **local**
p95: movimento **1,256/1,229 ms**, extração **3,416/3,037 ms**.

Estresse sintético com 274 recursos esgotados e 274 pilhas, no formato .4:
40.999 bytes no estado completo e 859 sem alterações. Repetir o completo a
10 Hz daria 409.990 bytes/s por jogador; omitir arrays inalterados usa
8.590 bytes/s, redução aproximada de 98%. Primeira entrada/alterações ainda
transmitem o estado completo necessário. Este é um A/B do formato .4, não
uma medição de tráfego físico da .3.

O endpoint público anterior estava indisponível: **não existe antes/depois
numérico público comparável**. Novo túnel: HTTPS, 10 amostras, p50 73,57/p95
270,30 ms; conexão WSS, 5 amostras, p50 117,24/p95 416,80 ms; ida/volta da
recusa anônima p50 31,84/p95 61,72 ms. Isso verifica transporte e proteção,
**não latência de partida autenticada nem rede do celular**. O túnel pode
expirar novamente e depende deste PC ligado; não há disponibilidade contínua.

Relatórios agregados em `docs/evidence/multiplayer-pilot-4-performance.json`.
As alterações finais de posicionamento dos botões não mudam a carga do
benchmark e foram verificadas novamente no teste Web.

## Testes e pendências físicas

Servidor: contas distintas do Auth emulado e WS real; tokens/UIDs falsos,
ferramenta, intervalo, distância, paredes, concorrência, inventário cheio e
parcial, entrada tardia, reconexão, necessidades individuais e mensagens
compactas. Godot: campanha, migração/reabertura, saves/backups, sync/handoff,
controles, mobile/menu, autenticação, poços e isolamento; HUD e drops reais
projetados do servidor, quantidade parcial, áreas dos 18 biomas.

Web: dois Edge independentes e contas emuladas diferentes; teclado/joystick
simultâneos; dois dedos; E/Pegar disputando a pilha; poço, cantil, inventário,
chat bloqueando comandos, desconexão/reconexão, servidor silencioso e percurso
entre biomas. Capturas de partida são **emuladas**; as do site publicado são
do login, sem alegação de login positivo das duas contas reais pela automação.

Resultados: **31** testes do servidor, **355** verificações Godot distintas,
**22** de regras, **11** de chat nativo e **46** verificações Web, sem falhas.
Capturas emuladas: [PC](images/multiplayer-4-pc-forest.png),
[mobile com itens no chão](images/multiplayer-4-mobile-ground.png),
[mobile no poço](images/multiplayer-4-mobile-well.png) e
[inventário mobile](images/multiplayer-4-mobile-inventory.png).

O usuário testou fisicamente a **.3** em PC/celular e relatou mundo ampliado,
travadas, crédito automático e ausência de vida/fome. Esse relato não aprova
testes da .4. Desempenho prolongado, controles/toques, soma dos inventários,
inventário cheio/reconexão e legibilidade física aguardam reteste da .4.

Roteiro: recarregar e conferir .4; entrar com uma conta em cada aparelho;
andar juntos floresta/pântano; extrair a mesma árvore, ver 5 madeiras no chão
sem crédito automático e disputar E/Pegar; somar os inventários; deixar uma
pilha e reconectar; encher inventário e conferir o excedente; observar as três
barras e beber com apenas um jogador.

## Operação

No checkout `.tools/multiplayer-pilot`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Status
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Start
```

`Stop` verifica PID, executável e início antes de encerrar somente os processos
do jogo. `RestartServer` reinicia só o servidor e **zera a sala em RAM**;
`RepairTunnel` troca só o túnel, preservando a sala quando o servidor está vivo.
Se `needs_republish=True`, reexportar com o novo WSS e republicar no mesmo Site;
o cliente não troca seu endpoint embutido sozinho. DNS/rota novos podem demorar:
confirmar `tunnel_healthy=True` antes da publicação.

Inventários, necessidades, recursos e drops continuam em RAM. Não há importação
nem escrita em mundos solo. Só o serviço do jogo em loopback é exposto.
Firebase mantém validação de tokens e as duas contas; sem tokens em logs,
credenciais administrativas, mudança de dados/configurações ou faturamento.

Oficial reconferido: 0.9.0, commit `15ba9685`, `main` `c790758`, tag `v0.9.0`;
PCK `2681e0b166b982a9642019770b11803dde28c76bfa1e7b20fcc1a8c31a8d40ae`.
Digest de configurações/lista das duas contas:
`4ad90aec7bc4d5feadaf2d66de6dd1e87055f2418b24a0bf72973e62d84f2625`.
Alterações locais do IDE preservadas no checkout original.

## Publicação confirmada

- Código exportado: `4791f31c6d91bb33e186111be6f914e111c98b78`.
- Sites versão **4**, fonte `15736340884a5518b73d643e90b4db864ab1cde0`;
  deploy `appgdep_6ad80da908e08191a9e5ee2b45cf3a8c`, **succeeded**.
- PCK servido: `3fd595cab897582154e650132d366820e16ecfa48132c02ceba33dea596fa1db`.
  Manifesto identifica versão .4, commit, protocolo 3, save v8 e o novo WSS.
  Os 17 assets além do HTML coincidem por SHA256; o HTML mantém toda a fonte
  com a inserção de 938 caracteres do provedor Sites.
- **8** verificações do PCK, incluindo abertura de cópias v5 e v8 com vitória
  preservada; **30** do cliente publicado em PC/mobile emulado; **10** HTTPS/WSS
  negativos externos. O cliente compilado também recusou token sem assinatura.
  Isso não registra login positivo das duas contas reais em produção.
- [Login publicado PC](images/multiplayer-4-published-login-pc.png) e
  [mobile emulado](images/multiplayer-4-published-login-mobile.png).
  No harness de acesso privado, AudioWorklets usam Blobs dos bytes publicados
  verificados por hash, pois esse carregamento não recebe o cabeçalho de serviço
  do navegador automatizado. O cliente publicado não recebe esse contorno.
- Instância ativa em loopback **8791**, servidor `25248`, túnel `33464`;
  comandos padrão operam a .4. Saúde local/externa confirmada e
  `needs_republish=False`. Túnel/servidor anteriores foram encerrados. A .4
  inicia uma nova sala de teste em RAM; inventários da .3 não são importados.

Evidências: [validação](evidence/multiplayer-pilot-4-validation.json),
[Web emulado](evidence/multiplayer-pilot-4-web.json),
[desempenho](evidence/multiplayer-pilot-4-performance.json) e
[pacote/publicação](evidence/multiplayer-pilot-4-deployment.json).
