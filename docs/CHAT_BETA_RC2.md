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

1. Exportar as regras atualmente publicadas e obter, com acesso administrativo
   fora do jogo/repositório, o documento REST `chatSettings/global`, incluindo
   `updateTime`. A CLI acessível nesta revisão não tem uma conta administrativa
   ativa; portanto a leitura autenticada remota atual não foi confirmada.
   No terminal pessoal do projeto, executar
   `node node_modules/firebase-tools/lib/bin/firebase.js login --reauth`,
   concluir a autenticação diretamente no navegador e depois executar
   `node tools/export-chat-beta-baseline.mjs`. Esse último comando só faz GET e
   grava regras/settings em `.tools/firebase-current`, ignorado pelo Git. Não
   colocar senha, token, chave de serviço ou credencial administrativa no jogo,
   no repositório ou na conversa.
2. Preparar sem escrever remotamente:

   `node tools/prepare-chat-beta.mjs --base .tools/firebase-current/firestore.rules --settings .tools/firebase-current/settings.json --mode verified`

   O comando exige que tudo fora de `chatAccess()` coincida com as regras desta
   revisão. Se houver divergência, interrompe sem sobrescrever proteções.
3. Revisar e publicar somente as regras geradas via Firebase Console/CLI para o
   projeto `tece-island-285cd`. Nenhum passo exige habilitar faturamento.
   **Somente após decidir a abertura**, o comando é
   `node node_modules/firebase-tools/lib/bin/firebase.js deploy --project tece-island-285cd --only firestore:rules --config .tools/chat-beta-prepared/firebase.json`.
4. Para abertura a todas as verificadas, fazer PATCH em
   `https://firestore.googleapis.com/v1/projects/tece-island-285cd/databases/(default)/documents/chatSettings/global?updateMask.fieldPaths=access_mode`
   com corpo `{"fields":{"access_mode":{"stringValue":"verified"}}}` e
   acrescentar à URL `&currentDocument.updateTime=` seguido do `updateTime`
   recém-lido, codificado para URL. Isso preserva
   `enabled`, `allowed_uids`, `admin_uids` e todo o histórico. **Não substituir o
   documento inteiro nem usar o template antigo com `admin_uids: []`.**
5. No cliente, exportar com `TECE_CHAT_AUDIENCE=verified`; o servidor continua
   sendo a autoridade. `TECE_PILOT_ALLOWED_UIDS` conserva exatamente os dois UIDs
   originais da sincronização. `world-sync.json` não deve receber novos UIDs.
6. Para a alternativa inicial de convites: manter `access_mode=allowlist` (ou
   ausente), adicionar somente os convidados a `chatSettings/global.allowed_uids`
   e ao arquivo **global-chat.json** do cliente. Preservar a lista de sync com
   duas contas e a lista administrativa atual. A ferramenta de exportação padrão
   desta RC2 continua restrita às duas; preparar outra candidata de acesso após
   a decisão sobre o grupo, sem alterar mecânicas.
7. Reversão de acesso: PATCH somente `access_mode` para `allowlist` e retornar o
   cliente a `audience=allowlist`; emergência: PATCH somente `enabled=false`.
   Não apagar perfis, mensagens ou saves. Conferir a cota antes de reabrir.

Não aplicado nesta revisão: deploy de regras Firebase, mudança em settings,
adição de convidados, alterações de administradores, faturamento ou sync público.
O site de revisão também continua privado. Testes positivos com contas reais
novas, cadastro/confirmar e-mail e operação pública dependem da etapa de acesso.

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
