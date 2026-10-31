# Candidata 0.9.1-beta-rc.2

Branch `release/solo-beta-rc2`, derivada de `release/solo-beta-rc1` em `bd0ccf7`.
Revisão solicitada em 31/10/2026. Oficial 0.9.0/main, checkout do IDE, saves
pessoais e branch/documentação do multiplayer preservados. Não há novas mecânicas
de combate, campanha ou multiplayer fora dos ajustes explicitamente solicitados.

## Ajustes

- Fabricação geral tem Ferramentas, Recursos e Armaduras. Alimentos continuam
  nas receitas de fogueira, com ingredientes, madeira consumida e resultados
  anteriores. Não foram removidos alimentos do inventário, coleta ou saque.
- Reprodução técnica da RC1 confirmou que o piso opaco ancorado no centro Y da
  construção encobria jogador/drops na metade superior. Piso e parede traseira
  passaram a ser desenhados abaixo dos atores. Casas e templos mantêm cômodos,
  paredes, cantos, colisões, posição dos baús e orçamento de loot.
- Guardiões de interiores ficam inativos/ocultos antes da aproximação da entrada;
  a revelação não se desfaz ao afastar. A guarda de ataque também exige interior
  revelado. Vida/derrotas são salvas; reabrir não dispara derrotas/loot novamente.
  Câmera mantém o comportamento existente; o percurso técnico verifica o jogador
  enquadrado nos cantos superiores, inferiores e laterais dos templos.
- Mouse arrasta pilhas inteiras no inventário: vazio move, ocupado troca,
  destino inválido cancela. Prévia/destino destacados; atributos e referência do
  equipamento acompanham a pilha e a barra rápida atualiza. Teclas de descarte/
  uso ficam bloqueadas durante arrasto. Seleção e Mover/trocar por toque continuam.
- Chat verificado preparado e validado em emulador, com abertura remota pendente:
  [configuração exata, orçamento e proposta de convites](CHAT_BETA_RC2.md).

## Regra da cama

O dia do relógio e a etapa da lista são independentes. Para cada uma das seis
etapas diurnas, registra-se uma única primeira conclusão efetiva de todas as
suas tarefas. Se ela ocorrer **depois** do dia previsto, gera um crédito persistente
para dormir uma vez. A mesma conclusão nunca gera outro crédito por mover itens,
consumir/repor comida, equipar/desequipar ou recarregar. A lista ainda mostra as
condições atuais, mas o registro da primeira conclusão não regride.

Exemplos: terminar o kit no dia 1 não autoriza pular a noite 1. Concluir o mapa e
todo o preparo da etapa 3 durante o dia/noite 4 concede um uso; à noite, com
segurança, esse uso leva ao amanhecer do dia 5. Com a etapa 3 ainda incompleta,
não há exceção. Não há congelamento/renumeração do relógio. Completar várias
etapas atrasadas pode gerar um crédito por etapa, cada qual consumido uma vez.

Sono bloqueado de dia, nas Ruínas Escuras, com inimigo vivo a menos de 260 px,
encontro de templo iniciado e ainda incompleto, ataque final ou partida pausada.
Não consome o crédito em tentativas bloqueadas. A cama sempre pode definir o
ponto de reaparecimento conforme a regra anterior, mesmo sem liberar sono.
O motivo aparece no prompt. O salto não entrega componentes, marca encontros,
derrota o Guardião nem substitui requisitos de resgate. Pendências permanecem
acessíveis em noites posteriores. Após vencer, exploração livre permite dormir
à noite com as mesmas condições de segurança, sem exigir novos créditos.

Saves antigos estabelecem uma base das etapas já atendidas, sem créditos
retroativos inventados. Primeira conclusão posterior de uma etapa ainda
incompleta pode gerar crédito por atraso. [Formato v9 e recuperação](RECUPERACAO_BETA_V9.md).

## Validação e publicação

Os testes técnicos preparados estão separados da rodada exploratória. Podem
congelar IA/relógio e posicionar o cenário, sem serem apresentados como campanha
jogada. A rodada exploratória da candidata congelada usa somente UI/controles
normais e terá registro próprio; bugs adicionais serão relatados sem correção
automática. Não há aprovação física de PC/celular nesta revisão.

Os registros finais de pacote, commit, deploy, testes e rodada exploratória serão
acrescentados após congelar o código. O endereço de reteste permanece
https://tece-island-solo-beta.gustavotccandido.chatgpt.site/Tece-Island/ .

## Reteste físico enxuto

1. Confirmar RC2 e criar mundo de teste; C não tem Alimentos; fogueira cozinha
   carne/peixe e desconta uma madeira/ingrediente por preparo.
2. PC: espada 7→1, pilha para vazio, troca ocupada, soltar fora e pressionar Q
   durante arrasto; fechar/reabrir e conferir quantidades/equipamento/barra.
3. PC/celular: entrar/sair de casas, quatro cantos dos templos, abrir baús,
   recolher drops, vencer guardião; salvar e reabrir no interior sem reaparecer
   inimigo ou duplicar itens. No celular, usar Mover/trocar e dois dedos.
4. Kit concluído no dia 1 não pula a noite. Etapa 3 concluída no dia 4 libera um
   salto seguro, sem segundo uso após reabrir. Combate/templo/ataque final bloqueiam.
5. Nas contas autorizadas: chat, teclado sem atacar/andar, fechar/voltar, sync e
   exportação. Novas contas: solo local; chat público aguarda decisão/aplicação.
6. Campanha até resgate e Continuar explorando; som, rotação, teclado físico,
   suspensão e desempenho reais permanecem sob reteste do usuário.
