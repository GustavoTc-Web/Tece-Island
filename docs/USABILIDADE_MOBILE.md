# Usabilidade mobile

## Login — causa e correção

Reprodução na exportação anterior, Godot 4.7.2, Edge/Windows com toque
emulado: o primeiro toque no e-mail previamente focado deixava o canvas ativo;
trocar para senha ativava o input oculto do teclado virtual; tocar novamente
desativava esse input e devolvia o foco ao canvas. O `MobileInput` consumia o
toque e chamava `LineEdit.edit()`, enquanto o adaptador Web usava um input
oculto, desativado no blur. Não houve evidência de falha no Firebase.

A autenticação Web usa agora inputs HTML visíveis, com teclado de e-mail,
edição nativa, seleção/colagem, senha sem capitalização ou correção e rolagem
com `visualViewport`. O formulário envia operações ao `FirebaseAuth` existente
via `JavaScriptBridge`; não há outro serviço, SDK ou armazenamento de sessão.
O formulário nativo do Godot permanece. Tokens continuam apenas em memória.

Referências oficiais: [teclado virtual Web](https://docs.godotengine.org/en/stable/classes/class_editorexportplatformweb.html)
e [integração JavaScript](https://docs.godotengine.org/en/stable/tutorials/web/javascript_bridge.html).
O template instalado contém `GodotDisplayVK`: input oculto, focus no show e
desativação no blur. Essa investigação inspecionou o template realmente exportado.

### Testes da etapa de login

- `node tools/login-focus-reproduction.mjs`: reproduziu o problema anterior;
  executar contra a versão anterior (teste histórico).
- `node tools/mobile-login-validation.mjs`: 28 verificações no Edge Chromium
  instalado no Windows, desktop 960×540 e toque emulado 393×852/852×393,
  viewport reduzido a 393×300. Foco, edição, colagem real do clipboard, exclusão,
  cursor, mostrar/ocultar, modos cadastro/recuperação e rotação.
- Duas solicitações reais de login com credenciais de teste inválidas:
  rejeitadas pelo Firebase; mensagem e nova tentativa disponíveis.
- `tests/native_auth_ui_probe.gd`: 5 verificações com renderização nativa
  Compatibility/Intel Iris Xe; `tests/validate_auth_release.gd`: 10 verificações
  de configuração, bloqueio de entrada, expiração e logout sem sessão positiva.

Nenhum celular físico, Safari ou teclado virtual real foi testado nesta etapa.
A redução do viewport simula espaço disponível; não prova funcionamento de IME.
Cadastro/confirmar/recuperar com conta real foram validados pelo proprietário
na versão anterior, e precisam de nova conferência da apresentação no aparelho.

### Conferência no celular físico

1. Abra https://gustavotc-web.github.io/Tece-Island/ no aparelho e informe
   aparelho, navegador e versão caso encontre uma falha.
2. Toque uma vez no e-mail; digite, selecione, cole e apague. Troque para senha,
   incluindo maiúsculas e símbolos. Confira mostrar/ocultar e a posição do cursor.
3. Com o teclado aberto, role até Entrar; gire o aparelho nas duas orientações,
   feche/reabra o teclado e confirme que o texto continua intacto.
4. Confira cadastro, confirmação e recuperação com sua própria conta;
   nunca envie senha ou tokens pelo chat.
