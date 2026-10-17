# Publicação privada do chat e sincronização

## Revisão .3 — publicada em 16/10/2026

**0.8.2-chat-pilot.3**, publicada pelo Sites às **16h07 (Brasília)**, estado
`succeeded`, versão da hospedagem **4**. Mesmo endereço:
https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/
A audiência foi relida após o deploy: `custom`, somente o proprietário, sem
convites ou alterações de acesso. Usar a mesma conta ChatGPT nos dois aparelhos.
Recarregar o jogo para atualizar; preservar os dados do navegador/IndexedDB.

- Commit do jogo enviado ao GitHub: `f7e7bd2cbedea04efca593d6b372e2519b10a545`.
- Commit do pacote de hospedagem: `cad22d2fcb8bbaf5d58e160e56d620d11ad102ab`.
- Deployment: `appgdep_6ad275d9189481918938e9c1bb2f4a4b`.
- Versão Sites: `appgprj_6ad0212da2388191920d282fd2dd7f32~appgver_0ebe3c7ca0b4819188b927dbae56a530`.
- Arquivo portátil: `build/tece-island-0.8.2-chat-pilot.3.zip`, incluindo projeto
  nativo, Web, regras completas e roteiro. Compilação real sem fixture,
  `working_tree:false`, mesmos dois UIDs, chat e sync ativos só no pacote privado.

Validação: 44 checks Web, 9 de transporte nativo, 21 subtestes de regras (incluem
12 checks REST dos saves), 155 verificações de saves, 7 de controles e 11 do pacote
final aprovados. Mensagens no emulador: 1,000–5,214 s; exclusão automática no outro
painel: 118,986 s. [Evidências e limites](VALIDACAO_CHAT.md).
Leitura autenticada da hospedagem confirmou o manifesto .3/commit `f7e7bd2`,
os mesmos dois UIDs, sync ativo e o **SHA-256 do index.pck idêntico ao exportado**.
Essa leitura confirma o pacote entregue; não é login ou teste no Firebase real.

**Firebase real não foi atualizado.** Aplicar somente as duas linhas de regras
de perfil sobre a base exportada atual. **Preservar `chatSettings/global` e os
saves**, sem recriar documentos. [Regras completas e passos exatos](RETESTE_CHAT_PILOT3.md).
O .3 exibe acesso negado se a regra antiga ainda bloquear update do perfil.
A causa específica da falha de recebimento relatada no .2 não foi reproduzida
no emulador; o novo ciclo e a recuperação de falhas precisam do reteste real.

Não houve merge na main nem publicação definitiva no GitHub Pages. O endereço
oficial continua `https://gustavotc-web.github.io/Tece-Island/`. O caminho de
publicação está documentado no roteiro; aguarda reteste físico e decisão posterior.

## Histórico da publicação .2

URL: https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/

Publicação confirmada pelo Sites em **15/10/2026 às 19h04 (Brasília)**,
estado `succeeded`, versão **3**. O acesso continua privado, somente ao
proprietário da hospedagem. Abra com a mesma conta ChatGPT no PC e no celular;
dentro do jogo, use as duas contas Firebase do piloto. Nenhum convite ou mudança
de audiência foi realizado. O endereço reutiliza a origem do piloto anterior:
não limpe seus dados do navegador/IndexedDB para atualizar o jogo.

- Jogo: `0.8.2-chat-pilot.2`, commit `d97abc14832905847c9d3207c54e8631cb8e0c46`.
- Base do chat: `7300d24`; inclui o código corrigido de `0.8.1-sync-pilot.2`.
- Pacote da hospedagem: `ddeccb6762b97ecb9e87f2c1d550e617396c73fa`.
- Deployment: `appgdep_6ad14dc650a88191a061ae0be5b28731`.
- A branch `feat/global-chat-pilot` foi enviada ao GitHub. Não foi criado merge.
  PR #1 continua aberto, na branch de saves `f2dd666`; `main` permanece `e89b0ed`.
  O workflow de GitHub Pages só publica em push na main e não foi disparado.

## Backend pendente

**A hospedagem está pronta, mas o chat depende da configuração manual no Firebase.**
O assistente não publicou regras, não escreveu documentos e não alterou faturamento.
Projeto: `tece-island-285cd`, banco `(default)`. Manter Spark e nenhum vínculo novo
de Cloud Billing, Functions, SMS, TTL, backup gerenciado ou outro serviço pago.

1. Em Firestore Database → Rules, guardar uma cópia das regras atuais e publicar
   o conteúdo completo de `firestore.rules` da branch do chat. Inclui saves e chat;
   não substituir por regras que contenham só o chat. O arquivo exato está também
   em `.tools/chat-backend/firestore.rules` e foi entregue integralmente na resposta.
2. Em Firestore Database → Data, criar coleção `chatSettings`, documento `global`,
   com estes campos: `enabled` do tipo boolean, valor `true`; `allowed_uids` do tipo
   array, com as duas strings de UID já usadas no piloto anterior; `admin_uids` do
   tipo array, inicialmente vazio. Os valores exatos reutilizados estão em
   `.tools/chat-backend/chat-settings.json` e na resposta. Não usar e-mails.
