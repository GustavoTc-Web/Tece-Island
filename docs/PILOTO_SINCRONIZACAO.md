# Piloto Web do PR #1

**Atualização em 15/10/2026:** o mesmo endereço privado agora serve
`0.8.2-chat-pilot.2`, com chat e sincronização somente para as duas contas
de teste. A correção de `0.8.1-sync-pilot.2` está incluída. Os retestes físicos
continuam pendentes. Veja [publicação do chat](PUBLICACAO_CHAT.md).
O registro abaixo descreve a publicação anterior, versão 2 do Sites.

URL: https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/

Publicação privada atualizada e confirmada pelo Sites (`succeeded`, versão 2)
em 14/10/2026. Código do jogo: `5af37a6`; pacote hospedado: `120026e`.
O PR não foi integrado. A versão 1 anterior usava `e88d055` / `99cb051`.

Este endereço é separado do GitHub Pages. A hospedagem Sites é privada: abra
com a mesma conta ChatGPT usada nesta conversa, no PC e no celular. Depois,
entre no jogo com sua conta Firebase. A segunda conta Firebase pode ser
testada dentro desse mesmo acesso privado. Apenas os dois UIDs informados
pelo responsável têm sincronização habilitada na configuração compilada.
Essa lista é uma restrição do piloto no cliente; as regras do Firestore
continuam sendo a barreira de segurança por UID e e-mail verificado.

A versão pública não foi alterada; `config/world-sync.json` continua desativado.
O PR permanece em revisão. Nenhum faturamento ou serviço pago foi ativado.
O piloto atualizado identifica-se como `0.8.1-sync-pilot.2` em Ajuda e suporte.
Recarregue normalmente para baixar a versão nova, preservando os dados do site.
O navegador mantém seu armazenamento por origem: os mundos do endereço público
não aparecem automaticamente neste endereço de teste. Não importe saves reais
para o primeiro ensaio. Use um mundo novo e mantenha os backups originais.

## Teste curto com as duas contas

1. **PC:** abra o piloto, entre na primeira conta e confirme o e-mail se pedido.
   Crie `Piloto PC-celular`. Colete madeira e anote a quantidade no inventário.
2. Abra **Menu → Dados e salvamento → Salvar e tentar sincronizar**. Aguarde
   **Sincronizado**, anote o ID do mundo e a última revisão confirmada.
   Se o envio anterior foi há menos de 10 segundos, aguarde e tente novamente.
   O envio automático tem intervalo mínimo de 2 minutos. Volte ao lobby para
   pausar esse mundo antes de usar o outro aparelho.
3. **Celular:** abra o mesmo link e entre na mesma conta Firebase. Gire para
   paisagem ao jogar. Abra o mundo com o mesmo nome/ID, confira a quantidade
   anotada e faça outra alteração, como coletar mais madeira. Repita a etapa 2.
   Depois volte ao lobby no celular.
4. **PC:** recarregue, entre novamente e abra o mesmo mundo. Confira a nova
   quantidade e a revisão. Feche/reabra esse navegador e confira de novo.
5. **Isolamento:** saia da conta pelo menu do jogo e entre na segunda conta
   Firebase. O mundo da primeira não deve aparecer. Crie `Piloto conta B` e
   sincronize. Volte à primeira: apenas seus mundos devem aparecer. Confira
   também dois mundos da mesma conta com inventários diferentes.

Para ensaiar conflitos, primeiro sincronize um mundo nas duas sessões, depois
produza mudanças diferentes sem consultar a versão nova. A sessão antiga deve
oferecer resolução no lobby, preservando a versão remota e uma cópia do aparelho
com outro ID. Nenhuma escolha deve sobrescrever silenciosamente a outra versão.
Para ensaiar rede, desligue a conexão durante um envio; aguarde o aviso pendente,
restaure a rede e use o botão de tentativa. Confira ambas as cópias antes de fechar.

## Verificação de e-mail e configuração

