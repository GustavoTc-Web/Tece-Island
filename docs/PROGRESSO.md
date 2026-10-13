# Atualização — registro para retomada

A atualização seguinte (combate, base, O Último Sinal, objetivos e saves por
conta) está registrada em [ATUALIZACAO_SINAL.md](ATUALIZACAO_SINAL.md), com
commits por etapa, testes e verificação manual. O histórico abaixo corresponde
à expansão anterior, publicada em cf5bc20.

## Etapa 0: autenticação obrigatória

Implementado: Firebase REST, cadastro, confirmação de e-mail, login,
recuperação, logout e renovação/expiração; tokens apenas em memória.
Godot/F5 e Web usam config/firebase-public.json com enabled true.
Quatro variáveis públicas Firebase foram configuradas e verificadas no Actions.
Nenhum serviço pago ou faturamento foi habilitado.

Validação do assistente: 10 verificações da ativação em Godot nativo e headless,
14 de lógica/formulários e teste da exportação principal com mouse e toque emulado,
incluindo rejeição real de credenciais inválidas. Sem erros na exportação Web.
Validação real informada pelo usuário: cadastro, confirmação, login e recuperação.
Logout de uma sessão real, renovação prolongada e celular físico: verificação manual.

Publicação confirmada: implementação 0d76e9c, merge preservando README remoto
47b0114. Actions 38269574352 concluído com sucesso. Tela de login do Pages
verificada em navegador, mouse e toque, incluindo rejeição real pelo Firebase.

## Etapa 1: nitidez e fabricação

Implementado: canvas considera DPR, limitado a 2 para conter custo de GPU,
ResizeObserver e acompanhamento de mudanças de densidade. Canvas antes em
852×393 para tela CSS 852×393 com DPR 3; depois 1704×786. Campo de visão
1170×540 preservado. Desktop DPR 1 permanece 960×540. Texturas usam nearest.
Categorias Ferramentas/Recursos/Alimentos, busca, ícone do resultado, quantidade,
ingredientes disponíveis/necessários e motivo de bloqueio visível.
Cozidos aparecem exclusivamente na interface da fogueira.

Validação: 12 verificações Godot, 20 verificações de navegador (mouse e toque
emulado), inclusive multitouch com DPR 2 e perda de foco; 10 de autenticação.
Capturas da mesma posição antes/depois em .tools/screenshots/sharpness-*.
Fixture de gameplay explicitamente offline numa cópia, excluída da publicação;
não representa login real. Nenhum teste em celular físico.
Documentação técnica da filtragem: https://docs.godotengine.org/en/stable/classes/class_viewport.html

## Estado final da implementação

Etapas 0–11 implementadas e verificadas. Publicação pelo workflow Pages após
o commit final; resultado do deploy será conferido no endereço existente.
Decisão atual do usuário: chance dos poços adiada; preservar regra fixa.
Detalhes dos testes e limites: docs/VALIDACAO.md.

## Etapa 2: bolsas

Quatro níveis com totais 9/11/13/15. Receita inicial preservada; melhorias usam
a bolsa anterior equipada, madeira e linha, substituindo sem empilhar bônus.
Retirada bloqueada com espaços extras ocupados. Restauração validada preserva
propriedades e recusa estados inconsistentes sem substituir o estado atual.
Linha será obtida das aranhas na etapa 4; testes desta etapa fornecem ingredientes
na fixture, sem alterar os recursos da publicação.

Validação: 25 verificações Godot e 14 verificações de interface Web com mouse
e toque emulado (quatro melhorias, quinze slots, fechar e ausência de erros).
As 12 verificações da fabricação continuam passando.
Auditoria antes da persistência: código só acessa FileAccess na configuração
pública Firebase; README informa ausência de save. Pasta user:// contém
somente caches, logs e snapshots internos do Godot; nenhum save a converter.
Nenhuma migração aplicada. Salvamento em disco ainda pertence à etapa 3.

## Etapa 3: baú, arco, flechas e persistência local

Baú construível: 20 madeiras/8 pedras, 12 slots, Guardar/Retirar 1 ou pilha,
mesmos botões PC/toque, transferência preparada antes dos sinais, propriedades
de arma/cantil preservadas, desmontagem bloqueada quando cheio.
Arco 8 madeiras/3 linhas, dano 12, intervalo 1 s; flechas 2 madeiras/1 pedra
produzem 4, limitadas por pilha e capacidade. Só tiro válido consome munição;
mira cancelada, menu e cooldown bloqueiam consumo; projétil colide com paredes.

