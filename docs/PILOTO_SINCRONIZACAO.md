# Piloto Web do PR #1

URL: https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/

Este endereço é separado do GitHub Pages. A hospedagem Sites é privada: abra
com a mesma conta ChatGPT usada nesta conversa, no PC e no celular. Depois,
entre no jogo com sua conta Firebase. A segunda conta Firebase pode ser
testada dentro desse mesmo acesso privado. Apenas os dois UIDs informados
pelo responsável têm sincronização habilitada na configuração compilada.
Essa lista é uma restrição do piloto no cliente; as regras do Firestore
continuam sendo a barreira de segurança por UID e e-mail verificado.

A versão pública não foi alterada; `config/world-sync.json` continua desativado.
O PR permanece em revisão. Nenhum faturamento ou serviço pago foi ativado.
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
commit, origem, ID, revisão confirmada e último erro. O texto não inclui tokens,
senha ou inventário. HTTP 401 indica sessão; 403 indica permissão; 429 indica
limite. Um erro de acesso nunca significa que o mundo não existe.

Para uma cópia dos dados locais, no console do navegador dessa mesma origem
execute `await tcExportLocalSaves()`: baixa um JSON sem apagar ou sobrescrever
originais. Esse arquivo contém progresso; guarde-o em privado. No celular sem
console, mantenha o navegador/perfil original e reporte os dados acima antes
de qualquer tentativa de recuperação. Considere também a origem pública antiga
se o mundo ausente foi criado lá, conforme [RECUPERAR_MUNDO.md](RECUPERAR_MUNDO.md).

## Evidência e limites de validação

- 141 verificações em oito suítes Godot: persistência, conta/catálogo, backup,
  migração, conflitos, captura/restauração de equipamentos e 100 baús, autenticação
  e classificação de erros/renovação de verificação. Os testes positivos de
  autenticação desta última suíte usam transporte controlado, identificado como fixture.
- 12 verificações Edge/IndexedDB: reload, fechar/reabrir perfil próprio, duas abas,
  isolamento de chaves, backups e migração pelo Godot Web. São testes automatizados.
- Backend real: chamada nativa com credenciais inválidas foi rejeitada corretamente,
  sem cadastro, envio de e-mail ou leitura/escrita de mundos de jogadores.
- Login positivo das duas contas, permissões das regras publicadas, fluxo real
  PC → celular → PC e migração de um save real permanecem pendentes do responsável.
  Emulação mobile não comprova execução em um celular físico.

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
