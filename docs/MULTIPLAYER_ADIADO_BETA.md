# Multiplayer adiado para a beta solo

Em 29/10/2026, por solicitação do usuário, a beta passou a priorizar exclusivamente o solo. Nenhuma funcionalidade multiplayer nova será incluída nesta etapa.

Preservados: branch `feat/multiplayer-pilot`, piloto `0.9.0-multiplayer-pilot.7.1`, código e evidências em `docs/MULTIPLAYER_PILOTO_7_1.md`, último commit anterior `df0902e`.

Inspeção antes de encerrar: tarefa sem execução, servidor e túnel ausentes, porta 8791 sem listener. Último heartbeat em 25/10 às 05:53:28 UTC; cloudflared recebeu terminated às 05:53:37 UTC. A RAM já estava perdida antes desta revisão. Executado `manage-multiplayer-pilot.ps1 -Action Stop`, confirmando encerramento exclusivo do host/servidor/túnel desta instância; não foi necessário iniciar nem reiniciar nenhum serviço. Firebase, chat, sincronização e serviços solo não foram alterados.

Evidência humana preservada: na .2, PC/celular entraram com contas distintas, viram movimento e corte. Na .6 a entrada funcionou, mas o usuário relatou desempenho injogável. A .7 ficou bloqueada na consulta; .7.1 não recebeu confirmação física.

Pendências: disponibilidade durável, entrada atual com duas contas reais, desempenho físico PC/celular, soma exata dos drops e ausência de duplicação, inventários/HUD, saída/retorno e reconexão física. Testes automatizados/emulados anteriores não aprovam essas etapas. Combate/PvP permanecem fora desta beta, sem data prometida.
