# Atualização — registro para retomada

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

## Próxima etapa

4. Esqueletos/aranhas, veneno e drops que fornecem flechas/linha.

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

## Etapas seguintes solicitadas

2. Bolsas de quatro níveis e melhorias atômicas.
3. Baú construível, transferências, arco e flechas.
4. Esqueletos e aranhas, veneno e drops.
5. Peixes e Garça-azul.
6. Aquático e nado.
7. Ruínas Escuras e templos.
8. Expansão para norte/sul/oeste e minimapa.
9. Poços por região, sorteio persistente e migração segura.
10. Paredes, portas e vidraças.
11. Persistência, validação final e publicação.

Antes de persistência/migração, conferir saves realmente existentes e fazer
backup. A documentação anterior declara que a versão atual não tem salvamento;
não presumir um formato sem examinar o código e os arquivos.
Preservar as coordenadas atuais e as correções dos controles.
