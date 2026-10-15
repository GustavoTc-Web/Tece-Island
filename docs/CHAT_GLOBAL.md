# Chat global — 0.8.2-chat-pilot.1

Primeira versão preparada na branch `feat/global-chat-pilot`. **Não publicada,
não integrada à main e desativada no projeto principal.** Nenhuma configuração
remota ou de faturamento foi alterada. O pacote real está em `build/chat-pilot/`;
o projeto de desenvolvimento nativo usa `.tools/chat-pilot-project/project.godot`.
Não há servidor multiplayer novo nesta entrega.
O pacote portátil reúne Web, projeto nativo, capturas e arquivos pendentes do
backend em `build/tece-island-0.8.2-chat-pilot.1.zip`.

## Dependência e preservação dos saves

A branch parte de `f2dd666`, na branch `fix/reliable-saves-world-sync` do PR #1.
Reutiliza a sessão verificada e os componentes desse trabalho. Portanto, um PR
de chat deve indicar essa dependência e comparar com a branch de saves, sem
mesclar ou alterar o PR #1. O estado inicial do Git estava limpo.

As políticas `/users/{uid}/worlds/...` permaneceram iguais. O chat tem coleções,
transporte e estado próprios. Não participa da fila de salvamento e uma falha
do serviço não bloqueia jogar, salvar localmente ou sair da partida. O painel
pausa a simulação solo pelos mecanismos já existentes e bloqueia entradas até
ser recolhido. A exportação do piloto mantém a sincronização de mundos desativada.
Essa escolha evita que este teste publique progresso de mundos durante a
validação separada dos saves. O código de saves continua na base da branch.

O teste físico PC → celular → PC já preservou posição e itens, conforme relato
do responsável. **Continuam pendentes** o reteste do falso conflito corrigido no
`0.8.1-sync-pilot.2`, fechar/reabrir o navegador e isolamento entre contas reais.
Os testes automatizados desta entrega não aprovam esses testes físicos.

## Como funciona

- Botão **Chat** no topo central do lobby e da partida; **Recolher** fecha o painel.
- Sem apelido de jogador anterior no projeto. No primeiro uso, definir 2–20 letras,
  números, espaços, `_` ou hífen. O apelido fica vinculado ao UID e é imutável nesta
  versão; não é exclusivo nem um comprovante de identidade. Não se deriva de e-mail.
- Autor, texto literal e horário local. Até 200 caracteres por mensagem; Enter
  ou **Enviar**. Mensagem vazia recusada. Estado de envio, espera e falha no painel.
- **Silenciar** oculta o autor neste aparelho para a conta atual. **Reativar
  silenciados** desfaz as preferências. UID é usado internamente, sem mostrar
  e-mail, senha, JWT ou credencial administrativa na lista.
- Administrador autorizado vê **Remover**. Na Web, a confirmação é feita no
  próprio painel do navegador. A remoção exige permissão nas regras e a versão
  exata do registro para não apagar uma mensagem nova no mesmo lugar.
- Native: componentes Godot e `IslandTheme`. Web: formulário DOM no shell existente,
  com a mesma paleta/fontes e `visualViewport` para o teclado. `textContent`/Label
  exibem HTML e BBCode como texto. As entradas e os ataques mantidos são bloqueados
  enquanto o painel está aberto, incluindo toque e movimento consultado por frame.

## Serviço gratuito e limites

