# Saves confiáveis e sincronização de mundos

Implementação para revisão na branch `fix/reliable-saves-world-sync`.
A sincronização pública permanece **desativada** em `config/world-sync.json`.
Não foram alterados faturamento, plano, regras remotas ou saves de jogadores.

Atualização do piloto: o responsável informou criação do Firestore `(default)`
e publicação das regras do PR #1, mantendo Spark sem faturamento. A versão Web
privada e o roteiro atual estão em [PILOTO_SINCRONIZACAO.md](PILOTO_SINCRONIZACAO.md).
A configuração pública segue desativada; os testes reais ainda precisam de confirmação.

## Investigação e causa reproduzida

Na revisão anterior `e89b0ed`, uma cópia isolada reproduziu três problemas:

1. Apagar somente o catálogo `worlds.json` faz a lista ficar vazia, embora o
   arquivo do mundo permaneça byte a byte intacto. O catálogo não procurava
   arquivos órfãos. Isso é **mundo oculto**, não perda comprovada do save.
2. Duas instâncias leem o mesmo save; a antiga consegue gravar depois da nova,
   substituindo seu progresso. Faltava comparação local antes da substituição.
3. Um arquivo de mundo ausente retorna `{}` sem erro. O fluxo de entrada abre
   uma ilha inicial para um ID já usado. A próxima gravação pode consolidar um
   reinício. Agora somente a criação explícita permite um primeiro save vazio.

Reprodução: `tests/audit_save_loss_baseline.gd`, executado contra o checkout
anterior em `.tools/save-baseline/`. Saída: três linhas `REPRODUCED ... = true`.
Os testes corrigidos estão em `validate_save_reliability.gd`.

O relato individual ainda não tem causa confirmada. Sem os dados daquele
aparelho, não se pode distinguir catálogo perdido, save inválido, última gravação
não concluída ou outro navegador/origem/perfil. A ausência de sincronização
explica um mundo não existir em **outro aparelho**, mas não explica sozinha seu
desaparecimento no aparelho original.

## Persistência local e migração

- UID Firebase define o proprietário. Pastas/chaves locais usam SHA-256 desse
  UID; e-mail não identifica saves. ID do mundo permanece estável.
- Web: IndexedDB `tece-island-progress-v4`, store `saves`. O nome permanece
  igual nas atualizações. Login/logout não apagam armazenamento.
- Nativo: `user://accounts/<hash-uid>/worlds/<id>/progress.json` e catálogo
  `user://accounts/<hash-uid>/worlds.json`. O nome da aplicação permanece igual.
- Gravação periódica a cada 30 segundos, debounce de eventos de 1,5 segundo e
  intervalo local mínimo de 3 segundos. Sair para o lobby e logout voluntário
  aguardam save local; falha mantém a partida. Foco/pausa/visibilidade tentam
  gravar também, sem depender do fechamento da aba.
- Web confirma somente após `transaction.oncomplete`; pede armazenamento
  persistente ao navegador, cuja concessão não é garantida. Escrita compara
  conteúdo esperado dentro da mesma transação. Nativo compara sob uma trava
  de diretório e substitui arquivo temporário depois de flush/validação.
- Sessões locais antigas são recusadas; seu candidato é arquivado quando há
  espaço. Último save, penúltimo e arquivos anteriores à migração são mantidos.
  A nova tentativa oferece continuar como outro mundo; a versão da outra
  sessão permanece no ID original. O jogo não obriga encerrar sem preservar a partida.
- A lista é reconciliada com arquivos/chaves da própria conta. Catálogo inválido
  é arquivado antes de usar backup/reconstrução. Arquivos quebrados também
  permanecem visíveis para recuperação; dono/ID divergente bloqueia importação.
- Save inválido não pode ser substituído pelo save automático. Backups passam
  por validação de dono, ID, versão, inventário, equipamentos, baús, objetivos,
  diário e estruturas. Recuperação exige escolha do jogador e arquiva o original.
