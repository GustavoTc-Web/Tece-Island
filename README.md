# Tece Island — solo Web e controles de toque

Jogo 2D de sobrevivência em **Godot 4.7.2 Standard**, GDScript e **Compatibility**.
O navegador oferece o mapa e a campanha solo completos. Multiplayer indisponível
nesta beta, sem data anunciada. O piloto foi preservado e seus serviços temporários
encerrados; veja [registro](docs/MULTIPLAYER_ADIADO_BETA.md).

Candidata de revisão: **0.9.1-beta-rc.2**, save **9**, campanha **2**, tarefas **2**.
A oficial **0.9.0** continua disponível até o reteste final. Veja a
[revisão, limites e roteiro](docs/BETA_SOLO_RC2.md).
O chat para novas contas está preparado, com [abertura e orçamento pendentes](docs/CHAT_BETA_RC2.md).
A [recuperação da candidata exige cliente compatível com v9](docs/RECUPERACAO_BETA_V9.md).

**0.9.0 — campanha solo:** promoção do piloto .4 aprovado pelo usuário após uma
campanha completa com vitória no dia 7. [Publicação e validação](docs/PUBLICACAO_0_9_0.md).
Saves v8 exigem [recuperação com cliente compatível](docs/RECUPERACAO_0_9_0.md).

Confiabilidade dos saves e piloto de sincronização Firestore:
[investigação, configuração e testes](docs/SAVES_E_SINCRONIZACAO.md).
Na build pública, chat e sincronização ficam restritos às mesmas duas contas
autorizadas; os defaults de desenvolvimento continuam desligados. O solo aceita
qualquer conta de e-mail confirmado, com progresso local por conta, endereço,
navegador e aparelho. Para as demais contas, não há sincronização automática.
Para mundos desaparecidos, siga a
[exportação e recuperação sem apagar armazenamento](docs/RECUPERAR_MUNDO.md).

## Começar

Importe `project.godot`, execute com F5 e entre com uma conta de e-mail confirmado.
**Continuar** identifica e abre o último mundo jogado. **Meus mundos** permite
selecionar e jogar outro mundo, criar ou renomear com confirmar/cancelar.
Sem partida anterior, o destaque é **Criar mundo**.
Para o primeiro acesso, use **Criar conta** e confirme
o link recebido por e-mail. **Voltar ao menu**
funciona durante a pausa; iniciar novamente retoma o progresso local.
Na primeira partida, começa com sete espaços, vida/fome/sede completas,
posição inicial (1152, 768) e dia 1. **Reaparecer** mantém itens, estruturas, drops e horário da
mesma partida, restaurando vida, fome e sede. Usa a cama definida ou a clareira inicial.

O modo solo salva mundo, inventário, equipamento, bases, baús, diário e objetivos
por UID da conta Firebase **e ID do mundo**. Salva periodicamente a cada 30 segundos, após mudanças
importantes, ao perder foco e antes de retornar ao menu ou sair da conta.
O indicador distingue gravação local, sincronizando, sincronizado e pendência/falha
com nova tentativa. Sincronizado exige confirmação do serviço.
Godot usa `user://accounts/<SHA-256 do UID>/worlds/<ID>/progress.json`, temporário,
cópia anterior `.backup.json` e backups versionados antes das migrações até v9.
O catálogo fica em `worlds.json` na pasta da conta. O save anterior dessa conta
migra uma vez para **Meu primeiro mundo**, com verificação e backup, mantendo o
arquivo original. Inventário, equipamento, baús, objetivos e mundo são independentes.
Na Web, uma transação IndexedDB confirma a gravação e conserva a cópia anterior.
O arquivo antigo `user://solo-progress.json` permanece intacto: o menu oferece
uma importação única e confirmada para a conta atual, sem sobrescrever progresso.
Desktop e navegador mantêm cópias locais. O piloto Firestore permite continuar
os mesmos mundos entre aparelhos; a ativação pública permanece desabilitada.
Limpar os dados do site apaga o progresso local. Senhas e tokens continuam
somente em memória e nunca fazem parte do save.

