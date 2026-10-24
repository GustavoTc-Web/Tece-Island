# Piloto .7.1 — recuperação da entrada e consulta de endereço

Correção limitada à entrada do cliente .7, protocolo 3 e servidor compatível .6.
As otimizações de desempenho, mapa, biomas, drops e inventários da .7 foram
preservados. Desempenho físico da .7 e da .7.1 **não aprovado**.

## Evidências atuais, antes de recuperar

Em 24/10/2026, servidor `21580`, túnel `13600` e host anterior já estavam
encerrados; porta 8791 sem listener (`ECONNREFUSED`). O domínio publicado
`finance-powered-midwest-footage.trycloudflare.com` não resolvia (`ENOTFOUND`).
A tarefa estava `Ready`, com resultado `1073807364` (`0x40010004`).

Último heartbeat: 23/10 às 01:32:00 UTC. O túnel perdeu a conexão de controle
às 01:32:01 e recebeu `terminated` às 01:32:03; o Windows entrou em suspensão
às 01:32:13. Não foi identificado quem encerrou os processos. A máquina não
reiniciou nesse intervalo. Logs e runtime foram copiados para `.tools/mp8-before`
antes de iniciar qualquer processo.

A consulta atual do GitHub respondeu HTTP 200, CORS `*` e JSON válido, apontando
para o domínio antigo. No Node levou cerca de 238 ms. A mesma consulta executada
no Godot Web .7 também concluiu e avançou em menos de um segundo em teste
emulado com transporte adaptado para um servidor local autenticado.

Com a resposta HTTP retida, a .7 atingiu o timeout de oito segundos, exibiu o
erro por aproximadamente um segundo e voltou a “Conferindo…”. O usuário
confirmou esse ciclo de erro/retentativa. **Não foi provada a causa específica
da falha HTTP no aparelho**; o servidor/túnel indisponível foi comprovado,
mas o aviso descrito sozinho não permite confundir essas duas etapas.

## Recuperação e correção

- Foi necessário criar uma nova sala: a RAM anterior já estava perdida antes
  da recuperação. Nenhum save solo foi lido como mundo multiplayer ou alterado.
- Servidor novo `22332` e túnel `30664`, com a mesma configuração e duas contas.
  O primeiro início aguardou o registro público e ainda não confirmou health;
  os processos foram mantidos. Após confirmar HTTPS/WSS, repetir Start preservou
  ambos e publicou a rota, sem outro reset da sala.
- A primeira rota recuperada, `monitored-sleeping-alternatively-organization`,
  respondeu inicialmente, mas caiu durante esta validação: timeouts na conexão
  ao edge/DNS, depois `Unauthorized: Tunnel not found` às 20:25:45 UTC e domínio
  `ENOTFOUND`. O servidor continuou respondendo localmente com o mesmo PID 22332.
  Não foi determinada a origem dos timeouts de rede.
- Logs/runtime foram copiados para `.tools/mp71-tunnel-expired` antes de usar
  `RepairTunnel -PublishEndpoint`. Apenas o túnel foi trocado (PID 11812);
  servidor, horário de início e sala atual foram preservados. Nova rota:
  `wss://volleyball-representations-representations-bachelor.trycloudflare.com/room`.
  O endereço é temporário; sua verificação vale no horário registrado, sem
  garantia de disponibilidade futura.
- A .7.1 mantém visível o último resultado HTTP, código de resultado do Godot,
  duração e validade do manifesto durante as novas tentativas. O tempo decorrido
  e o limite de oito segundos aparecem enquanto a consulta está em curso.
- Há um limite independente de nove segundos antes do retorno por socket nulo.
  Ele invalida/cancela a consulta atrasada e retorna à retentativa, sem permitir
  que uma resposta antiga abra uma conexão depois de outra tentativa.
- Nenhum payload HTTP, token ou credencial é colocado no aviso ou nos logs.
  Não há alteração em previsão, interpolação, gráficos, coleta, relógio ou vitória.

## Validação e reteste

Testes automatizados: 16 verificações nativas do endpoint/watchdog, 14 de
isolamento solo, duas identidades emuladas em navegadores independentes,
HTTP 503, resposta sem término, JSON inválido, retentativa com último erro
visível, carregamento da sala, movimento, troca de rota e preservação da sala.
São 18 verificações do fluxo Web de consulta/recuperação e nove do PCK real.
O painel de diagnóstico foi conferido em PC e mobile emulado. A checagem inicial
de encaixe confundia coordenadas lógicas com pixels CSS; corrigido o teste e
confirmado nas capturas, sem necessidade de alterar a disposição da interface.
WSS de produção
recusa anônimos e tokens sem assinatura; as mesmas duas contas foram mantidas.

Recarregar o [piloto privado](https://tece-island-multiplayer-pilot.gustavotccandido.chatgpt.site/Tece-Island/)
e conferir **.7.1**. Entrar com uma conta em cada aparelho. Se falhar, informar
a etapa e a linha “Última consulta”, além do código WSS quando existir.
Depois de entrar, retomar o roteiro FPS/RTT da .7. Entrada e desempenho físico
continuam dependendo do reteste real; não são aprovados pelos testes emulados.

Oficial 0.9.0, saves v8, campanha, configurações Firebase, duas contas e ausência
de faturamento preservados. Nenhuma funcionalidade de jogo acrescentada.
