# Beta solo — candidata 0.9.1-beta-rc.1

Revisão iniciada em 29/10/2026 na branch `release/solo-beta-rc1`, a partir de
`main` `c790758`. A oficial 0.9.0 permanece no GitHub Pages, commit do pacote
`15ba9685`, tag `v0.9.0`. O checkout do IDE e seus arquivos locais não foram
alterados. Esta candidata é um ambiente privado de reteste, anterior à beta pública.

## Escopo e correções

Sem novas mecânicas, combate multiplayer ou PvP. Campanha, receitas, relógio,
encontros e equilíbrio da 0.9.0 preservados.

- Reproduzido erro ao copiar diagnóstico no lobby: `GameMenu` acessava
  `account_store` em um menu que não possui mundo. Corrigido o acesso opcional;
  copiar ajuda funciona antes e durante uma partida, sem credenciais.
- Dados e salvamento não recomenda mais aguardar sincronização para contas
  locais. O botão indica “Salvar neste aparelho”; contas autorizadas mantêm a
  sincronização existente, seus intervalos e conflitos.
- Entrada, ajuda, versão e documentação identificam a beta solo, créditos,
  salvamento local e indisponibilidade do multiplayer, sem data prometida.
- Texto antigo de objetivo “bolsa nível 3” corrigido: a campanha aprovada usa
  nível 1 no dia 2; níveis superiores continuam opcionais.

## Campanha e saves

Dia 1: machado/picareta de madeira ou melhores, espada de pedra e fogueira.
Dia 2: ferramentas de pedra, bolsa nível 1, armadura, duas refeições e cantil
com duas doses. Dia 3: arco, oito flechas, três refeições, três doses e mapa na
torre da Serra em qualquer noite 3+. Dia 4: Templo da Névoa; dia 5: Cinzas e Eco,
individualmente registrados. Dia 6: reparo e suprimentos; noite 6 ou posterior:
ativação, duas formações e Guardião; amanhecer seguinte: resgate. O dia 7 é a
vitória mais cedo; atraso não impede concluir em dias posteriores.

Preparação orienta, sem novos bloqueios. Componentes ficam protegidos no Diário;
fabricação é permanente, mas alimentos/água/equipamento são condições atuais.
Templos conservam inimigos vencidos; sair durante ataque final exige reativar,
preservando conquistas/reparo. Após vitória, Continuar explorando conserva mundo.

Formato atual: save 8, campanha 2, tarefas 1. Usar somente cópias nos testes.
Migração conserva originais e backups; recuperação explícita, conflitos e
isolamento por conta/mundo permanecem. A candidata tem origem separada: saves
locais do endereço oficial não aparecem automaticamente nela. Não limpar dados
do navegador nem copiar progressos entre contas.
As duas contas autorizadas continuam ligadas à nuvem existente; seus mundos
remotos podem aparecer também na candidata. Para o reteste, criar um mundo
novo de teste. A automação desta revisão não abriu nem gravou mundos de produção.

Recuperação: [procedimento v8](RECUPERACAO_0_9_0.md) e
[exportação de dados](RECUPERAR_MUNDO.md). Republicar cliente compatível no mesmo
endereço é a primeira opção; voltar apenas ao aplicativo 0.8.3 não abre saves v8.

## Acesso e decisões de lançamento

Solo: qualquer conta Firebase com e-mail confirmado. Exige internet para login;
não há login convidado. Para novas contas, mundos ficam localmente no mesmo
endereço/navegador/aparelho, separados por UID e ID. Remover armazenamento perde
essas cópias. A exportação está no Menu do lobby.

Chat e sincronização: somente as mesmas duas contas autorizadas; sem ampliação
das regras ou permissões, alteração dos dados Firebase ou faturamento. As demais
contas não fazem consultas Firestore desses recursos nem recebem falsas falhas
de permissão ao jogar solo. Cadastro público e envio de confirmação continuam
sujeitos à disponibilidade/limites do Firebase Auth.

Decisão para a beta pública: manter chat/sync fechados como nesta candidata ou
revisar separadamente permissões, consumo e moderação. Não é necessário ampliar
esses recursos para publicar o solo. A promoção ao endereço oficial aguarda o
reteste final do usuário.