- Criar mundo grava primeiro o estado inicial e a semente, depois registra seu
  ID no catálogo. Saves iniciais e mundos inativos também sincronizam no lobby;
  a migração não depende de abrir cada mundo. Um catálogo antigo com arquivo
  ausente não autoriza inicializar uma ilha vazia pelo horário de último acesso.
- Migração por conta usa `migration_done`, mantém `first-world` e originais.
  Destino divergente recebe outra cópia com ID determinístico; repetir não duplica.
  O legado global sem dono só é atribuído mediante importação explícita, única
  por aparelho, com reserva/backup. Na Web, `legacy-original-v4` guarda os bytes
  anteriores à conversão. Saves pertencentes a outra conta não são importados.

Caso o processo nativo caia exatamente durante uma escrita, uma pasta `.lock`
pode permanecer. O jogo bloqueia novas escritas em vez de arriscar outra sessão.
Feche **todas** as instâncias, copie a pasta da conta e remova somente
`progress.json.lock/owner.json` e sua pasta vazia, ou o equivalente
`worlds.json.lock`. Não remova o save. Este caso raro não tem recuperação
automática; a trava não usa relógio para decidir se pode substituir progresso.

## Protocolo remoto

O mesmo cliente GDScript/HTTPRequest usa Firestore REST na Web e no Godot
nativo, com ID token Firebase em memória. Troca de sessão invalida respostas
pendentes. Não há Admin SDK, conta de serviço ou senha no jogo/repositório.

```
users/{firebase_uid}/worlds/{world_id}                 cabeçalho atual
  versions/{snapshot_id}                            manifesto imutável
    chunks/{0..7}                                   payload imutável
```

`WorldProgress.capture()` envia inventário, seleção/equipamentos/atributos,
construções e baús completos, personagem/necessidades/veneno/posição, cama,
objetivos, diário, semente, exploração, tempo, recursos, drops, poços,
construções regionais e saque dos recipientes. `_sync` é metadado exclusivamente
local. A ilha gerada é reconstruída pela semente e pelos deltas capturados.

Cada envio lê o cabeçalho remoto primeiro. Somente `NOT_FOUND` confirmado pelo
serviço significa ausência; timeout, 403, quota e payload inválido são erros.
A revisão base e o hash local determinam se cabe baixar, enviar ou resolver
conflito. O relógio do dispositivo serve apenas para a apresentação de último
acesso, não para escolher progresso.

Um único `documents:commit` grava cabeçalho, manifesto e todas as partes. A
condição é `exists:false` na criação ou `currentDocument.updateTime` na revisão
seguinte. As regras também exigem incremento de revisão, manifesto idêntico e
todas as partes presentes. Elas recusam escrita em outra conta e mutações de
snapshots. O carregamento usa um snapshot fixo, valida tamanho e SHA-256 antes
de tocar a cópia local. Uma migração para a nuvem mantém backup local permanente.

Antes de enviar, a intenção `{hash, revision}` é gravada localmente. Se o commit
for concluído e a resposta se perder, a tentativa seguinte reconhece esse hash
e essa revisão. Confirmar um envio conserva o progresso local produzido durante
a rede; não grava de volta o corpo antigo. A comparação local impede também
que a confirmação de uma sessão autorize sobrescrever os arquivos de outra.

Conflitos preservam as duas versões. No lobby o jogador escolhe continuar a
nuvem ou uma cópia deste aparelho. Ambas continuam listadas; a cópia local
recebe um novo ID, e o mundo remoto original mantém seu ID. Não há mesclagem
automática de inventário/construções. A resolução relê o remoto antes de baixar.

## Estado e custo

Os avisos distinguem `Salvo neste aparelho`, `Sincronizando`, `Sincronizado`
e sincronização pendente/falha, com nova tentativa. A confirmação de rede é
necessária para `Sincronizado`; alterações locais posteriores continuam pendentes.
O estado também pode ser consultado em Menu → Dados. A rotina continua salvando
localmente quando não há rede ou o serviço recusa operações.

