# Piloto de consumo do chat — 0.8.2-chat-budget-pilot.1

Base: `main` em `b94a68a`, branch `perf/chat-read-budget`. Publicação oficial 0.8.2 preservada. Meta desta etapa: consumo e estabilidade antes da beta de 25/10.

## Origem das 3.100 leituras

Com 50 mensagens, chat aberto e nenhuma novidade, uma hora estável da 0.8.2 fazia:

| Operação | Leituras diretas/h |
| --- | ---: |
| Contador global a cada 5 s | 720 |
| Histórico de 50 a cada 120 s | 1.500 |
| Perfil + configurações a cada 120 s | 60 |
| Total direto | 2.280 |
| Reserva: `chatSettings/global` nas regras de cada um dos 810 pedidos | 810 |
| Estimativa total | **3.090 ≈ 3.100** |

Não era uma medição de faturamento. A abertura e os envios acrescentavam leituras; cada envio bem-sucedido também provocava uma releitura completa no remetente.

## Estratégia implementada

- Primeira abertura: perfil, permissões e últimas 50 mensagens. Sem duplicar a leitura inicial do perfil/configurações.
- Depois: consulta `sequence > cursor`, descendente, limitada a 50. Inclusive cursor zero. Elimina o heartbeat do contador; uma consulta vazia já custa o mínimo de uma leitura.
- Intervalo de 5 s; após 60 s sem mensagens recebidas/enviadas, passa a 15 s. Uma mensagem ou retorno à aba retoma o intervalo de 5 s. Latência de projeto: até 5 s em conversa e até 15 s ocioso, mais rede/execução. Não é garantia de prazo com erros ou suspensão do sistema.
- A cada 120 s: `count()` entre a menor e a maior sequência do cache bruto, com `limit: 50`. Se a contagem mudou, busca novamente as últimas 50. Perfil e permissões têm um prazo independente de 120 s.
- Remoções aparecem em até 120 s + próximo poll (até 15 s) + rede. Enquanto fechado/oculto, são conciliadas ao voltar se o prazo venceu. Compatível com o delete administrativo da 0.8.2, sem tombstones nem escritor adicional.
- O envio continua consultando o perfil e usando o batch atômico com contador, rate limit e precondições. Depois recebe incrementalmente, sem baixar 50 mensagens a cada envio.
- Uma única instância autoload, timer e ciclo de leitura; operações de escrita aguardam a leitura. Sem SDK, conexão persistente ou assinatura por painel/cena. IDs deduplicam e o cache continua limitado a 50.
- Fechar, trocar de cena ou ocultar a aba interrompe novos ciclos. O pedido já em voo pode terminar; antes da etapa seguinte, o serviço revalida painel, visibilidade e sessão. Rascunhos de mensagem/edição permanecem na interface; logout/troca de UID limpa os dados da sessão anterior e cancela pedidos.
- Erros de transporte/permissão/cota são visíveis e têm backoff de 10 a 240 s. Eventos repetidos de foco não furam o backoff de cota/permissão. Falha de contagem não é convertida em releituras de 50; conserva o cache, sinaliza erro e tenta novamente com backoff. Falha de índice/consulta incremental tem uma recuperação limitada pelo histórico, com aviso e backoff também quando a recuperação funciona; um erro persistente não pode provocar 50 leituras a cada 5 s.

A contagem usa o cache **antes do filtro de silenciamento**. Pelas regras atuais, uma mensagem não pode ser editada mantendo a sequência: só um novo envio com sequência superior pode ocupar o slot. Dentro de limites congelados, apenas exclusão/reciclagem reduz a contagem; inserções posteriores não escondem uma exclusão. Isso pressupõe que alterações administrativas no console respeitem o esquema. Edição arbitrária via Admin SDK/console não é detectada por igualdade de contagem.

### Listeners avaliados

