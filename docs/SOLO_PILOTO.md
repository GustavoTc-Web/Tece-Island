# Campanha solo — 0.9.0-solo-pilot.1

Base: main 0.8.3 (`7eae4f3`). Branch `feat/solo-seventh-night`.
A publicação oficial permanece na 0.8.3 até o reteste e aprovação.

## Campanha e recuperação

O sinalizador quebrado fica junto à clareira inicial (1152, 570). O registro
original na casa a sudoeste também revela as pistas da campanha. Os componentes
ficam na torre da Serra Nebulosa (1152, -2048), nas ruínas da Floresta Queimada
(3072, -2048) e no castelo do Pântano (2800, 520). E ou o botão de coleta usa
os mesmos controles de interação existentes. J ou menu → Diário abre o progresso.

A exploração pode ser antecipada. Com três componentes, interagir com o sinal
repara o aparelho; outra interação durante qualquer noite do dia 7 em diante
chama o Guardião. Derrotá-lo conclui a campanha. A tela de resumo permite
continuar no mesmo mundo. Passar do dia 7 nunca remove a oportunidade de resgate.

O Guardião anuncia uma investida dourada e um leque azul de três projéteis.
A investida tem direção fixa e os projéteis respeitam paredes. Espada de pedra,
armadura, arco e flechas fabricáveis bastam; armas de fogo continuam opcionais.
O chefe tem 300 de vida: são 20 golpes da espada de pedra. Essa conta verifica
o dano necessário; a dificuldade e conforto em uma partida real exigem reteste.

Derrota, fuga além de 900 px do sinal, amanhecer ou reabertura durante o confronto
permitem uma nova tentativa explícita, com chefe em vida cheia. Componentes,
inventário e construções permanecem. O chefe não aparece no sorteio noturno.

## Compatibilidade

O campo `campaign`, com versão própria 1, integra o save v6, mantendo os
IDs de contas/mundos, envelope de sincronização e controle de conflitos.
Antes da primeira gravação com campanha, o save anterior é preservado exatamente
em `.before-campaign-v1.json` no nativo ou `:before-campaign-v1` no IndexedDB,
Também existe backup `.before-v6.json` / `:before-v6`. Na Web, os backups ficam
dentro da mesma transação da gravação. Repetir não substitui esses backups.
Dados de campanha desconhecidos ou inconsistentes bloqueiam a gravação.

As duas regiões são acrescentadas ao norte: +3.932.160 px², aproximadamente
9,5% da superfície anterior das regiões. Nenhum bioma anterior, árvore,
construção, poço ou baú existente é reposicionado. Os novos pontos de loot usam
as mesmas probabilidades e itens das casas; os componentes têm IDs próprios,
obtenção garantida e ficam no diário, fora das bolsas e sorteios.

Construções novas reservam 80 px junto aos pontos da campanha. Uma base antiga
perto de um objetivo libera uma ação de acesso pelo Diário, a até 400 px, sem
apagar ou mover a base. Isso evita que paredes antigas tornem o resgate impossível.

O piloto usa as mesmas duas contas e configurações de acesso anteriores.
Chat, apelidos, moderação, regras Firestore e plano gratuito não são alterados.
A 0.8.3 recusa saves v6: ela não pode silenciosamente apagar o progresso novo.
Para voltar ao cliente antigo, use uma cópia do backup anterior à migração;
isso preserva o mundo anterior, mas não leva a campanha ao cliente antigo.

## Reteste curto

1. Confirmar **0.9.0-solo-pilot.1** em Ajuda e suporte. Criar um mundo de teste;
   investigar sinalizador e casa, conferir HUD e Diário em PC e celular.
2. Ir ao norte do Pântano e ao norte dos Campos; entrar nas duas novas regiões,
   chegar aos componentes e coletar com bolsa cheia. Recuperar também o do castelo.
   Reabrir após cada coleta: progresso deve continuar único e intacto.
3. Reparar o sinal. Antes da noite 7, ativação deve explicar a espera. Na noite 7
   ou posterior, ativar; sair ao menu durante a luta e voltar. Reativar, morrer,
   reaparecer e tentar novamente. Conferir inventário, base e componentes.
4. Vencer com equipamento fabricado, conferir resumo, continuar explorando e
   reabrir. Não deve surgir outro chefe nem sumir o mundo.
5. Repetir com cópia de mundo antigo posterior ao dia 7 e com uma base perto
   do sinal/castelo. Usar o acesso pelo Diário se houver paredes no objetivo.
6. Nas noites 2 e 4, conferir Caçador/Brutamonte; esquivar dos avisos e das
   flechas. Em celular físico, conferir dois dedos, coleta e espaço do HUD.
7. Com as duas contas, conferir chat nos dois sentidos, apelidos e sincronização
   PC → celular → PC no mesmo mundo de teste; testar suspensão e conflito entre
   sessões sem escolher sobrescrita inadvertida.

## Limites de validação

Em 18/10/2026, executados:

- **787 verificações em 34 suítes Godot headless**, sem falhas. Incluem 45 da
  campanha, 20 do combate novo, 14 da migração de um save produzido pela main
  0.8.3, as nove suítes de persistência/sincronização e regressões de controles,
  ferramentas, loot, construções, animais, diário e apresentação.
- **22 testes de regras** no emulador Firestore/Auth, nenhum ignorado, incluindo
  **12 verificações REST no Godot nativo**. Backend real não foi alterado.
- **42 verificações Web** em Edge/SwiftShader: PC 1280×720 e toque emulado
  852×393 / 640×360, coleta real pelos controles, dois dedos, HUD, diário,
  componentes, reparo, ativação, vitória, continuação e migração IndexedDB.
- **12 verificações adicionais de saves Web**, incluindo fechar/reabrir perfil,
  duas abas, conflito, isolamento por conta/mundo e importação de legado.
- Caminhos validados com formas e varreduras físicas em quatro sementes:
  1, 77, 20261018 e 2147480000. Coleta com bolsa cheia, derrota, amanhecer,
  reativação e reabertura também foram exercitados.
- Cliente 0.8.3 inalterado executado contra um save v6: recusou a leitura e
  manteve os bytes. Migração v5 → v6 seguida de PC → celular testada sem falso
  conflito, mantendo a campanha no envelope completo.

[Evidências estruturadas](validation/solo-2026-10-18.json) e capturas:
[Serra](images/solo-lens-1280.png), [Floresta Queimada](images/solo-coil-1280.png),
[controles móveis](images/solo-lens-640.png), [diário](images/solo-journal-640.png),
[vitória](images/solo-victory-640.png).

Os intervalos de `requestAnimationFrame` foram amostrados nos novos biomas
(45 por região/resolução), sob Edge headless e renderização por software.
São observações curtas do ambiente de automação, não benchmark de celular,
GPU real, bateria ou temperatura. A névoa usa desenho estático transparente;
o limite de cinco monstros comuns foi mantido, acrescido de um chefe somente
durante o confronto. Não foi feita uma campanha inteira jogada por uma pessoa.

Automação de dano e interface não substitui uma campanha jogada por uma pessoa. Bateria,
temperatura, teclado virtual, suspensão do sistema e desempenho em aparelhos
físicos permanecem para o reteste. Não foi ampliado o escopo com animações externas,
partículas, shaders de névoa ou mudanças de infraestrutura para a beta de 25/10.
O sandbox também não pôde consultar o repositório de certificados do Windows:
o transporte REST validado foi o emulador HTTP local; TLS nativo real e chat/
sincronização autenticados entre as duas contas reais não foram retestados.