Uploads automáticos agrupam alterações por pelo menos 120 segundos; falhas
recuam para 120, 240, 480 e até 900 segundos. Tentativas manuais/foco têm mínimo
de 10 segundos e não abrem envios concorrentes. O catálogo remoto é consultado
ao abrir/atualizar o lobby, sem listener por frame. Reabrir uma partida consulta
seu cabeçalho. A limpeza posterior preserva o snapshot atual e o predecessor;
versões antigas são removidas somente após confirmação. Se a limpeza falhar,
ficam armazenadas e serão tentadas novamente em um envio futuro.

Medições com dados próprios, capturados pelo jogo:

| Cenário | JSON UTF-8 | Deflate/base64 | Partes |
| --- | ---: | ---: | ---: |
| Mundo inicial gerado | 12.066 bytes | 3.352 bytes | 1 |
| Mundo com armadura, arco e 100 baús abastecidos | cerca de 65.551 bytes | cerca de 4.824 bytes | 1 |

Sementes/posições geradas podem variar um pouco. O teste imprime e grava os
valores reais em `.tools/sync-fixture-*/measurements.json`. Um payload aleatório
adicional valida transferência multipartes pelo emulador, sem representar um
save típico. A entrada tem limite de 16 MiB antes da compressão e 8 partes de
até 200.000 caracteres depois dela. Cada documento fica abaixo de 1 MiB; o
commit inteiro fica abaixo de 10 MiB. Acima do limite: envio recusado, local mantido.

