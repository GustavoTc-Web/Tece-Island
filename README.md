# Tece Island — solo Web e controles de toque

Jogo 2D de sobrevivência em **Godot 4.7.2 Standard**, GDScript e **Compatibility**.
O navegador oferece o mapa solo completo. O teste multiplayer ENet permanece no desktop.

## Começar

Importe `project.godot`, execute com F5, entre com uma conta de e-mail confirmado
e escolha **Jogar solo**. Para o primeiro acesso, use **Criar conta** e confirme
o link recebido por e-mail. **Voltar ao menu**
funciona durante a pausa; iniciar novamente retoma o progresso local.
Na primeira partida, começa com sete espaços, vida/fome/sede completas,
posição inicial (1152, 768) e dia 1. **Reaparecer** mantém itens, estruturas, drops e horário da
mesma partida, restaurando vida, fome e sede. Usa a cama definida ou a clareira inicial.

O modo solo salva inventário, propriedades dos itens, estruturas, baús, recursos
e itens no chão a cada 30 segundos, ao perder foco e ao retornar ao menu.
O arquivo local é `user://solo-progress.json`, com cópia anterior
`solo-progress.json.backup.json`; conversões guardam uma cópia antes de migrar.
No navegador, os dados ficam no IndexedDB deste dispositivo e navegador.
Desktop e navegador têm saves separados; não há sincronização em nuvem.
Limpar os dados do site apaga o progresso local. Senhas e tokens continuam
somente em memória e nunca fazem parte do save.

A fabricação tem busca e categorias; alimentos cozidos estão na fogueira.
Bolsas melhoram de 9 até 15 espaços, usando madeira e linha das aranhas.
O baú construído guarda 12 pilhas: abra, selecione Inventário ou Baú, selecione
o item e use Guardar/Retirar 1 ou pilha. Baú cheio não pode ser desmontado.
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

Use o aparelho **na horizontal**. Dispositivos de toque ativam o layout automaticamente.
A opção **Controles de toque (testar no computador)** no menu permite ativá-lo manualmente;
os joysticks também aceitam arrastar com o mouse.

- Joystick esquerdo: andar. Direito: arrastar para mirar e manter ataque fora da zona morta.
  Soltar para parar. Dois dedos controlam movimento e mira separadamente.
- Botões **Interagir**, **Usar item**, **Recarregar**, **Inventário**, **Fabricação**
  e **Voltar ao menu**. Consumíveis usam uma unidade por toque.
- Toque na barra rápida para selecionar.
- Inventário: selecione origem → **Mover / trocar** → toque no destino.
  **Jogar 1** / **Jogar pilha** descartam. Role o painel com o dedo.
- Cama/fogueira: **Colocar selecionado** → toque no terreno para ajustar prévia →
  **Confirmar** / **Cancelar**. Tocar no terreno não confirma sozinho.
- Painéis têm **Fechar**. Nenhuma dessas ações exige teclado.

Painéis pausam a simulação solo e limpam entradas mantidas. Perda de foco,
suspensão e mudança de orientação também limpam entradas. Na vertical aparece
orientação para girar, mantendo acesso ao menu. A página respeita áreas seguras
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
30 de fome; água, 40 de sede. Cantil guarda três doses e permanece quando vazio.
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

Abra duas instâncias. Primeira: **Criar partida de teste**. Segunda: informe IP
do anfitrião e mesma porta UDP (padrão 7000), então **Entrar na partida de teste**.
Na mesma máquina use `127.0.0.1`. Há anfitrião e um convidado, com opção de dano
entre jogadores. Servidor valida ações e mantém estado dos itens. A arena não
oferece todos os sistemas solo; inventário bloqueia só o jogador local.
Na Web, ENet/UDP não é iniciado: menu indica **Multiplayer em breve**.

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
Para testes de navegador:

```powershell
npm install --prefix .tools/browser-test playwright
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build-browser-fixture.ps1 -Godot "C:/caminho/Godot_console.exe"
node tools/serve-web.mjs 8081 .tools/web-validation
# Outro terminal:
node tools/browser-validation.mjs
# Smoke da produção, servida na porta 8080:
node tools/browser-smoke.mjs --touch
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
