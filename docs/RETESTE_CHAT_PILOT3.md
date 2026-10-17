# Reteste — 0.8.2-chat-pilot.3

Branch `feat/global-chat-pilot`, continuação do `0.8.2-chat-pilot.2`.
Piloto: https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/
Publicação e commits: [registro](PUBLICACAO_CHAT.md).

## Alterações

**Alterar apelido** aparece junto de **Apelido atual**. O formulário traz o nome
atual e **Salvar/Cancelar**. Mantém 2–20 caracteres e o mesmo conjunto de letras,
números, espaços internos, `_` e hífen. Cancelar, receber mensagens e atualizar o
histórico preservam o rascunho. O perfil é gravado no Firestore por UID; outras
sessões leem o perfil na entrada, na reconciliação e antes de cada envio.
Mensagens anteriores mantêm o apelido original. Silenciamento, autoria e cargo
administrativo continuam por UID; nome igual ao de um admin não concede cargo.

Um único Timer do serviço e seus HTTPRequests processam também durante a pausa.
Com painel aberto e aba visível, leem `chatRuntime/global` a cada 5 s **após a
conclusão** do ciclo anterior. Só consultam mensagens se a sequência mudar; a
cada 120 s reconciliam as últimas 50, perfil e permissões. Um erro 400/412/500 na
consulta incremental provoca uma única tentativa pelo histórico limitado.
O diagnóstico permanece visível até uma consulta incremental funcionar.
Nenhum listener/SDK adicional foi instalado. Ler, enviar, renomear e remover
compartilham a exclusão de operações; nenhum pedido do chat fica em paralelo
na mesma sessão. Abrir/recolher não cria timers ou assinaturas.

`visibilitychange`, `pageshow`, `focus` e `online` acordam o mesmo agendador,
coalescendo eventos. Aba oculta e painel fechado suspendem novas consultas.
Logout cancela pedidos e invalida respostas pela geração da sessão, inclusive
ao entrar novamente no mesmo UID. Falhas usam espera de 10 até 240 s; eventos
de foco não contornam espera por cota/permissão. Não há reenvio automático de
mensagem cuja confirmação seja incerta.

Quem está no fim acompanha novas mensagens. Quem lê o histórico mantém uma
âncora da mensagem visível e recebe **N novas mensagens · Ver**. Se a mensagem
sair da janela de 50, só é possível manter a posição dentro do histórico retido.

## Investigação e limites da evidência

O responsável confirmou envio e visualização entre PC e celular no piloto .2,
mas encontrou apelido imutável e recebimento apenas ao reabrir, nos dois lados.
A imutabilidade foi confirmada no código e nas regras. O botão **Tentar conexão**
era incondicional e sua presença sozinha não comprovava uma falha.

A tentativa de reprodução no transporte REST/emulador da implementação anterior
manteve ambos os painéis abertos por 18 s no lobby e mais 18 s com a partida
pausada: o polling funcionou nesse ambiente. Portanto, **a causa específica do
problema no Firebase real não foi comprovada**. Os testes anteriores forçavam o
poll e não demonstravam o prazo natural. O .3 reforça o ciclo e passa a mostrar
estado/última atualização e códigos sanitizados de serviço/HTTP, sem expor tokens
ou UIDs. O botão de conexão só aparece com falha; o restabelecimento é automático.
O teste com consulta incremental recusada é uma falha injetada, não evidência de
que esse era o erro do backend real.

## Firebase — atualização necessária das regras

Não foi feito deploy no Firebase real. Entrega completa de referência:
[`firestore.rules`](../firestore.rules), incluindo os saves e todo o chat.
O diff do arquivo se limita a duas linhas em `chatProfiles/{uid}`: permitir
`create, update` com as mesmas validações e negar `delete, list`.
O restante foi comparado integralmente com a versão anterior. Os saves também
foram comparados à base corrigida `f2dd666`.

**Não recriar nem substituir `chatSettings/global`**: preservar `enabled`,
`allowed_uids` e `admin_uids` atuais. Nenhum comando abaixo escreve documentos,
índices, Auth, Hosting ou saves. Manter o plano Spark existente.

1. No projeto **tece-island-285cd**, Firestore Database → Rules, copiar o
   conteúdo atualmente publicado para `.tools/regras-publicadas.rules` em UTF-8.
   Guardar essa cópia para comparação/rollback.
2. Preparar as **regras completas**, preservando byte a byte tudo fora do bloco
   conhecido de perfil:

   ```powershell
   node tools/prepare-chat-profile-update.mjs --base .tools/regras-publicadas.rules
   git diff --no-index -- .tools/regras-publicadas.rules .tools/chat-profile-update/firestore.rules
   ```

   O `git diff --no-index` retorna 1 quando existem diferenças, o que é esperado.
   Só devem mudar as duas linhas descritas. Se o preparador recusar uma base
   personalizada, parar e revisar essa base; não sobrescrevê-la com outra.