O projeto deve permanecer Spark, sem conta Cloud Billing vinculada. A quota
gratuita é compartilhada pelo projeto: 50.000 leituras, 20.000 escritas e 20.000
exclusões por dia, 1 GiB armazenado e 10 GiB de saída por mês. Há uma base gratuita
por projeto. [Limites oficiais](https://firebase.google.com/docs/firestore/quotas).

Para `C` partes: cada publicação custa `C+2` escritas. A limpeza de uma versão
antiga custa `C+1` exclusões. Conte também cabeçalho, lista de versões e leituras
dependentes das regras; falhas e acesso pelo console podem consumir operações.
Como orçamento conservador, use 12 leituras por publicação de uma parte e 20
para oito partes, além de catálogos/downloads e retries. Com 30 uploads/hora,
um jogador típico usa até 360 leituras, 90 escritas e 60 exclusões/hora; 100
jogadores com uma hora/dia: até 36.000, 9.000 e 6.000, antes dos extras. Oito partes
reduzem muito a capacidade gratuita. Não há garantia de caber com público sem
limite; acompanhe Usage e aumente o intervalo/restrinja o piloto quando necessário.
[Leituras das regras e cobrança](https://firebase.google.com/docs/firestore/security/rules-conditions#access_calls_and_pricing).
Exceder quota mantém o estado pendente e a cópia local; não ativa faturamento.

## Console e piloto: ações do responsável

1. No projeto **tece-island-285cd**, confirme Spark e ausência de vínculo Cloud
   Billing. Não habilite Functions, Storage, TTL, backup gerenciado ou PITR.
2. Abra Firestore Database. Se ainda não existir, crie a base **(default)**,
   Standard/Native mode, em modo de produção. Escolha e registre a região.
   Se já existir, faça cópia das regras atuais antes de integrar estas regras.
3. Publique `firestore.rules` e `firestore.indexes.json` apenas depois de revisar
   os testes. Pelo CLI, no seu terminal autenticado: `npx firebase login` e
   `npx firebase deploy --only firestore:rules,firestore:indexes --project tece-island-285cd`.
   Não envie credenciais do terminal ao chat nem ao jogo.
4. Mantenha e-mail/senha e domínios do Authentication conforme `FIREBASE.md`.
   Se a Web API Key tiver restrição por serviço, inclua Firestore API junto de
   Identity Toolkit e Secure Token. Não remova as restrições indiscriminadamente.
5. Use **sua própria conta de teste verificada**; copie seu UID do Authentication.
   Gere o piloto, sem modificar a configuração pública:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export-sync-test.ps1 -Godot "CAMINHO/DO/GODOT_console.exe" -AllowedUid "UID_DA_SUA_CONTA_DE_TESTE"
node tools/serve-web.mjs 8086 build/sync-test
```

No PC, abra `http://localhost:8086/Tece-Island/`. No celular da mesma rede, use
`http://IP-DO-PC:8086/Tece-Island/`. Para Godot nativo, abra
`.tools/sync-real-project/project.godot` e F5. O nome `TC Island Sync Test` isola
o armazenamento nativo; navegador/origem de teste e conta própria isolam os
dados Web. Use perfil de teste e mantenha exportações antes de ensaiar migração.

6. Execute o roteiro abaixo e registre UID, IDs, revisões e hashes, sem tokens.
   A criação da base e a publicação das regras foram informadas pelo responsável;
   as permissões com login positivo e os índices ainda precisam ser conferidos.
   Nenhum deploy Firebase foi feito pelo assistente. Há um piloto privado pronto,
   descrito em [PILOTO_SINCRONIZACAO.md](PILOTO_SINCRONIZACAO.md).
7. Só depois de validar migração e ida/volta reais, revise/mescle o PR. A exportação
   pública gera sincronização desativada por padrão. Uma ativação posterior exige
   configurar `TECE_SYNC_ENABLED=true` e `TECE_SYNC_VALIDATED=true` no passo de
   configuração de sincronização do workflow; o piloto usa `TECE_SYNC_ALLOWED_UIDS`.
   Essa alteração de publicação deverá ser revisada separadamente.

## Testes e validação pendente

```powershell
$env:GODOT_EXE = "CAMINHO/DO/GODOT_console.exe"
# Java 21 disponível no PATH; dependências apenas de desenvolvimento.
npm ci
npm run test:rules
& $env:GODOT_EXE --headless --path . --script tests/validate_save_reliability.gd
& $env:GODOT_EXE --headless --path . --script tests/validate_world_sync.gd
# Fixture Web + Edge/Playwright conforme ferramentas existentes do projeto.
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-browser-fixture.ps1 -Godot $env:GODOT_EXE
node tools/serve-web.mjs 8081 .tools/web-validation
node tools/save-browser-validation.mjs
```

Emuladores usam somente `demo-tece-island`, nunca o projeto real. Tokens de
fixture são aceitos somente pelo emulador; os testes não comprovam login real.
`GODOT_EXE` habilita a integração REST nativa na suíte de regras. CI prepara
Godot/Java e roda a persistência e o emulador em pull requests.

Validados: regressões de catálogo/contas/migração/backup, falha local ao voltar
ao lobby/logout, serialização e carga de equipamentos/100 baús, ida/volta em
transporte controlado, duas sessões incompatíveis, resposta de envio perdida,
reload/fechar navegador/reabrir perfil próprio, duas abas e regras de isolamento,
revisão, versão incompleta, imutabilidade, limite de partes e limpeza. O cliente
nativo também passa por commits condicionais e leitura multipartes do emulador.

Ainda pendentes com serviço real e aparelhos físicos:

- Celular → PC Web → celular e celular → Godot nativo → celular, mesma conta/ID.
- Conferir inventário/equipamentos, baús/construções, personagem, objetivos,
  diário, recursos/exploração depois de cada transferência confirmada.
- Desconectar durante o envio, reabrir sem rede, restaurar conexão e conferir
  que o status não indique sincronizado antes da confirmação.
- Duas contas e dois mundos, incluindo logout/relogin e renovação de token.
- Produzir mudanças nos dois aparelhos, escolher cada opção do conflito e
  confirmar que a outra versão permanece disponível.
- Migrar cópias próprias de v3/v4 e de mundos existentes; recuperar backup e
  repetir entrada/atualização sem criar duplicatas. Nunca testar em saves reais
  da jogadora antes de exportá-los e analisar cópias.

Limitações: armazenamento do navegador pode ser removido pelo usuário/SO;
fechamento abrupto pode perder alterações posteriores ao último save confirmado;
o estado remoto representa snapshots do jogo, sem mesclagem de partidas
concorrentes. Alterar origem, perfil, UID ou nome da aplicação pode dar acesso a
outro armazenamento local. O piloto/manual também deve verificar tamanho dos
avisos e diálogos em celulares físicos. Confirmação remota não é uma garantia
contra exclusão administrativa do projeto.
