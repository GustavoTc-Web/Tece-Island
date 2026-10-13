# Tece-Island 0.7 · Mundos e sobrevivência

Login obrigatório e campos nativos de autenticação preservados. O lobby mostra
o personagem usado no solo, mundos locais por conta e conexões ENet realizadas.
Nenhum serviço pago, servidor adicional ou sincronização entre aparelhos.
Na Web, o histórico informa quando está vazio; ENet e reconexão continuam no desktop.

## Interface e orientação

Vida vermelha, água azul, fome amarela e proteção roxa usam fundo cinza e valores
internos com contorno. Água/fome indicam reserva restante. O HUD consulta o relógio
global: 300 segundos de dia e 300 de noite, inclusive transições. Ruínas mantêm
escuridão local permanente e aviso ao entrar, sem mudar o relógio global.

O celular pode autenticar em qualquer orientação. Depois disso, retrato apresenta
ícone de rotação e aviso; paisagem libera automaticamente o lobby/jogo. Tela cheia
e orientação são solicitadas por toque e podem ser recusadas pelo navegador.
O solo pausa e libera entradas mantidas; multiplayer bloqueia comandos locais.
A opção de testar toque no PC não transforma computadores em celulares.

Salvando… aparece durante a gravação; Salvo só após confirmação do armazenamento
e desaparece em dois segundos. Falha permanece com botão de nova tentativa.
Retorno ao lobby e logout aguardam salvamento; falha voluntária conserva a partida.

## Mecânicas e objetivos

Comida válida mantém +30 de fome, consome uma unidade e inicia cinco ticks de
5 HP, separados por um segundo da simulação. Novo consumo renova cinco ticks,
sem efeitos paralelos. Pausa congela o temporizador; morte ou descarte da partida
cancela o efeito. É permitido comer com fome cheia quando falta vida.

Armadura de pedra custa 20 pedras +4 linhas, na categoria Armaduras. Equipar
transfere o item para campo próprio e concede 10/100 de proteção. Retirada exige
espaço; troca conserva a armadura anterior. Dano de golpes/projéteis usa
`dano × 100 / (100 + proteção)`, com vida fracionária. Veneno, fome e sede mantêm
seus danos. Inventário, slot de armadura e vida fracionária são persistidos.

Cinco etapas: 10 madeiras, 10 pedras, picareta/machado/espada de pedra, uma fogueira
e bolsa nível 3. Apenas a etapa ativa aparece no HUD; Objetivos abre a lista,
incluindo os três equipamentos marcados separadamente. Crafts antecipados ficam
registrados. Conclusão emite som curto com as preferências de volume/silêncio e
destaque temporário. O save guarda conclusões apresentadas; carregar não repete
sons. O Diário e seus três registros permanecem.

Migração de objetivos conserva coleta de madeira já registrada e reconhece
equipamentos/bolsas/fogueiras existentes, produzidos apenas por fabricação no solo.
Não inventa coletas passadas a partir de materiais ou marcos genéricos antigos.

## Construções e dados

Cada região terrestre é verificada pelo ID, não pelo nome do bioma. Regiões vazias
recebem até três construções, em espaços que comportem prédio e entrada, evitando
recursos, bases e poços. Floresta/Pântano usam casas, Campos fazendas e Deserto
ruínas de barro. Templos e regras próprias das Ruínas permanecem. Regiões sem
espaço livre voltam a ser avaliadas ao carregar, preservando bases existentes.
Layout, IDs, semente e saque consumido ficam no save; recarregar não duplica
prédios nem repõe loot. A distribuição fixa dos 16 poços permanece.

Save v5: `accounts/<hash UID>/worlds/<ID>/progress.json`; catálogo `worlds.json`.
IndexedDB conserva a base existente e utiliza chaves por UID + mundo. O save
anterior da conta migra para ID determinístico `first-world`, chamado Meu primeiro
mundo. Primeiro cria backup/cópia, confirma a leitura e só então grava o catálogo.
O original fica intacto. Repetir após interrupção reutiliza o mesmo destino.
A importação antiga sem dono continua explícita e única; não substitui progresso.

## Roteiro curto no celular físico

1. Abra o mesmo Pages na vertical. Digite, edite e alterne login/cadastro/recuperação;
   entre com sua conta. Confira o aviso e gire para acessar o lobby.
2. Crie dois mundos com nomes diferentes, renomeie um e entre. Mova/ataque com dois
   dedos; gire para vertical enquanto os segura. Confira pausa e comandos soltos.
3. Volte à horizontal, abra inventário, coma e equipe/retire armadura. Confira
   barras, cura em cinco segundos e suspensão da cura enquanto o painel estiver aberto.
4. Registre objetivos, volte ao lobby e alterne mundos. Itens, armadura, construções
   e objetivos devem ficar no mundo original; repita saindo e entrando em outra conta.
5. Visite novas regiões e ruínas; confira entradas, relógio e escuridão. Recarregue,
   entre novamente e confira construções e baús consumidos.
6. Teste tela cheia, recusa do bloqueio de orientação, teclado real, troca de aba e
   bloqueio/desbloqueio do aparelho. Observe desempenho e bordas/áreas seguras.

Os testes de navegador usam mouse e toque emulado; a autenticação positiva é
interceptada exclusivamente na fixture de testes. A exportação principal também
é testada com Firebase real e credenciais inválidas. Nenhum celular físico foi usado.
