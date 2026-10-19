# Piloto 0.9.0-solo-pilot.4 — caminho até a torre

[Piloto privado](https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/).
Branch `feat/solo-seventh-night`. A publicação oficial continua na 0.8.3.
As metas, relógio, encontros, interiores dos templos e vitória da .3 permanecem.
[Objetivos e histórico da .3](SOLO_PILOTO_3.md).

## Diagnóstico

O objetivo podia ficar em 4/5 sem o jogador ter examinado o sinalizador.
O minimapa da .3 exigia essa descoberta para desenhar um ponto de apenas cinco
pixels, sem nome. Assim, a existência do objetivo não garantia orientação.

A torre e o pergaminho **existem no pacote publicado da .3**, não apenas no HUD.
Executamos o PCK de SHA-256
`34658997f132609bdbe3133ba4b5ceb728376005da05a18d1553e3f377671d42`,
isolado dos arquivos do projeto. Um percurso com movimento, colisões e tecla E
recuperou o mapa na noite 3 sem examinar o sinalizador. O teste não atribuiu
`map_found`, não chamou a interação da campanha diretamente e não teleportou
o jogador. Surgimento de inimigos e relógio foram controlados para testar acesso.

Não foi encontrada falha de geração/migração nas fixtures e sementes testadas.
A geometria e os pontos da campanha são criados também ao abrir mundos antigos;
a restauração preserva esses pontos. Uma construção do Pântano intercepta a linha
reta para o norte: é necessário contorná-la. Os percursos completos usados nos
testes consideram essa colisão. A seta indica o destino, não uma rota sem obstáculos.
O save real do jogador não esteve disponível nesta investigação.

## Correção

- Ícone de torre sobre o minimapa, inclusive na área não explorada e sem descobrir
  o sinalizador. Some depois da coleta ou de uma vitória antiga já concluída.
- Fora do alcance, seta na borda; nome **Torre da Serra** e rumo N/NE/L/SE/S/SO/O/NO.
- Na chegada, pergaminho destacado, indicação de mapa no chão e instrução de E ou
  botão **Interagir**. Não há escada nem necessidade de subir.
- Durante o dia, instrução para aguardar anoitecer; antes da terceira noite,
  indicação da noite mínima. Qualquer noite posterior continua válida.
- Diário com percurso prático também quando a tarefa está bloqueada pelo horário.
- Painel de tarefas com espaço reservado ao minimapa e texto dimensionado para
  PC e toque emulado. Checks, recolhimento e pendências anteriores permanecem.

## Seu mundo

Abra o **mesmo mundo** na .4. Não precisa reiniciar a campanha nem criar outro.
Não há nova migração: save **8**, campanha **2**, tarefas **1**.
O mapa continua pendente até uma interação manual válida. Inventário, construções,
IDs, recursos esgotados, progresso de templos e conquistas permanecem.

Uma base antiga sobre o ponto não é removida ou deslocada. Ao se aproximar,
o Diário oferece **Acessar mapa pela base**, já existente nos pilotos anteriores.
É uma interação manual próxima, sujeita à mesma restrição de noite 3+.
O teste carregou uma parede sobre o pergaminho, conferiu seu ID/posição/estado,
recusou a ação diurna e recuperou o mapa à noite sem apagar a parede.

A coleta participa do save e do snapshot sincronizado existentes. Reabertura não
duplica a coleta. Sem alteração de backend, regras, intervalo de 120 s, contas
autorizadas ou faturamento. A .3 continua compatível com o mesmo formato, mas sua
orientação anterior não contém a correção; a .2 não lê v8.

## Reteste físico curto

1. Confirme **0.9.0-solo-pilot.4**. Abra seu mundo do dia 4 em 4/5 e confira nome,
   torre e rumo no minimapa, mesmo sem ter examinado o sinalizador.
2. Partindo do sinalizador `(1152, 570)`, siga ao norte pela Floresta e Pântano,
   contornando construções, até a Serra Nebulosa. A torre fica em `(1152, -2048)`,
   a leste/direita do Templo da Névoa. O pergaminho está na base aberta da torre.
3. De dia, aproxime-se e confira a explicação de horário. Espere anoitecer e
   aperte **E** no PC ou toque em **Interagir**. Na noite 4 ou posterior também vale.
4. Confira o mapa concluído e os templos indicados. Salve, feche e reabra o mesmo
   mundo. Depois teste a continuação no outro aparelho da mesma conta.
5. Se a base antiga bloquear a passagem, aproxime-se e use **Diário → Acessar mapa
   pela base** à noite. Confira que a construção continua no lugar.

As verificações e a publicação estão em
[evidências da .4](validation/solo4-2026-10-18.json).
Os percursos automatizados isolam acesso e controles, com inimigos desativados;
os tempos registrados não representam exploração ou sobrevivência humanas.
PC e toque são emulados no navegador, sem partida em celular físico.
Continuam pendentes o reteste no save real, conforto em aparelho físico e a troca
entre duas sessões autenticadas reais. Nenhuma conclusão automática foi adicionada.
