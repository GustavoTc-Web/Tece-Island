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
4. Implementado: seis objetivos opcionais, progresso por eventos efetivos,
   acompanhamento/recolher/desativar na HUD e área separada no Diário.
   Sem recompensas; conclusão notifica uma única vez. Saves antigos reconhecem
   cama/fogueira presentes, primeiro registro e posição dentro de templo;
   não inventam coleta/fabricação/cozinha históricas sem dados.
   Validação: 15 verificações; estado/visibilidade/progresso e notificações.
   Etapa 3 registrada em 93d2d63.
5. Implementado: save v4 por UID (nome de pasta/chave SHA-256, dono validado),
   mundo/inventário/bases/baús/diário/objetivos isolados. Native usa gravação
   temporária e backups; Web usa transação IndexedDB com backup na mesma
   transação, confirma sucesso só em oncomplete. Estado Salvando/salvo/falha
   com retry, serialização, debounce 1,5 s, limite 3 s e automático 30 s mesmo
   com painel pausado. Logout aguarda gravação antes de limpar UID/tokens;
   falha bloqueia logout voluntário para permitir retry. Expiração limpa sessão
   mesmo se a tentativa de gravação falhar, mostrando aviso.
   Save legado sem dono permanece intacto: menu oferece importação confirmada,
   única por aparelho, nunca substitui progresso da conta. Interface informa
   armazenamento local sem sincronização entre aparelhos. Nenhum serviço pago.
   Validação: 21 testes de isolamento, migração, recuperação de escrita, estado
   real/coalescência e ordem de logout; 12 poços e 10 autenticação obrigatória.
   Contas/UIDs dos testes são fixtures; não representam login Firebase real.
   Mais seis verificações da sessão: falha mantém partida antes de menu/logout,
   nova tentativa grava e reentrada restaura dados. UI Web: 50 verificações
   aprovadas em PC e toque emulado, incluindo transações reais e reload.
   Etapa 4 registrada em c595eff.

Referência: [armazenamento user:// na Web](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html).
O arquivo virtual anterior do Godot é usado somente para ler/importar legado;
novos saves de conta na Web têm confirmação explícita da transação IndexedDB.
6. Pendente: testes nativos/Web/toque, commits, push e verificação do Pages.