3. Para testar moderação, incluir em `admin_uids` somente o UID da conta escolhida,
   que deve continuar em `allowed_uids`. Sair e entrar novamente nessa conta para
   o botão Remover ser atualizado. Alterações devem ser feitas por quem tem
   permissão administrativa no Console; o jogo não pode editar esse documento.
4. Em Authentication → Users, confirmar que ambos os UIDs correspondem às contas
   de teste e têm e-mail verificado. Entrar novamente no jogo para usar token atual.
5. Não criar `chatRuntime`, `chatProfiles`, `chatRates` ou `globalMessages`
   manualmente. O cliente cria os documentos permitidos pelas regras. Nenhum índice
   composto é necessário; `sequence` usa o índice simples padrão.
6. Para interromper o chat no backend, definir `chatSettings/global.enabled=false`.
   Isso não altera os saves ou as regras de acesso aos mundos.

`allow list, write: if false` em `chatSettings/global` impede que qualquer cliente,
inclusive um administrador do chat, conceda acesso ou cargo. Leitura e envio do
chat exigem UID presente na lista e e-mail verificado no token validado pelo Firebase.
Só `admin_uids` pode remover mensagens; esse cargo não concede acesso a mundos alheios.

## Preservação e verificações

O bloco de regras dos mundos foi comparado integralmente com `f2dd666` e não mudou.
O pacote também conserva, com comparação de conteúdo e SHA-256, os arquivos de
sincronização, transporte Firestore, conta, catálogo de mundos, validação e gravação
dos saves. Isso inclui a correção de avanço exclusivo da nuvem e limpeza do falso
conflito, backups, revisões consecutivas, referência ao snapshot anterior e
precondições `updateTime` do cliente. Versão atual e anterior não podem ser removidas
pelo cliente nas regras. O chat usa coleções e transporte separados.

`tools/verify-chat-pilot.mjs` confirmou que os dois conjuntos de UIDs do pacote são
exatamente os do piloto anterior, chat e sincronização estão ligados só no pacote
privado e os padrões do projeto principal continuam desligados. O manifesto
`/Tece-Island/pilot-build.json` acompanha a publicação para identificar essa compilação.
Uma leitura autenticada desse manifesto na hospedagem privada confirmou a versão,
o commit `d97abc1`, as duas contas, a sincronização ativa e a base corrigida.
Essa leitura não autentica usuários Firebase nem testa o envio real de mensagens.

Nesta continuação passaram novamente:

- 155 verificações automatizadas de saves, incluindo os 14 casos de handoff/conflito.
- 20 subtestes de regras no Firestore Emulator, incluindo mundos, limite, autoria,
  autorização do piloto e moderação; também 12 verificações REST nativas dos saves.
- 11 verificações do pacote final no Edge: PC e mobile emulado, engine dividido em
  partes e validado por hash, formulário, falha de rede sem perda de bytes locais,
  reload e rejeição de download incompleto. Não usaram login Firebase positivo.

A implementação inicial já tinha 23 verificações Web do chat, 6 do transporte
nativo e 7 de controles aprovadas: [relatório anterior](VALIDACAO_CHAT.md).
As regras do Firebase real e o diálogo entre as duas contas reais ainda dependem
da configuração e dos resultados do responsável. Publicação não é aprovação física.

## Roteiro curto

1. PC na conta Firebase A, celular na B, ambos nesse link privado. Abrir Chat,
   definir apelidos e trocar mensagens nas duas direções. Recebimento em até 15 s,
   máximo de 200 caracteres e intervalo mínimo de 5 s por UID, inclusive entre abas.
2. Durante uma partida no celular, tocar no campo, escrever, colar e enviar pelo
   botão e pelo teclado. Confirmar que não houve movimento, ataque ou abertura de
   inventário. Recolher o painel e verificar que os controles voltam normalmente.
3. Silenciar B em A: as mensagens de B devem desaparecer só nessa conta/aparelho.
   Reativar. Com a conta escolhida como admin, remover uma mensagem; outra sessão
   deve reconciliar em até 120 s. Conta comum não pode remover ou se promover.
4. Para sincronização, usar a mesma conta Firebase nos dois aparelhos. Em um mundo
   de teste, salvar/sincronizar no PC, voltar ao lobby, abrir no celular, alterar e
   salvar/sincronizar, voltar ao lobby e conferir no PC o mesmo ID/revisão/itens/posição.
   Fechar/reabrir e repetir. Para isolamento, sair e entrar na outra conta: ela não
   deve listar os mundos da primeira. A conversa global é compartilhada; mundos não.

O teste físico PC → celular → PC já preservou posição e itens, conforme relato
anterior. Continuam **sem aprovação** o reteste da correção do falso conflito,
fechar/reabrir navegador e isolamento entre contas reais. Testes físicos de chat e
teclado Android/iOS também aguardam o responsável informar os resultados.
