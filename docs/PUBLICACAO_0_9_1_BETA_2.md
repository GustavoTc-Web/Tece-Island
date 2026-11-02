# Publicação 0.9.1-beta.2 — backup por conta e arrasto por toque

[Jogar no endereço oficial](https://gustavotc-web.github.io/Tece-Island/).
Tag: **v0.9.1-beta.2**. Autorização e publicação em **02/11/2026 BRT**.
Workflow concluído com sucesso às **12:34:42 BRT**; arquivos públicos conferidos.

## Aprovação e escopo

Promoção da candidata **0.9.1-beta.2-rc.1**, jogo aprovado
`2738a9f49fb5d390fdb6bbcfec06e2af54aeb358`, registros
`0edc372942e741c567c03b0d091be9c2350bc7ea`, branch `release/solo-beta.2-rc.1`.
Após o jogo congelado, a branch acrescenta apenas registros e evidências.
Na preparação pública, os únicos arquivos de runtime alterados recebem a
substituição do rótulo da versão. Metadados, documentação e verificadores são
alinhados à publicação, sem novas funcionalidades ou ajustes de campanha.

O usuário informou: **“Testei a candidata 0.9.1-beta.2-rc.1 e os ajustes
funcionaram aqui.”** Registrado como **reteste manual relatado pelo usuário**.
Não houve observação independente nem confirmação específica de aparelhos,
áudio, suspensão, todos os cenários ou campanha completa. A campanha exploratória
pelo controlador permanece não executada por limitação da ferramenta.

## Correções incluídas

- **Exportar backup dos meus mundos:** sessão atual obrigatória, chave e dono
  conferidos, campos reconhecidos, referências do catálogo respaldadas por
  cópias próprias. Inclui mundos, backups e metadados compatíveis; exclui dados
  de outras contas, registros desconhecidos/ilegíveis/sem proprietário e
  credenciais. O arquivo contém progresso e nomes definidos pelo jogador e é
  um backup privado. Os registros excluídos continuam intactos no navegador.
- **Arrasto por toque no inventário:** espera de 350 ms, prévia e destaque,
  movimento/troca da pilha inteira e cancelamento seguro. Deslizar antes da espera
  rola o painel. Mouse e Mover/trocar são preservados, assim como atributos,
  equipamento, seleção, barra rápida e persistência após reabrir.

Detalhes, critérios, recuperação de excluídos e evidências:
[registro da candidata](BETA_2_RC1_BACKUP_TOQUE.md). As branches de exportação e
toque permanecem preservadas separadamente. Relógio, encontros, receitas, combate,
condições de vitória e demais mecânicas não foram modificados nesta promoção.

## Preservação e compatibilidade

Save **v9**, campanha **v2**, tarefas **v2**, com os mesmos bancos, chaves e origem.
Não há nova migração de formato. As proteções de propriedade, backups e conflitos
continuam em vigor. Todos os testes novos usam cópias/perfis descartáveis;
saves reais e arquivos abertos no IDE não são usados para testes destrutivos.

Recuperação exige cliente **compatível com v9** no mesmo endereço/origem.
**0.9.0 não abre v9.** Não limpar IndexedDB nem editar a versão do save. Registros
ilegíveis/legados excluídos do backup normal não foram apagados e requerem
recuperação técnica identificando o proprietário, sem reatribuição automática.
[Procedimento](RECUPERACAO_BETA_V9.md), [dados excluídos](RECUPERAR_MUNDO.md).

As mesmas duas contas de chat/sync e intervalo de 120 s são mantidos. Novas contas
verificadas podem jogar solo local, mas a abertura de chat/sync continua separada.
Nenhuma regra, usuário, administrador, dado, configuração ou faturamento Firebase
é alterado pelo workflow Pages. Multiplayer continua adiado em sua branch.

## Verificações e publicação

Reaproveitadas as evidências válidas da candidata: **211 checks Godot**, oito
testes de configuração, **27 checks Web de backup** e **23 de inventário**.
São automações com dados preparados, Auth simulado e toque emulado; não equivalem
a campanha humana. A limitação de autorização dos AudioWorklets no Site privado
não foi tratada como aprovação de áudio; a conferência do endereço oficial será
registrada separadamente.

Integração em checkout isolado, sem checkout/stash/reset no diretório do IDE.
Commit publicado: **`ed840cbd11e23b98d9fce66944e08a2022bb820a`**, merge da
preparação `30226c5` com a main. A tag **v0.9.1-beta.2** aponta para esse merge.
Registros posteriores alteram apenas documentação e não reexportam o jogo.
[Workflow 41472352111](https://github.com/GustavoTc-Web/Tece-Island/actions/runs/41472352111):
validação, exportação e deploy **success**.

O CI passou **704 checks Godot em 25 suítes**, **23 testes de regras** sem skips,
**11 checks de chat REST nativo** e **oito testes de configuração**. O backend de
teste foi o emulador local Auth/Firestore; nenhuma regra foi aplicada em produção.
Os testes locais afetados tiveram 89 checks aprovados em cinco suítes, além dos
oito testes de configuração. Eles se sobrepõem ao CI e não são somados como novos
casos independentes.

No endereço oficial foram conferidos manifesto, **16 arquivos** por SHA-256 contra
o artefato exato do Pages e os **38 hashes de fontes** contra o commit publicado.
PCK servido: `3a8621ed0de7c60535079273e3ad895b564c76b4a1de8d61d9ff33a4a2f5d51e`.
O PCK baixado abriu isoladamente com versão/commit/schema corretos, os mesmos dois
UIDs, as duas correções e ausência de fixtures/regras administrativas. As variáveis
GitHub conservaram o mesmo digest antes/depois.

O cliente servido passou novamente em **27 checks Web de backup**, com duas
identidades sintéticas no mesmo perfil e Auth interceptado somente no navegador.
Cada conta exportou seus registros, incluindo backups reconhecidos, sem dados
estrangeiros ou credenciais; a cópia baixada foi restaurada em outro perfil e
aberta pelo cliente v9, preservando inventário, atributos, seleção e campanha.
Não houve criação/login real ou tráfego Firebase de produção nesses testes.

O carregamento inicial público foi conferido em Edge headless PC/mobile emulados,
com recusa de exportação sem login e sem erros JavaScript, GDScript ou HTTP
observados. Ambos os arquivos AudioWorklet tiveram bytes/HTTP conferidos no pacote
público; o 401 observado na checagem autorizada por cabeçalho do Site privado não
foi reproduzido nesta conferência pública. Isso não é aprovação física de áudio,
desempenho ou suspensão. [Evidências e capturas](validation/beta.2-public/publication.json).

[Release e recuperação](https://github.com/GustavoTc-Web/Tece-Island/releases/tag/v0.9.1-beta.2):
`tece-island-0.9.1-beta.2-web-recovery.tar.gz`, com os 16 arquivos do aplicativo e
sem saves de jogadores. Upload e download público conferidos. SHA-256:
`2c489501f94774938e1c27ee8df51fcbd0a2dd6c7266ba0cb3d0968e68f50097`.
Nenhum rollback foi acionado.

**Sem bloqueio técnico de publicação conhecido.** O relato manual confirma os
ajustes aprovados; campanha completa, exploração pelo controlador e casos físicos
não especificados permanecem sem nova aprovação. Chat/sync continuam nas duas
contas atuais; multiplayer permanece adiado. Saves reais, alteração local do IDE,
Firebase e faturamento foram preservados.
