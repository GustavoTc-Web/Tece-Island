# Valores de equilíbrio

- Receitas, ingredientes e quantidade produzida: scripts/resource_rules.gd.
- Capacidade básica e limite por pilha: scripts/inventory.gd (7 e 15).
  Bolsa concede backpack_bonus × nível; padrão 2, níveis 1–4.
- Arco e armas: scripts/gun_rules.gd (arco 12 danos, 1 s, uma flecha).
- Monstros: exports de scripts/forest_creature.gd. Esqueleto 10 danos,
  intervalo mínimo 2,5 s, aviso 0,65 s, flecha 240 px/s.
  Aranha 4 danos, 1,5 s, veneno 3 s; Player aplica um dano/s sem empilhar.
  Distribuições dos drops estão em drop_quantity do mesmo arquivo.
- População noturna: exports de scripts/enemy_spawner.gd; cinco no total.
  Ruínas: scripts/ruins_system.gd; quatro guardiões e seis unidades por templo.
- Animais: scripts/animal.gd e exports de scripts/animal_spawner.gd.
  Garça: 2% por tentativa válida, >=60 s, no máximo uma.
- Terreno, área de água e nado: scripts/world_terrain.gd; nado 60%.
- Ciclo: scripts/day_night.gd; dia/noite 300 s cada, transição 30 s.
- Fome/sede: scripts/survival.gd; 5/8 por minuto, restaurações 30/40.
- Colocação: scripts/structure_system.gd; alcance 110, tolerância de encaixe 6,
  grade 32 nas peças de base e 8 em cama/fogueira/baú.

Poços continuam fixos: um por região, quatro originais nas coordenadas antigas.
A mudança para 35% foi adiada pelo usuário e não integra esta publicação.
Vidro ocupa entradas do saque existente; não acrescenta unidades ao orçamento.
Não há ranking nem terceiro bioma novo nesta atualização.