O projeto compilado usa `tece-island-285cd`, banco `(default)` e os endpoints
REST de Authentication, Secure Token e Firestore. Nenhuma chave administrativa
entra na versão Web. “Já confirmei” renova o token antes da consulta de confirmação,
pois as regras verificam `email_verified` no token autenticado.

O retorno dos e-mails continua sendo o endereço já configurado:
`https://gustavotc-web.github.io/Tece-Island/`. Após confirmar o e-mail ou recuperar
a senha, volte manualmente ao piloto. Isso evita depender de um domínio novo
como endereço de retorno. Não significa que o endereço do piloto foi autorizado
no console: restrições adicionais da chave só podem ser confirmadas com login real.

Se houver bloqueio, no console do projeto confira:

- Authentication → Users: as duas contas e **e-mail verificado**; Sign-in method:
  E-mail/senha habilitado. Use Reenviar confirmação / Já confirmei ou entre novamente.
- Google Cloud → APIs & Services → Credentials → a Web API Key existente:
  se houver restrição por referrer, autorize
  `https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/*` sem remover
  os endereços já permitidos. Se a chave tiver restrição por API, mantenha
  Identity Toolkit API, Token Service API e Cloud Firestore API permitidas.
- Firestore Database → `(default)` → Rules: regras de `firestore.rules` do PR #1
  publicadas. Não flexibilize a separação de contas nem a verificação de e-mail.
- Para os índices sem payload, caso ainda não publicados: em seu terminal
  autenticado, `npx firebase deploy --only firestore:indexes --project tece-island-285cd`.
  Isso aplica `firestore.indexes.json`; não exige habilitar faturamento.
- Firestore → Usage: acompanhar cotas compartilhadas no Spark. Os limites e a
  estimativa de consumo estão em [SAVES_E_SINCRONIZACAO.md](SAVES_E_SINCRONIZACAO.md).

## Se falhar, preserve os dados

Não limpe cookies, cache, dados do site ou IndexedDB; não use janela anônima.
Anote aparelho/navegador, conta A ou B, quantidade esperada e aviso exibido.
Em **Ajuda e suporte → Copiar informações para relatar problema**, copie versão,
commit, origem, ID, revisão confirmada, hashes local/confirmado e último erro.
Dados e salvamento também informa se o progresso local corresponde à última
versão sincronizada ou possui alterações pendentes. O texto não inclui tokens,
senha ou inventário. HTTP 401 indica sessão; 403 indica permissão; 429 indica
limite. Um erro de acesso nunca significa que o mundo não existe.

Para uma cópia dos dados locais, no console do navegador dessa mesma origem
execute `await tcExportLocalSaves()`: baixa um JSON sem apagar ou sobrescrever
originais. Esse arquivo contém progresso; guarde-o em privado. No celular sem
console, mantenha o navegador/perfil original e reporte os dados acima antes
de qualquer tentativa de recuperação. Considere também a origem pública antiga
se o mundo ausente foi criado lá, conforme [RECUPERAR_MUNDO.md](RECUPERAR_MUNDO.md).

## Evidência e limites de validação

- 155 verificações em nove suítes Godot: persistência, conta/catálogo, backup,
  migração, conflitos, captura/restauração de equipamentos e 100 baús, autenticação
  e classificação de erros/renovação de verificação. Os testes positivos de
  autenticação desta última suíte usam transporte controlado, identificado como fixture.
- 12 verificações Edge/IndexedDB: reload, fechar/reabrir perfil próprio, duas abas,
  isolamento de chaves, backups e migração pelo Godot Web. São testes automatizados.
- 12 verificações do pacote Web exportado: carregamento completo em partes no PC
  e mobile emulado, identificação do piloto, configuração real do formulário,
  falha de rede sem alteração dos bytes locais, reload, login em retrato e download
  incompleto com aviso/recarregar. Rejeição de credenciais inválidas no Firebase
  real também passou; nenhuma conta foi criada.
- 10 subtestes de regras no projeto fictício `demo-tece-island`, incluindo 12
  verificações REST no Godot nativo. Não são uma prova das regras já publicadas.
