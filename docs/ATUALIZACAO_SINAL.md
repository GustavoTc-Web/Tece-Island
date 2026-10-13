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
6. Verificação final concluída; commit/push/deploy em sequência.
   Etapa 5: 928600d. Correções finais: relógio visual dos erros separado do
   cooldown de gameplay (regressão da troca mãos→pistola corrigida), efeitos
   próprios de flecha/tiro/acerto/bloqueio e desvanecimento sem falso impacto.
   Multiplayer envia feedback real do servidor e ignora snapshots após remoção
   da cena. Sons desativados em headless e liberados ao encerrar.
   Veneno junto à vida e status de save no painel lateral, sem cobrir combate.
   Gravação de saída bloqueia atalhos/interface até concluir ou permitir retry.

## Testes realmente executados nesta atualização

| Ambiente | Resultado |
| --- | --- |
| Godot headless | Suíte completa de 488 verificações, mais três casos de impacto/erro/bloqueio e um de transição: 492 verificações distintas aprovadas |
| Godot nativo Compatibility | 14 de menu, 24 de controles móveis injetados, 10 de autenticação obrigatória e 15 de combate/render: 63 aprovadas |
| Dois processos ENet | 43 host + 4 guest, 24 de inventário/consumo/coleta, seis de feedback de acerto/bloqueio/erro: 77 aprovadas |
| Edge desktop e toque emulado | 50 verificações novas, incluindo rolagem, diário/objetivos, nome/ID, transferências, desmontagem, combate, IndexedDB real e reload |
| Firebase | Configuração pública e bloqueio sem sessão; smoke da exportação principal com rejeição real de credenciais inválidas. Nenhum login positivo inventado |
| Celular físico | Não executado; legibilidade revisada em capturas emuladas 852×393/DPR3, desempenho no aparelho permanece manual |

Fixtures de gameplay desativam auth somente na cópia isolada. Testes de contas
usam UIDs de fixture e armazenamento real; falhas de I/O são injetadas e
identificadas. Não comprovam troca entre duas contas Firebase reais. Todos os
saves dos testes ficam separados do progresso pessoal. A migração real de um
save legado acontece apenas se o usuário confirmar a importação no menu.
Erro proposital de cena no teste do menu verifica a nova tentativa. O sandbox
headless avisa sobre certificados Windows; checks nativos e REST no navegador
executados fora dessa restrição. Não há alteração de dano, alcance, intervalos,
poços, login obrigatório ou faturamento.

## Verificação manual necessária

1. No [Pages](https://gustavotc-web.github.io/Tece-Island/) ou Godot/F5, entre
   com sua conta A confirmada. Havendo save antigo e conta sem progresso, clique
   Importar save antigo, leia a confirmação e escolha Importar para esta conta.
   Cancelar deve deixar o original sem dono. Importação não substitui outro save.
2. Na conta A, renomeie um baú, guarde um item, descubra um registro e acompanhe
   um objetivo. Espere Progresso salvo, volte ao menu e saia da conta.
3. Entre com uma conta B confirmada no mesmo aparelho: deve começar com seu
   próprio progresso, sem baú/diário/objetivo da A. A importação antiga já usada
   não deve aparecer. Saia de B e retorne a A para conferir seus dados.
4. Em celular físico, confirme sons discretos, volume/silenciar e FPS com
   combate; use dois dedos, troque de aba/bloqueie tela e confira entradas soltas.
   Percorra a lista de objetivos/diário por rolagem e confirme/cancele desmontagem.
5. Mantenha uma sessão real por mais de uma hora para renovação. Ao perder rede,
   confira mensagem e nova tentativa. Expiração deve retornar à entrada.

Não envie senhas ou tokens ao assistente. Armazenamento continua local: conta
igual em outro navegador/aparelho não sincroniza. Sons são sintetizados no jogo;
controles de áudio foram verificados, mas apreciação sonora no aparelho é manual.