Um listener de últimas 50 mensagens seria mais econômico ocioso (snapshot inicial e depois mudanças) e daria remoção mais rápida. Entretanto, a integração atual usa autenticação REST, tokens em memória e `HTTPRequest` do Godot em ambas as plataformas. O Web não tem uma sessão Firebase JS SDK que possa ser entregue diretamente a `onSnapshot`; um ID token não é um custom token. O nativo também não tem um SDK Firestore/stream gRPC integrado. Adotar apenas no Web exigiria migrar autenticação e manter dois transportes, com testes de persistência/logout adicionais. Não foram usados provedores internos de autenticação nem WebChannel não documentado.

Nesta etapa foi mantido o transporte REST comum e reduzido o consumo sem alterar login, saves ou regras. Listener com integração oficial de autenticação nas duas plataformas fica como evolução separada, caso o grupo/tempo de uso exija mais economia.

## Projeção, incluindo regras

Valores de planejamento; não medição do painel Firebase. Hora estável, 50 mensagens, sem erros/retries, um cliente conectado e painel visível:

| Cenário | 0.8.2 | Piloto otimizado |
| --- | --- | --- |
| Ocioso | 3.090 leituras/h | **660/h**: 240 incrementais + 30 contagens + 60 metadados + reserva de 330 regras |
| Conversa contínua, 6 mensagens/min no grupo, até 1 por poll | ~3.750–3.810/h de recepção, antes dos envios | **1.620/h** de recepção: 720 incrementais + 30 contagens + 60 metadados + 810 regras |
| Fechado / aba oculta | 0 novos ciclos | 0 novos ciclos; no máximo o pedido já iniciado termina |
| Retorno sem reiniciar processo, sem prazos vencidos | contador + consulta se houver novidade | incremental: mínimo 2 leituras com reserva de regras |
| Retorno, prazos vencidos, sem novidade/remoção | pode reler 50 + metadados/contador | incremental + contagem + 2 metadados: aproximadamente 8 leituras |
| Nova sessão/processo, histórico cheio | aproximadamente 61 na abertura | aproximadamente 55 na abertura |
| Exclusão detectada | releitura periódica já inclusa | contagem + snapshot de até 50, uma vez por divergência |

Primeira hora ociosa: planejar aproximadamente **730**, incluindo abertura (~55) e primeiro minuto em 5 s (~16 adicionais), em vez de tratar 660 como custo completo de entrada. Intervalos se contam após a resposta e o timer tem granularidade de 0,5 s; rede pode reduzir a frequência efetiva e aumentar a latência. Não extrapolar uma amostra curta que inclui inicialização como se fosse uma hora estável.

Na recepção ativa antiga, às 3.090 somam-se 330–360 consultas incrementais de uma mensagem e suas regras (660–720 leituras). A faixa depende de quantas novidades coincidem com as 30 releituras periódicas já contabilizadas. Envios, disputa por slot e deletes são adicionais em ambas as versões.

Com várias mensagens no mesmo poll, acrescentar `max(0, documentos retornados - 1)` às leituras de recepção. Um envio faz **3 writes**; reservar até **12 leituras adicionais por envio**, incluindo perfil/contador, refresh antecipado e dependências das regras do batch, sem disputa/retry. Isso é margem de planejamento, não contagem faturada observada. Regras consultam settings, perfil, contador, rate e slot; documentos dependentes repetidos podem ser reaproveitados na avaliação. Falhas negadas também podem consumir leituras. Conflitos/retries, reaberturas de processo e remoções devem consumir uma margem adicional.

### Pequenos grupos — cenários hipotéticos, sem ampliar o piloto

Sessão de 2 h/dia por pessoa, uma abertura por dia, 50 mensagens. Ativo = 6 mensagens/minuto **no grupo inteiro** (720 envios/dia), recepção a 5 s e reserva de 12 leituras por envio. Não são 6 mensagens por pessoa/minuto.

| Clientes | Ocioso, leituras/dia | Ativo, leituras/dia | Writes de chat/dia no ativo |
| --- | ---: | ---: | ---: |
| 2 | ~2.782 | ~15.230 | 2.160 |
| 5 | ~6.955 | ~25.115 | 2.160 |
| 10 | ~13.910 | ~41.590 | 2.160 |

