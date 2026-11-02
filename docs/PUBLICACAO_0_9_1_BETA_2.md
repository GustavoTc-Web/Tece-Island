# Publicação 0.9.1-beta.2 — backup por conta e arrasto por toque

[Jogar no endereço oficial](https://gustavotc-web.github.io/Tece-Island/).
Tag preparada: **v0.9.1-beta.2**. Autorização e preparação em **02/11/2026 BRT**.
O resultado do deploy será registrado após a conferência do pacote servido.

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

Nesta promoção serão conferidos os testes afetados e o CI obrigatório, o pacote
Web com as mesmas restrições, manifesto, hashes e carregamento inicial público.
Integração em checkout isolado, sem checkout/stash/reset no diretório do IDE.
O pacote de recuperação do aplicativo v9 será preservado como asset da release,
sem dados de jogadores. Commit, tag, workflow, hashes e limites serão registrados
abaixo após concluir; não será presumida autenticação real ou teste físico.
