# Integração 0.8.2 — 17/10/2026

Destino oficial: https://gustavotc-web.github.io/Tece-Island/
**Publicado: 0.8.2, deploy concluído com `success`.**
[Run oficial 38999412608](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/38999412608)
concluiu validação, exportação e deploy com sucesso em 17/10/2026.
O [manifesto servido](https://gustavotc-web.github.io/Tece-Island/version.json)
confirma versão `0.8.2`, commit `81aa0f9`, chat/sync habilitados para duas contas.
A verificação no endereço público confirmou o SHA-256 do PCK e passou em 11
checks no PC/mobile emulado, incluindo reload/armazenamento de dados próprios de
fixture. Não usou conta Firebase real nem dados de jogadores.

Integração na main: `81aa0f96afe8aa0ded0a3d520183a332f05ea745`, por meio do
[PR #2](https://github.com/GustavoTc-Web/Tece-Island/pull/2). O PR #1 foi marcado
como incorporado pelo GitHub. A árvore desse merge é idêntica à do candidato
`0419750`, aprovado no CI e nas verificações locais.

## Dependências e preservação

A main anterior é `e89b0ed9dfc1effc30e2712118a319b5da685b04`, publicada pelo
[run 38483914888](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/38483914888).
O PR #1 tem head `f2dd666f1d68726bf74e2a5e8f0dd4bc5b320923`; essa revisão já
é ancestral de `feat/global-chat-pilot`, head `465f8f6`.
O candidato foi construído a partir da main, mesclando primeiro os saves
(`2aee921`) e depois o chat (`4902a55`). Não houve conflito de integração.
Os arquivos de sincronização, catálogo, progresso, transporte e armazenamento
foram comparados integralmente com a base corrigida `f2dd666`.

`firestore.rules` inclui `allow create, update` do próprio `chatProfiles/{uid}`,
exigindo acesso ao piloto, UID autenticado, esquema exato e apelido válido.
Excluir/listar perfis e editar perfil alheio continuam proibidos. As regras
dos mundos são idênticas à base dos saves: revisão consecutiva, snapshots
completos e proteção das versões atual/anterior, com isolamento por UID e
e-mail verificado. O deploy Web não executa nenhum comando Firebase.

Validação local sobre a árvore integrada: **155 checks de saves, 21 subtestes
de regras (incluem 12 checks REST nativos dos saves), 44 de chat Web, 12 de
persistência Web, 9 de chat nativo, 7 de controles e 11 do build Web**, sem falhas.
O CI do PR #2 passou; o Pages repetiu saves e regras combinadas antes de exportar.
Recebimento no emulador nesta execução: 1,883–5,333 s; retorno da aba simulada,
0,658 s; remoção administrativa no outro painel, 119,120 s. São medidas locais,
não uma distribuição estatística ou medição de latência móvel/Firebase real.
[Resumo sanitizado](validation-0.8.2.json).

Não se troca o endereço, nome do banco IndexedDB, chaves de armazenamento ou
formato dos saves nesta preparação. Não limpar dados do navegador ou apagar
backups para atualizar. A cópia aberta no IDE foi preservada em sua branch;
a integração usa checkout isolado em `.tools/main-integration`.

## Configuração de publicação

O workflow Pages agora exige aprovação automática das suítes de saves e
regras combinadas antes de exportar. `configure-release-access.mjs` exige
exatamente dois UIDs distintos na variável `TECE_PILOT_ALLOWED_UIDS`, reutilizados
do piloto anterior, sem ampliar a lista. Ausência/lista inválida aborta o build.
Chat **e sincronização** ficam restritos às mesmas duas contas; o backend
`chatSettings/global` conserva sua lista e administradores atuais.
Os padrões versionados de desenvolvimento continuam desligados.

O build gera `version.json`, com versão/commit, quantidade de contas e hashes
dos arquivos do jogo, sem publicar a lista de UIDs nesse manifesto. O backend
continua sendo a autoridade, independentemente da configuração do cliente.
Não há alteração de faturamento, Functions, TTL, índices ou documentos Firebase.

## Resultados manuais informados pelo responsável

Em 17/10/2026, o responsável confirmou:

- Atualizou as regras e conseguiu salvar o novo apelido.
- No piloto .3, mensagens PC → celular e celular → PC funcionaram no lobby e na
  partida, com ambos os painéis abertos por pelo menos 30 s, sem reabrir/atualizar.
- Relatou que aparentemente todos os casos consultados de sincronização passaram:
  PC → celular → PC sem falso conflito, reabrir navegador preservando o mundo
  e troca de conta sem listar mundos de outro UID.

São resultados relatados, sem observação independente do assistente. Resolvem
as pendências manuais indispensáveis apontadas para este rollout de duas contas.
Não equivalem à aprovação de todos os roteiros antigos. Permanecem sem confirmação
separada teclado Android/iOS real, rede interrompida durante envio, ambas as
escolhas de conflito real, migração/recuperação de cópias antigas, teste TLS nativo
positivo e moderação real. Continuam pendentes; não foram declarados aprovados.

## Consumo

O algoritmo do chat não mudou: contador a cada 5 s após terminar o ciclo,
reconciliação de até 50 mensagens/perfil/configuração a cada 120 s, pausa quando
painel fechado/aba oculta e backoff de erros. Continua válida a estimativa
ociosa de **aproximadamente 3.100 leituras por cliente/hora**, com janela cheia
e reserva de uma leitura de autorização por pedido: 720 de contador + 1.500 de
histórico + 60 de perfil/configuração + cerca de 810 dependentes = 3.090/h.
Dois clientes por duas horas: aproximadamente 12.400 leituras, sem saves/envios.
É estimativa, não medição de cobrança; o total cresce com mensagens, reconexões
e sincronizações de mundos. Cada envio grava três documentos e cada renomeação,
um. Cotas são compartilhadas com os saves. Plano de faturamento não foi alterado.
Fontes: [preços](https://firebase.google.com/docs/firestore/pricing) e
[cotas](https://firebase.google.com/docs/firestore/quotas).

## Como reverter

Não reverter regras Firebase ou apagar documentos/IndexedDB para reverter o jogo.
O commit público anterior é `e89b0ed`. O artefato desse run expirou; antes da
publicação foi preparado um backup dos arquivos estáticos públicos em
`build/rollback/public-e89b0ed/`, com hashes em `rollback-manifest.json`.

Existe também a tag `pages-before-0.8.2`, apontando para `e89b0ed`. Para reverter
via Git, em um checkout limpo, criar uma nova branch a partir da main e executar:

```powershell
git fetch origin
git switch -c rollback/pages-0.8.2 origin/main
git restore --source=pages-before-0.8.2 --staged --worktree -- project.godot export_presets.cfg scripts scenes assets web config tools tests .github/workflows
git commit -m "Rollback Web to pre-0.8.2; preserve Firebase protections"
git push -u origin rollback/pages-0.8.2
```

Essa restauração atua somente no aplicativo e seus workflows; mantém as regras
Firebase, índices e relatórios versionados. Revisar/exportar e mesclar esse
rollback na main. O workflow anterior volta a publicar o jogo antigo no mesmo
endereço, preservando as regras versionadas.
Não executar deploy Firebase, reset/force-push ou remoção de dados para isso.

O jogo antigo pode não listar mundos criados no catálogo novo. Isso não significa
que foram apagados: manter dados, backups e nuvem intactos para recuperação ou
republicação da 0.8.2. A reversão muda o aplicativo servido, não desfaz o progresso.