Planejamento: separar **20 mil leituras/dia para saves** e limitar chat a aproximadamente 30 mil, dentro das 50 mil leituras gratuitas/dia; reservar também a maior parte das 20 mil writes/dia para saves. Cinco clientes ativos nesse cenário deixam ~4,9 mil leituras de margem além da reserva de saves; dez já excedem o orçamento de chat. Clientes = abas/aparelhos simultâneos, não contas únicas. Duas contas abertas em PC e celular podem representar quatro clientes. Duas contas ociosas 24 h já usariam ~31.680 leituras/dia, antes dos saves. O intervalo não torna uso ilimitado gratuito.

Não foi habilitado faturamento, Cloud Functions, TTL, backup gerenciado ou outro recurso pago. O piloto permanece nas mesmas duas contas. Os grupos acima não foram adicionados às permissões.

Fontes oficiais: [preços, mínimos e dependências das regras](https://firebase.google.com/docs/firestore/pricing), [contagens, índices e regras de agregação](https://firebase.google.com/docs/firestore/query-data/aggregation-queries), [REST runAggregationQuery](https://firebase.google.com/docs/firestore/reference/rest/v1/projects.databases.documents/runAggregationQuery), [listeners](https://firebase.google.com/docs/firestore/query-data/listen).

## Firebase e preservação dos mundos

**Não há atualização de regras nem configuração de backend necessária para este piloto.** `firestore.rules` permanece igual à main, incluindo `create, update` do próprio `chatProfiles/{uid}` e validações de acesso/apelido. Agregação respeita a regra existente de list com limite de 50. Usa somente o índice automático de `sequence`, já utilizado no chat; índice desabilitado é erro a corrigir no índice, não motivo para abrir as regras.

Não publicar/substituir `chatSettings/global`; conservar `allowed_uids` e `admin_uids`. Nenhuma migração de coleção, mundo, backup ou documento. Arquivos de saves e regras de mundos são conferidos por hash no pacote privado. Silenciamento, autoria e administração continuam por UID; mensagens antigas conservam o apelido de envio. Defaults públicos permanecem desligados no código-fonte e a release oficial não foi republicada.

## Reprodução dos testes

Com Godot 4.7.2, Java/emulador local e dependências instaladas:

1. Importar o projeto: Godot `--headless --path . --editor --import --quit`.
2. Iniciar Firestore Emulator `demo-tece-island` em `127.0.0.1:8085`, com `firestore.rules`. Definir `FIRESTORE_EMULATOR_HOST=127.0.0.1:8085` e `GODOT_EXE`.
3. `node --test --test-concurrency=1 tests/firestore-rules.test.mjs tests/chat-rules.test.mjs`.
4. `tools/validate-saves.ps1 -Godot <Godot>`; Godot `--headless --path . --script tests/validate_controls.gd`.
5. `tools/export-chat-pilot.ps1 -Godot <Godot> -AllowedUid 'chat-a,chat-b,chat-admin' -Emulated`; `node tools/chat-browser-validation.mjs`.
6. Godot `--headless --path . --script tests/validate_chat_transport.gd`, ainda contra o emulador.
7. Exportar também o baseline `b94a68a`/0.8.2 em outro diretório, verificar igualdade de `global_chat.gd` e `chat_client.gd`; `node tools/chat-budget-validation.mjs <diretório-do-export-baseline>`. Executar depois dos outros testes de chat: a fixture limpa somente o banco demo.

O comparativo mantém ambos os painéis abertos e observa 135 s reais sem mensagens, depois novidade, fechamento, aba oculta, retorno, exclusão física com autor silenciado, fechamento durante request e backoff de cota. Registra pedidos/documentos reais do HTTP; converte em leituras **estimadas** e reserva de regras. Não mede cobrança, rádio mobile, suspensão real de Android/iOS nem latência de produção.

## Resultados executados — 17/10/2026

Build do jogo: `f24c907d7ab0bc6a24428d036b02c0c044ba44a1`. Godot 4.7.2, Node 22.21.0, Edge headless e Firestore Emulator 1.19.8 local. O baseline emulado usa os mesmos `global_chat.gd` e `chat_client.gd` da main `b94a68a` (igualdade de conteúdo conferida), exportados anteriormente para o piloto .3. A identificação visual do baseline é .3; o algoritmo comparado é o da 0.8.2 pública.

| Amostra automatizada | Antes: pedidos / diretas estimadas / reserva de regras | Depois: pedidos / diretas estimadas / reserva de regras |
| --- | --- | --- |
| Inicialização, 50 mensagens | 6 / 55 / 6 | 3 / 52 / 3 |
| Ocioso por **135,002 s**, sem novidades | 28 / 77 / 28 | 19 / 19 / 19 |
| Conversa, 3 mensagens novas | 9 / 9 / 9 | 6 / 6 / 6 |
| Retorno à aba, uma mensagem pendente, prazos ainda válidos | 2 / 2 / 2 | 1 / 1 / 1 |

Na amostra ociosa: **105 → 38 leituras estimadas**, incluindo reserva de regras; documentos efetivamente retornados **77 → 2**. O piloto fez 16 incrementais vazios, uma contagem e dois GETs de metadados; nenhuma consulta de histórico. A redução curta (~64% com reserva) difere dos ~79% da projeção estável porque a janela inclui o primeiro minuto em 5 s. Não é medição da cota/cobrança real Firebase.

Fechado e oculto: zero pedidos nas respectivas janelas quietas de 6 s, comprovado por contadores antes/depois. O campo `phases.closed` do registro inclui também a **reabertura ao fim** (um pedido por cliente); não deve ser interpretado como pedido enquanto fechado. O teste de fechamento durante uma requisição também confirmou ausência de etapas subsequentes.

Latências locais do piloto: **0,586–5,248 s** nas quatro entregas naturais entre duas sessões (lobby e partida pausada); **8,264 s** para a primeira novidade depois de ocioso, depois **5,469 e 5,475 s** na conversa do comparativo. Retorno à aba: **0,544 s** no comparativo e **3,454 s** na suíte funcional. Remoção administrativa natural: **121,555 s**, sem forçar consulta ou fechar painel. São poucas amostras em rede local/emulação, não percentis nem resultados físicos/produção.

Verificações aprovadas nesta execução:

- **22 testes de regras** de saves/chat, incluindo agregação limitada, identidade verificada, UID fora do piloto, renomeação somente do próprio perfil, atomicidade, cooldown e administração.
- **155 verificações de saves** em 9 suítes; mundos, backups, conflitos, handoff e isolamento por UID.
- **11 verificações REST no Godot nativo**, incluindo `count()` autenticado, incremental vazio, apelido, envio atômico e cooldown.
- **7 verificações de controles**.
- **45 verificações Web** em duas sessões desktop/mobile emulado: recebimento automático, pausa, rascunho na troca de cena, apelido entre sessões, mutes por UID, rolagem, falhas, remoção natural, logout e máximo de um pedido simultâneo por sessão.
- **22 verificações de consumo/estabilidade** comparando dois builds: 135 s ocioso, 3 mensagens, fechar/ocultar/retornar, exclusão física com autor silenciado, fechamento em voo, 429 com tempestade de eventos de foco e 400 persistente. Ambos os erros respeitaram backoff; cada tentativa de consulta recusada teve no máximo um fallback completo, sem ciclo de 50 leituras a cada 5 s.
- **11 verificações do pacote Web real**, incluindo engine dividido e íntegro, IndexedDB/reload, login sem rede, viewport mobile e recusa de parte corrompida. Não houve login positivo automatizado em produção.
- Auditoria do pacote: mesmos dois UIDs; código de saves e regras de mundos preservados; chat/shell iguais ao commit exportado, conferidos por SHA-256; fixture de emulação excluída.

Registros resumidos: [chat-budget-2026-10-17.json](validation/chat-budget-2026-10-17.json). As verificações acima são automação local e preservam seu registro histórico. O reteste físico foi concluído posteriormente conforme relato do usuário abaixo; medição de faturamento no console Firebase continua sem confirmação.

## Piloto privado disponível

[Abrir 0.8.2-chat-budget-pilot.1](https://tece-island-sync-pilot.gustavotccandido.chatgpt.site/Tece-Island/)

- Deploy **succeeded**, versão de hospedagem **5**, em 17/10/2026 às 04:13 UTC (01:13 em São Paulo).
- Mesmo endereço/origem e audiência privada anterior (somente proprietário); o jogo conserva os mesmos dois UIDs autorizados. Nenhum acesso foi ampliado.
- [Branch enviada ao GitHub](https://github.com/GustavoTc-Web/Tece-Island/tree/perf/chat-read-budget); build do jogo `f24c907d7ab0bc6a24428d036b02c0c044ba44a1`. Commits posteriores de documentação/verificação não alteram o jogo exportado.
- Fonte da hospedagem: `8c60c1f3937e3d97726f3278832449acb1f71b5d`. Manifesto servido conferido integralmente e `index.pck` remoto idêntico ao local: SHA-256 `058cba012ae4b333fed502c28c2450e5055ab888e84b18358d7af1fe86b24ec3`.
- Oficial 0.8.2/GitHub Pages e main preservados; nenhuma alteração/deploy Firebase, billing ou migração de saves.
- Reversão do reteste: republicar a versão privada **4** da hospedagem (piloto .3, fonte `cad22d2fcb8bbaf5d58e160e56d620d11ad102ab`), preservando regras, `chatSettings/global` e dados. Esta etapa não exige reversão da publicação oficial.

## Reteste manual relatado pelo usuário

Em 17/10/2026, o usuário informou: “Concluí o reteste físico do 0.8.2-chat-budget-pilot.1 e não encontrei novos problemas.” Autorizou integrar à main e publicar no endereço oficial. Registro: **reteste manual relatado pelo usuário**, sem observação independente do assistente e sem atribuir resultados separados a cada aparelho/caso. O relato conclui o reteste deste piloto para a publicação 0.8.3. Os valores de consumo continuam estimativas; não houve confirmação de faturamento medido.

O roteiro disponibilizado para esse reteste foi:

1. PC + celular, uma conta em cada: confirmar o selo **0.8.2-chat-budget-pilot.1** (recarregar normalmente se ainda mostrar o anterior; preservar os dados do site). Abrir chat no lobby, esperar **mais de 2 minutos** sem enviar, então enviar nos dois sentidos, sem recolher/atualizar. Repetir em partida. Esperado: até 15 s ocioso e depois aproximadamente 5 s + rede; nada duplicado.
2. Digitar rascunho, receber mensagens, recolher/reabrir, entrar/sair da partida e bloquear/desbloquear o celular ou trocar de aba por >2 min. Confirmar rascunho, recepção ao voltar e rolagem/aviso de novas mensagens; abrir/fechar repetidamente.
3. Modo avião/rede desligada com rascunho; restaurar conexão. Confirmar erro visível, recuperação automática sem reenviar texto e sem duplicar mensagens. Teclado real: enviar/recolher acessíveis em paisagem/retrato.
4. Renomear, recarregar/entrar em outro aparelho, enviar; silenciar esse UID e renomeá-lo novamente. Confirmar persistência e silenciamento. Logout/troca de conta deve limpar rascunho/histórico da anterior.
5. Conta administrativa **já autorizada**: remover uma mensagem ainda visível (também testar autor silenciado) e confirmar desaparecimento no outro aparelho em até ~135 s + rede; repetir após suspensão. Não conceder administração a outra conta para o teste.
6. Conferir um ciclo de save/sincronização PC → celular → PC sem conflito falso e com mundo/backups preservados. Regressão física curta, sem assumir que os testes da release anterior aprovam este build.

O relato geral acima é a evidência manual desta etapa; não se converte em uma lista de medições físicas independentes. Para medir consumo futuro, aferir o painel de uso Firebase antes/depois de uma janela isolada, anotando aparelhos, duração, saves e mensagens; o painel agrega operações de outros clientes e pode ter atraso.
