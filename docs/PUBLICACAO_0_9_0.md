# Publicação 0.9.0 — campanha solo aprovada

[Endereço oficial](https://gustavotc-web.github.io/Tece-Island/).
**Publicado como 0.9.0**, tag **v0.9.0**, commit `15ba9685c120ce867588668a35f3c3f53077981d`.
Integração de `feat/solo-seventh-night` na main.
[Workflow oficial](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/39299335063): validação, exportação e deploy **success**.

## Versão promovida e escopo

O endereço privado foi conferido por HTTPS antes da integração: **0.9.0-solo-pilot.4**,
versão salva Sites **11**, código do jogo
`b3680077a01b5afdfb77a483e385dbb67aa9e1c0`, fonte de hospedagem
`a6090334702478228b7e1f7d9770e1956b1d0e56` e PCK SHA-256
`3cc1609fe3a938138190c52d7e890520bde7b12993d7b4e0559d6b62d61d2d4f`.
O topo da feature, `d539869a4c25e37488c84195fc5d86d17d23e60e`, acrescenta somente
documentação/evidências após esse código. Não há funcionalidade posterior incluída.

Scripts do jogo, cenas, assets, shell Web, projeto, presets e regras são comparados
integralmente com o piloto aprovado. A preparação da versão altera apenas o
carimbo/manifesto 0.9.0, instrumentos de verificação, CI e documentação.
Save **8**, campanha **2** e tarefas **1** continuam iguais aos pilotos .3/.4.
Relógio, encontros, receitas, orientação e condições de vitória não foram ajustados.

O checkout do IDE permanece em `feat/solo-seventh-night`, com suas alterações locais
preservadas. A integração e os testes usam `.tools/release-090/`.

## Relato manual do usuário

Na autorização desta publicação, o usuário informou:

> Concluí uma partida no piloto, alcancei a vitória no sétimo dia e não encontrei bugs durante esse percurso.

Registro: **um teste manual de campanha completa, com vitória no dia 7, relatado
pelo usuário**. O piloto correspondente foi identificado pelo manifesto ativo acima.
Não houve observação independente pelo assistente. O relato não especifica aparelho,
navegador, rotação, teclado, suspensão, consumo, chat ou troca entre contas/aparelhos;
esses casos não foram marcados como testes físicos aprovados.

## Verificações da integração

Os resultados desta publicação serão consolidados em
[`validation-0.9.0.json`](validation-0.9.0.json), separados das evidências históricas
dos pilotos. A preparação cobre campanha/combate, tarefas, migração v5/v6/v7,
reabertura v8 (inclusive vitória no dia 7), contas, catálogo, backups, conflitos,
sincronização, chat, controles e apresentação Web PC/toque emulado.

A suíte da torre apresentou uma intermitência na injeção de teclado a 4x: múltiplos
ticks de física podiam compartilhar um ciclo de entrada. O teste passou a entregar
keydown/keyup em ciclos separados e descarregar o buffer. O jogo permaneceu
idêntico ao piloto; 125 checks passaram após a correção do instrumento de teste.
O novo teste de checkpoints usa dados sintéticos e não simula outra partida humana.

Chat e sincronização conservam as **mesmas duas contas autorizadas** e intervalo
de sync de 120 s. A configuração pública de autenticação e as variáveis existentes
do repositório foram conferidas sem modificá-las. Regras, índices, configurações,
dados, usuários e faturamento do Firebase não são publicados ou alterados por este
workflow. Os testes de backend usam somente o projeto demo em emuladores locais.

## Recuperação compatível

Siga [RECUPERACAO_0_9_0.md](RECUPERACAO_0_9_0.md). A primeira alternativa é republicar
um cliente compatível com v8 no mesmo endereço. **Voltar só ao aplicativo 0.8.3
impede abrir os saves v8**, embora ele preserve o arquivo ao recusá-lo.
Não se faz downgrade do formato, limpeza de armazenamento, reset/force-push,
regravação de dados remotos ou restauração automática de backup antigo.


## Resultado conferido

Passaram **621 verificações Godot em 22 suítes**, **22 testes de regras** sem skips, 12 checks do transporte REST dos saves (incluídos em um desses testes) e 11 de chat nativo. No navegador: **218 checks**, incluindo PC e toque emulado, campanha, tarefas, coleta/reabertura do mapa, persistência, chat e build oficial. O novo teste de checkpoints teve 57 checks. Nenhuma dessas automações é partida humana.

O PCK efetivamente servido foi baixado, conferido pelo SHA-256 do manifesto e executado isoladamente: abriu o save v5 sem conceder mapa e o checkpoint v8 de vitória no dia 7 sem repetir a tela final; ambos os originais permaneceram intactos. Configurações compiladas mantêm autenticação, as mesmas duas contas, chat/sync e intervalo de 120 s. Fixtures e configuração de desenvolvimento estão excluídas.

SHA-256 do PCK publicado: `2681e0b166b982a9642019770b11803dde28c76bfa1e7b20fcc1a8c31a8d40ae`. Os hashes de `index.js`, `index.wasm` e dos 24 fontes declarados também foram conferidos com o commit publicado. As variáveis GitHub conservaram o mesmo digest antes/depois. Não foi executado deploy, escrita administrativa ou alteração de faturamento no Firebase.

Pacote de recuperação baixado do endereço oficial: `build/tece-island-0.9.0-web-recovery.zip`, 15 arquivos, SHA-256 `3898be1934656ab88783d961851833d5fd273cbff3a5af86fa7a9bf8b87bcc65`. Não contém dados de jogadores. O procedimento de rollback em produção não foi acionado.

Não há bloqueio conhecido de publicação. O relato manual aprova uma campanha completa até o dia 7; aparelho, rotação, teclado virtual, suspensão, troca entre duas sessões autenticadas reais e consumo/faturamento não receberam nova aprovação física. A evidência manual não foi ampliada para esses casos.