3. Publicar o conteúdo **inteiro** de
   `.tools/chat-profile-update/firestore.rules` na aba Rules → Publish.
   Alternativa, com Firebase CLI já autenticada:

   ```powershell
   npx firebase deploy --project tece-island-285cd --config .tools/chat-profile-update/firebase.json --only firestore:rules
   ```

4. Aguardar propagação, manter as duas contas verificadas já autorizadas, e
   retestar o piloto .3. Não apagar/criar manualmente perfis, contador ou rate.
   As mensagens usam o índice simples **sequence / Descending / Collection**
   de `globalMessages`; não é necessário índice composto. Se houver um erro de
   índice, conferir a configuração atual no Console antes de alterá-la. Não
   publicar `firestore.indexes.json` inteiro sobre índices personalizados.
5. Rollback, se necessário: republicar somente a cópia integral do passo 1.
   Isso volta a bloquear renomeações; não elimina perfis ou mensagens existentes.

O pacote inclui regras completas preparadas contra a base local conhecida.
Essa base local não é prova do conteúdo hoje publicado no Firebase.

## Latência e consumo

Resultados numéricos da execução atual ficam registrados na
[validação](VALIDACAO_CHAT.md). São Godot Web/Edge e emulador local, com viewport
mobile emulado. Não são medidas de internet móvel ou do Firebase de produção.
O alvo saudável é cerca de 0–5,5 s mais tempo de rede; remoções, até 120 s mais
tempo de consulta. Rede lenta e backoff ampliam os prazos.

Estimativa conservadora por cliente/hora, painel continuamente aberto e visível,
histórico cheio e ocioso: até 720 leituras de contador + 30 × 50 de reconciliação
+ 60 de perfil/configuração = **2.280 leituras diretas/h**. Reservando uma leitura
dependente de autorização por pedido: aproximadamente **3.100 leituras/h**.
Com histórico vazio, cerca de 1.620/h nessa mesma reserva. Inicialização custa
até aproximadamente 62 leituras com janela cheia. Dois clientes ociosos por
duas horas: aproximadamente **12.400 leituras**, fora saves e tráfego de mensagens.
Como o intervalo é contado após o término do pedido, o total real tende a ser menor.

Cada renomeação confirmada grava 1 documento; enviar grava 3. Cada envio ainda
lê perfil e contador e reconcilia o remetente (até 50 mensagens + metadados),
além das leituras dependentes das regras; destinatários consultam só as novas.
Uma falha incremental pode acrescentar uma consulta de até 50. A reconciliação
continua limitada a uma por 120 s, salvo envio, retorno de um ciclo atrasado ou
fallback de erro. Painel fechado/aba oculta: zero novos ciclos de polling;
um pedido já iniciado pode terminar.

São estimativas, não medição de cobrança. As cotas do projeto são compartilhadas
com os saves: 50 mil leituras e 20 mil escritas/dia no nível gratuito. Acompanhar
Usage e usar sessões curtas de reteste; não habilitar faturamento.
Fontes: [preços e leituras dependentes](https://firebase.google.com/docs/firestore/pricing),
[cotas](https://firebase.google.com/docs/firestore/quotas) e
[condições das regras](https://firebase.google.com/docs/firestore/security/rules-conditions).

## Roteiro físico ainda pendente

1. No link privado, PC na conta A e celular na B. Confirmar versão .3, manter
   ambos os chats abertos por ao menos 30 s e enviar nas duas direções, no lobby
   e na partida. Registrar latência e qualquer código de erro exibido.
2. Alterar “Testando”, cancelar uma edição, salvar outra. Sair/entrar e conferir
   o nome em ambos os aparelhos na mesma conta. Mensagens antigas podem manter
   “Testando”. Outro UID não pode editar o perfil (recusa automatizada no emulador).
3. Deixar um rascunho e ler mensagens anteriores; receber sem perder texto ou
   posição e usar o aviso para ir ao fim. No fim, conferir acompanhamento automático.
4. Android/iOS: abrir teclado real, editar/colar/enviar por botão e tecla de envio,
   recolher e retomar controles. Girar tela e verificar nome, Salvar e Cancelar.
5. Retirar rede, manter rascunho, retornar à aba e restabelecer rede. Aguardar
   reconexão sem reabrir chat. Conferir histórico antes de repetir envio incerto.
6. Silenciar B, renomear B e enviar: continuar oculto por UID. Reativar. Com um
   UID já configurado como admin, remover e esperar até 120 s no outro painel.
   Usuário comum não pode remover ou se promover por escolher outro apelido.
7. Continuam pendentes os testes de saves antes registrados: reteste do falso
   conflito, reabrir navegador e isolamento real entre contas.

## Publicação definitiva

O endereço oficial continua **https://gustavotc-web.github.io/Tece-Island/**.
Não houve merge na main nem disparo manual do Pages. O workflow existente
continua publicando somente main/execução manual, com caminhos relativos sob
`/Tece-Island/`. O padrão do código mantém chat/sync desligados; o piloto isolado
habilita somente os dois UIDs anteriores. Após reteste físico, revisar a
dependência do PR de saves e definir a liberação de UIDs/configuração antes de
mesclar. A publicação do piloto .3 antecede essa decisão.
