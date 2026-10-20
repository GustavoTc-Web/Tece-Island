# Mundo compartilhado — piloto .3

Versão: **0.9.0-multiplayer-pilot.3**, protocolo 2.
Branch: `feat/multiplayer-pilot`.
Publicação exclusiva no [piloto privado](https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/).

## Sequência e reaproveitamento

1. Extrair terreno, regiões, recursos, poços, construções e colisores do solo em
   uma descrição compartilhada, independente dos saves.
2. Integrar movimento, colisões do cenário, coleta, água e inventário com
   autoridade do servidor; reutilizar os componentes visuais e os controles.
3. Validar dois clientes independentes, publicar e retestar PC + celular.

Esta entrega cobre essa primeira integração. A campanha de sete dias permanece
no solo. Objetivos multiplayer, combate, PvP, fabricação, construção e saque de
construções não fazem parte deste piloto; os prédios entram como cenário com
paredes e entradas transitáveis. Não há desbloqueio automático de missão.

`tools/export-multiplayer-world.gd` instancia o mundo solo em processo isolado,
com semente fixa e sem ler saves pessoais. Extrai **18 regiões**, limites
**−3072, −2560 até 6912, 3072** (9.984 × 5.632), **274 recursos**, **18 poços**,
**39 construções** e **532 colisores**. O arquivo resultante,
`assets/data/multiplayer-world.json`, é usado tanto pelo Node quanto pelo Godot.
Os quatro poços originais conservam suas posições exatas. Há verificação de
espaço livre para os demais; neste layout nenhum precisou ser deslocado.

Reutilizados: `WorldTerrain`, desenho dos biomas, `CampaignTerrain` somente
como cenário, árvores/pedras/arbustos e variantes, `WaterWell`, construções,
`Player`, `IslandMinimap`, HUD, slots, ícones, tema, inventário e painel de poço.
O desenho do chão foi extraído para `WorldScenery` com os mesmos comandos do solo.
Não se instancia `world.tscn` na partida multiplayer: relógio, objetivos, inimigos,
save e sincronização solo continuam separados.

## Autoridade e estado

- O cliente envia direção e intenção. O servidor calcula movimento a 20 Hz,
  colisões circulares/retangulares, limites do terreno, linha de visão, alcance,
  ferramenta, intervalo e recompensa. Água reduz a velocidade para 60%, como
  no solo. Colisão entre personagens não foi acrescentada nesta etapa.
- Cada conta tem sete slots, pilhas de até 15 e cinco atalhos. O kit da sala
  inclui machado e picareta de madeira e um cantil vazio para testar água.
  Seleção, troca de slots, coleta e consumo são decididos no servidor.
  Descarte e fabricação ficam ocultos; não há descarte local que apague itens.
- Coleta de madeira, pedra e fibra usa recompensas/golpes/intervalos extraídos
  das regras solo. O último golpe confirma espaço no inventário antes de
  remover o recurso; ações simultâneas não repetem a recompensa.
- Poços: alcance de 90, linha de visão e intervalo mínimo de 500 ms. Beber
  repõe até 40 de água; encher deixa o cantil com três doses. Cada dose repõe
  até 40. A sede cai 8/min apenas para o jogador online. Dano por necessidades,
  fome e combate ficam para a próxima etapa; a HUD exibe somente a água.
- A interface é uma projeção do inventário recebido. O painel de poço emite
  pedidos e não altera água localmente. Movimentos/ações visuais do outro
  jogador são derivados dos snapshots, incluindo os golpes aceitos.
- Cenário estático fica no pacote. O SHA256 do mundo é conferido no welcome;
  versões incompatíveis pedem atualização. Snapshots a 10 Hz enviam jogadores,
  inventário privado e apenas recursos alterados, sem retransmitir o mapa.
- Entrada tardia recebe todas as alterações da sala. Reconexão por UID mantém
  um personagem, slots, cantil e coleta. Reiniciar o servidor continua criando
  uma sala em RAM do zero; não é persistência durável de multiplayer.

## Testes e limites da evidência

O usuário confirmou fisicamente na **.2**, com PC + celular e contas diferentes:
entrada dos dois, visualização de movimentos e ações de cortar árvore. Não
confirmou soma exata de cinco madeiras nem saída/retorno com inventário e
personagem preservados. Essas duas verificações humanas continuam pendentes;
nenhum resultado da .2 aprova automaticamente a .3.

Automação desta integração:

- **25 testes Node/WebSocket:** regressões da .2 em fixture pequena, autenticação
  emulada, colisões/linha de visão/água, inventário, poço simultâneo, cantis
  separados e reconexão. O serviço de produção usa o mundo completo por padrão.
- **754 amostras** de terreno/água calculadas pelo Godot e comparadas ao Node.
  Rotas verificadas pelo movimento do servidor até todas as regiões e até um
  acesso utilizável de cada um dos 18 poços. Isso é simulação automatizada,
  não uma partida humana percorrendo o mapa inteiro.
- **327 verificações nativas** com dados isolados: campanha, migração, reabertura v8,
  backups, sincronização, controles, menu, mobile e poços. O teste específico
  confirma que o HUD de poço emite pedidos sem conceder água localmente.
- **36 verificações Web** em dois processos Edge independentes, usando teclado e
  toques CDP em 640 × 360. Exercitam travessia Floresta/Pântano, coleta da mesma
  árvore, dois dedos, poço, cantil, inventário, reconexão e bloqueio pelo chat.
  As capturas representam emulação, sem aprovação de aparelhos físicos.
- **22 testes de regras Firebase e 11 verificações REST de chat** em emuladores,
  sem alteração de regras, contas ou dados de produção.
