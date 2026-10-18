# Piloto 0.9.0-solo-pilot.3 — objetivos por etapa

[Abrir piloto privado](https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/).
Branch `feat/solo-seventh-night`. A versão oficial permanece na **0.8.3**.
Relógio, encontros, inimigos, recompensas e condições de vitória da .2 foram
preservados. [Roteiro e histórico da campanha .2](SOLO_PILOTO_2.md).

## Objetivos escolhidos

As metas de preparação orientam e podem ser adiantadas. Não acrescentam bloqueios
ao mapa, templos ou ataque. As regras noturnas existentes continuam valendo.

| Etapa | Tarefas e quantidades |
| --- | --- |
| **Dia 1 · Kit — 4 tarefas** | Obter machado e picareta de madeira ou melhores; fabricar espada de pedra; fabricar uma fogueira. |
| **Dia 2 · Preparação — 5** | Fabricar machado e picareta de pedra (meta conjunta 0/2); bolsa nível 1; armadura de pedra; ter duas refeições cozidas; um cantil com pelo menos duas doses. A linha pode vir de loot ou das aranhas na noite 2. |
| **Dia/noite 3 · Expedição — 5** | Fabricar arco; levar oito flechas, três refeições e um cantil com três doses; recuperar mapa na torre da Serra na noite 3 ou posterior. |
| **Dia/noite 4 · Templo alto — 5** | Vestir armadura de pedra; levar espada de pedra ou arco; três refeições; cantil com três doses; conquistar o Templo da Névoa. |
| **Dia/noite 5 · Extremos — 6** | Vestir armadura; levar seis refeições, cantil com três doses e 16 flechas; conquistar Cinzas e Eco, registrados separadamente. |
| **Dia 6 · Preparação final — 6** | Reparar sinalizador; vestir armadura; levar espada de pedra ou arco, seis refeições, cantil com três doses e 16 flechas. |
| **Noite 6+ · Ataque — 3** | Ativar sinal; vencer duas formações; derrotar Guardião. Ativação e formações correspondem à tentativa atual. |
| **Amanhecer · Resgate — 1** | Confirmar resgate no amanhecer após o Guardião, preservando a vitória no dia 7 quando concluída a noite 6. |

Refeições aceitam carne ou peixe cozido. A reserva de água exige as doses em um
mesmo cantil. Flechas e arco são recomendações; armas de fogo continuam opcionais.
Ter o preparo incompleto não impede uma tentativa permitida pelas regras da campanha.

## Escolha e viabilidade

As receitas e os quatro níveis de bolsa foram conferidos no jogo. A bolsa 1
custa quatro madeiras e 12 fibras. Chegar da bolsa 1 à 3 acrescenta **32 madeiras
e 12 linhas**; essa linha competiria com as quatro da armadura e três do arco.
Por isso, a bolsa 3 não virou obrigação precoce.

O kit do dia 1 custa **11 madeiras e sete pedras**, usando picareta de madeira
para obter pedra. A automação na semente 77 coletou 15 madeiras e oito pedras
pelas recompensas normais e fabricou os quatro itens em **21,18 segundos do jogo**.
Usou movimento, colisões, recursos do mundo, drops, intervalos e receitas reais,
sem injetar materiais na bolsa. Execução 4× com passo físico de 1/60 s. Não inclui
colocar a fogueira, caça, exploração livre ou os dias seguintes; não é partida humana.

O custo bruto adicional do dia 2, sem aproveitar sobras, é 12 madeiras, 26 pedras,
14 fibras, quatro linhas e duas carnes cruas. Pedra e fibra usam as ferramentas
e regras existentes. A progressão reserva as linhas à proteção antes do arco.
Dia 3 acrescenta arco e oito flechas; comida e água representam reservas atuais,
reaproveitáveis entre etapas. Para os extremos, seis comidas dão margem sobre as
três usadas na medição automatizada da .2; essa medição não substitui teste humano.
Os orçamentos dos dias 2 e 3 foram exercitados com receitas reais e materiais de
fixture, cabendo na bolsa 1. Guarde ferramentas de madeira após melhorar, coloque
a fogueira e vista a armadura para liberar espaço; a coleta completa desses dias
ainda não foi cronometrada numa partida humana.

## HUD e Diário

- Cabeçalho com etapa e contador; até três tarefas, com checks desenhados e
  destaque da próxima executável. Quando há bloqueio, mostra o requisito que falta.
- Botão `−` recolhe e `+` expande. O título abre todas as etapas no Diário.
  O recolhimento é salvo por mundo. O painel não pausa a exploração.
- O Diário abre em **Objetivos**, com lista completa, contadores e pendências.
  **Registros** conserva pistas e história. Etapas antigas continuam na lista.
