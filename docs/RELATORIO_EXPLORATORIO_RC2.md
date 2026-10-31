# Rodada exploratória da RC2 — não iniciada

Versão congelada: **0.9.1-beta-rc.2**, jogo
`7c254c1f8454d768228c171cf6fa040b5eb322dc`.
Site privado publicado em 31/10/2026, versão interna 2. O cliente servido teve
manifesto e 19 arquivos conferidos por hash. Não houve mudanças de código do jogo
depois desse congelamento; os commits seguintes só finalizam testes e registros.

## Ponto exato da interrupção

Ambiente: Windows, janela separada do Edge com perfil de teste dentro de
`.tools/exploratory-edge-profile`, endereço solicitado:
https://tece-island-solo-beta.gustavotccandido.chatgpt.site/Tece-Island/ .

Foi aberta uma janela que o inventário identificou como
`É necessário entrar - Perfil 1`. Na tentativa de obter seu estado, o controlador
encerrou o Computer Use com o motivo:

> could not determine the current browser URL on Windows with enough confidence to enforce policy

Frequência: uma tentativa de captura, um encerramento. O controlador não
devolveu captura da página ou estado suficiente para iniciar ações. A orientação
da skill exige interromper entradas quando o controle termina; nenhum método
alternativo foi usado para contornar a proteção.

Classificação: **limitação da ferramenta antes do login**, não um defeito de
campanha demonstrado. Não houve login positivo de produção, criação de mundo
exploratório, dia jogado, morte/nova tentativa, vitória ou Continuar explorando
nesta rodada. A causa interna da falha de reconhecimento da URL não foi
diagnosticada. Nenhuma senha/token foi solicitado ou registrado.

Próximo passo: o usuário autoriza o acesso ao Site privado e faz o login Firebase
diretamente nessa janela, deixando o jogo no lobby, sem abrir um mundo principal.
Na retomada, o controlador precisa reconhecer o endereço com segurança antes
de prosseguir. Criar então um mundo novo de teste e usar somente controles/UI
normais, sem concessão de itens, edição de save, aceleração, teleporte ou vitória
por código. Se o controle continuar indisponível, registrar esse bloqueio.

## Bugs adicionais da rodada

**Nenhum bug adicional de jogabilidade foi confirmado: a rodada não começou.**
Não há evidência para aprovar uma campanha completa ou afirmar ausência de bugs.
As verificações preparadas de templos, sono, morte, reabertura e vitória são
testes técnicos separados; não substituem esse percurso.

Quando a rodada puder ocorrer, cada ocorrência deve registrar versão/ambiente,
dia/etapa, passos, esperado/observado, impacto, evidência/frequência e hipótese
separada de causa confirmada. Problemas adicionais aguardam avaliação do usuário;
não serão corrigidos automaticamente após encontrá-los.

## Limites dos resultados entregues

Confirmados por automação: os cinco ajustes solicitados, migração de cópias,
persistência, regras de chat no emulador e integridade do pacote privado.
Preparação das regras/configurações Firebase concluída; aplicação remota e
abertura a novas contas pendentes. Não há acesso administrativo ativo na CLI.

Permanecem físicos: campanha completa desta RC2, sensação de controle/desempenho,
som audível, teclado do aparelho, rotação e suspensão/retomada reais; casas/templos
e organização do inventário nos aparelhos do usuário. Nenhum desses itens foi
marcado como aprovado nesta revisão.
