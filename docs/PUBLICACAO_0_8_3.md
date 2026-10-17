# Publicação 0.8.3 — otimização do chat

Endereço oficial preservado: https://gustavotc-web.github.io/Tece-Island/

Candidato integrado a partir da main `b94a68a`, mesclando `perf/chat-read-budget` (`988530f`) sem conflitos. Preparação da versão 0.8.3 e validação sobre a árvore integrada antes de atualizar a main remota. O resultado final do deploy será registrado ao concluir.

## Escopo e proteções

O código do chat é idêntico ao piloto retestado: consultas incrementais, contagem de janela para remoções a cada 120 s, poll de 5 s em atividade / 15 s após 60 s ocioso, backoff e um pedido por sessão. Renomeação, mutes e administração por UID preservados. Saves, backups, conflitos, isolamento por UID, autenticação, regras Firestore e shell do jogo não mudam em relação à main 0.8.2.

O workflow Pages conserva a validação de saves/regras antes do export e exige exatamente os dois UIDs já configurados em `TECE_PILOT_ALLOWED_UIDS`. Conferir a igualdade dessa variável com o pacote privado retestado sem imprimir os UIDs. Nenhuma variável, documento, regra, índice ou configuração de faturamento Firebase deve ser alterada. Defaults de desenvolvimento continuam desligados; o build oficial habilita chat e sync somente para as duas contas.

`version.json` identifica versão, commit, estratégia/intervalos e hashes dos três arquivos do pacote, das regras **do código-fonte** e dos arquivos principais de saves/chat. Hash de regras no manifesto não afirma que o estado remoto foi lido/deployado.

## Evidência manual e consumo

**Reteste manual relatado pelo usuário**, em 17/10/2026: “Concluí o reteste físico do 0.8.2-chat-budget-pilot.1 e não encontrei novos problemas.” O usuário autorizou integração e publicação. Não houve observação independente pelo assistente, nem detalhes separados de dispositivo/caso. Esse relato conclui o reteste do piloto para este rollout; não reclassifica a automação histórica como teste físico.

Consumo continua sendo **estimativa**, não medição de faturamento: aproximadamente 660 leituras/cliente/h em regime ocioso estável, 730 na primeira hora incluindo abertura, e 1.620/h de recepção ativa antes dos envios. Inclui reserva para leituras das regras. A amostra HTTP do piloto (135 s) observou 28 → 19 pedidos e estima 105 → 38 leituras incluindo regras; não é uma amostra de cobrança. Projeções de grupos e capacidade reservada aos saves em [CHAT-BUDGET-PILOT.md](CHAT-BUDGET-PILOT.md).

## Validação da versão integrada

Registrar abaixo os resultados executados nesta integração, separadamente dos resultados anteriores do piloto. Conferir igualdade integral das regras e dos arquivos de saves com a main anterior e do chat com o piloto.

## Rollback

Versão oficial anterior: **0.8.2**, tag `v0.8.2`, commit `81aa0f96afe8aa0ded0a3d520183a332f05ea745`. O ponto anterior da main é `b94a68a` (somente documentação posterior ao jogo 0.8.2). Preparar também a tag `pages-before-0.8.3` antes de publicar.

Após o merge, registrar o SHA real no comando abaixo. Em checkout limpo:

```powershell
git fetch origin --tags
git switch -c rollback/pages-0.8.3 origin/main
git revert -m 1 MERGE_COMMIT_0_8_3
git push -u origin rollback/pages-0.8.3
```

Abrir PR dessa branch para main, executar o CI e mesclar. O workflow volta a publicar o aplicativo 0.8.2 no **mesmo endereço**, com um novo SHA de rollback. Conferir `version.json`, hashes e login/armazenamento local após o deploy. Não fazer reset/force-push, deploy Firebase ou limpeza de dados do navegador/nuvem. O rollback do aplicativo mantém progresso, backups, regras, configurações administrativas e faturamento; saves têm o mesmo formato nas duas versões.
