# Beta solo pública 0.9.1-beta.1

[Jogar no endereço oficial](https://gustavotc-web.github.io/Tece-Island/).
Tag: **v0.9.1-beta.1**. Preparação e autorização em **01/11/2026**, horário de São Paulo.
Este documento separa a autorização de lançamento das verificações do deploy.
O resultado final será acrescentado após a publicação.

## Versão aprovada e escopo

Promoção da **0.9.1-beta-rc.2**, branch `release/solo-beta-rc2`, jogo congelado
`7c254c1f8454d768228c171cf6fa040b5eb322dc`, consolidação
`17895fc65fa6d4a2a5291eeb8fd1862962d30c66`.
As alterações de preparação pública limitam-se à identificação **0.9.1-beta.1**,
documentação, metadados, verificações de integridade e CI. Não foram acrescentadas
funcionalidades nem alterados relógio, encontros, receitas ou vitória.

Inclui os cinco ajustes da RC2: retirada da aba vazia Alimentos (cozimento na
fogueira preservado); visibilidade nas casas; visibilidade em templos e loot;
arrasto/troca de inventário no PC com Mover/trocar no toque; regra de sono com
uso único por primeira conclusão de etapa atrasada e persistência.

## Evidência manual e limites

Na autorização, o usuário informou: **“Os últimos ajustes funcionaram nos testes
que fiz.”** Registro: relato manual do usuário aprovando os últimos ajustes da
RC2. Não especifica uma campanha completa, aparelhos, todos os gestos, áudio,
suspensão ou testes entre contas; esses casos não recebem aprovação presumida.

**Campanha exploratória não executada por limitação da ferramenta.** O ciclo de
tentativas do controlador permanece encerrado; não foi criada uma partida
exploratória nem foi forçada progressão/vitória. A campanha completa relatada
para a versão 0.9.0 é histórica, não uma aprovação de campanha na RC2.

Foram reaproveitadas as [evidências técnicas da RC2](validation/beta-rc2.json),
incluindo migração/reabertura/backups com cópias, sono, interiores, arrasto,
controles e chat no emulador. Cenários preparados, headless e toque emulado
continuam separados de partidas humanas. O [roteiro manual](RETESTE_MANUAL_RC2.md)
mantém identificada a rodada de campanha completa ainda não confirmada.

## Acesso público e Firebase

- **Solo:** cadastro e login Firebase com e-mail confirmado; mundo, progresso e
  backups locais por conta, mundo, origem, perfil, navegador e aparelho.
- **Chat:** teste fechado para as mesmas duas contas autorizadas. Uma conta nova
  verificada ainda não tem acesso ao chat. A abertura para convidados ou todas
  as contas verificadas exige decisão e publicação separadas de cliente/backend.
- **Sincronização:** opt-in do cliente continua limitado aos mesmos dois UIDs,
  intervalo de 120 s. Demais contas não têm cópia automática entre aparelhos.
  As regras existentes preservam isolamento por proprietário; a lista de dois
  UIDs do cliente não é apresentada como uma nova regra de allowlist no servidor.
- **Firebase:** esta publicação não aplica regras/índices, não altera usuários,
  administradores, configurações, saves ou dados remotos e não habilita faturamento.
  `firestore.rules` contém preparação para uma futura abertura do chat; testes
  locais dessa preparação não significam aplicação em produção.
- **Multiplayer:** indisponível nesta beta, sem data anunciada. Trabalho preservado
  em `feat/multiplayer-pilot` (`a8ab12f`); serviços temporários não são reiniciados.

Limitações conhecidas: progresso local não acompanha troca de origem/aparelho
para novas contas; limpar dados do site pode apagá-lo. Recursos Firebase sujeitos
às cotas gratuitas podem ficar indisponíveis; não foi contratado plano pago.
Desempenho, áudio e suspensão variam por aparelho e não receberam nova aprovação
física por esta publicação. Não há novo bug bloqueador demonstrado nas evidências
técnicas reaproveitadas; isso não equivale a garantir uma campanha sem bugs.

## Saves e recuperação

Save **v9**, campanha **v2**, tarefas **v2**. A primeira migração conserva os
bytes anteriores em `.before-v9.json` no nativo e `:before-v9` no IndexedDB Web;
backups anteriores, conflitos e proteções de propriedade/gravação são mantidos.
Testes usam cópias em diretórios/perfis isolados, sem saves principais.

**A 0.9.0/RC1 não abre saves v9.** Recuperação preferida: publicar um cliente
compatível com v9 no mesmo endereço, conservando exportações e originais.
Não editar o número do save nem limpar o armazenamento. Retorno a v8 exige
restauração explícita de backup v8 e perde o progresso posterior àquela cópia.
[Procedimento completo](RECUPERACAO_BETA_V9.md).

## Publicação

Integração preparada em worktree isolada; checkout do IDE e seus arquivos locais
preservados. O workflow Pages valida, exporta e publica somente o cliente Web.
Após concluir, serão registrados commit do pacote, execução do workflow, hashes,
carregamento inicial automatizado e arquivo de recuperação. Não haverá teste
autenticado de produção ou teste físico sem evidência específica.
