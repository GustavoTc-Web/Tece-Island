# Combate, base, O Último Sinal e progresso por conta

Pedido de 12/10/2026. Implementação por etapas funcionais, mantendo Firebase
obrigatório, Compatibility, controles existentes e poços fixos. R$ 0.

Inspeção inicial: combate tem arco simples e flash de dano; barras inimigas
permanecem após ferimento. Baú já transfere parcialmente, mas não tem nome/ID
e sua desmontagem devolve item inteiro. Save versão 3 é compartilhado entre
contas. Diário e objetivos inexistentes. Baseline: 18 testes de monstros passam.

1. Implementado: comunicação do combate, efeitos e sons limitados (12 visuais,
   quatro vozes, intervalo por som), volume/mute. Ataques e reações visuais;
   vida inimiga temporária e duração do veneno. Equilíbrio preservado.
   Validação: 12 testes novos e 18 regressões de monstros; interface Web/nativa
   e apreciação dos sons previstas na verificação final.
2. Implementado: baús com nome até 24 caracteres e ID persistente; transferência
   parcial existente reutilizada, atalho T indicado e botão de pilha para toque.
   Painel Base seleciona/identifica peça e exige confirmação. Devolve metade
   da receita arredondada para baixo; excedentes no chão. Baú ocupado bloqueado,
   cama desmontada limpa retorno; naturais não entram na seleção.
   Validação: 14 testes de nomes/transferência/save/desmontagem; regressões de
   baú/arco/save e bases. Etapa 1 registrada em 88f0cef.
3. Implementado: O Último Sinal, três registros originais de 40–80 palavras na
   casa da Floresta (550,1250), fazenda do Pântano (3250,1120) e primeiro templo
   das ruínas a oeste. Pistas direcionam entre locais reais. Coleta E/toque sem
   inventário, IDs únicos, ordem/novas páginas persistidas, Diário por J/botão,
   texto 22px com rolagem. Validação: 15 verificações incluindo inventário cheio,
   coleta pelo sistema existente e reload sem reaparecimento.
   Etapa 2 registrada em e0cac1c.
4. Pendente: objetivos opcionais com evidências persistidas.
5. Pendente: estados reais de gravação, saves por UID e importação legada explícita.
6. Pendente: testes nativos/Web/toque, commits, push e verificação do Pages.
