# Correção do piloto multiplayer .2 — 20/10/2026

Versão: **0.9.0-multiplayer-pilot.2**. Branch `feat/multiplayer-pilot`.
Piloto privado: https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/

## Diagnóstico

Os dois prints da .1 mostram conexão perdida, inventário aguardando servidor,
ausência de personagens/recursos e instruções de teclado também no celular.
O usuário confirmou que nunca chegou a carregar a sala em nenhum aparelho.
Esses prints não comprovam defeito de movimento, coleta ou câmera.

Reproduzido no cliente publicado: o manifesto servia .1, commit `1be3b14`,
os arquivos correspondiam ao pacote anterior, o login Firebase aparecia, mas
o WebSocket do endereço compilado não conectava. O servidor loopback respondia;
o antigo domínio `intake-patrick-jenny-caring.trycloudflare.com` não resolvia e
cloudflared repetia **Unauthorized: Tunnel not found**, embora o PID continuasse
ativo. O status anterior confundia processo existente com túnel disponível.
Não há evidência de que suspensão, reinício do PC ou algum aparelho tenha causado
a perda do túnel.

## Correções

- Relay temporário recriado e endereço WSS atualizado no pacote. HTTPS e
  WebSocket verificados externamente, além do health local.
- Gerenciador verifica saúde local, saúde do relay e endereço publicado.
  `Start` recupera relay sem resposta; `RepairTunnel` força a troca somente do
  túnel, preservando o processo da sala. Aguarda o registro do relay antes de
  sondar DNS/HTTPS. PID, executável e instante de início continuam conferidos.
- HUD com largura máxima e fontes em pixels CSS, botões que quebram linha,
  instruções adequadas ao toque e Chat deslocado para fora do cabeçalho durante
  a sala. Câmera compensa o painel apenas quando ele cobre boa parte da largura.
- Enquanto não há estado válido, ferramentas, joystick e coleta ficam ocultos.
  Falha mostra contagem até nova tentativa. Cinco segundos sem snapshots pausam
  controles e iniciam reconexão; a identidade e o inventário continuam no servidor.
- Exportação usa diretório de dados do Godot isolado do editor do usuário.
- Health informa somente a quantidade agregada de jogadores autenticados; não
  publica UID, apelido, inventário ou tokens.

## Operação e limites

No checkout `.tools/multiplayer-pilot`, em PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Status
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Start
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 Stop
```

`Stop` encerra somente os dois processos registrados. `Start` reutiliza a sala
se o servidor ainda estiver ativo. `RestartServer` reinicia a sala em RAM;
personagens, inventários e recursos **multiplayer** são zerados. Depois use
`Start` se o túnel também estiver parado. Saves solo não participam desse estado.

Se o túnel expirar, use `Start` ou `RepairTunnel`, confira `tunnel_healthy=True`
e `needs_republish`. Se o domínio mudou, **é necessário reexportar e republicar
o piloto com o novo WSS**; apenas reiniciar o processo não corrige um cliente
compilado com URL antiga. Os comandos e artefatos da publicação estão no registro
abaixo. Não foi contratado serviço nem habilitado faturamento.

Um Quick Tunnel é temporário e sem garantia de disponibilidade:
https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/ . O PC precisa
ficar ligado, conectado e sem suspender. A correção verifica essa dependência;
não transforma o relay gratuito em hospedagem permanente.

Neste reparo, o primeiro acesso ao novo domínio ocorreu antes da rota terminar
de registrar e deixou NXDOMAIN no cache local. DNS públicos já respondiam;
limpar somente o cache com `Clear-DnsClientCache` fez o HTTPS local funcionar.
Não houve troca de DNS, edição de hosts ou desativação de certificados.

## Reteste PC + celular

1. Recarregar o piloto, conferir `.2`, entrar com contas diferentes e abrir
   **Multiplayer — teste**. Esperar `sala 2/2 · conectado`, dois apelidos e árvores.
2. Andar simultaneamente: WASD no PC e joystick no celular em paisagem. Cada
   aparelho deve mover só seu personagem. Segurar o joystick com um dedo e tocar
   em Coletar com outro, perto da árvore.
3. Golpear a mesma árvore nos dois aparelhos. A soma das recompensas deve ser
   **5 madeiras**, com a árvore removida nos dois. Cada inventário é separado.
4. Sair no celular e entrar de novo; depois interromper e restabelecer sua rede.
   Conferir um personagem por conta, inventário mantido e coleta sem duplicação.
5. Abrir chat e conferir que digitar não move o personagem; voltar ao Menu e
   reabrir um mundo solo antigo/piloto, sem mudança no dia ou progresso.

## Evidências e publicação

O registro final abaixo distingue emulação, verificações externas e testes
manuais. Login manual informado pelo usuário não equivale a partida validada.

- **Automação local:** 29 verificações em dois processos Edge independentes,
  Godot Web real e contas diferentes do Auth Emulator. PC 1920×950 e mobile
  640×360; indisponibilidade inicial também em 800×360. Movimento simultâneo,
  dois dedos, coleta concorrente (5 madeiras no total), entrada tardia, saída,
  reconexão, conexão aberta sem snapshots, câmera e botões de pelo menos 44 CSS
  pixels no mobile. Nenhum erro de script nos clientes. Sala cheia foi injetada
  para apresentação; a capacidade é testada separadamente no protocolo.
- **Protocolo:** 19 testes reais WebSocket, com verificação Firebase emulada;
  incluem conta externa, token inválido, alcance, ferramenta, intervalo,
  repetição de ação, simultaneidade, inventários separados e reinício da sala.
- **Regressão nativa isolada:** 282 verificações de campanha, saves antigos,
  reabertura v8, backups, sincronização, handoff, controles, mobile, menu,
  autenticação e isolamento multiplayer. Dados temporários em `.tools`.
- **Firebase emulado:** 22 testes de regras e 11 verificações REST do chat nativo.
- **Serviço real:** 10 verificações externas de HTTPS/WSS e segurança. Anônimos
  e tokens sem assinatura são recusados inclusive quando alegam UID permitido.
  Logs conferidos sem tokens nem UIDs. Este teste não simula sucesso de login real.
- **Evidências locais emuladas:** [PC 1920](images/multiplayer-2-pc-1920.png),
  [mobile 640](images/multiplayer-2-mobile-640.png) e
  [servidor indisponível](images/multiplayer-2-mobile-offline-800.png).

No login assistido, o usuário informou que entrou manualmente em duas contas
reais diferentes, em perfis Edge isolados. A ferramenta de UI não disponibiliza
essas janelas; a entrada efetiva na sala será confirmada pelo serviço e pelo
reteste do usuário após a publicação. Não se registra partida física aprovada
com base nesse login ou na emulação.