## Multiplayer preservado

[Estado e pendências](MULTIPLAYER_ADIADO_BETA.md), branch
`feat/multiplayer-pilot`, sem inclusão nesta candidata. Os serviços temporários
foram encerrados pelo Stop existente; já estavam ausentes, com RAM anterior
perdida, antes desta revisão. Serviços solo/Firebase não foram encerrados.

## Reteste físico final

1. PC: entrar/criar conta e confirmar e-mail; criar mundo, coletar, fabricar,
   equipar, comer/beber; abrir Diário/HUD, ajuda e copiar diagnóstico.
2. Fechar navegador e reabrir o mesmo perfil/conta/endereço: conferir mundo,
   bolsa, relógio, construções e tarefas; exportar cópia. Trocar de conta e
   conferir isolamento. Nas contas autorizadas, conferir sincronização/conflicto.
3. Celular em paisagem: andar/atacar com dois dedos, coletar, fabricar, reorganizar,
   colocar estrutura e usar poço. Girar, abrir teclado de login/nome, suspender
   durante movimento e retornar: entradas devem parar e progresso permanecer.
4. Som/silenciar, pausa, retorno ao menu; nas contas autorizadas, digitar chat
   sem movimentar/atacar. Conferir campanha até vitória e continuar explorando.

Som audível, teclado real, suspensão do sistema e desempenho físico não são
aprovados por emulação. O único relato humano anterior é a campanha completa
do piloto solo .4, vencida no dia 7 sem bugs relatados, sem aparelho especificado.

## Vídeo de 60–90 segundos

0–10 s: título/clareira, “beta solo”. 10–25 s: coleta, inventário e fabricação.
25–40 s: fogueira, comida, poço e necessidades. 40–55 s: exploração de biomas,
minimapa e tarefas/Diário. 55–70 s: mapa na torre e combate em um templo.
70–85 s: sinalizador, Guardião e resgate; fechar com exploração após vitória.
Usar gravações reais; não apresentar chat/sync como públicos, multiplayer, PvP,
ranking ou voz como disponíveis. Acelerar o tempo somente na edição do vídeo,
sem representar uma automação como partida humana.

## Evidências