A fabricação tem busca e categorias; alimentos cozidos estão na fogueira.
Bolsas melhoram de 9 até 15 espaços, usando madeira e linha das aranhas.
O baú construído guarda 12 pilhas: abra, selecione Inventário ou Baú, selecione
um item e use Guardar/Retirar pilha ou T; transferências parciais conservam o resto.
Renomeie o baú em até 24 caracteres. O painel Base seleciona e confirma desmontagem:
50% dos materiais, arredondados para baixo, com excedentes no chão; baú cheio bloqueado.
Diário por J ou Menu → Diário e objetivos reúne O Último Sinal e a sequência inicial.
O HUD acompanha tarefas por dia, contador, requisitos e conclusões automáticas;
o Diário mantém todas as etapas, inclusive atrasadas. Bolsa nível 1 é a meta do
dia 2; níveis superiores são opcionais. Fabricações antecipadas ficam registradas.
Menu → Configurações permite volume/silenciar e mostrar objetivos.
Detalhes: [ATUALIZACAO_SINAL.md](docs/ATUALIZACAO_SINAL.md) e
[usabilidade mobile, testes e capturas](docs/USABILIDADE_MOBILE.md).
O lobby tem clareira decorativa, fontes locais e datas no horário do aparelho.
Barra rápida, inventário, receitas e baús compartilham desenhos dos 33 itens.
[Apresentação, capturas PC/mobile e roteiro físico](docs/APRESENTACAO_LOBBY.md).
O arco usa os controles de ataque/mira, consome uma flecha por tiro e dispensa
recarga. A receita de flechas produz quatro unidades.

## Computador

| Ação | Controle |
| --- | --- |
| Andar | WASD / setas |
| Atacar na direção em que olha | F, toque ou mantenha pressionado |
| Atacar na direção do cursor | Botão esquerdo, clique ou mantenha pressionado |
| Usar comida ou dose do cantil selecionado | F / clique, uma unidade por acionamento |
| Coletar / vasculhar / usar cama, fogueira ou poço | E |
| Selecionar cinco espaços da barra | 1–5, teclado numérico ou scroll |
| Recarregar | R |
| Inventário / fabricação | I / C |
| Fechar painel / cancelar prévia | Esc |
| Jogar uma unidade / pilha selecionada | Q / Shift+Q |
| Colocar estrutura | Inventário → selecionar → Colocar selecionado → clique no terreno |
| Cancelar colocação | Esc / botão direito |

Números selecionam o **item exato no espaço**, incluindo espaço vazio (mãos).
Fabricar ferramenta melhor não troca automaticamente a seleção.
Armas iguais têm identidade e carregadores independentes.

## Celular

Login, cadastro e recuperação aceitam retrato ou paisagem. Após o login, o celular
exige **paisagem** para acessar o lobby e a partida. O aviso oferece tela cheia e
tentativa de bloqueio de orientação; a rotação manual funciona se houver recusa.
Dispositivos de toque ativam o layout automaticamente.
A opção **Simular controles de toque** em **Menu → Desenvolvimento**, nas builds
de desenvolvimento, permite ativá-lo manualmente;
os joysticks também aceitam arrastar com o mouse.

- Joystick esquerdo: andar. Direito: arrastar para mirar e manter ataque fora da zona morta.
  Soltar para parar. Dois dedos controlam movimento e mira separadamente.
- Mão **Coletar/Interagir**, mochila **Inventário** e martelo **Fabricar** ficam
  juntos acima da barra rápida, com ícones e legendas. **Fabricar** abre diretamente
  as categorias, receitas e ingredientes existentes.
  **Comer/Beber** e **Recarregar** aparecem em uma linha separada quando o item permite.
  Consumíveis usam uma unidade por toque.
- O inventário também mantém o acesso a **Fabricação** e **Base**. **Menu** reúne diário/objetivos,
  configurações, ajuda, dados/salvamento, retorno ao menu principal e logout.
- Toque na barra rápida para selecionar.
- Inventário: selecione origem → **Mover / trocar** → toque no destino.
  **Jogar 1** / **Jogar pilha** descartam. Role o painel com o dedo.
- Cama/fogueira: **Colocar selecionado** → toque no terreno para ajustar prévia →
  **Confirmar** / **Cancelar**. Tocar no terreno não confirma sozinho.