Persistência local: user://solo-progress.json, arquivo temporário e backup anterior,
sem dados da autenticação. Inventário, baús, cama de reaparecimento, estruturas,
vida/necessidades, relógio, drops, recursos restantes e loot vasculhado.
Saves inválidos são preservados e bloqueiam sobrescrita. Web usa IndexedDB do
navegador; teste de recarregar a página confirma persistência, sem nuvem/custo.
Não havia save real anterior: conversão/backup foi testada em fixture sintética,
não é declaração de migração de progresso real.

Validação: 25 verificações Godot, 18 de navegador com mouse/toque (incluindo
reload com baú e munição preservados), 6 regressões da coleta. Nenhum celular físico.
Etapas 1/2 já registradas nos commits 0a138cb / ea8e0d2; push das etapas de gameplay
ainda pendente até consolidar a atualização.

## Etapa 4: monstros e veneno

Esqueleto e aranha entram na rotação do spawner existente, com o mesmo limite
noturno total de cinco. Esqueleto: flecha de dano 10/velocidade 240, intervalo
mínimo 2,5 s, aviso 0,65 s com direção capturada e LOS antes de iniciar/liberar.
Aranha: 4 danos/1,5 s, veneno 3 s com um dano/s; novo ataque renova duração
sem empilhar. Veneno congela na pausa, termina no respawn e integra o save.
Drops no chão: flechas 70/25/5% para 1/2/3; linha 75/25% para 1/2.

Validação: 18 verificações Godot (desvio, paredes, veneno, pausa, respawn,
distribuições e limite compartilhado), 25 regressões baú/arco/save.
Capturas Web desktop e resolução de celular revisadas, sem erros do navegador.
Não houve teste em aparelho físico. Etapa 3: commit dbfef4b.

## Etapas 5/6: animais e Aquático

Implementadas juntas por dependência do terreno: lambari/tilápia com aparências
distintas, cada um deixa uma carne de peixe; receita e consumo de peixe cozido
na fogueira. Peixes permanecem na água, com colisão e drops coletáveis pelo
combate/controle existentes. Garça-azul azul/cinza, bico/penas/pernas, fuga rápida,
colisão pequena, uma carne; chance 2% por tentativa válida, intervalo >=60 s,
no máximo uma ave. Fixture força o sorteio apenas para testar, não no jogo.

Duas regiões Aquáticas a oeste/norte, sem deslocar coordenadas antigas.
Amostragem de terreno: 78,9% água; ilhas, margens e passagens conectadas.
Nado 60% com indicação visual, retorno automático à velocidade terrestre.
Construção requer solo e drops usam limites atuais. Bordas físicas agrupadas.

Validação: 29 verificações Godot, 10 de navegador mouse/toque (caçar e coletar
peixe na água, movimento e transição); 12 fabricação e 25 baú/save continuam
passando. Capturas da ave/água revisadas. Rótulos da barra rápida reduzidos a
duas linhas para não cortar carne de peixe no rodapé. Nenhum celular físico.
Etapa 4: commit d06789b. Ainda faltam Ruínas, outras regiões, minimapa, poços,
peças de base e publicação final das etapas de gameplay.

## Etapa 7: Ruínas Escuras

Duas regiões oeste/sul, quatro templos grandes ao todo, salas e corredores com
entrada acessível. Cada templo tem 3–5 baús e orçamento total de seis unidades,
dividido entre eles. Guardiões existentes com configuração própria, limite quatro,
independentes da população noturna; regras das construções antigas mantidas.
Escuridão no contexto do jogador ao entrar; sair restaura o horário global.
Dormir é bloqueado com motivo e sem avançar relógio. A semente do mundo agora
é persistida e carregada antes da geração; loot dos recipientes não é sorteado
novamente. Novas regiões não perdem recursos ao carregar um save anterior.

Validação: 27 verificações Godot, 8 de navegador teclado/toque (entrada física
e luz ao entrar/sair), 26 regressões de baú/save, incluindo semente e todos
os recipientes. Captura de templo em celular emulado revisada. Nenhum aparelho real.
Etapas 5/6: commit d0d63a4. Gameplay ainda não enviado ao Pages.

## Etapa 8: expansão e minimapa

16 regiões no total: quatro originais preservadas, duas novas Florestas/Pântanos/
Campos/Desertos e duas Aquáticas/Ruínas. Norte/sul/oeste conectados, câmera
-3072,-1536 até 6912,3072. Aberturas nas árvores do perímetro liberam acessos
centrais; coordenadas antigas e bases não se deslocam. Novos recursos em terra.
Minimapa circular direito com cores, orientação e exploração persistida, sem
interceptar mouse/toque. IA, animação e colisão de animais/guardiões distantes
desativadas e reativadas por proximidade; noturnos muito distantes são removidos
para manter o limite compartilhado útil na região ativa. Bordas físicas agrupadas.