Reutiliza Firebase Auth + Firestore REST, sem SDK adicional no jogo, Functions,
Cloud Run, SMS, TTL, novo banco, extensão ou servidor dedicado. Spark permanece
sem vínculo de Cloud Billing. A cota gratuita inclui 50.000 leituras, 20.000
escritas e 20.000 exclusões diárias, 1 GiB de dados e 10 GiB de saída por mês.
TTL requer faturamento, por isso não é usado. Os limites pertencem ao projeto
inteiro e são compartilhados com os saves. Fonte: [cotas oficiais do Firestore](https://firebase.google.com/docs/firestore/quotas).

`globalMessages/0` a `globalMessages/99` formam um histórico circular. Cada envio
incrementa `chatRuntime/global.sequence` e substitui `sequence % 100`; portanto
existem no máximo 100 mensagens, mesmo sem limpeza, tarefas agendadas ou clientes
administrativos conectados. A interface só mantém as últimas 50. `chatProfiles`
e `chatRates` têm no máximo um documento por UID autorizado. Remover contas do
piloto não apaga esses documentos automaticamente; o responsável pode removê-los
pelo Console quando encerrar o teste. Não há arquivo permanente de conversas.

Somente contas verificadas presentes em `chatSettings/global.allowed_uids` podem
ler/enviar. Lista vazia nega todos. Cada envio grava mensagem, contador e limite
do UID em um batch atômico. As regras exigem UID do JWT, apelido previamente
registrado, esquema exato, texto limitado, sequência consecutiva, slot correto,
horário do servidor e pelo menos 5 s desde o último envio daquele UID. Apagar
ou retroceder o limite é proibido; múltiplas abas compartilham esse limite.
`getAfter` valida o conjunto antes do commit: [documentação oficial](https://firebase.google.com/docs/firestore/security/rules-conditions#access_other_documents).

Consulta inicial: últimas 50 por sequência. Com painel aberto e página visível,
há consulta incremental a cada 15 s, limitada a 50; a cada 120 s há reconciliação
completa para refletir remoções administrativas e a janela atual. Uma mensagem
pode demorar até 15 s para chegar e uma remoção até 120 s para desaparecer de
outra sessão. Reabrir com cache dentro do intervalo não cria consulta adicional.
Fechar interrompe o polling; não há assinatura contínua. Logout cancela pedidos
pendentes, descarta respostas da sessão anterior e limpa o estado e rascunhos.
Falhas aplicam espera progressiva de até 240 s. Não há reenvio automático de
mensagem após falha ambígua: conferir o histórico antes de tentar novamente.

Estimativa de sessão ociosa com painel aberto: até 50 leituras iniciais,
aproximadamente 1.500 de reconciliação/hora e 240 consultas incrementais vazias/hora,
mais leituras de autorização. Cada envio custa três escritas, leitura do contador,
consultas e leituras dependentes das regras. A estimativa não é uma cota rígida;
acompanhar Usage, começar com as duas contas e sessões curtas. Restrição de consulta
é aplicada também no serviço ([regras de consultas](https://firebase.google.com/docs/firestore/security/rules-query)).
Uma conta autorizada ainda pode desperdiçar a cota fazendo leituras repetidas;
o piloto não é proteção contra abuso distribuído. Ao atingir a franquia, aguardar
reposição, restringir/desativar o chat; não fazer upgrade ou cadastrar cobrança.

## Arquivos e configuração externa pendente

O jogo principal tem `config/global-chat.json` com `enabled:false` e lista vazia.
O piloto isolado reutiliza somente os dois UIDs já presentes no piloto de saves,
sem senhas ou tokens. A liberação efetiva continua dependendo do backend.

Arquivos locais exatos já preparados em `.tools/chat-backend/`:

- `firestore.rules`: regras combinadas, adicionando o chat à base da branch de saves.
- `firebase.json`: configuração de deploy de regras somente.
- `chat-settings.json`: valores do documento `chatSettings/global`, com os dois
  UIDs do piloto e `admin_uids:[]`.
- `chat-settings.rest.json`: os mesmos valores no formato de campos da API REST.
- `save-branch-baseline.rules` e `BASELINE.txt`: origem da base usada na preparação.

Esses arquivos **não provam quais regras estão atualmente publicadas**. Não aplicar
uma base que altere o acesso aos mundos. Para preparar novamente com as regras
atuais exportadas do Console, sem modificação remota:

```powershell
node tools/prepare-chat-backend.mjs --base .tools/regras-atuais-do-console.rules --uids-from .tools/sync-real-project/config/world-sync.json
```

Passos pendentes do responsável, após revisar a base e o diff:

1. Confirmar que o projeto `tece-island-285cd` continua Spark sem Cloud Billing.
   Não ativar recursos pagos. Reutilizar o Firestore existente em modo de produção.
2. Comparar a base usada com as regras efetivamente publicadas. O preparador
   acrescenta apenas o bloco de chat antes da negação final e recusa bases
   inesperadas. Se a base do backend for diferente da branch de saves, usar a
   exportação atual do Console para preservar integralmente as regras de mundos.
3. Aplicar somente as regras revisadas. Com Firebase CLI já autenticada pelo
   responsável, o comando preparado é:

   ```powershell
   npx firebase deploy --project tece-island-285cd --config .tools/chat-backend/firebase.json --only firestore:rules
   ```

4. No Console Firestore, criar `chatSettings/global` com os tipos/valores de
   `chat-settings.json`: boolean `enabled`, arrays de strings `allowed_uids` e
   `admin_uids`. Manter apenas as contas de teste. Para testar remoção, adicionar
   explicitamente o UID da conta administradora em ambos os arrays. Nenhum cliente,
   nem mesmo administrador, pode editar esse documento pelas regras do jogo.
5. Não é preciso criar contador, perfil ou rate manualmente. Não são necessários
   índices compostos. `sequence` usa índice simples padrão. As novas isenções em
   `firestore.indexes.json` são otimizações opcionais de campos do chat; preservar
   as configurações de índices já existentes se aplicá-las pelo Console.
6. Testar as duas contas verificadas. Para desligar, definir `enabled:false` no
   documento do backend. Isso corta o chat inclusive em pacotes de piloto antigos.

Nenhum desses passos remotos foi executado nesta entrega. Não habilitar o chat
na versão pública e não mesclar o PR dos saves para realizar este piloto.

## Executar o piloto

```powershell
node tools/serve-web.mjs 8088 build/chat-pilot
```

PC: `http://localhost:8088/Tece-Island/`. Celular na mesma rede:
`http://IP-DO-PC:8088/Tece-Island/`. O servidor escuta na rede local, sem túnel ou
hospedagem contratada. Se necessário, liberar essa porta somente na rede privada
do PC. Restrições de contexto seguro do navegador podem exigir uma origem HTTPS
de teste já disponível; a versão pública não deve ser substituída. O endereço
do piloto anterior de sincronização não foi modificado.

Login usa o Firebase real e exige e-mail verificado. Senhas só no formulário.
Para PC nativo, abrir `.tools/chat-pilot-project/project.godot` no Godot 4.7.2 e F5.
O nome `TC Island Chat Pilot` separa o diretório nativo da aplicação principal.
A origem local/porta do piloto separa o armazenamento do navegador dos endereços
anteriores. O chat global compartilha a conversa entre as contas autorizadas;
mundos e preferências de silenciamento continuam associados às respectivas contas.

Reproduzir o pacote usando os mesmos UIDs existentes, sem imprimi-los:

```powershell
$chatUids = ((Get-Content .tools/sync-real-project/config/world-sync.json -Raw | ConvertFrom-Json).allowed_uids -join ',')
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export-chat-pilot.ps1 -Godot "CAMINHO/Godot_console.exe" -AllowedUid $chatUids
```

O modo `-Emulated` exporta para `build/chat-emulated/` e inclui comandos de fixture
e identidades sem assinatura, aceitas **somente no emulador local**. Nunca publicar
ou fornecer essa cópia como login real. Ela não integra o piloto real.

## Evidências e roteiro restante

Resultados detalhados e capturas: [Validação do chat](VALIDACAO_CHAT.md).
Faltam duas sessões no Firebase real com regras aplicadas, teste físico de teclado
Android/iOS, troca/reabertura de contas reais e confirmação visual no PC nativo.
Nenhuma sessão positiva do Firebase real foi criada ou utilizada pelo assistente.