- Painéis têm **Fechar**. Nenhuma dessas ações exige teclado.

[Captura dos atalhos e roteiro em aparelho físico](docs/ATALHOS_MOBILE.md).

Painéis pausam a simulação solo e limpam entradas mantidas. Perda de foco,
suspensão e mudança de orientação também limpam entradas. Voltar ao retrato pausa
o solo e mostra o aviso; girar novamente preserva a conta, o mundo e a pausa dos painéis.
A página respeita áreas seguras
e acompanha o tamanho disponível do navegador.

## Inventário, sobrevivência e mundo

Bolsa nível 1 amplia **7 → 9 espaços**, ocupa seu próprio campo e equipa automaticamente
quando fabricada. O bônus não acumula. Retirar guarda a bolsa; descartar gera drop.
Se itens restantes e bolsa não couberem em sete espaços, a operação é bloqueada sem perda.
Reorganizar, descartar e recolher conservam água, munição e identidade das armas.
Recursos, carnes e munição empilham até 15. Coleta parcial deixa o restante no chão.
Fabricação valida consumo e inclusão juntos; consome primeiro pilhas menores de ingredientes.

| Receita | Madeira | Pedra | Fibra | Outro requisito |
| --- | --- | --- | --- | --- |
| Cantil | 2 | 0 | 2 | — |
| Bolsa nível 1 | 4 | 0 | 12 | — |
| Cama | 8 | 0 | 6 | — |
| Fogueira | 4 | 5 | 0 | — |
| Machado / picareta de madeira | 3 | 0 | 0 | — |
| Espada de madeira | 2 | 0 | 0 | — |
| Machado / picareta de pedra | 2 | 3 | 0 | — |
| Espada de pedra | 1 | 2 | 0 | — |
| Carne cozida | 1 | 0 | 0 | 1 carne crua e fogueira próxima |

Fome diminui 5/minuto e sede 8/minuto. Abaixo de 25 há alerta. Uma necessidade
zerada causa 1 de dano a cada 5 segundos; ambas zeradas, 2. Carne cozida restaura
30 de fome e inicia cinco recuperações de 5 HP, uma por segundo; outro alimento
renova cinco segundos sem acumular taxa. É possível comer com fome cheia para
recuperar vida. Água restaura 40 de sede. Cantil guarda três doses e permanece quando vazio.
Poços oferecem **Beber** / **Encher cantil**. Pausa e morte suspendem necessidades.
Coelhos fogem e deixam uma carne crua. Vacas começam passivas, fogem quando
atacadas e deixam duas ou três. Animais nascem em regiões com vegetação,
separados dos monstros, com limites e reposição gradual.

Mapa original de **6912 × 1536 pixels** preservado. A expansão tem 16 regiões:
duas novas de cada tipo original, duas Aquáticas e duas Ruínas Escuras, para
norte/sul/oeste. Limites de câmera: (-3072, -1536) a (6912, 3072).
Minimapa circular mostra orientação e terreno explorado, conservado no save.
O Aquático tem aproximadamente 80% de água, com nado a 60% da velocidade.
Lambari/tilápia deixam uma carne de peixe cada; cozinhe na fogueira.
Garça-azul foge rapidamente, deixa uma carne e aparece raramente.
Ruínas mantêm escuridão, bloqueiam sono e têm quatro templos com 3–5 baús,
seis unidades de saque por templo e limite próprio de guardiões.
As nove construções anteriores e quatro poços originais permanecem.
Cada região terrestre da expansão recebe construções com IDs persistentes,
sem mover bases ou recursos. Loot consumido permanece consumido após recarregar.
Cada nova região mantém a regra de um
poço fixo; a mudança de chance foi adiada. Dia e noite duram cinco minutos cada, incluindo
transições de 30 segundos. HUD mostra tempo até a próxima fase. Monstros noturnos
surgem gradualmente e desaparecem ao amanhecer; guardiões defendem construções de dia também.
Construções: 70% de loot, 30% de ocupação, 2% de chance total de dois guardiões,
uma ou duas entradas de loot, sorteio de arma de 5% e peso de pistola de 75%.
Sorteio ocorre uma vez por construção, sem gerar novos itens ao vasculhar novamente.

