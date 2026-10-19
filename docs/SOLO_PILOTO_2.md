# Campanha solo — 0.9.0-solo-pilot.2

[Abrir piloto privado](https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/).
Branch: `feat/solo-seventh-night`. Build do jogo: `5287330eb43d58019ea67b839a00bf600a9abaa7`.
A publicação oficial continua na **0.8.3**. Esta entrega não altera backend,
regras, chat, apelidos, moderação, as duas contas permitidas nem faturamento.

## Investigação do piloto .1

O código anterior exibia “Ative o sinal · noite 7 ou posterior” sempre que
`repaired` estava verdadeiro. O prompt também dizia “ativar” sem verificar o
relógio. A ativação em si permanecia bloqueada. Assim, um estado preparado
cedo reproduz as duas mensagens enganosas. A coleta antiga permitia adiantar
os três componentes; o reparo exigia esses três registros.

Não foi inspecionado o save da sessão relatada. **Não há confirmação de que
o jogador coletou os componentes**, nem evidência suficiente para atribuir
aquele estado a coleta rápida, migração ou avanço indevido. A migração normal
e o relógio não concediam componentes. Os testes novos cobrem mundo vazio,
progresso parcial, reparo legado e campanha concluída.

O HUD agora deriva a etapa do progresso real e informa espera, templo ou
invasores. A interação bloqueada explica o requisito pendente; o Diário
detalha nomes, coordenadas, componentes e conquistas. Os textos do HUD foram
encurtados para celular. O relógio também atualiza o dia quando um save ou
salto de teste mantém a mesma fase e os mesmos segundos restantes; seus
callbacks recebem o ciclo já atualizado. Esse caso foi reproduzido nos testes,
mas não foi estabelecido como causa da sessão relatada.

## Roteiro da campanha

| Etapa | Objetivo e mundo aberto |
| --- | --- |
| Dias/noites 1–2 | Preparar ferramentas, arma, armadura e suprimentos. Noite 1: somente roxos, até três. Noite 2: acrescenta esqueletos e aranhas, até quatro. |
| Noite 3+ | Recuperar mapa na torre da Serra Nebulosa, `(1152, -2048)`. Introduz Caçador; limite comum passa a cinco. |
| Noite 4+ | Conquistar Templo da Névoa, **ALTO**, `(750, -2048)`: duas formações, quatro inimigos. |
| Noite 5+ | Conquistar Templo das Cinzas, **EXTREMO**, `(3072, -2048)`, e Templo do Eco, **EXTREMO**, `(-2339, 504)`: duas formações e seis inimigos em cada. |
| Dia 6+ | Reparar sinalizador em `(1152, 570)` com três componentes; preparar ataque. |
| Noite 6+ | Ativar sinal com mapa, componentes, reparo e pelo menos **180 s** restantes. Duas formações de invasores precedem o Guardião. Brutamonte e Uivador também entram no mundo aberto. |
| Amanhecer do dia 7 | Vitória se o ataque da noite 6 terminou com o Guardião derrotado. Uma tentativa posterior vence no amanhecer seguinte à sua noite. |

O mapa revela os três templos no Diário e números/direções no minimapa.
Cada componente é garantido pela conquista, tem ID único e fica protegido
fora da bolsa. Os sorteios de loot comum permanecem separados e inalterados.
O Templo do Eco reutiliza um templo existente; os outros usam pátios nas
trilhas dos biomas. Construções, recursos, IDs e geometria antigos permanecem.
Os caminhos foram verificados com colisões em quatro sementes.

Um templo novo exige mapa e a noite indicada; os extremos também exigem o
templo alto. **Depois de iniciado, pode continuar de dia dentro da construção.**
Os inimigos específicos ficam no recinto. As formações substituem surgimentos
comuns dentro dos templos, permitindo recuperação após a conquista; guardiões
existentes das construções conservam sua exceção diurna. Durante o ataque final,
o evento também substitui os surgimentos comuns.

## Combate e preparo

Sentinela: 65 de vida, lento, golpe forte com aviso de 1,2 s e recuperação.
Acólito: 35 de vida, projétil roxo, preparação de 0,85 s, trajetória fixa e
colisão com obstáculos. Ambos têm desenho distinto dos inimigos comuns.
O alto apresenta as ameaças aos poucos; os extremos combinam salas, inimigos
à distância, pressão próxima e investidas. O esqueleto mantém a preparação,
antecipação moderada, recuo e flecha rápida sem perseguir o alvo após sair.

