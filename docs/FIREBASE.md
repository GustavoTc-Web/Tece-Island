# Firebase Authentication — teste real e publicação

O projeto usa somente Firebase Authentication por e-mail/senha no plano Spark.
Não foram habilitados faturamento, SMS, banco de dados, Functions ou serviços
adicionais. O serviço REST GDScript é compartilhado pelo PC e pela Web.

## Configuração atual

Os valores públicos fornecidos estão em config/firebase-public.json:
apiKey, authDomain e projectId. O retorno mantém
https://gustavotc-web.github.io/Tece-Island/. **enabled está true.**
Godot/F5 e Web carregam a mesma configuração pública, sem substituição local
por arquivo de desenvolvimento e sem depender da cópia especial de teste.
O cliente não contém credenciais administrativas ou chave de conta de serviço.

Em Firebase Console → Authentication:

1. Confirme E-mail/senha em Sign-in method.
2. Em Settings → Authorized domains, adicione gustavotc-web.github.io e localhost.
   Cadastre domínios sem protocolo, porta ou caminho.
3. Em Templates, confira os e-mails de verificação e recuperação em português.
   Mantenha o manipulador de ações padrão do Firebase no domínio do projeto.
4. Mantenha o plano Spark e não vincule Cloud Billing.

O jogo envia a URL completa de retorno com /Tece-Island/. O Firebase abre seu
manipulador seguro para confirmar o e-mail ou definir a nova senha. Ao terminar,
volte à aba local do teste. Continuar no e-mail pode abrir a página pública;
isso não autentica automaticamente a cópia local.

Referências: [API REST](https://firebase.google.com/docs/reference/rest/auth),
[domínios e retorno dos e-mails](https://firebase.google.com/docs/auth/web/passing-state-in-email-actions),
[limites gratuitos](https://firebase.google.com/docs/auth/limits).
Se um limite for atingido, a interface informa a falha e permite tentar mais tarde;
não realiza upgrade nem contratação automática.

## Abrir a versão de teste real

Na pasta do projeto, execute:

    powershell -NoProfile -ExecutionPolicy Bypass -File tools/export-auth-test.ps1 -Godot "C:/Users/gusta/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
    node tools/serve-web.mjs 8083 build/auth-test

Abra **http://localhost:8083/Tece-Island/**.
O teste usa Firebase real e exige login somente na cópia
.tools/auth-real-project/, exportada para build/auth-test/.
Ele não modifica a configuração nem os arquivos da publicação atual.

Para PC nativo, importe .tools/auth-real-project/project.godot no Godot e use F5.
No celular na mesma rede, abra http://IP-DO-PC:8083/Tece-Island/; permita a porta
8083 no firewall se necessário. Se mudar o retorno para esse host, autorize-o
também no Firebase. Mantenha /Tece-Island/ no caminho.

Esta versão não contém as interfaces de inspeção dos testes automatizados.
Digite a senha somente no formulário local. Não envie senha, tokens ou links
de confirmação/recuperação no chat.

## Roteiro da sua conta

1. Escolha Criar conta e preencha seu e-mail, senha e confirmação.
2. Cadastre. A mensagem deve orientar a confirmação, mantendo o jogo bloqueado.
3. Confira caixa de entrada e spam. Abra o link enviado pelo Firebase.
4. Volte à aba local e use Já confirmei, ou entre novamente com e-mail e senha.
   Só uma conta confirmada deve abrir o menu.
5. Abra solo, retorne ao menu e use Sair da conta. A tela de entrada deve voltar.
6. Recarregue a página: a sessão deve desaparecer, pois não há lembrar de mim.
7. Tente uma senha incorreta: a mensagem deve informar credenciais inválidas.
8. Use Esqueci minha senha. Abra o e-mail, defina nova senha na página do Firebase
   e volte ao teste local para entrar com ela.
9. Confira renovação durante uso e retorno após expiração/perda de conexão.

## Sessão

Cadastro mantém apenas uma sessão temporária em memória para enviar/reenviar a
confirmação; isso não autoriza jogar. Login consulta accounts:lookup e exige
emailVerified verdadeiro e o identificador do usuário correspondente.
Renovação usa Secure Token sem reabrir o menu ou reiniciar a partida.
Expiração ou credenciais revogadas voltam à entrada. Logout limpa a memória.
Não são usados arquivos, cookies de sessão do jogo ou localStorage para tokens.
Senhas e tokens não são registrados pelo serviço.

## Resultados e limites dos testes

- Testes locais: formulários, mostrar/ocultar senha, bloqueio de partida,
  configuração ausente e limpeza da memória. Nenhum login positivo foi simulado.
- PC nativo: teclado, mouse e renderização do formulário.
- Backend real: login com credenciais inválidas foi rejeitado, sem cadastrar
  contas ou enviar e-mails, no Godot nativo e no navegador.
- Navegador: formulários com teclado/mouse e toque emulado. O comando
  node tools/auth-ui-validation.mjs --live-invalid também testa a rejeição real.
- O usuário confirmou o teste real de cadastro, confirmação de e-mail, login e
  recuperação de senha antes de autorizar a publicação.
- Validação local da ativação: configuração do projeto principal, bloqueio sem
  sessão, expiração e limpeza de tokens no logout.
- Renovação automática e logout de uma sessão real continuam sujeitos à
  verificação manual, sem fornecer senha ou tokens ao assistente.
- Celular físico e teclado virtual precisam de verificação manual.

Foi corrigida a descompressão duplicada na Web: o navegador já entrega o corpo
HTTP descomprimido, portanto o serviço desativa accept_gzip no HTTPRequest Web.
Isso evita tratar respostas válidas do Firebase como falha de conexão.

## Publicação no GitHub Pages

O login obrigatório foi autorizado após a validação real informada pelo usuário.
Em Settings → Secrets and variables → Actions → Variables, configure:

| Variável pública | Valor |
| --- | --- |
| FIREBASE_API_KEY | Web API Key fornecida |
| FIREBASE_AUTH_DOMAIN | tece-island-285cd.firebaseapp.com |
| FIREBASE_PROJECT_ID | tece-island-285cd |
| FIREBASE_AUTH_ENABLED | true |

O workflow gera o JSON que acompanha a exportação, sem depender das variáveis
do notebook. Ele recusa ativação com configuração incompleta.
Push em main publica a exportação com autenticação obrigatória. Confira o deploy
e a tela de entrada no mesmo endereço HTTPS. Senhas, tokens e chaves de conta
de serviço não são variáveis de build nem arquivos da exportação.
