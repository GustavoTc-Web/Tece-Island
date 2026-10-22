# Piloto .6 — recuperação do host e endereço atual

Versão **0.9.0-multiplayer-pilot.6**, protocolo **3**, branch
`feat/multiplayer-pilot`. [Piloto privado](https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/).
Oficial 0.9.0, saves solo e duas contas preservados; sem faturamento.

## Evidência anterior à recuperação

- Servidor `30780`, cloudflared `14148` e host `18216` da .5 já encerrados.
  Nenhum listener na 8791; HTTP local `ECONNREFUSED`; DNS e HTTPS públicos
  `ENOTFOUND`. A falha é anterior à autenticação/estado inicial, independentemente
  do código 1006 do navegador.
- O pacote realmente servido era .5, commit `9596431`, protocolo 3, PCK SHA256
  `14961bb908431ee2d907e678e769ae75980fc0c3b72f27a68219b4957c4fce5a`.
  Seu endereço era `wss://become-tri-billion-window.trycloudflare.com/room`,
  igual ao último runtime. Não havia outro túnel ativo ou divergência de endereço
  antes da recuperação.
- O servidor registrou autenticação, welcome e estado inicial de duas conexões
  às 20:57–20:58 BRT de 21/10; ambas saíram normalmente antes das 21h.
  Isso é consistente com o reteste humano bem-sucedido registrado na .5.
- O cloudflared registrou timeouts DNS a partir das 21:03 BRT, perda da conexão
  de controle às 21:58:40 e tentativa IPv6 com host inacessível às 22:34:11.
  Recebeu `terminated` às **22:34:18 BRT de 21/10**. O Windows entrou em suspensão
  às **22:34:27**, por Application API, e retornou em 22/10 às 15:42.
- A tarefa ficou `Ready`, resultado `3221225786` (`0xC000013A`,
  [STATUS_CONTROL_C_EXIT](https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-erref/596a1078-e883-4972-9bbc-49e60bebca55)).
  Isso caracteriza encerramento por controle; não identifica quem o solicitou.
  O log operacional do Task Scheduler estava desativado. A proximidade com a
  suspensão não comprova a origem do encerramento. Não houve reboot: boot em 14/10.

Logs e runtime foram copiados para `.tools/mp6-before` antes da recuperação.
A RAM anterior já havia sido perdida. A recuperação **criou uma nova sala**;
nenhum save solo foi usado ou alterado.

## Correção e limites

- A .6 consulta um pequeno manifesto HTTPS de rota ao entrar e a cada nova
  tentativa, com URL de consulta variável para evitar cache antigo. Não envia
  login a esse endereço: apenas lê schema, protocolo e URL. Aceita somente WSS
  em `*.trycloudflare.com/room`, protocolo 3; resposta ausente/inválida aparece
  como etapa **endereço atual**, sem tentar o endereço antigo embutido.
- `Start -PublishEndpoint` reutiliza processos vivos, inicia os ausentes,
  verifica HTTPS e WSS real, publica apenas `runtime/multiplayer-endpoint.json`
  na branch do piloto e confere a rota pública. Usa o acesso GitHub já existente,
  sem gravar credenciais. Falha de push deixa os serviços ativos e informa que
  o piloto ainda não está pronto. O manifesto é público e não contém identidades.
- Após esta atualização do cliente, uma troca de Quick Tunnel exige atualizar
  esse manifesto; dispensa recompilar/republicar o Godot. Clientes .5 precisam
  recarregar uma vez para receber a .6. A descoberta passa a depender também
  da disponibilidade do conteúdo público do GitHub.
- `Status` verifica processo, versão/protocolo, HTTP local, HTTPS e WSS externo,
  além da rota publicada. Só informa `ready_to_play=True` quando essas etapas
  concordam. Isso comprova prontidão de transporte, não login positivo ou jogo.
- `Start` não mata um túnel vivo por uma falha isolada de health. Após examinar
  a rede/logs, `RepairTunnel -PublishEndpoint` troca somente o relay e preserva
  o servidor vivo. PID reutilizado é preservado. A conexão do relay usa IPv4
  para evitar a rota IPv6 inacessível observada; isso não garante rede disponível.
- Host mantém heartbeat local a cada 15 s e registra mudanças de processos.
  Não há watchdog que recrie silenciosamente a sala, gatilho de logon/boot,
  senha salva, mudança de energia ou serviço pago.

[Quick Tunnels](https://developers.cloudflare.com/tunnel/get-started/quick-tunnels/)
mudam de hostname ao serem recriados e não garantem disponibilidade. O PC
precisa ficar ligado, acordado e com a sessão aberta. Fechar a shell solicitante
foi testado; fechar todas as ferramentas, suspender ou reiniciar deliberadamente
o PC não foi reproduzido nesta correção. Os eventos reais de suspensão acima
foram inspecionados. Após suspensão, conferir; após reboot/logoff, iniciar
novamente. Reboot/logoff ou encerramento do servidor perde a sala em RAM.

## Procedimento simples

No checkout `.tools/multiplayer-pilot`, dar duplo clique em
`tools/multiplayer-start.cmd` para iniciar/publicar/conferir. Para somente
conferir, `tools/multiplayer-status.cmd`. A janela mostra o resultado e aguarda
uma tecla. Exige Node no PATH e o acesso GitHub desta máquina.

Equivalentes no terminal desse checkout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 -Action Start -PublishEndpoint
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 -Action Status
```

Jogar quando `ready_to_play=True`. Se `needs_endpoint_publish=True`, repetir
Start com `-PublishEndpoint` após recuperar a rede/GitHub. Se o relay vivo
continuar indisponível após conferir a rede e logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/manage-multiplayer-pilot.ps1 -Action RepairTunnel -PublishEndpoint
```

`Stop` encerra ambos e perde a RAM. `RestartServer` também perde a RAM; não usar
para consertar apenas túnel/endereço. Não executar Stop como etapa habitual de
diagnóstico. `Status` retorna código 2 quando o piloto não está pronto.

## Validação

- 32 testes de servidor; 13 de formato/segurança/retry do endpoint; 14 de
  isolamento solo. Sintaxe PowerShell/Node conferida.
- 9 verificações Web: dois processos Edge, PC 1920×950 e mobile emulado 640×360,
  duas identidades do Auth local. Descoberta indisponível não abre a rota antiga;
  recuperação automática, personagens, movimento, troca de hostname sem reload,
  mesma sala e inventário preservados. O harness adapta somente o hostname WSS
  fictício para WS local real; TLS público é testado separadamente.
- 10 verificações externas do servidor de produção: HTTPS, protocolo/versão,
  raiz 404, WSS, recusa de anônimo e tokens forjados, mesmas duas contas,
  ausência de tokens/UIDs nos logs. Sem login positivo automatizado real.
- Repetir Start preservou servidor `21580` e túnel `13600` depois de encerrada
  a shell solicitante. Não houve reinício adicional da sala nessa conferência.

**Pendências físicas mantidas:** desempenho, drops, HUD e reconexão. Entrada
com as duas contas reais na .6 também requer confirmação manual; o sucesso
humano da .5 é histórico e não aprova automaticamente a .6.
