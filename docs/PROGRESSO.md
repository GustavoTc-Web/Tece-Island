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

Publicação desta etapa: commit/deploy em andamento; atualizar após confirmação.

## Próxima etapa

1. Investigar nitidez comparando a mesma cena em desktop e resolução de celular.
2. Organizar receitas em Ferramentas, Recursos e Alimentos; cozidos somente na fogueira.
3. Acrescentar apresentação de resultado, quantidade e ingredientes disponíveis/necessários.

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