Validação: 14 verificações Godot, 18 de navegador desktop e celular emulado
852×393/DPR3, incluindo travessia real do norte por teclado/toque e minimapa.
18 monstros e 27 Ruínas continuam passando. Captura mobile revisada.
Etapa 7: commit 72be039. Publicação de gameplay ainda pendente.

## Etapa 9: decisão atual — manter os poços

O usuário adiou expressamente os 35% e a rejeição de mundos sem poço.
A proposta de sorteio foi retirada antes de qualquer publicação.
Os quatro poços originais ficam em 1310,768 / 3000,768 / 4520,768 / 6030,768.
Cada nova região segue a regra anterior de um poço fixo, em terra acessível;
total 16. Nenhum RNG decide presença/ausência. Layout fixo persistido.
Save versão 3 aceita formatos anteriores e guarda bytes em before-v3 antes
de converter; também recupera a distribuição fixa caso exista save do rascunho.
Construções e inventário preservados; poços novos evitam bases salvas.

Validação: 12 verificações Godot e 10 de navegador mouse/toque (beber, encher,
uma dose por uso, reload sem mudar layout); 26 regressões baú/arco/save.
Etapa 8: commit 95450e7. Nada da proposta de 35% foi enviado ao GitHub.

## Etapa 10: peças de base

Parede/porta/vidraça custam 4 madeiras / 6 madeiras / 4 madeiras+2 vidros.
Vidro usa o orçamento de saque anterior, inclusive nos templos.
Sistema de colocação existente: grade 32 nas peças, prévia, R/Girar para orientar,
confirmar/cancelar PC/toque; só consome após validar alcance, terra e colisões.
Porta aberta libera passagem; fechada bloqueia. Não fecha sobre personagens.
Vidro transparente à visão usa camada própria que bloqueia corpos/projéteis,
ações e coleta, preservando LOS visual. Save conserva posição, orientação
e estado da porta. Equilíbrio documentado em docs/EQUILIBRIO.md.

Validação: 25 verificações Godot e 16 de navegador mouse/toque, incluindo
rotação, abrir/fechar, cancelamento e reload com base/porta aberta.
Etapa dos poços fixos: commit b4f8377.

## Etapa 11: persistência e validação final

Save versão 3, gravação temporária verificada antes da substituição e backup.
Formatos antigos aceitos; arquivo inválido/futuro preservado sem sobrescrever.
Inventário, equipamento, propriedades dos itens, bases, portas, baús, loot,
recursos coletados, semente, exploração e distribuição fixa conservados.
Migração de um save local v1 conferida: inventário/jogador idênticos, duas bases
e loot anteriores preservados; bytes originais disponíveis no before-v3.
Testes de menu e rede agora usam arquivos separados para evitar carregar
progresso pessoal. Limites antigos dos testes atualizados para o mapa expandido.
HUD compacto não cobre o personagem; animais terrestres distantes ficam
inativos, preservando os antigos e limitando a população total em 48.

Validação: 405 verificações headless; 48 na janela Godot Compatibility;
71 em duas instâncias reais ENet; 114 no navegador com mouse/toque emulado.
Após o ajuste final, repetidos fabricação/base (36), menu/mobile (38),
animais/aquático/expansão (77) e smoke da exportação principal Firebase.
Falha de cena proposital verifica mensagem e nova tentativa; não é falha
da partida normal. Sem teste em celular físico ou login positivo simulado.
Etapa 10: commit 571577f. Histórico mantém um commit por etapa funcional.

## Atualização 0.7: sobrevivência e mundos locais

Interface/orientação: `519454c`. Mecânicas/mundo: `158cb60`. Terceira etapa
reúne lobby, saves por UID + mundo, migração confirmada e validação final.
Barras coloridas com valores internos, relógio global, cura sem acumular,
armadura de pedra e cinco objetivos sequenciais. Regiões terrestres da expansão
recebem prédios com IDs persistentes, preservando bases, recursos e os 16 poços.
Loot consumido não é reposto ao carregar.

Lobby mostra personagem, lista/nome/último acesso dos mundos e histórico apenas
de conexões realizadas. Save v5 com backups e migração do mundo anterior, mantendo
o original. Falha de gravação impede retorno/logout voluntário sem descartar estado.
Mobile exige horizontal após autenticação, com pausa solo e entradas liberadas.
Login nativo no navegador e controle de toque em computadores permanecem.

Validação: 591 verificações em 28 scripts headless; 72 em dois processos ENet;
41 no navegador PC/mobile emulado, com autenticação positiva isolada na fixture;
28 de digitação e rejeição pelo Firebase real. Zero falhas nas execuções finais.
Capturas de lobby/HUD/rotação revisadas. Nenhum celular físico: roteiro curto e
detalhes em `docs/ATUALIZACAO_MUNDOS.md`. Publicação conserva o workflow Pages.