- Backend real: chamada nativa com credenciais inválidas foi rejeitada corretamente,
  sem cadastro, envio de e-mail ou leitura/escrita de mundos de jogadores.
- Endereço atualizado: três verificações adicionais passaram no Edge — carregamento
  do jogo/login, versão/commit do pacote servido e rejeição de credenciais inválidas pelo Firebase a partir da origem
  HTTPS do piloto. Isso verifica a hospedagem e o acesso básico de autenticação nessa
  origem; não comprova a permissão Firestore com uma conta verificada.
- O responsável confirmou PC → celular → PC com o progresso correto ao escolher
  “Continuar versão da nuvem”. Isso confirma essa recuperação entre aparelhos;
  ainda não confirma uma troca sem conflitos com a cópia local limpa. Separação
  entre duas contas, persistência após fechar/reabrir e migração de um save real
  permanecem pendentes da confirmação do responsável. Emulação mobile não
  comprova execução em um celular físico.

## Correção de conflitos na troca de aparelho

Reprodução automatizada com dados próprios em `tests/validate_sync_handoff.gd`:
o PC confirma revisão 1; o celular publica revisão 2; o PC tenta enviar uma cópia
que ainda tem exatamente o hash confirmado da revisão 1. A comparação já retornava
`download`, mas o caminho de envio tratava esse resultado como `conflict`.
Além disso, carregar depois a nuvem não limpava esse registro em memória, que
podia bloquear novas sincronizações. Dois testes falharam antes da correção.

Agora essa tentativa indica **Progresso na nuvem · Voltar ao lobby**, sem publicar
o estado antigo, avançar sua base ou substituir uma simulação em execução.
Na reentrada, o save local final é relido: se permanece igual à sua base confirmada,
a nuvem é carregada automaticamente com backup; se existem mudanças independentes,
continua o diálogo **Duas versões do mundo**, preservando ambas as cópias.
Conflitos obsoletos só são removidos após carga/comparação válida bem-sucedida.

As 14 verificações adicionais incluem o retorno real da sessão ao lobby, carga
do mundo completo, alteração local durante uma consulta remota atrasada, diálogo
de conflito real e conservação das duas versões ao continuar a nuvem. Transporte
de teste substitui o Firebase nessa suíte; não são novos testes em aparelhos físicos.
O caso individual ainda depende de identificar se havia mudanças locais pendentes.
Tempo do mundo, necessidades do personagem e outros campos também são progresso;
não foram excluídos do hash para suprimir avisos.

Para repetir o caso no piloto atualizado: sincronize com a partida pausada em
Dados e salvamento e confira **Progresso local: igual à última versão sincronizada**.
Volte ao lobby no PC antes de jogar no celular. Sincronize no celular e volte ao
lobby. No PC, use Atualizar mundos / Tentar sincronização e reabra o mesmo ID.
O avanço exclusivo da nuvem deve carregar sem diálogo. Caso apareça um conflito,
copie o diagnóstico antes de escolher uma versão; ele contém os hashes comparáveis.

Não mesclar o PR ou ativar sincronização para todos antes de registrar os
resultados do roteiro e validar migração com cópias de teste.

## Reproduzir o pacote

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export-sync-test.ps1 -Godot "CAMINHO/Godot_console.exe" -AllowedUid "UID_A,UID_B"
node tools/package-sync-pilot.mjs build/sync-test .tools/sync-pilot-site/dist
node tools/serve-web.mjs 8086 .tools/sync-pilot-site/dist/Tece-Island
node tools/sync-pilot-browser-validation.mjs --live-invalid
```

O projeto `.tools/sync-real-project/project.godot` permite o teste nativo (F5),
com `TC Island Sync Test` como pasta própria. O empacotamento divide o WASM em
arquivos de até 8 MiB, recompõe em memória e confere SHA-256 antes de iniciar.
Não modifica o protocolo de save ou usa um backend administrativo.
