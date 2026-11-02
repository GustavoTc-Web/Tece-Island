# Chat da beta: preparação e limite gratuito

31/10/2026. O cliente e as regras estão preparados para contas Firebase com
e-mail confirmado fora das duas contas originais. **A abertura remota não foi
aplicada.** A RC2 mantém o chat das mesmas duas contas e a sincronização de mundos
com o mesmo opt-in de duas contas e intervalo de 120 s. Nenhum faturamento foi
habilitado. O solo continua disponível quando o chat está fechado ou falha.

## O que foi preparado e validado

`GlobalChat.available()` aceita `audience: "verified"` somente com sessão válida
e e-mail confirmado. O padrão continua `allowlist`. `chatAccess()` aceita contas
verificadas quando `chatSettings/global.access_mode == "verified"`; sem esse campo
o comportamento anterior é preservado. Autoria, perfil e silenciamento são por
UID; apelido não concede cargo. Continuam 200 caracteres, intervalo de 5 s validado
no backend, histórico circular de 100 documentos e janela de 50. Somente os
administradores já indicados em `admin_uids` podem remover mensagens. Clientes,
inclusive administradores, não podem alterar `chatSettings/global`.

No arquivo preparado, as regras de mundos permanecem byte a byte iguais à base RC1 antes do bloco de chat:
isolam dados pelo UID e validam versões/batches. A habilitação de sincronização
para duas contas é uma configuração do cliente já existente; não se deve
apresentá-la como uma nova allowlist de segurança no backend. Não foi ampliada.

Os testes usam exclusivamente Auth/Firestore demo locais, nunca mensagens ou
mundos de produção. Incluem nova conta verificada, não verificada, anonimato,
autoria forjada, autoelevação recusada, remoção administrativa, duas sessões Web,
troca de conta, pausa, teclado, silenciamento, falha/reconexão e aba oculta.

## Projeções Spark