Esqueletos e aranhas compartilham o limite noturno de cinco: esqueletos avisam
antes de disparar flecha de dano 10; aranhas causam 4 e veneno de 3 segundos,
um dano/s sem empilhar. Drops: flechas e linha, recolhidos pelo comando existente.

Peças de base: parede (4 madeiras), porta (6 madeiras) e vidraça (4 madeiras,
2 vidros). Vidro aparece no saque com o mesmo orçamento anterior.
Coloque pelo inventário, ajuste prévia, use **R** ou **Girar** para orientar
e confirme/cancele. Grade de 32 nas peças, de 8 nas demais estruturas.
Porta abre/fecha por **E / Interagir** e não fecha sobre personagens.
Paredes, porta fechada e vidro bloqueiam corpos/projéteis; vidro mantém visão.
Posição, orientação e porta aberta/fechada ficam no save.
Valores ajustáveis e referências: [docs/EQUILIBRIO.md](docs/EQUILIBRIO.md).

Árvore deixa cinco madeiras, rocha quatro pedras, arbusto quatro fibras, coletadas
do chão. Intervalos: mãos 1,20 s, madeira 0,54 s, pedra 0,36 s.
Combate valida alcance, direção e linha de visão. Pistola: oito tiros, intervalo
0,45 s, recarga 1,2 s. Espingarda: dois cartuchos, seis projéteis por disparo,
intervalo 1,2 s, recarga 1,8 s. A cadência é compartilhada por todas as entradas.
Cama define reaparecimento e permite dormir à noite sem inimigo próximo.
Fogueira fornece luz local e permite cozinhar a até 100 pixels com linha de visão.
Colocação valida distância, bordas e colisões; somente confirmar consome o item.

## Multiplayer desktop

Nas builds de desenvolvimento, abra duas instâncias. Primeira: **Menu →
Desenvolvimento → Criar partida de teste**. Segunda: em **Servidores → Conexão
avançada**, informe IP do anfitrião e mesma porta UDP (padrão 7000) e use **Conectar**.
Na mesma máquina use `127.0.0.1`. Há anfitrião e um convidado, com opção de dano
entre jogadores. Servidor valida ações e mantém estado dos itens. A arena não
oferece todos os sistemas solo; inventário bloqueia só o jogador local.
Na Web, ENet/UDP não é iniciado; Servidores informa a disponibilidade no aplicativo
para computador. A área de desenvolvimento fica oculta na exportação pública.

## Exportar e testar por HTTP

Requisitos: Godot **4.7.2 Standard**, Node.js 22 e acesso aos releases oficiais.
Preset `Web`: Compatibility, **sem threads**, sem GDExtension e sem PWA/cache offline.
Templates oficiais ficam em `.tools/godot-templates/4.7.2/`, extraídos por intervalos
HTTP com verificação de tamanho, CRC e versão.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/export-web.ps1 -Godot "C:/caminho/Godot_v4.7.2-stable_win64_console.exe"
node tools/serve-web.mjs
```

Abra **http://localhost:8080/Tece-Island/**, nunca `file://`.
Celular na mesma rede: `http://IP-DO-PC:8080/Tece-Island/`; permita porta 8080 no
firewall se necessário. Saída: **build/web/index.html**. Publique todos os arquivos
de `build/web/`, preservando nomes. Caminhos relativos funcionam sob `/Tece-Island/`.
Há progresso de carregamento, mensagem de falha e nova tentativa.
Fonte é preservado; build, templates, caches e credenciais são ignorados pelo Git.
[Documentação oficial de exportação Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html).

## Publicar no GitHub Pages

