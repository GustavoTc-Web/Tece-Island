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

Resultados automatizados, medições, capturas e publicação desta revisão serão
consolidados em `docs/validation/beta-rc1.json`, separados de testes físicos.