[Candidata privada](https://tece-island-solo-beta.gustavotccandido.chatgpt.site/Tece-Island/):
**0.9.1-beta-rc.1**, commit do jogo `3450cabfef156e46d2df3b946913455fd5c95e0a`.
Fonte Sites `e9ea43e3eda9ffc7a3f6c9e540232a0f0d37d790`, versão interna 1;
deploy `appgdep_6ae3da884bf08191b6aea3bb09767a50` **succeeded**, 29/10 às
20:45 BRT. SHA-256 do PCK:
`0985ad616f5b9c5e1f1fb12c23c9a81221fdf4d64f4f0c1e431c54719dea464d`.
Manifesto e 19 arquivos servidos conferidos, com a inserção de HTML do provedor
identificada sem remoção do shell original.

Resultados: [resumo](validation/beta-rc1.json),
[pacote compilado](validation/beta-rc1/beta-pack.json),
[PC](validation/beta-rc1/beta-release-pc-world.png) e
[mobile emulado](validation/beta-rc1/beta-release-mobile-world.png).
As 25 suítes iniciais tiveram 714 verificações; o novo teste de acesso adicionou
12, totalizando 726 em 26 suítes. Controles/mobile/apresentação foram repetidos
após os ajustes. Regras: 22 casos sem skips, com transportes de saves/chat no
emulador. Campanha Web, tarefas, torre, persistência, controles, login e fluxo
novo no pacote final somaram 246 checks antes da suíte de chat.
O chat foi executado em duas sessões Web contra Auth/Firestore demo locais,
incluindo digitação durante o solo, recebimento com pausa, suspensão simulada
das consultas ao ocultar a aba, retorno sem perder rascunho e reconciliação
natural de remoção. Não foram usadas contas nem mensagens de produção.
Foram 44 checks do chat, totalizando 290 verificações Web, além de sete no
login da candidata efetivamente publicada e vinte de integridade dos arquivos.
No endereço publicado, Firebase real rejeitou credenciais inválidas nos dois
formatos, com mensagem clara e nova tentativa disponível. Isso não é login
positivo, cadastro real nem confirmação por e-mail.

A primeira automação de publicação encontrou HTTP 401 em dois AudioWorklets:
a rota de autorização por header do teste não alcançava suas requisições.
O teste seguinte carregou como Blob os mesmos bytes servidos e autenticados,
mantendo a credencial fora do jogo e sem alterar o cliente ou o acesso do site.
Passou sem erros de script. Essa adaptação é exclusiva do QA; ouvir o áudio
na sessão normal autenticada do usuário permanece no roteiro físico.

O fluxo novo no pacote de produção usou respostas Auth simuladas **somente no
navegador**, sem enviar identidade sintética ao Firebase. Criou mundo, abriu o
solo, andou, gravou a posição pelo callback de ocultação e manteve o v8 no reload;
nenhuma requisição Firestore foi feita para essa conta. O teste anterior que
disparava somente `blur` não invocava o salvamento de ocultação: foi corrigido
o instrumento, sem alteração no salvamento do jogo. Fechar/reabrir um perfil
persistente foi validado separadamente pela fixture IndexedDB/AccountProgress.

Medição em Edge headless neste computador, com renderização de software permitida,
70 amostras de monitores Godot a cada 100 ms por cenário:

| Cenário | FPS mediano PC / mobile emulado | Mínimo PC / mobile | TIME_PROCESS p95 amostrado PC / mobile |
| --- | --- | --- | --- |
| Clareira em movimento | 60 / 60 | 57 / 59 | 33,8 / 31,9 ms |
| Bioma expandido | 60 / 60 | 60 / 60 | 17,0 / 19,6 ms |
| Encontro de templo | 59 / 57 | 55 / 34 | 27,1 / 63,9 ms |

Esses p95 são amostras do monitor TIME_PROCESS, não um traço de todos os quadros;
FPS vem do Engine. Fixture: PC 1280×720/DPR1; mobile 852×393/DPR2. No pacote
final local, login disponível em 5,15 s na primeira execução PC e 2,27 s na
segunda mobile emulada, sem limitar banda e com caches diferentes. Não comparar
esses números como velocidade relativa de aparelhos. Sem otimização gráfica ou
ajuste de equilíbrio baseado só em emulação; o templo é o cenário prioritário
para avaliação física. [Amostras](validation/beta-rc1/beta-performance.json).
A tabela usa a repetição final, com emuladores e demais suítes já encerrados.
A primeira rodada teve 54/45 FPS medianos no templo, com outras atividades de QA
concorrentes; [registro inicial](validation/beta-rc1/performance-first-pass.json).
O código do cliente foi o mesmo: a diferença não é ganho de uma otimização.
Na primeira tentativa de repetição, o benchmark enviou E instantaneamente e não
iniciou o templo; o instrumento passou a manter a tecla por 120 ms e verificar
o mapa antes do templo. A repetição completa teve seis cenários e nenhum erro.
Na candidata publicada, o login apareceu em 8,24 s no formato PC e 6,99 s em
mobile emulado, duas execuções sem limitar banda, sem representar a rede/aparelho
do usuário. [Verificação publicada](validation/beta-rc1/published-browser.json).

O projeto público Auth confirmou o domínio oficial autorizado. O novo domínio de
teste não foi adicionado: confirmação/recuperação mantém o retorno oficial
existente. Após confirmar e-mail, voltar manualmente à candidata. Nenhuma conta
foi cadastrada nem e-mail enviado por esta revisão; cadastro e confirmação reais
continuam pendentes de teste humano, assim como performance, som audível, teclado
do sistema, rotação/suspensão e troca física entre aparelhos.

Bloqueio de promoção: reteste final do usuário ainda pendente. Não há falha de
campanha ou perda de progresso demonstrada nas verificações aprovadas; isso não
substitui o percurso humano. WebGL 2 é necessário. A candidata tem armazenamento
separado da oficial; contas públicas não recebem chat/sync. Para promovê-los,
seria necessária uma decisão separada de acesso/consumo/moderação, não executada.
