# Publicação 0.8.3 — otimização do chat

Endereço oficial preservado: https://gustavotc-web.github.io/Tece-Island/

**Publicado: 0.8.3, deploy concluído com `success`.** [Workflow oficial](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/39037784828), com validação, exportação e deploy aprovados. [Manifesto servido](https://gustavotc-web.github.io/Tece-Island/version.json) confirmado após o deploy.

Integração pelo [PR #3](https://github.com/GustavoTc-Web/Tece-Island/pull/3), commit `7c17e63f634d4abbaca87c6f5ad1b5198601e99d`, tag **`v0.8.3`**. Main anterior `b94a68a`, branch incorporada `perf/chat-read-budget` (`988530f`), sem conflitos. O candidato `a057449` teve CI aprovado; o build Web local usou `d5c28f0`, com o mesmo código do jogo. Alterações posteriores do candidato tratam somente a instrumentação dos testes.

## Escopo e proteções

O código do chat é idêntico ao piloto retestado: consultas incrementais, contagem de janela para remoções a cada 120 s, poll de 5 s em atividade / 15 s após 60 s ocioso, backoff e um pedido por sessão. Renomeação, mutes e administração por UID preservados. Saves, backups, conflitos, isolamento por UID, autenticação, regras Firestore e shell do jogo não mudam em relação à main 0.8.2.

O workflow Pages conserva a validação de saves/regras antes do export e exige exatamente os dois UIDs já configurados em `TECE_PILOT_ALLOWED_UIDS`. Conferir a igualdade dessa variável com o pacote privado retestado sem imprimir os UIDs. Nenhuma variável, documento, regra, índice ou configuração de faturamento Firebase deve ser alterada. Defaults de desenvolvimento continuam desligados; o build oficial habilita chat e sync somente para as duas contas.

`version.json` identifica versão, commit, estratégia/intervalos e hashes dos três arquivos do pacote, das regras **do código-fonte** e dos arquivos principais de saves/chat. Hash de regras no manifesto não afirma que o estado remoto foi lido/deployado.

## Evidência manual e consumo

**Reteste manual relatado pelo usuário**, em 17/10/2026: “Concluí o reteste físico do 0.8.2-chat-budget-pilot.1 e não encontrei novos problemas.” O usuário autorizou integração e publicação. Não houve observação independente pelo assistente, nem detalhes separados de dispositivo/caso. Esse relato conclui o reteste do piloto para este rollout; não reclassifica a automação histórica como teste físico.

Consumo continua sendo **estimativa**, não medição de faturamento: aproximadamente 660 leituras/cliente/h em regime ocioso estável, 730 na primeira hora incluindo abertura, e 1.620/h de recepção ativa antes dos envios. Inclui reserva para leituras das regras. A amostra HTTP do piloto (135 s) observou 28 → 19 pedidos e estima 105 → 38 leituras incluindo regras; não é uma amostra de cobrança. Projeções de grupos e capacidade reservada aos saves em [CHAT-BUDGET-PILOT.md](CHAT-BUDGET-PILOT.md).

## Validação da versão integrada

Resultados executados nesta integração, separados dos resultados históricos do piloto:

- **155 verificações de saves**, 9 suítes, sem falhas.
- **22 testes de regras** de saves/chat, com transporte REST nativo dos saves, sem falhas; **7 verificações de controles**.
- **12 verificações de persistência Web**, incluindo reabertura de navegador, backup e conflito entre abas.
- **45 verificações de chat Web**, incluindo painéis abertos, lobby/partida pausada, apelido entre sessões, silenciamento por UID, remoção natural, reconexão, logout e máximo de um pedido simultâneo. **11 verificações do transporte de chat nativo**.
- **13 verificações do build Web local** e **13 no endereço oficial**, após o deploy. Incluem login obrigatório, hash do PCK, fixture própria no IndexedDB/reload e viewport mobile emulado. Não foi feita autenticação positiva com conta real Firebase pelo assistente.
- Hashes dos três arquivos servidos (`index.pck`, `index.js`, `index.wasm`) iguais ao manifesto; hashes dos fontes iguais ao commit publicado. PCK público SHA-256: `3965a0f84884fcf641a2eab702e2c0e068767b03e79b58c83a278b574a12c04c`.
- Configuração **lida de dentro do PCK público**, em processo de auditoria sem iniciar o jogo/Firebase: chat/sync habilitados para exatamente os dois UIDs do piloto, intervalo de sync 120 s, identificação 0.8.3/commit correto e fixtures excluídas.
- Igualdade integral de regras, saves, autenticação, painel e shell com a main anterior; serviços do chat iguais ao piloto retestado. Defaults versionados de desenvolvimento desligados. A configuração temporária de export não foi commitada.
- CI do PR e validação repetida pelo Pages aprovados. Rollback do aplicativo conferido em checkout temporário.

[Registro estruturado](validation-0.8.3.json). Automação local e Web pública não foi reclassificada como teste físico; o reteste físico é o relato do usuário registrado acima. Consumo/faturamento permanece sem medição confirmada.

## Rollback

**Nota posterior à 0.9.0:** o procedimento histórico abaixo pressupõe os formatos
antigos. Para mundos v8, não volte apenas ao aplicativo 0.8.3/0.8.2; siga
[a recuperação compatível com v8](RECUPERACAO_0_9_0.md).

Versão oficial anterior: **0.8.2**, tag `v0.8.2`, commit `81aa0f96afe8aa0ded0a3d520183a332f05ea745`. O ponto anterior da main é `b94a68a` (somente documentação posterior ao jogo 0.8.2). A tag **`pages-before-0.8.3`** foi criada e enviada, apontando para o commit oficial 0.8.2. O manifesto anterior foi conferido antes da publicação.

Em checkout limpo, restaurar aplicativo/build/testes do ponto anterior, mantendo os registros de publicação e as regras atuais:

```powershell
git fetch origin --tags
git switch -c rollback/pages-0.8.3 origin/main
git restore --source=pages-before-0.8.3 --staged --worktree -- project.godot export_presets.cfg scripts scenes assets web config tools tests .github/workflows
git commit -m "Rollback Pages to 0.8.2; preserve Firebase and publication records"
git push -u origin rollback/pages-0.8.3
```

Abrir PR dessa branch para main, executar o CI e mesclar. O workflow volta a publicar o aplicativo 0.8.2 no **mesmo endereço**, com um novo SHA de rollback. Conferir `version.json`, hashes e login/armazenamento local após o deploy. A restauração dos caminhos acima foi validada em checkout temporário e coincide integralmente com a tag anterior nesses caminhos, preservando regras e documentação. Não fazer reset/force-push, deploy Firebase ou limpeza de dados do navegador/nuvem. O rollback do aplicativo mantém progresso, backups, regras, configurações administrativas e faturamento; saves têm o mesmo formato nas duas versões.
