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

2. Bolsas de quatro níveis: melhorias atômicas, capacidade, preservação de itens.
Depois baú/arco/flechas e persistência; conferir saves e backup antes de migrar.

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