Remoto: [GustavoTc-Web/Tece-Island](https://github.com/GustavoTc-Web/Tece-Island).
Workflow **Publicar TC Island**, em `.github/workflows/pages.yml`, instala Godot,
obtém templates, exporta e publica todos os arquivos. Push em `main` ou execução
manual em Actions faz nova implantação. **Settings → Pages → Source: GitHub Actions**.
Antes do push, rode testes e confira a exportação local por HTTP.
Após deploy, abra a URL indicada pelo job e confirme menu, partida e carregamento
de `index.js`, `index.wasm` e `index.pck`.
Use Git Credential Manager ou GitHub CLI para autenticação; nunca grave tokens no projeto.

## Firebase Authentication

Integração REST ativada no projeto principal (Godot/F5) e na Web, com a
configuração pública fornecida, tokens apenas em memória e bloqueio para
e-mail não confirmado. **Sair da conta** limpa a sessão e retorna à entrada.
Veja [configuração, versão de teste e roteiro real](docs/FIREBASE.md).

O teste isolado abre em http://localhost:8083/Tece-Island/ após executar
tools/export-auth-test.ps1 e servir build/auth-test na porta 8083.

## Validação

Resultados desta atualização e limites dos testes: [docs/VALIDACAO.md](docs/VALIDACAO.md).
Etapas e commits: [docs/PROGRESSO.md](docs/PROGRESSO.md).

Correção de coleta: baús já vasculhados deixam de competir com os drops na
seleção do alvo. O botão de toque mostra Coletar, Abrir, Beber, Usar cama ou Cozinhar.
Confirmar/Cancelar ficam fora da região próxima ao jogador usada pela prévia.
`validate_controls.gd` reproduz o baú vazio interceptando coleta e verifica
inventário cheio/parcial, nova tentativa e alcance sem depender do cursor.

Testes GDScript em `tests/` exercitam entrada do viewport, pausa, inventário,
exploração, sobrevivência, armas, animais e transições:

```powershell
& "C:/caminho/Godot_console.exe" --headless --path . --script tests/validate_mobile.gd
& "C:/caminho/Godot_console.exe" --headless --path . --script tests/validate_menu.gd
```

`network_probe.tscn` e `network_update_probe.tscn`: duas instâncias, passando
`-- --role=host --port=17158` e `-- --role=guest --port=17158`.
Em execução headless, passe `--max-fps 60` aos dois processos para manter
a temporização das entradas do probe.
Para testes de navegador:

```powershell
npm install --prefix .tools/browser-test playwright
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-browser-fixture.ps1 -Godot "C:/caminho/Godot_console.exe"
node tools/serve-web.mjs 8081 .tools/web-validation
# Outro terminal:
node tools/mobile-hud-validation.mjs
node tools/signal-validation.mjs
node tools/presentation-validation.mjs
node tools/mobile-shortcuts-validation.mjs
node tools/next-update-validation.mjs
# Login principal com Firebase real (somente credenciais inválidas):
node tools/mobile-login-validation.mjs
# Smoke da produção, servida na porta 8080:
node tools/browser-smoke.mjs --touch
node tools/presentation-release-check.mjs
```

Fixture é uma exportação separada em `.tools/`, com itens determinísticos para
armas e receitas. Sua interface de teste é **excluída da publicação**.
Scripts usam Edge instalado no Windows; `BROWSER_EXE` permite outro executável
na validação. Resultados e capturas ficam em `.tools/`, fora do Git.

**Celular físico ainda precisa de validação manual.**

1. Abra solo na horizontal, ande e ataque com dois dedos, solte e recarregue.
2. Colete/fabrique, selecione barra e reorganize/descarte no inventário.
3. Coloque cama e fogueira com Confirmar/Cancelar; cozinhe e use cama.
4. Coma uma unidade por toque; beba, encha e use cantil.
5. Abra/feche painéis e volte ao menu pausado, sem ações acidentais.
6. Troque de aba ou suspenda durante movimento/ataque; ao retornar, entradas devem parar.
7. Gire vertical/horizontal e confira recortes, barras do navegador e alcance dos botões.

Avalie desempenho no aparelho alvo. Movimento, combate, necessidades e ciclo
usam tempo de simulação; valores não foram alterados para compensar FPS.

## Sincronização e chat — 0.8.2

Integrados à main e publicados no endereço oficial, com chat e sincronização
restritos aos mesmos dois UIDs do piloto. A configuração de desenvolvimento
continua desativada por padrão; o workflow gera a configuração restrita e valida
saves/regras antes de publicar. Veja [publicação, consumo e reversão](docs/PUBLICACAO_0_8_2.md).
Os registros do [piloto](docs/CHAT_GLOBAL.md) e das [capturas](docs/VALIDACAO_CHAT.md)
permanecem como histórico, com os limites de validação física identificados.