O Uivador anuncia um chamado por 2 s; qualquer dano o interrompe. Há no máximo
um Uivador nos surgimentos comuns, dois reforços simultâneos e cinco inimigos
da origem do chamador. Intervalo de chamado completo: 18 s; interrompido: 12 s.
Reforços do evento precisam ser vencidos antes da próxima formação. O Guardião
vem por último, tem 300 de vida e requer 20 acertos de espada de pedra.

O teste real de fabricação, usando recursos de fixture, produziu armadura
equipada, espada, arco, 16 flechas e seis comidas na bolsa inicial com
30 madeiras, 26 pedras, sete linhas e seis carnes cruas. Fogueira, ferramentas,
cantil e construção de base exigem recursos adicionais. Linha vem das aranhas
a partir da noite 2, além do loot existente; a preparação deve priorizar
equipamento antes da bolsa opcional. Essa verificação não cronometra uma coleta
humana. Pistola e doze continuam opcionais; a medição abaixo usa apenas
espada, armadura de pedra e comida.

## Quinta noite medida

Automação física na semente 77, começando perto do templo alto já conquistado,
com equipamento e comida preparados por fixture. Surgimentos comuns ligados;
movimento, colisões, IA hostil, ataques, intervalos, dano, armadura e cura normais.
Sem teleporte no percurso medido, invulnerabilidade ou dano direto de fixture.
Escala de execução 4×, mantendo passo físico de **1/60 s**; os tempos são
**segundos do relógio do jogo**, não duração de uma partida humana.

| Trecho | Segundos |
| --- | ---: |
| Névoa → Cinzas | 11,57 |
| Combate das Cinzas | 13,95 |
| Cinzas → Eco | 42,07 |
| Combate do Eco | 14,70 |
| Recuperação final | 4,00 |
| **Total medido** | **86,28** |
| Reserva planejada para erros, adicional | 30,00 |
| Orçamento da noite | 300,00 |

Consumiu três comidas e terminou com **95,09 de vida**. Há 183,72 s além do
percurso e da reserva planejada. A reserva não foi uma sequência de erros
humanos executada. Uma medição anterior revelou acúmulo de inimigos comuns
nos templos; a build final inclui o ajuste dos interiores e foi medida novamente.
Isso demonstra espaço no orçamento em uma rota automatizada; habilidade,
orientação e conforto por toque ainda precisam de uma partida humana.

## Persistência, recuperação e rollback

Save externo **v7**, campanha **2**. V5 e v6 continuam legíveis. A leitura
mantém os bytes/versionamento do snapshot confirmado para preservar seu hash
de nuvem; a conversão ocorre ao carregar a partida e só é gravada depois.
O teste v6 → v7 → PC → celular passou sem falso conflito.

Na conversão da campanha 1, somente componentes já registrados recebem
**crédito legado explícito** no Diário. Reparo, tentativas, mortes e vitória
anteriores permanecem; não se inventam combate nem componentes adicionais.
Campanhas ainda abertas precisam recuperar o novo mapa. Vitória antiga continua
concluída e não repete a tela automaticamente.

- Cada inimigo conquistado e cada recompensa geram marco de salvamento local.
  Vida dos sobreviventes entra no snapshot; dano marca autosave. Fechar pelo
  fluxo de salvar/sair força a captura. Autosave e sincronização conservam seus
  intervalos e proteção contra conflitos; não se força envio à nuvem por golpe.
- Reabrir templo retoma os inimigos restantes e sua vida salva, sem refazer
  conquistas ou duplicar componente. Derrota conserva o mundo e essas etapas.
- Sair, morrer, fugir além de 900 px ou amanhecer durante o ataque final
  interrompe a tentativa. Reativar em outra noite reinicia invasores e chefe,
  preservando templos, componentes, reparo, inventário e base.
- Guardião vencido gera `awaiting_dawn`, persistido mesmo após desconexão.
  O próximo amanhecer confirma resgate; o relógio sozinho nunca concede vitória.
  Continuar e reabrir uma vitória salva não duplicam chefe ou resumo.
- Base antiga próxima a objetivo permite acesso pelo Diário até 400 px.
  Não se remove ou move a construção para liberar a campanha.

Antes da atualização, o nativo preserva `.before-v7.json`; ao converter campanha
1, também `.before-campaign-v2.json`. Na Web, sufixos `:before-v7` e
`:before-campaign-v2` ficam na mesma transação IndexedDB da gravação. São
exatos e idempotentes; backups anteriores não são apagados.

