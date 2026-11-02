# Reteste manual da RC2

Versão: **0.9.1-beta-rc.2**, jogo `7c254c1`, save **9**, tarefas **2**.
[Abrir candidata privada](https://tece-island-solo-beta.gustavotccandido.chatgpt.site/Tece-Island/).

Criar **mundo novo de teste**, com nome próprio, sem abrir/importar seus mundos
principais. Usar o mesmo endereço, perfil do navegador e conta ao reabrir. Nas
duas contas de sync, esse mundo novo pode sincronizar: não selecionar um mundo
principal compartilhado com a oficial 0.9.0. Não limpar os dados do site.

Marcar como aprovado somente o que executar, indicando PC ou celular e a versão.

| Check | Ação | Resultado esperado |
| --- | --- | --- |
| 1. Fabricação | Abrir C/Fabricar, buscar receitas; cozinhar carne e peixe na fogueira. | Não existe aba Alimentos na fabricação geral. Cozidos aparecem na fogueira; cada preparo consome o ingrediente e uma madeira, entrega uma refeição e atualiza as tarefas correspondentes. |
| 2. Casa | Entrar pela porta, percorrer os cantos e encostar na parede traseira; sair e voltar. | Personagem continua visível; construção e colisões permanecem inteiras. Guardião revelado aparece no combate e não volta a ficar oculto ao afastar da porta. |
| 3. Templo e loot | Percorrer salas superiores, inferiores e laterais; abrir baús e pegar os itens. | Personagem e itens ficam visíveis/enquadrados; o indicador aponta a interação correta. Recipiente já aberto não libera loot novamente. |
| 4. Inventário PC | Equipar espada e arrastar 7→1; mover pilha para vazio, trocar com ocupado e soltar fora; tentar Q durante o arrasto. | Pilha inteira move/troca, sem descarte, uso ou ataque acidental. Quantidade, cantil, carregador e equipamento acompanham o item; barra rápida atualiza. |
| 5. Salvar/reabrir | Salvar, voltar ao lobby, fechar o navegador e abrir o mesmo mundo. Repetir dentro de construção depois de abrir baú e vencer um guardião. | Ordem/equipamento, posição, baú, drops e progresso permanecem. Inimigo derrotado não reaparece e loot não duplica. |
| 6. Celular, som e retorno | Usar Mover/trocar; mover e atacar com dois dedos; digitar em campo/chat; ajustar som/silenciar. Girar, suspender e retomar. | Controles e botões continuam acessíveis; digitação não move/ataca; entradas não ficam presas após retorno. Efeitos são audíveis quando habilitados e silenciosos quando desabilitados; a partida retoma com progresso preservado. |
| 7. Sono — teste estendido | Executar os dois exemplos abaixo usando só ações normais. | Cada conclusão atrasada gera somente um uso, sem recriação pelo reload. Bloqueio explica seu motivo e não gasta o uso. |

**Exemplo em dia:** concluir o kit do dia 1 e tentar dormir na noite 1.
Esperado: sono bloqueado; o ponto de reaparecimento pode ser definido e a noite
precisa ser enfrentada.

**Exemplo atrasado:** concluir as etapas anteriores em dia, deixar somente a
etapa 3 pendente até o dia 4 e então completar todas as suas tarefas, incluindo
o mapa em uma noite permitida. Usar uma cama segura fora das Ruínas Escuras,
sem combate nem encontro iniciado. Esperado: um salto até o próximo amanhecer.
Salvar/reabrir e tentar de novo em outra noite, **sem concluir outra etapa
atrasada**: esse mesmo crédito não pode voltar. Consumir/repor comida ou mudar
equipamento também não cria outro. Se outra etapa atrasada for concluída, seu
crédito é independente; registrar isso para não confundir com duplicação.

## Exige campanha completa na RC2

Os sete checks acima não aprovam automaticamente a campanha inteira. O sono
atrasado já exige avançar até o dia 4; vitória e continuação exigem outro trecho
mais longo, que pode usar o mesmo mundo de teste.

- Jogar desde o mundo novo: preparo, mapa da torre na noite 3 ou posterior,
  templo alto e dois extremos, componentes, reparo/ativação do sinalizador,
  formações finais, Guardião e resgate. O dia 7 é o mais cedo; registrar o dia
  real se houver atraso permitido pelas regras.
- Verificar uma morte/Reaparecer e uma saída/retomada, mantendo conquistas e os
  requisitos que ainda faltam. Um ataque final interrompido exige a retentativa
  prevista; o relógio e o sono não devem conceder vitória por si mesmos.
- Após o resgate, escolher **Continuar explorando**, conferir mundo/inventário,
  salvar e reabrir sem repetir a vitória ou duplicar recompensas. Testar sono
  noturno seguro nesse modo.

Ainda **pendente**, tanto para automação exploratória quanto para aprovação
humana desta RC2. O relato humano do piloto anterior e os cenários técnicos
preparados não substituem esse percurso.

## Como relatar um problema

Informar versão, aparelho/navegador, dia/etapa, passos, esperado/observado, impacto,
frequência e imagem/vídeo quando possível. Separar hipótese de causa confirmada.
Não enviar credenciais. Novos bugs serão relatados para avaliação antes de
qualquer correção; testes não executados permanecem pendentes.
