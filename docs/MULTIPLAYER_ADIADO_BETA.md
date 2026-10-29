# Multiplayer adiado para a beta solo

Em 29/10/2026, por solicita??o do usu?rio, a beta passou a priorizar exclusivamente o solo. Nenhuma funcionalidade multiplayer nova ser? inclu?da nesta etapa.

Preservados: branch `feat/multiplayer-pilot`, piloto `0.9.0-multiplayer-pilot.7.1`, c?digo e evid?ncias em `docs/MULTIPLAYER_PILOTO_7_1.md`, ?ltimo commit anterior `df0902e`.

Inspe??o antes de encerrar: tarefa sem execu??o, servidor e t?nel ausentes, porta 8791 sem listener. ?ltimo heartbeat em 25/10 ?s 05:53:28 UTC; cloudflared recebeu terminated ?s 05:53:37 UTC. A RAM j? estava perdida antes desta revis?o. Executado `manage-multiplayer-pilot.ps1 -Action Stop`, confirmando encerramento exclusivo do host/servidor/t?nel desta inst?ncia; n?o foi necess?rio iniciar nem reiniciar nenhum servi?o. Firebase, chat, sincroniza??o e servi?os solo n?o foram alterados.

Evid?ncia humana preservada: na .2, PC/celular entraram com contas distintas, viram movimento e corte. Na .6 a entrada funcionou, mas o usu?rio relatou desempenho injog?vel. A .7 ficou bloqueada na consulta; .7.1 n?o recebeu confirma??o f?sica.

Pend?ncias: disponibilidade dur?vel, entrada atual com duas contas reais, desempenho f?sico PC/celular, soma exata dos drops e aus?ncia de duplica??o, invent?rios/HUD, sa?da/retorno e reconex?o f?sica. Testes automatizados/emulados anteriores n?o aprovam essas etapas. Combate/PvP permanecem fora desta beta, sem data prometida.
