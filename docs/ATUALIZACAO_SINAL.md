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
2. Pendente: nomes/IDs de baús, transferência rápida e desmontagem confirmada.
3. Pendente: registros originais, coleta e diário.
4. Pendente: objetivos opcionais com evidências persistidas.
5. Pendente: estados reais de gravação, saves por UID e importação legada explícita.
6. Pendente: testes nativos/Web/toque, commits, push e verificação do Pages.
