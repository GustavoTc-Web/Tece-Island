# Validação desta atualização

Executada no Windows com Godot 4.7.2, renderer Compatibility; navegador Edge
com Playwright e toque emulado. Capturas revisadas em `.tools/screenshots/`.
Fixtures de gameplay têm autenticação desativada somente na cópia isolada e
saves próprios. Não representam login real e são excluídas da exportação pública.

| Ambiente | Resultado efetivamente executado |
| --- | --- |
| Godot headless | 405 verificações: receitas, bolsas, baús, arco, save, monstros, animais, terreno, ruínas, expansão, poços, bases, controles e autenticação |
| Godot nativo, OpenGL | 48 verificações com eventos de mouse/teclado/toque injetados: menu, retorno pausado, criação de anfitrião, multitoque, foco, construção, autenticação obrigatória |
| Multiplayer ENet | 71 verificações em dois processos: entrada, movimento, combate, inventário, coleta, consumo, morte, reconexão e retorno ao solo |
| Navegador desktop/toque | 114 verificações das interfaces de fabricação, bolsas, baús/arco, aquático, ruínas, expansão, poços e bases |
| Exportação principal Firebase | Tela real de login com mouse/toque; envio REST real e rejeição HTTP 400 de credenciais inválidas; mensagem permite nova tentativa |
| Conta real | Cadastro, confirmação, login e recuperação confirmados pelo usuário antes desta atualização; nenhuma senha solicitada ao assistente |
| Celular físico | Não executado; emulação não mede desempenho nem peculiaridades do aparelho |

Regressões repetidas após os últimos ajustes: fabricação e bases no navegador;
menu e controles móveis na janela nativa; animais, aquático e expansão headless.
A falha intencional de carregamento no teste do menu produz um erro esperado
e confirma mensagem compreensível e nova tentativa. O ambiente headless restrito
também emite aviso do armazenamento de certificados do Windows; testes nativos
fora dessa restrição e chamadas Firebase reais no navegador foram executados.

## Preservação do progresso

Save v1 local encontrado durante um teste antigo: migração para v3 com backup
dos bytes originais antes da conversão. Comparação confirmou inventário e jogador
idênticos, duas bases anteriores e loot preservados. Fixtures seguintes usam
caminhos separados. Testes também cobrem JSON inválido, versão futura, propriedades
de cantil/arma, baú, portas abertas e exploração. A versão pública grava progresso
local; sessão Firebase e tokens continuam somente em memória.

Poços: um fixo por região, 16 no mapa completo; quatro originais nas posições
anteriores. Não há regra de 35% nem rejeição de mundos sem poço nesta publicação.

## Verificação manual pendente

1. No Pages e no Godot/F5, entre com sua própria conta confirmada. Sem login,
   as partidas devem permanecer bloqueadas. Não envie senha ou tokens no chat.
2. Saia da conta durante uma partida e confira a tela de entrada. Entre novamente;
   o progresso solo deve continuar. Fechar a página deve encerrar a sessão.
3. Mantenha uma sessão real aberta por mais de uma hora para verificar renovação.
   Interrompa a conexão e confira mensagem/repetição; uma sessão expirada deve
   exigir novo login. A lógica de expiração e limpeza já foi testada isoladamente.
4. Em celular físico, ande e ataque/colete com dois dedos; abra inventário,
   melhore bolsa, transfira ao baú, cozinhe e consuma uma unidade por toque.
5. Coloque, gire, confirme e cancele parede/porta/vidraça. Abra e feche a porta;
   recarregue e confira as construções. Visite aquático e ruínas, use o minimapa.
6. Troque de aba, bloqueie/desbloqueie a tela e gire o aparelho: comandos devem
   soltar, painéis impedir ações por baixo e botões respeitar bordas. Avalie FPS.

Configuração pública usa Firebase Spark, sem faturamento ou serviço adicional.
Actions lê as quatro variáveis públicas documentadas no README e conserva
`https://gustavotc-web.github.io/Tece-Island/` como endereço de continuação.