- O foco usa o dia atual e recupera mapa/templos atrasados. Não exige terminar
  tarefas de preparação antigas para avançar na campanha.

[Kit no celular](images/daily3-complete-640.png),
[condições atuais](images/daily3-current-640.png),
[Diário](images/daily3-journal-640.png).

## Histórico e condições atuais

Fabricações são conquistas permanentes: gastar, colocar ou perder o item não
apaga o registro. Repetir a mesma fabricação não duplica a contagem. Um equipamento
de pedra também satisfaz a obtenção da ferramenta inicial equivalente.

Comida, doses de água, flechas, arma na bolsa e armadura vestida são marcadas como
**agora**. Consumir ou retirar os itens atualiza o contador e pode reabrir a tarefa.
O jogo não grava esses checks como conquistas eternas. As reservas de etapas antigas
continuam visíveis, mas não desviam o foco da etapa atual.

Mundos antigos reconhecem os registros individuais existentes de ferramentas,
fogueira e bolsa, inclusive depois de perder os itens. Itens fabricáveis presentes
na bolsa, equipamento ou baús também são evidência; sua origem é indicada como
reconhecida no save anterior. Ausência de item e de histórico não inventa fabricação.
Matéria-prima na bolsa não é tomada como prova de coleta ou fabricação anterior.

## Save, sincronização e rollback

Save **v8**, campanha **2**, acompanhamento de tarefas **1**, dentro de `objectives`.
Os dados entram no snapshot completo e no hash da sincronização existente. IDs,
inventários, construções, backups, contas e resolução de conflitos permanecem.
Formato desconhecido ou conquistas duplicadas são rejeitados.

V5/v6/v7 continuam legíveis; ler não altera a versão/hash confirmados da nuvem.
A captura da partida grava o formato novo. Antes de migrar, o original é preservado
em `.before-v8.json` no nativo ou `:before-v8` na mesma transação IndexedDB. O backup
não é sobrescrito ao reabrir. Os backups anteriores também permanecem.

Piloto .2 e cliente oficial não leem v8. Rollback da hospedagem para a versão salva
**7** restaura .2; para o mundo, use uma cópia do backup anterior, preservando a
versão remota atual. Para 0.8.3 é necessário o backup v5, anterior aos pilotos.
Não se substitui um mundo atual silenciosamente por um backup antigo.

## Reteste

1. Confira `.3`. Faça o kit; veja os checks e contador 4/4. Recolha, salve e reabra.
2. Gaste ou descarte uma ferramenta: a fabricação fica registrada. Coma, beba e
   retire a armadura: as condições **agora** devem voltar a ficar pendentes.
3. Adiante equipamento; passe de dia com tarefas incompletas e confira toda a lista
   no Diário. Mapa e templos atrasados continuam acessíveis, com requisito correto.
4. Com cópia de mundo .2, confira inventário, base e conquistas reconhecidas.
   Teste PC → celular → PC, conflito entre sessões, suspensão e retomada.

Os testes automatizados, a build e a publicação final estão registrados em
[evidências](validation/solo3-2026-10-18.json). Permanecem para reteste humano:
campanha completa, tempos dos dias seguintes, conforto em aparelho físico,
suspensão, teclado virtual, bateria/temperatura e chat/sincronização entre as duas
contas reais. Nenhum backend, regra, lista de contas ou faturamento foi alterado.


## Publicação verificada

Piloto **0.9.0-solo-pilot.3**, versão salva **10**, deployment **succeeded**.
Build do jogo: `0e9d27d1c534dc6b0495a9a0ca27446b57def57e`. Fonte Sites: `61284677eda2bc5a6973520c8daaab41e2457610`.
Deployment: `appgdep_6ad51f67fd9881919cf98f9a7b3d9245`. Acesso privado preservado.
Manifesto e PCK conferidos por HTTPS; SHA-256 do PCK: `34658997f132609bdbe3133ba4b5ceb728376005da05a18d1553e3f377671d42`.
O pacote inclui também a correção que mantém evidências e créditos antigos visíveis no Diário.

Executados **388 checks Godot em 16 suítes**, **39 checks Web de tarefas**,
**63 de campanha Web** e **12 de persistência Web**, sem falhas.
PC 1280×720 e toque emulado 852×393 / 640×360; não são aparelhos físicos.
O cliente .2 foi executado contra v8: recusou a leitura e preservou os bytes.

Oficial conferido em **0.8.3**, commit `7c17e63f634d4abbaca87c6f5ad1b5198601e99d`.
Main remota preservada em `7eae4f3c6b922232dc5c1910f3fdfd26ba1a9c9d`.
Pacote local: `build/tece-island-0.9.0-solo-pilot.3.zip`.