**0.8.3 recusa v6 e v7; piloto .1 recusa v7**, mantendo o arquivo intacto nos
probes executados. Rollback da hospedagem para a versão salva **6** devolve o
cliente .1, mas não converte mundos v7 de volta. Para retomar aquele cliente,
use uma cópia do backup v6 anterior à migração. Para 0.8.3, use o backup v5
anterior ao primeiro piloto (`before-v6`) ou o backup v5 de uma migração direta
v5 → v7. Não reponha um backup antigo silenciosamente sobre o mundo remoto atual;
preserve as duas versões e use um mundo/cópia de teste. Os backups Web pertencem
à origem do piloto; o cliente oficial em outra origem não os lê diretamente.

## Verificação e limites

Em 18/10/2026: **750 verificações em 32 suítes Godot**, sem falhas; **63
verificações Web** em 1280×720, 852×393 e 640×360; **12 de persistência Web**;
**22 testes de regras/transporte no emulador**, incluindo 12 verificações REST
nativas, nenhum ignorado. Incluem progressão, migração real de fixtures v5/v6,
reentrada, morte, atraso, duplicação, amanhecer, vitória, sincronização e conflito.

Os testes Web usam teclado/mouse e toque emulado, incluindo dois dedos. A
progressão de teste elimina inimigos com dano de fixture; não é uma partida
jogada. A medição da quinta noite usa combate normal automatizado. O pacote
final foi aberto separadamente: campanha 2, três templos, supressão de comuns
nos interiores, cinco no exterior, duas contas e ausência de fixtures confirmadas.
O motor dividido em cinco partes carregou o acesso de PC e celular emulado.

[Evidências estruturadas](validation/solo2-2026-10-18.json),
[templo no celular](images/solo2-lens-640.png),
[Diário](images/solo2-journal-640.png) e
[vitória](images/solo2-victory-640.png).

**Pendências reais de reteste:** campanha inteira jogada por pessoa; esquiva e
orientação em telefone físico; teclado virtual, suspensão/reabertura, bateria,
temperatura e desempenho no aparelho; chat e sincronização autenticados entre
as duas contas reais. Não houve login Firebase em produção nem alteração do
backend. O sandbox não lê o repositório de certificados Windows; o transporte
nativo foi testado no emulador HTTP, não em TLS real autenticado.

## Reteste físico curto

1. Confirmar **0.9.0-solo-pilot.2** no selo e em Ajuda. Criar mundo de teste;
   na noite 1 conferir HUD e motivo dos bloqueios, movimento/mira com dois dedos.
2. Na noite 3, pegar mapa na torre; na 4, conquistar Névoa. Salvar/sair no meio
   de uma formação e voltar: só sobreviventes, com vida salva, sem prêmio duplicado.
3. Na noite 5, ir Cinzas → Eco com espada, armadura e comida; anotar tempo,
   consumo, mortes e conforto de esquiva. Conferir recuperação dentro do templo.
4. Reparar no dia 6; ativar no início da noite 6. Interromper chamado do Uivador,
   vencer as duas formações e o Guardião. Só o amanhecer do dia 7 confirma vitória.
   Continuar e reabrir não devem repetir chefe/resumo.
5. Em outro mundo/cópia, sair ou morrer durante o ataque e retentar numa noite
   posterior. Conferir base/inventário; testar PC → celular → PC e conflito entre
   sessões, além de chat, apelidos e moderação com as duas contas autorizadas.

O registro exato da publicação, hashes e commits está nas evidências estruturadas.

## Publicação conferida

- Sites: versão salva **7**, deployment `appgdep_6ad50cc99eec8191a4d8ab6bd27399c3`,
  resultado **succeeded**. Fonte da hospedagem: `d69bc90d821110acf7c34e3e10e2212d41dba8e5`.
  Acesso privado do proprietário preservado.
- Manifesto e PCK publicados comparados por HTTPS com a exportação final.
  PCK SHA-256: `7179d2ec4a2eef558b62869cf01a2c0e0f4d85bf10158d14e96fcab8d7de96ec`.
  A build hospedada é exatamente `5287330`, incluindo os ajustes de `73bce71`
  e a correção final de relógio/HUD. Motor em cinco partes verificadas por hash.
- [Cliente oficial](https://gustavotc-web.github.io/Tece-Island/): manifesto ainda
  **0.8.3**, commit `7c17e63f634d4abbaca87c6f5ad1b5198601e99d`.
  Main remota preservada em `7eae4f3c6b922232dc5c1910f3fdfd26ba1a9c9d`.
- Commits da revisão: `e059fda` (campanha), `73bce71` (interiores),
  `5287330` (relógio, HUD, testes e build), seguidos do registro da entrega.
- Pacote local: `build/tece-island-0.9.0-solo-pilot.2.zip`, Web e fontes nativas.
  As alterações locais preexistentes em `project.godot`, no UID de
  `validate_sync_handoff` e nos cinco imports de imagens antigos ficam fora dos commits.