Fontes consultadas em 31/10/2026:
[cotas](https://firebase.google.com/docs/firestore/quotas) e
[cobrança de consultas e regras](https://firebase.google.com/docs/firestore/pricing).
Firestore gratuito: 50.000 leituras, 20.000 gravações e 20.000 exclusões/dia;
1 GiB armazenado e 10 GiB de saída/mês. A cota diária reinicia à meia-noite do
Pacífico. Consultas vazias e contagens pequenas também têm leitura mínima;
documentos consultados pelas regras podem consumir leituras adicionais.
Limites e semântica do PATCH reconferidos nas fontes oficiais em 01/11/2026;
as projeções abaixo não foram transformadas em medições de produção.

Modelo de planejamento, **não medição de faturamento**:

- Chat ativo: 5 s entre consultas; após 60 s sem novas mensagens, 15 s; metadados
  e reconciliação por contagem a cada 120 s. Fechado/aba oculta: sem novos polls.
- Hora de cliente estável: aproximadamente 660 leituras ociosa ou 1.620 ativa,
  já reservando uma leitura dependente de regras por requisição de consulta.
- Abertura com 50 mensagens: reserva adicional de 55 leituras; no cenário ocioso,
  mais 16 para o primeiro minuto ainda no ritmo ativo.
- Conversa ativa: **6 mensagens/minuto no grupo inteiro**, não por jogador;
  reserva conservadora de até 12 leituras por envio e 3 gravações por mensagem.
  Rajadas com vários documentos no mesmo poll, reaberturas, retentativas e
  administração podem aumentar o consumo. Não é um teto garantido.
- Reservar 20.000 leituras e pelo menos 5.000 gravações/dia para saves e demais
  usos. Essa reserva é planejamento; a produção não foi instrumentada aqui.

| Cenário | Pico | Duração por conta | Horas de chat somadas/dia | Leituras ociosas | Leituras em conversa | Gravações da conversa | Conversa + reserva de leituras |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Menor | 2 | 30 min | 1 | 802 | 3.890 | 540 | 23.890 |
| Opção 1 | 10 | 1 h | 10 | 7.310 | 21.070 | 1.080 | 41.070 |
| Opção 2 | 30 | 2 h | 60 | 41.730 | 107.490 | 2.160 | 127.490 |

O cenário de 30 pessoas excede o Spark mesmo ocioso quando somada a reserva.
Picos isolados não dimensionam o serviço: cinco pessoas com duas horas cada têm
as mesmas dez horas-cliente de dez pessoas com uma hora, mas sessões frias e
distribuição/volume de mensagens mudam os totais. Reabrir repetidamente também
recarrega a janela inicial. Downloads JSON medidos no emulador não equivalem a
GiB faturados; é necessário acompanhar armazenamento/saída no console real.

**Proposta antes de abrir:** primeiro grupo por convite de até cinco contas
verificadas, meta de até dez horas-cliente/dia no total, sem mais de seis mensagens
por minuto no grupo, acompanhamento diário no console. Manter cerca de 9 mil
leituras de folga além da reserva no cenário 1. Os intervalos atuais não impõem
um teto global nem um limite de horas; o operador precisa fechar o chat se o uso
se aproximar de 30 mil leituras de chat/dia. Uma divulgação irrestrita no LinkedIn
não tem orçamento previsível neste modelo. Esgotar o Spark deve indisponibilizar
o chat, mantendo o solo local. Sem plano pago e sem promessa de acesso ilimitado.

## Aplicação exata, ainda pendente

Em 01/11, a CLI acessível continua sem sessão; não houve leitura autenticada
atual de regras/settings nem aplicação em produção. A configuração do PCK
publicado continua em allowlist com duas contas. Os passos abaixo são preparação
para depois da decisão de acesso; nenhum deles foi executado remotamente aqui.

### Autenticar e preservar a base

No terminal pessoal, na worktree isolada, sem alterar a branch do IDE:

```powershell
Set-Location 'C:\Users\gusta\Desktop\Tece-Island\.tools\solo-beta-rc2'
node ../../node_modules/firebase-tools/lib/bin/firebase.js login --reauth
node tools/export-chat-beta-baseline.mjs
```

Concluir a autenticação diretamente no navegador com uma conta administrativa
do projeto `tece-island-285cd`. Não enviar senha/token pela conversa nem colocar
chave de serviço no jogo ou Git. A exportação só faz GET e grava regras/settings
com `updateTime` em `.tools/firebase-current`, ignorado pelo Git.

### Opção recomendada: convidados verificados

Escolher até cinco contas **no total**, incluindo as originais. Usar o UID real
exibido no Firebase Auth, não apelido/e-mail. Exemplo de preparação local (trocar
o identificador de exemplo pelo UID real):

```powershell
node tools/prepare-chat-beta.mjs --base .tools/firebase-current/firestore.rules --settings .tools/firebase-current/settings.json --mode allowlist --invite-uids 'UID_CONVIDADO_REAL'
```

Saídas em `.tools/chat-beta-prepared`:

- `firestore.rules` e `firebase.json`: regra completa revisável. Tudo fora de
  `chatAccess()` precisa coincidir com a base conhecida; divergência interrompe.
- `settings-patch.rest.json`: somente `access_mode=allowlist` e `allowed_uids`
  atual **mesclado** com convidados; não remove convidados anteriores.
- `preconditions.json`: máscara de atualização e `currentDocument.updateTime`.
  Não sobrescrever alterações administrativas concorrentes; reexportar se falhar.
- `client-chat-config.json`: lista correspondente para o cliente, sem configurar
  sincronização de mundos.

Backend esperado: `enabled=true`, `access_mode=allowlist` e UID convidado na lista.
Cliente esperado: `enabled=true`, `audience=allowlist` e esse mesmo UID na lista.
O e-mail deve estar confirmado e a conta deve entrar novamente para obter sessão
atualizada. Só alterar a lista no backend não faz aparecer o botão no PCK atual.

As regras fechadas existentes já usam a allowlist. Se a base exportada confirmar
essa política completa, os convites dependem da lista, sem exigir abertura para
todas as verificadas. A regra preparada também pode ser aplicada após revisão,
mantendo `access_mode=allowlist` durante o grupo inicial.

### Alternativa: todas as contas verificadas

```powershell
node tools/prepare-chat-beta.mjs --base .tools/firebase-current/firestore.rules --settings .tools/firebase-current/settings.json --mode verified
```

Aplicar a regra `chatAccess()` preparada, que permite sessão com e-mail confirmado
quando `access_mode=verified`. O PATCH dessa opção contém só
`{"fields":{"access_mode":{"stringValue":"verified"}}}`: listas existentes e
administradores ficam intactos. Cliente usa `audience=verified`, sem uma lista
de convites como condição de entrada. Isso admite qualquer nova conta verificada;
o custo passa a depender do uso total e não há teto global de horas/mensagens.

### Aplicar backend e compilar o cliente correspondente

**Após decidir a abertura e revisar a base**, a publicação das regras é:

```powershell
node ../../node_modules/firebase-tools/lib/bin/firebase.js deploy --project tece-island-285cd --only firestore:rules --config .tools/chat-beta-prepared/firebase.json
```

Atualizar somente os campos indicados em `preconditions.json` do documento
`chatSettings/global`, pelo console ou REST. No REST, usar:

```text
PATCH https://firestore.googleapis.com/v1/projects/tece-island-285cd/databases/(default)/documents/chatSettings/global
```

Acrescentar um parâmetro `updateMask.fieldPaths` por campo indicado e
`currentDocument.updateTime=<updateTime exportado, codificado para URL>`, com o
corpo de `settings-patch.rest.json` e autenticação administrativa mantida fora
do jogo. A [máscara preserva campos não citados](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/patch).
**Não substituir o documento inteiro nem gravar `admin_uids: []`.**

Conferir `enabled` na base. O preparador preserva esse campo, inclusive se estiver
desligado por cota. Se for necessário habilitar, isso requer a decisão de reabrir
e uma atualização revisada de `enabled=true`, incluída na mesma máscara/corpo ou
feita com nova precondição após reexportar. Nunca modificar admin_uids, chatRates,
chatProfiles, histórico ou saves para efetuar essa abertura.

O exportador foi preparado para separar as listas. No mesmo terminal, depois de
ler a lista original autorizada deste workspace:

```powershell
$taskSync = Get-Content .tools/approved-access.json -Raw | ConvertFrom-Json
$env:TECE_PILOT_ALLOWED_UIDS = $taskSync.allowed_uids -join ','
```

Para convidados:

```powershell
$taskChat = Get-Content .tools/chat-beta-prepared/client-chat-config.json -Raw | ConvertFrom-Json
$env:TECE_CHAT_AUDIENCE = 'allowlist'
$env:TECE_CHAT_ALLOWED_UIDS = $taskChat.allowed_uids -join ','
```

Para todas as verificadas:

```powershell
$env:TECE_CHAT_AUDIENCE = 'verified'
$env:TECE_CHAT_ALLOWED_UIDS = ''
```

Em ambos, `world-sync.json` continua com **exatamente os dois UIDs originais** e
intervalo 120 s. O exportador recusa convites que removam as originais, UIDs
inválidos/duplicados e ampliação da lista de sync. O manifesto distingue as
contagens; na política verified, não declara duas contas como limite do chat.
No GitHub Actions, as variáveis correspondentes foram preparadas, mas não foram
alteradas remotamente nesta revisão.

Somente depois do reteste/decisão, gerar o pacote com `tools/export-web.ps1` usando
Godot 4.7.2 e APPDATA isolado (restaurar a variável depois). Antes de publicar,
alinhar a identificação e os campos de rollout do carimbo ao estado realmente
confirmado; os da RC2 atual descrevem o chat ainda fechado. Testar privadamente
envio/recepção entre uma conta nova verificada e uma original, recusa da não
verificada, autoria/cooldown/administração e sync ainda restrita. Não promover
para a main por executar essa preparação local.

### Situação atual, acesso ao site e reversão

A RC2 no Sites continua **owner-only**. Convidar uma conta Firebase não concede
acesso ao Site privado; uma validação externa exige acesso à hospedagem também,
com decisão separada. O endereço oficial continua público e na 0.9.0.

Reversão: PATCH de `access_mode=allowlist` e cliente com `audience=allowlist` e a
lista aprovada. Emergência: PATCH só `enabled=false`. Não apagar perfis/mensagens/
saves. Conferir cota antes de reabrir. O Spark compartilha cota entre usos: falta
de cota pode afetar chat e sync, mantendo o solo local.

Não aplicado nesta revisão: deploy de regras Firebase, mudança em settings,
adição de convidados, alterações de administradores, faturamento ou sync público.
O site de revisão também continua privado. Testes positivos com contas reais
novas, cadastro/confirmar e-mail e operação pública dependem da etapa de acesso.

Em 01/11 foram aprovados oito testes locais de preparação/configuração,
separados dos 23 testes de regras no emulador e dos 45 checks Web anteriores.
Nenhum desses testes é aplicação de backend ou validação positiva de produção.

## Medições desta revisão, separadas das projeções

Em 31/10/2026, dois clientes Edge headless usaram o Firebase demo local, sendo
um UID novo fora da lista original. Durante 125 segundos sem mensagens novas,
foram observadas 14 e 15 requisições por cliente, sem reconsulta do histórico
completo. A contagem natural de reconciliação ocorreu nos dois. Os JSONs indicam
14/15 leituras diretas mínimas estimadas nesse intervalo; as leituras dependentes
das regras são a reserva do modelo, não telemetria de cobrança do emulador.

Fechar os painéis e aguardar sete segundos produziu zero novas requisições;
abas ocultas por sete segundos também produziram zero. Reabrir/retornar iniciou
a reconciliação. Três inserções observadas em ambos os clientes chegaram em
aproximadamente 1,0–18,0 s na repetição final; o caso mais lento veio depois do
período ocioso. O intervalo de polling ocioso é de 15 s, mas não é garantia de
tempo máximo de entrega; esta medição inclui agendamento/processamento do ambiente.
Isso mede entrega por polling local,
não RTT de produção ou desempenho físico. Os valores exatos da repetição final
estão em [chat-budget.json](validation/beta-rc2/chat-budget.json).

Os testes de falha/reconexão, backoff, remoção natural e controles com chat
somam 45 checks Web. Não houve uso de contas, mensagens, cobrança ou medição de
consumo real do projeto de produção. Aberturas, consultas vazias e metadados
foram contados no tráfego; o planejamento adiciona a reserva das regras.