- **10 verificações externas** da instância candidata .3: HTTPS/WSS, versão,
  recusa de anônimos/tokens forjados e ausência de tokens/UIDs nos logs.

Capturas da integração emulada: [PC/Floresta](images/multiplayer-3-pc-forest.png),
[PC/Pântano](images/multiplayer-3-pc-swamp.png),
[mobile/poço](images/multiplayer-3-mobile-well.png),
[painel do poço](images/multiplayer-3-mobile-well-panel.png) e
[inventário](images/multiplayer-3-mobile-inventory.png).

## Reteste curto PC + celular

1. Recarregar e conferir **.3**; entrar com uma conta diferente em cada aparelho.
   Conferir 2/2, a clareira e o poço original a leste do início.
2. Explorar pela estrada para leste até Pântano, Campos e Deserto; experimentar
   paredes, árvores, poços e água. Cada aparelho controla só seu personagem.
3. Cortar a mesma árvore e conferir **cinco madeiras no total**; coletar pedra
   com picareta e fibra com mãos (slot vazio ou Mãos no inventário).
4. No poço, E/Interagir → Encher cantil; selecionar o terceiro slot e usar
   F/Beber. Conferir doses separadas e reposição de água nas duas contas.
5. Mover a picareta entre slots no inventário, selecioná-la na barra e coletar.
   Sair/retornar e interromper/restabelecer a rede: conferir slots, cantil e
   personagem único. No celular, testar joystick e Coletar com dedos distintos.
6. Voltar ao menu e conferir um mundo solo existente, sem alteração de progresso.

## Operação

O servidor permanece local e o Quick Tunnel gratuito é temporário. O computador
precisa ficar ligado e conectado. Não foi contratado serviço nem habilitado
faturamento. As duas contas autorizadas e a verificação Firebase foram mantidas.

Após a promoção desta publicação, no checkout `.tools/multiplayer-pilot`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Status
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Stop
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Start
```

`Stop` encerra somente os processos registrados. `Start` recupera a instância
atual e verifica HTTPS/WSS, não apenas os PIDs. Se o domínio do túnel mudar,
reexportar e republicar o cliente com o novo endereço. `RepairTunnel` recria
somente o relay; `RestartServer` reinicia e zera apenas a sala multiplayer.
O relatório de publicação abaixo identifica os artefatos efetivamente servidos.

## Publicação conferida em 20/10/2026

- Código compilado e enviado: `491753d4b37ff92f27e79448a534df8f23aff03a`.
- [CI aprovada](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/39491841433).
- Fonte do Site: `cb52f0b116b72a5b4e6256cc9efe0f8aa4a91f69`.
- Publicação privada versão **3**, deployment
  `appgdep_6ad7cf322af0819195a98b2197a2b970`: **succeeded**.
- Versão salva:
  `appgprj_6ad6b7bc03c481918665130efcc41739~appgver_c1d36a7698848191bc7ec4a5d207187f`.
- WSS efetivamente compilado e servido:
  `wss://advertise-bean-marie-duplicate.trycloudflare.com/room`.
- PCK SHA256: `a98145e8ed07709d984dee6347b4d95325a4a9db5f61fbc2d84803c367722845`.
- Mundo compartilhado SHA256:
  `bfafff5233793bf02fc6e4192f2dc6a86355c334b18cdd6ce0bd9ed88ea71031`.
- **8 verificações do PCK final**: versão/commit, endpoint, configurações/contas,
  exclusão de servidor/testes, abertura, cópias de save legado v5 e v8 vencido,
  identidade do mundo compilado com o servidor. Originais preservados.
- **30 verificações pós-deploy**: manifesto, rótulo .3, PCK, engine, fontes e
  scripts por hash; login obrigatório e WSS anônimo recusado em PC e mobile
  emulado. Os 17 arquivos além do HTML coincidem por SHA256; HTML conserva toda
  a fonte mais a inserção de 938 caracteres do provedor Sites.
- As capturas do cliente **publicado** mostram o login: [PC](images/multiplayer-3-published-login-pc.png)
  e [mobile emulado](images/multiplayer-3-published-login-mobile.png).
  A partida com duas contas nas imagens anteriores usa o mesmo código .3 e
  autenticação emulada. Login positivo das contas reais e partida física na
  **.3** ainda não foram confirmados; os resultados físicos da .2 foram mantidos
  separadamente. No harness de acesso privado, os AudioWorklets usam Blobs dos
  bytes publicados já verificados por hash, pois requisições desse tipo não
  recebem o cabeçalho de serviço do Playwright; o jogo publicado não foi alterado
  para esse contorno de teste.
- A instância .2 foi mantida até verificar o deploy .3 e então encerrada, já sem
  jogadores conectados. A .3 começa uma nova sala de teste, com kit inicial e
  cantil vazio. Instância ativa: loopback **8790**; somente o serviço do jogo é
  exposto pelo túnel. `Status` confirma saúde local e externa e
  `needs_republish=False`. Os comandos padrão agora operam essa instância.
- Oficial reconferido: **0.9.0**, commit `15ba9685`, PCK servido
  `2681e0b166b982a9642019770b11803dde28c76bfa1e7b20fcc1a8c31a8d40ae`.
  `main` continua `c790758`, tag `v0.9.0` preservada; digest de configurações
  `4ad90aec7bc4d5feadaf2d66de6dd1e87055f2418b24a0bf72973e62d84f2625`.
  Os saves solo, alterações locais do IDE, duas contas, dados/configurações
  Firebase e ausência de faturamento foram preservados.

Relatórios: [Web emulado](evidence/multiplayer-pilot-3-web.json) e
[pacote/publicação/serviço](evidence/multiplayer-pilot-3-deployment.json).
