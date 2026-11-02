# Fechamento da candidata solo — 01/11/2026

Registro histórico da consolidação. O usuário posteriormente aprovou os últimos
ajustes e autorizou a promoção pública, mantendo chat fechado e sem declarar
campanha completa. Veja o [registro da publicação](PUBLICACAO_0_9_1_BETA_1.md).

Estado: **pronta para reteste manual; promoção ainda não autorizada**.
Nenhuma nova funcionalidade ou mudança no runtime do jogo nesta consolidação.

## Candidata preservada

- Versão **0.9.1-beta-rc.2**, jogo `7c254c1f8454d768228c171cf6fa040b5eb322dc`.
- [Site privado](https://tece-island-solo-beta.gustavotccandido.chatgpt.site/Tece-Island/),
  versão interna **2**, fonte Sites `60648858bd92fc1b4167195e2022652af82d570a`.
- PCK SHA-256 `e0f00a948d7406efef529a0899dad7ee8c2ba58e7dced408e0d47af0ba83d300`.
- Em 01/11, manifesto e 19 arquivos servidos conferidos novamente. Os 33 hashes
  de fontes registrados no manifesto correspondem ao commit congelado. Isso
  inclui piso/parede traseira e os cinco ajustes; não houve reexportação.
- Main `c790758`, oficial **0.9.0**/jogo `15ba9685` e tag `v0.9.0` preservados.
  O checkout do IDE mantém a alteração local em `project.godot`. Multiplayer
  permanece adiado em `a8ab12f`; nenhum serviço temporário foi reiniciado.

## O que está pronto e o que comprova

| Pedido | Estado técnico | Evidência existente |
| --- | --- | --- |
| Alimentos só na fogueira | Implementado, receitas/ingredientes/combustível preservados | Fabricação e cozimento reais nos testes preparados; busca e layout PC/toque |
| Visibilidade nas casas | Piso e parede traseira abaixo dos atores; revelação/vida/derrotas dos guardiões persistentes | Capturas finais, percurso pelos cantos e reabertura |
| Templo e loot | Quartos, colisões e câmera preservados, ator e drops visíveis | Percurso superior/inferior/lateral, baús, coleta e reabertura |
| Arrasto no PC | Move/troca pilha, cancela fora, mantém atributos/equipamento/ordem; toque mantém Mover/trocar | Slot 7→1, cancelamento, barra e AccountProgress/IndexedDB |
| Sono | Primeira conclusão de etapa atrasada concede um uso persistente; em dia não pula noite | Dois exemplos, repetição/reload, migração sem crédito inventado, combate/encontros e pós-vitória preparados |

Reaproveitados os resultados de 31/10: **31 suítes/864 checks nativos**, 23 testes
de regras no emulador, 11 checks REST de chat e 128 checks Web funcionais
(38 interiores/inventário + 20 fabricação + 12 saves + 45 chat + 13 cliente
completo), além de oito medições/checks do orçamento local. Eles são testes
técnicos, frequentemente com cenário preparado ou emulação, não uma campanha
humana ou exploratória concluída na RC2.

Hoje só foram executadas verificações justificadas: integridade/proveniência
remotas, preservação das refs e **oito testes locais de preparação de acesso**.
Esses testes novos verificam listas distintas de chat/sync, convites sem ampliar
sync, manifesto, PATCH condicional, manutenção de convidados antigos e recusa de
regras inesperadas. Não acessam Firebase nem iniciam clientes de jogo.

[Resultados anteriores](validation/beta-rc2.json),
[revisão atual](validation/beta-rc2/final-review.json),
[preparação de acesso](validation/beta-rc2/chat-rollout-preparation.tap).

## Campanha e bugs novos

**Campanha exploratória não executada por limitação da ferramenta.** O ciclo de
controle está encerrado: a revisão automática rejeitou até o inventário de
janelas como repetição desse ciclo. Não houve outra tentativa ou método de
controle para contornar a rejeição. Não foi criado mundo exploratório.

Nenhum bug adicional de jogabilidade foi confirmado nesta rodada. A falta de
percurso não aprova a ausência de bugs. Novas ocorrências aguardam avaliação do
usuário antes de correção. [Registro](RELATORIO_EXPLORATORIO_RC2.md).

## Bloqueios reais e pendências

1. **Aceite manual da RC2:** [roteiro curto com resultados esperados](RETESTE_MANUAL_RC2.md),
   incluindo os dois exemplos de sono, reabertura, PC/celular, áudio e suspensão.
2. **Campanha completa desta RC2:** vitória condicionada aos encontros e
   Continuar explorando, com relato do dia/etapa real e eventuais falhas. Pode ser
   fornecida pelo usuário; não depende de novas tentativas do controlador.
3. **Acesso do chat:** escolher convidados ou todas as verificadas, autenticar
   um administrador, conferir/aplicar regras/settings e compilar o cliente com
   essa mesma política. A nova conta real precisa enviar/receber após aplicação.
   A CLI desta revisão continua sem sessão; nenhuma regra/settings foi publicada.
4. **Autorização final e identificação oficial:** ainda aguardadas. Nenhum merge,
   tag nova, alteração de público do Site ou deploy oficial foi feito.

Não há novo defeito bloqueador do jogo demonstrado pelas verificações técnicas.
Os itens acima continuam como condições de lançamento, não como testes aprovados.

## Chat mantido na beta

O chat existente continua configurado no pacote para as duas contas originais.
Para uma conta nova verificada, faltam **cliente e backend concordarem sobre seu
acesso**, além da sessão com e-mail confirmado. A candidata hospedada continua
owner-only: convite Firebase não concede acesso ao Site privado.

| Opção | Cliente | Firestore chatSettings/global | Sync de mundos |
| --- | --- | --- | --- |
| Convidados | enabled=true; audience=allowlist; allowed_uids inclui originais e convidados | enabled=true; access_mode=allowlist; lista atual mesclada com convidados | Mesmos dois UIDs originais e intervalo 120 s |
| Todas verificadas | enabled=true; audience=verified | enabled=true; access_mode=verified; manter lista existente e admin_uids | Mesmos dois UIDs originais e intervalo 120 s |

Regras preparadas em [firestore.rules](../firestore.rules); as regras de mundos
e a administração permanecem preservadas. Backend não foi aplicado por esta
revisão. [Comandos exatos, PATCH, limites e autenticação](CHAT_BETA_RC2.md).
Recomendação inicial: até **cinco contas no total**, com meta de até dez
horas-cliente/dia, acompanhamento e sem faturamento. É uma meta operacional,
não um limitador global implementado. Não abrir irrestritamente sem aprovar o
risco de cota; se a cota compartilhada acabar, chat e sync podem ficar indisponíveis
enquanto o solo local permanece utilizável.

## Publicação preparada, a executar somente após resultado e autorização

1. Consolidar o relato manual e a campanha. Relatar novos bugs sem corrigir;
   decidir com o usuário quais precisam ser resolvidos antes de promover.
2. Escolher a política do chat e executar os passos administrativos documentados.
   Validar uma conta nova verificada, uma não verificada, autoria, envio/recepção
   e manutenção da sync/administração. Não habilitar faturamento.
3. Definir com o usuário o identificador oficial. Em worktree própria, preparar
   integração da RC2 sem alterar o checkout do IDE. Alinhar carimbo, menu, shell,
   manifesto e testes de versão; hoje eles identificam deliberadamente a RC2.
   Não incluir funcionalidades além do escopo aprovado.
4. Gerar o pacote final com as duas contas de sync preservadas e a política de
   chat escolhida. Executar checks afetados/obrigatórios e conferir v9/tarefas 2,
   hashes, ausência de fixtures/credenciais administrativas e recuperação.
5. **Só com autorização explícita:** integrar na main, criar a tag aprovada e
   publicar no GitHub Pages. O workflow publica em push na main e também aceita
   workflow_dispatch: não acionar nenhum dos dois antecipadamente. Ele não deve
   ser usado para publicar um rótulo RC2 como se fosse a versão final aprovada.
6. Conferir no endereço oficial versão e arquivos servidos, login/solo/chat,
   armazenamento e acesso. Registrar commit/tag/deploy e quaisquer pendências.

## Recuperação pronta para v9

[Procedimento](RECUPERACAO_BETA_V9.md): preservar originais/exportações e publicar
um cliente compatível com **v9** no mesmo endereço antes de tentar recuperação.
A oficial 0.9.0/RC1 recusa v9; não editar o número do save nem limpar o site.

Artefato local congelado disponível: `.tools/beta-rc2-site.tar.gz`, SHA-256
`d1beae540e1393266023052a9ca704bb87f1de5919f2c3314e0f3562282d2f87`.
É um pacote v9 de recuperação/reteste, não uma autorização para substituir a
oficial. Conferir o hash e servir no mesmo endereço/origem somente após decisão.
O commit `7c254c1` e a fonte Sites `60648858` permitem reconstrução com as mesmas
configurações autorizadas. Testes de migração usaram cópias, nunca os saves principais.
